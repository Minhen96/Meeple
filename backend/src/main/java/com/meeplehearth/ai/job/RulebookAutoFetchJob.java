package com.meeplehearth.ai.job;

import com.meeplehearth.ai.client.OnjRulebookClient;
import com.meeplehearth.ai.client.RuleBookOrgClient;
import com.meeplehearth.ai.client.RulebookUrlValidator;
import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.ai.service.RulebookIngestionRequestedEvent;
import com.meeplehearth.game.entity.Game;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

/**
 * One-time startup job: auto-fetches rulebooks for the top 2000 games by BGG
 * rank.
 *
 * Runs once on first application startup. A Redis flag (init:rulebook-fetch)
 * prevents
 * it from re-running on subsequent restarts. After the initial batch, new games
 * get
 * rulebooks either via the admin job trigger or through the on-demand "Generate
 * Rules"
 * button in the How To Play tab.
 *
 * Cost estimate: ~$0.40 one-time (text-embedding-3-small at $0.02/1M tokens).
 */
@Component
public class RulebookAutoFetchJob implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(RulebookAutoFetchJob.class);
    public static final String INIT_FLAG_KEY     = "init:rulebook-fetch";
    public static final String STOP_FLAG_KEY    = "stop:rulebook-fetch";

    /** Per-game lock so concurrent generate requests / batch runs never fetch the same game twice. */
    public static final String GAME_LOCK_PREFIX = "lock:rulebook-fetch:";
    public static final Duration GAME_LOCK_TTL = Duration.ofMinutes(15);
    private static final String BATCH_LOCK_KEY = "lock:rulebook-fetch-batch";
    private static final Duration BATCH_LOCK_TTL = Duration.ofHours(6);
    /** 'ingesting' rows older than this are treated as crashed and may be retried. */
    public static final Duration STALE_INGESTING_AFTER = Duration.ofHours(1);

    /** Outcome of a single-game fetch attempt. */
    public enum FetchResult { QUEUED, ALREADY_APPROVED, IN_PROGRESS, NOT_FOUND, ERROR }

    private final GameRulebookRepository rulebookRepository;
    private final RuleBookOrgClient ruleBookOrgClient;
    private final OnjRulebookClient onjClient;
    private final RulebookUrlValidator urlValidator;
    private final ApplicationEventPublisher eventPublisher;
    private final StringRedisTemplate redisTemplate;
    /** A game whose latest rulebook failed is not retried by the batch for this long. */
    private final Duration failedRetryBackoff;
    /** The batch stops retrying a game once it has this many failed rulebooks. */
    private final int maxFailedAttempts;

    public RulebookAutoFetchJob(GameRulebookRepository rulebookRepository,
            RuleBookOrgClient ruleBookOrgClient,
            OnjRulebookClient onjClient,
            RulebookUrlValidator urlValidator,
            ApplicationEventPublisher eventPublisher,
            StringRedisTemplate redisTemplate,
            @Value("${meeple.rulebook.failed-retry-backoff-days:7}") int failedRetryBackoffDays,
            @Value("${meeple.rulebook.max-failed-attempts:3}") int maxFailedAttempts) {
        this.failedRetryBackoff = Duration.ofDays(failedRetryBackoffDays);
        this.maxFailedAttempts = maxFailedAttempts;
        this.rulebookRepository = rulebookRepository;
        this.ruleBookOrgClient = ruleBookOrgClient;
        this.onjClient = onjClient;
        this.urlValidator = urlValidator;
        this.eventPublisher = eventPublisher;
        this.redisTemplate = redisTemplate;
    }

    // -------------------------------------------------------------------------
    // ApplicationRunner — fires once on first startup
    // -------------------------------------------------------------------------

    @Override
    public void run(ApplicationArguments args) {
        log.info("Rulebook pump auto-run disabled — use Admin → System Setup to trigger.");
    }

    // -------------------------------------------------------------------------
    // Core batch logic — also callable from admin endpoint
    // -------------------------------------------------------------------------

    /**
     * Fetch rulebooks for up to {@code limit} games without an approved rulebook.
     * Sets {@code completionFlagKey} in Redis when done (pass null to skip).
     */
    public void runBatch(int limit, String completionFlagKey) {
        if (!Boolean.TRUE.equals(redisTemplate.opsForValue().setIfAbsent(BATCH_LOCK_KEY, "1", BATCH_LOCK_TTL))) {
            log.info("Rulebook auto-fetch already running — skipping.");
            return;
        }
        try {
            log.info("Rulebook auto-fetch starting (limit={})", limit);

            Instant now = Instant.now();
            List<Game> games = rulebookRepository.findGamesWithoutApprovedRulebook(
                    now.minus(STALE_INGESTING_AFTER), now.minus(failedRetryBackoff), maxFailedAttempts,
                    PageRequest.of(0, limit));
            log.info("Found {} games without an approved rulebook", games.size());

            if (games.isEmpty()) {
                log.info("No games found — catalog may not be imported yet. Skipping flag set.");
                return;
            }

            int fetched = 0;
            for (Game game : games) {
                if (Boolean.TRUE.equals(redisTemplate.hasKey(STOP_FLAG_KEY))) {
                    log.info("Rulebook fetch stop requested — stopping at {}/{}", fetched, games.size());
                    break;
                }
                if (fetchForGame(game) == FetchResult.QUEUED)
                    fetched++;
            }

            log.info("Rulebook auto-fetch complete — fetched {}/{}", fetched, games.size());

            if (completionFlagKey != null) {
                redisTemplate.opsForValue().set(completionFlagKey, "1");
            }
        } finally {
            redisTemplate.delete(BATCH_LOCK_KEY);
        }
    }

    // -------------------------------------------------------------------------
    // Single-game fetch (also used by on-demand endpoint)
    // -------------------------------------------------------------------------

    /**
     * Try to find a PDF for a single game and queue it for ingestion.
     * Guarded by a per-game Redis lock (SET NX, {@link #GAME_LOCK_TTL}).
     */
    public FetchResult fetchForGame(Game game) {
        String lockKey = GAME_LOCK_PREFIX + game.getId();
        if (!Boolean.TRUE.equals(redisTemplate.opsForValue().setIfAbsent(lockKey, "1", GAME_LOCK_TTL))) {
            return FetchResult.IN_PROGRESS;
        }
        try {
            return doFetchForGame(game);
        } finally {
            // Safe to release: once queued, the fresh 'ingesting' row blocks duplicates
            redisTemplate.delete(lockKey);
        }
    }

    private FetchResult doFetchForGame(Game game) {
        // Skip if already approved or currently ingesting (stale 'ingesting' rows are retryable)
        if (rulebookRepository.existsByGame_IdAndStatus(game.getId(), "approved")) {
            return FetchResult.ALREADY_APPROVED;
        }
        if (rulebookRepository.existsActiveIngestion(game.getId(), Instant.now().minus(STALE_INGESTING_AFTER))) {
            return FetchResult.IN_PROGRESS;
        }

        String name = game.getNameEn();
        Optional<String> pdfUrl = ruleBookOrgClient.findPdfUrl(name).filter(urlValidator::isAllowedSyntax);
        String source = "rule_book_org";

        if (pdfUrl.isEmpty()) {
            pdfUrl = onjClient.findPdfUrl(name).filter(urlValidator::isAllowedSyntax);
            source = "onj";
        }

        if (pdfUrl.isEmpty()) {
            log.debug("No rulebook found for '{}'", name);
            return FetchResult.NOT_FOUND;
        }

        try {
            GameRulebook rulebook = new GameRulebook();
            rulebook.setGame(game);
            rulebook.setSource(source);
            rulebook.setStatus("ingesting"); // promoted to "approved" only after chunks are stored
            rulebook.setPdfUrl(pdfUrl.get());
            rulebookRepository.save(rulebook);

            // No surrounding transaction here: the listener runs immediately (async) after the save committed
            eventPublisher.publishEvent(new RulebookIngestionRequestedEvent(rulebook.getId()));

            log.info("Queued ingestion for '{}' via {}", name, source);
            return FetchResult.QUEUED;

        } catch (Exception e) {
            log.error("Failed to fetch/save rulebook for '{}': {}", name, e.getMessage());
            return FetchResult.ERROR;
        }
    }
}
