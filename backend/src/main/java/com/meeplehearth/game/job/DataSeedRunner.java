package com.meeplehearth.game.job;

import com.meeplehearth.config.AppProperties;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.service.GameDataImportService;
import com.meeplehearth.game.service.GameHydrationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.io.InputStream;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

/**
 * Automatic production data seed — runs on every startup but skips steps
 * already completed (tracked via Redis flags).
 *
 * Step 1 — Game catalog import (init:games-imported)
 *   Downloads boardgames.csv from SEED_CSV_URL (R2 public URL) and imports
 *   161k games. Skipped if the flag is set OR the games table is already
 *   non-empty. Set SEED_CSV_URL in Railway to enable.
 *
 * Step 2 — BGG hydration (init:games-hydration-started)
 *   Triggers GameHydrationService.hydrateAllMissingImages() which fills in
 *   mechanics, categories, player counts, etc. Takes ~3 hours for 161k games
 *   due to BGG rate limiting. Progress visible at GET /api/v1/admin/setup/status.
 *
 * Step 3 — Rulebook pump
 *   Handled independently by RulebookAutoFetchJob (init:rulebook-fetch flag).
 *   That job now skips its flag-set when the games table is empty, so it will
 *   re-run on the next restart after this runner has imported the catalog.
 */
@Component
public class DataSeedRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeedRunner.class);

    public static final String GAMES_IMPORTED_FLAG   = "init:games-imported";
    public static final String HYDRATION_STARTED_FLAG = "init:games-hydration-started";

    private final AppProperties appProperties;
    private final GameDataImportService importService;
    private final GameHydrationService hydrationService;
    private final GameRepository gameRepository;
    private final StringRedisTemplate redis;

    public DataSeedRunner(AppProperties appProperties,
                          GameDataImportService importService,
                          GameHydrationService hydrationService,
                          GameRepository gameRepository,
                          StringRedisTemplate redis) {
        this.appProperties = appProperties;
        this.importService = importService;
        this.hydrationService = hydrationService;
        this.gameRepository = gameRepository;
        this.redis = redis;
    }

    @Override
    public void run(ApplicationArguments args) {
        // Run in a virtual thread so startup completes immediately.
        Thread.ofVirtual().name("data-seed").start(this::seed);
    }

    private void seed() {
        // ------------------------------------------------------------------ //
        // Step 1: CSV catalog import
        // ------------------------------------------------------------------ //
        if (Boolean.TRUE.equals(redis.hasKey(GAMES_IMPORTED_FLAG))) {
            log.info("[seed] Catalog already imported — skipping");
        } else {
            String csvUrl = appProperties.getSeed().getCsvUrl();
            if (csvUrl == null || csvUrl.isBlank()) {
                log.info("[seed] SEED_CSV_URL not set — skipping catalog import");
            } else {
                long existing = gameRepository.count();
                if (existing > 0) {
                    log.info("[seed] Games table has {} rows — marking import as done", existing);
                    redis.opsForValue().set(GAMES_IMPORTED_FLAG, "1");
                } else {
                    if (!doImport(csvUrl)) return; // abort if import failed
                }
            }
        }

        // ------------------------------------------------------------------ //
        // Step 2: BGG hydration
        // ------------------------------------------------------------------ //
        if (Boolean.TRUE.equals(redis.hasKey(HYDRATION_STARTED_FLAG))) {
            log.info("[seed] BGG hydration already started — skipping");
            return;
        }

        long unhydrated = gameRepository.countByMinPlayersIsNull();
        if (unhydrated == 0) {
            log.info("[seed] All games already hydrated");
        } else {
            log.info("[seed] Starting BGG hydration for {} unhydrated games...", unhydrated);
            hydrationService.hydrateAllMissingImages(); // @Async — returns immediately
        }
        redis.opsForValue().set(HYDRATION_STARTED_FLAG, "1");
    }

    private boolean doImport(String csvUrl) {
        log.info("[seed] Downloading game catalog from {}", csvUrl);
        Path tmp = null;
        try {
            tmp = Files.createTempFile("boardgames-", ".csv");
            try (InputStream in = URI.create(csvUrl).toURL().openStream()) {
                Files.copy(in, tmp, StandardCopyOption.REPLACE_EXISTING);
            }
            log.info("[seed] Download complete ({}), importing...", tmp.getFileName());
            importService.runImport(tmp.toString());
            redis.opsForValue().set(GAMES_IMPORTED_FLAG, "1");
            log.info("[seed] Catalog import complete");
            return true;
        } catch (Exception e) {
            log.error("[seed] Catalog import failed: {}", e.getMessage());
            return false;
        } finally {
            if (tmp != null) {
                try { Files.deleteIfExists(tmp); } catch (Exception ignored) {}
            }
        }
    }
}
