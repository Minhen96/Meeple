package com.meeplehearth.game.service;

import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.GameDetail;
import com.meeplehearth.game.repository.GameDetailRepository;
import com.meeplehearth.game.repository.GameRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Fills BGG metadata (images, player counts, mechanics, ...) into imported games.
 *
 * BGG calls never run inside a DB transaction: details are fetched first, then
 * persisted in one short transaction per batch.
 */
@Service
public class GameHydrationService {

    private static final Logger log = LoggerFactory.getLogger(GameHydrationService.class);
    private static final int BGG_BATCH_SIZE = 20;
    /** Bulk run stops after this many consecutive batches that saved nothing. */
    static final int MAX_CONSECUTIVE_EMPTY_BATCHES = 3;
    /** Bulk run stops after this many consecutive BGG failures (with exponential backoff between). */
    static final int MAX_CONSECUTIVE_FAILURES = 5;
    private static final long MAX_BACKOFF_MS = Duration.ofMinutes(10).toMillis();

    public  static final String STOP_FLAG_KEY = "stop:hydration";
    static final String RUN_LOCK_KEY = "lock:hydration-run";
    private static final Duration RUN_LOCK_TTL = Duration.ofMinutes(30);

    private final GameRepository gameRepository;
    private final GameDetailRepository gameDetailRepository;
    private final BggApiClient bggApiClient;
    private final StringRedisTemplate redis;
    private final TransactionTemplate transactionTemplate;
    private final long batchDelayMs;
    private final long failureBackoffMs;
    private final Duration retryAfter;

    public GameHydrationService(GameRepository gameRepository,
                                GameDetailRepository gameDetailRepository,
                                BggApiClient bggApiClient,
                                StringRedisTemplate redis,
                                PlatformTransactionManager transactionManager,
                                @Value("${app.hydration.batch-delay-ms:1100}") long batchDelayMs,
                                @Value("${app.hydration.failure-backoff-ms:30000}") long failureBackoffMs,
                                @Value("${app.hydration.retry-after-hours:168}") long retryAfterHours) {
        this.gameRepository = gameRepository;
        this.gameDetailRepository = gameDetailRepository;
        this.bggApiClient = bggApiClient;
        this.redis = redis;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
        this.batchDelayMs = batchDelayMs;
        this.failureBackoffMs = failureBackoffMs;
        this.retryAfter = Duration.ofHours(retryAfterHours);
    }

    /** Called from browse — async, fires and forgets hydration for the current page */
    @Async
    public void hydrateImagesQuietly(List<Long> bggIds) {
        try {
            hydrateBatch(bggIds);
        } catch (BggApiClient.BggUnavailableException e) {
            log.debug("Background hydration skipped — BGG unavailable: {}", e.getMessage());
        } catch (RuntimeException e) {
            log.warn("Background hydration failed for {}: {}", bggIds, e.getMessage());
        }
    }

    /**
     * Called from getGame() — sync so the detail page gets full data on first load.
     * Must be called outside a transaction. Returns true if the game was updated.
     */
    public boolean hydrateImageSync(Game game) {
        if (game.getMinPlayers() != null || game.getBggId() == null) return false;
        try {
            return hydrateBatch(List.of(game.getBggId())) > 0;
        } catch (BggApiClient.BggUnavailableException e) {
            log.warn("Hydration for game {} skipped — BGG unavailable: {}", game.getId(), e.getMessage());
            return false;
        } catch (RuntimeException e) {
            // Never fail the detail page because of hydration; serve the data we have
            log.warn("Hydration for game {} failed: {}", game.getId(), e.getMessage());
            return false;
        }
    }

    /**
     * Bulk hydration — iterates games with missing minPlayers in batches of 20.
     * Fills in: thumbnail, image, minPlayers, maxPlayers, playTime, gameType,
     * mechanics, categories, subdomains, designers, artists, publishers, honors,
     * expansions, bggUrl.
     * Run once after import via POST /api/v1/games/hydrate-images.
     * Takes ~3 hours for 161k games due to BGG rate limiting.
     */
    @Async
    public void hydrateAllMissingImages() {
        runBulkHydration();
    }

    /**
     * Synchronous body of the bulk run. Terminates when:
     *   - no unattempted games remain (each attempted game gets hydration_attempted_at,
     *     so games BGG has no data for are not re-requested within {@code retryAfter})
     *   - {@value #MAX_CONSECUTIVE_EMPTY_BATCHES} consecutive batches save nothing
     *   - {@value #MAX_CONSECUTIVE_FAILURES} consecutive BGG failures (exponential backoff)
     *   - the Redis stop flag is set
     *
     * @return number of games hydrated
     */
    int runBulkHydration() {
        if (!Boolean.TRUE.equals(redis.opsForValue().setIfAbsent(RUN_LOCK_KEY, "1", RUN_LOCK_TTL))) {
            log.info("Bulk hydration already running on another instance — skipping.");
            return 0;
        }

        log.info("Starting bulk hydration for all unhydrated games...");
        int total = 0;
        int emptyBatches = 0;
        int failures = 0;
        try {
            while (true) {
                if (Boolean.TRUE.equals(redis.hasKey(STOP_FLAG_KEY))) {
                    log.info("Hydration stop requested — stopping at {} games hydrated.", total);
                    break;
                }

                Instant cutoff = Instant.now().minus(retryAfter);
                List<Game> batch = gameRepository.findHydrationCandidates(cutoff, PageRequest.of(0, BGG_BATCH_SIZE));
                if (batch.isEmpty()) break;

                List<UUID> gameIds = batch.stream().map(Game::getId).toList();
                List<Long> bggIds = batch.stream().map(Game::getBggId).filter(Objects::nonNull).toList();

                int saved;
                try {
                    saved = hydrateBatch(bggIds);
                } catch (BggApiClient.BggUnavailableException e) {
                    failures++;
                    if (failures >= MAX_CONSECUTIVE_FAILURES) {
                        log.warn("Bulk hydration aborted after {} consecutive BGG failures: {}", failures, e.getMessage());
                        break;
                    }
                    long backoff = Math.min(MAX_BACKOFF_MS, failureBackoffMs * (1L << (failures - 1)));
                    log.warn("BGG unavailable ({}), backing off {} ms (failure {}/{})",
                            e.getMessage(), backoff, failures, MAX_CONSECUTIVE_FAILURES);
                    if (!sleep(backoff)) break;
                    continue;
                }
                failures = 0;

                // Mark the whole batch as attempted so games BGG has no data for leave the candidate set
                Instant now = Instant.now();
                transactionTemplate.executeWithoutResult(status ->
                        gameRepository.markHydrationAttempted(gameIds, now));

                total += saved;
                if (saved == 0) {
                    emptyBatches++;
                    if (emptyBatches >= MAX_CONSECUTIVE_EMPTY_BATCHES) {
                        log.warn("Bulk hydration stopped: {} consecutive batches saved nothing.", emptyBatches);
                        break;
                    }
                } else {
                    emptyBatches = 0;
                }
                log.info("Bulk hydration progress: {} games hydrated so far...", total);

                redis.expire(RUN_LOCK_KEY, RUN_LOCK_TTL);
                long delay = saved == 0 ? Math.max(batchDelayMs, failureBackoffMs) : batchDelayMs;
                if (!sleep(delay)) break;
            }
        } finally {
            redis.delete(RUN_LOCK_KEY);
        }

        log.info("Bulk hydration complete. {} games hydrated.", total);
        return total;
    }

    // -------------------------------------------------------------------------

    private String normalizeUrl(String url) {
        if (url == null) return null;
        return url.startsWith("//") ? "https:" + url : url;
    }

    /**
     * Fetches details from BGG (no transaction), then persists them in one short transaction.
     *
     * @return number of games updated
     * @throws BggApiClient.BggUnavailableException if BGG failed for the whole batch / breaker is open
     */
    public int hydrateBatch(List<Long> bggIds) {
        if (bggIds == null || bggIds.isEmpty()) return 0;

        List<BggApiClient.BggGameDetail> details = bggApiClient.getDetails(bggIds);
        if (details.isEmpty()) return 0;

        Integer saved = transactionTemplate.execute(status -> persistDetails(details));
        return saved != null ? saved : 0;
    }

    private int persistDetails(List<BggApiClient.BggGameDetail> details) {
        Map<Long, BggApiClient.BggGameDetail> detailMap = details.stream()
                .collect(Collectors.toMap(BggApiClient.BggGameDetail::bggId, Function.identity(), (a, b) -> a));

        List<Game> games = gameRepository.findByBggIdIn(detailMap.keySet());
        Map<UUID, GameDetail> existingDetails = gameDetailRepository
                .findAllById(games.stream().map(Game::getId).toList())
                .stream()
                .collect(Collectors.toMap(GameDetail::getId, Function.identity()));

        int count = 0;
        for (Game g : games) {
            var d = detailMap.get(g.getBggId());
            if (d == null) continue;

            // Core game fields
            if (d.thumbnailUrl() != null) g.setThumbnailUrl(normalizeUrl(d.thumbnailUrl()));
            if (d.imageUrl() != null)     g.setImageUrl(normalizeUrl(d.imageUrl()));
            if (d.minPlayers() != null)   g.setMinPlayers(d.minPlayers());
            if (d.maxPlayers() != null)   g.setMaxPlayers(d.maxPlayers());
            if (d.minPlaytime() != null)  g.setPlayTime(d.minPlaytime());
            if (d.subtype() != null)      g.setGameType(d.subtype());

            // Sentinel: mark as hydrated even if BGG returned no player count
            if (g.getMinPlayers() == null) g.setMinPlayers(0);
            g.setHydrationAttemptedAt(Instant.now());

            // Update or create GameDetail
            GameDetail gd = existingDetails.get(g.getId());
            boolean isNew = gd == null;
            if (isNew) {
                gd = new GameDetail();
                gd.setGame(g);
            }
            if (d.mechanics()   != null && d.mechanics().length   > 0) gd.setMechanics(d.mechanics());
            if (d.categories()  != null && d.categories().length  > 0) gd.setCategories(d.categories());
            if (d.subdomains()  != null && d.subdomains().length  > 0) gd.setFamilies(d.subdomains());
            if (d.designers()   != null && d.designers().length   > 0) gd.setDesigners(d.designers());
            if (d.artists()     != null && d.artists().length     > 0) gd.setArtists(d.artists());
            if (d.publishers()  != null && d.publishers().length  > 0) gd.setPublishers(d.publishers());
            if (d.honors()      != null && d.honors().length      > 0) gd.setHonors(d.honors());
            if (d.expansions()  != null && d.expansions().length  > 0) gd.setExpansions(d.expansions());
            if (d.bggUrl()      != null)                               gd.setBggUrl(d.bggUrl());
            if (d.description() != null && !d.description().isBlank()) gd.setDescription(d.description());
            gd.setLastSyncedAt(Instant.now());
            if (isNew) gameDetailRepository.save(gd);

            count++;
        }
        if (count > 0) gameRepository.saveAll(games);
        return count;
    }

    /** Returns false if interrupted (caller should stop). */
    private boolean sleep(long ms) {
        if (ms <= 0) return true;
        try {
            Thread.sleep(ms);
            return true;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return false;
        }
    }
}
