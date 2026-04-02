package com.meeplehearth.game.service;

import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.entity.GameDetail;
import com.meeplehearth.game.repository.GameRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class GameHydrationService {

    private static final Logger log = LoggerFactory.getLogger(GameHydrationService.class);
    private static final int BGG_BATCH_SIZE = 20;
    private static final long BGG_DELAY_MS = 1100;
    public  static final String STOP_FLAG_KEY = "stop:hydration";

    private final GameRepository gameRepository;
    private final BggApiClient bggApiClient;
    private final StringRedisTemplate redis;

    public GameHydrationService(GameRepository gameRepository,
                                BggApiClient bggApiClient,
                                StringRedisTemplate redis) {
        this.gameRepository = gameRepository;
        this.bggApiClient = bggApiClient;
        this.redis = redis;
    }

    /** Called from browse — async, fires and forgets hydration for the current page */
    @Async
    @Transactional
    public void hydrateImagesQuietly(List<Long> bggIds) {
        hydrateBatch(bggIds);
    }

    /** Called from getGame() — sync so the detail page gets full data on first load */
    @Transactional
    public void hydrateImageSync(Game game) {
        if (game.getMinPlayers() != null) return;
        hydrateBatch(List.of(game.getBggId()));
    }

    /**
     * Bulk hydration — iterates ALL games with missing minPlayers in batches of 20.
     * Fills in: thumbnail, image, minPlayers, maxPlayers, playTime, gameType,
     * mechanics, categories, subdomains, designers, artists, publishers, honors,
     * expansions, bggUrl.
     * Run once after import via POST /api/v1/games/hydrate-images.
     * Takes ~3 hours for 161k games due to BGG rate limiting.
     */
    @Async
    public void hydrateAllMissingImages() {
        log.info("Starting bulk hydration for all unhydrated games...");
        int total = 0;
        List<Game> batch;

        // Always page=0: as games are hydrated they leave the null-minPlayers set,
        // so the next "page 0" is always a fresh batch of unhydrated games.
        do {
            if (Boolean.TRUE.equals(redis.hasKey(STOP_FLAG_KEY))) {
                log.info("Hydration stop requested — stopping at {} games hydrated.", total);
                break;
            }

            batch = gameRepository.findByMinPlayersIsNull(PageRequest.of(0, BGG_BATCH_SIZE));
            if (batch.isEmpty()) break;

            List<Long> bggIds = batch.stream().map(Game::getBggId).toList();
            int saved = hydrateBatch(bggIds);
            total += saved;
            log.info("Bulk hydration progress: {} games hydrated so far...", total);

            try { Thread.sleep(BGG_DELAY_MS); } catch (InterruptedException e) { Thread.currentThread().interrupt(); break; }
        } while (!batch.isEmpty());

        log.info("Bulk hydration complete. {} games hydrated.", total);
    }

    // -------------------------------------------------------------------------

    private String normalizeUrl(String url) {
        if (url == null) return null;
        return url.startsWith("//") ? "https:" + url : url;
    }

    @Transactional
    public int hydrateBatch(List<Long> bggIds) {
        if (bggIds == null || bggIds.isEmpty()) return 0;
        try {
            List<BggApiClient.BggGameDetail> details = bggApiClient.getDetails(bggIds);
            if (details.isEmpty()) return 0;

            Map<Long, BggApiClient.BggGameDetail> detailMap = details.stream()
                    .collect(Collectors.toMap(BggApiClient.BggGameDetail::bggId, Function.identity(), (a, b) -> a));

            // @EntityGraph on findByBggIdIn eagerly fetches gameDetail to avoid N+1
            List<Game> games = gameRepository.findByBggIdIn(bggIds);
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

                // Update or create GameDetail
                GameDetail gd = g.getGameDetail();
                if (gd == null) {
                    gd = new GameDetail();
                    gd.setGame(g);
                    g.setGameDetail(gd);
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

                count++;
            }
            if (count > 0) gameRepository.saveAll(games);
            return count;
        } catch (Exception e) {
            log.warn("Failed to hydrate batch {}: {}", bggIds, e.getMessage());
            return 0;
        }
    }
}
