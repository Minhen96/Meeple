package com.meeplehearth.game.controller;

import com.meeplehearth.ai.job.RulebookAutoFetchJob;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.game.job.DataSeedRunner;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.game.service.GameHydrationService;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClient;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Admin-only setup status + manual control endpoints.
 * Secured via SecurityConfig: /api/v1/admin/** requires ROLE_ADMIN.
 *
 * GET  /api/v1/admin/setup/status       — live progress for all 3 seed steps
 * POST /api/v1/admin/setup/start/{step} — manually trigger: import | hydrate | rulebooks
 * POST /api/v1/admin/setup/stop/{step}  — gracefully stop: hydrate | rulebooks
 * POST /api/v1/admin/setup/reset        — clear all Redis flags (restart to re-run)
 */
@RestController
@RequestMapping("/api/v1/admin/setup")
public class AdminSetupController {

    private static final int RULEBOOK_TARGET = 10_000;

    private final StringRedisTemplate redis;
    private final GameRepository gameRepository;
    private final GameRulebookRepository rulebookRepository;
    private final DataSeedRunner dataSeedRunner;
    private final RulebookAutoFetchJob rulebookAutoFetchJob;
    private final AppProperties appProperties;

    public AdminSetupController(StringRedisTemplate redis,
                                GameRepository gameRepository,
                                GameRulebookRepository rulebookRepository,
                                DataSeedRunner dataSeedRunner,
                                RulebookAutoFetchJob rulebookAutoFetchJob,
                                AppProperties appProperties) {
        this.redis = redis;
        this.gameRepository = gameRepository;
        this.rulebookRepository = rulebookRepository;
        this.dataSeedRunner = dataSeedRunner;
        this.rulebookAutoFetchJob = rulebookAutoFetchJob;
        this.appProperties = appProperties;
    }

    // -------------------------------------------------------------------------
    // Status
    // -------------------------------------------------------------------------

    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getStatus() {
        boolean catalogImported     = Boolean.TRUE.equals(redis.hasKey(DataSeedRunner.GAMES_IMPORTED_FLAG));
        boolean hydrationStarted    = Boolean.TRUE.equals(redis.hasKey(DataSeedRunner.HYDRATION_STARTED_FLAG));
        boolean hydrationStop       = Boolean.TRUE.equals(redis.hasKey(GameHydrationService.STOP_FLAG_KEY));
        boolean rulebookPumpStarted = Boolean.TRUE.equals(redis.hasKey(RulebookAutoFetchJob.INIT_FLAG_KEY));
        boolean rulebookStop        = Boolean.TRUE.equals(redis.hasKey(RulebookAutoFetchJob.STOP_FLAG_KEY));

        long total      = gameRepository.count();
        long unhydrated = gameRepository.countByMinPlayersIsNull();
        long hydrated   = total - unhydrated;
        long approved   = rulebookRepository.countByStatus("approved");
        long ingesting  = rulebookRepository.countByStatus("ingesting");

        long rulebookTarget  = Math.min(total, RULEBOOK_TARGET);
        int  hydrationPct    = total > 0 ? (int) (hydrated * 100L / total) : 0;
        int  rulebookPct     = rulebookTarget > 0 ? (int) (approved * 100L / rulebookTarget) : 0;

        Map<String, Object> catalog = new LinkedHashMap<>();
        catalog.put("imported", catalogImported);
        catalog.put("totalGames", total);

        Map<String, Object> hydration = new LinkedHashMap<>();
        hydration.put("started", hydrationStarted);
        hydration.put("hydrated", hydrated);
        hydration.put("unhydrated", unhydrated);
        hydration.put("total", total);
        hydration.put("percentDone", hydrationPct);
        hydration.put("running", hydrationStarted && unhydrated > 0 && !hydrationStop);
        hydration.put("stopRequested", hydrationStop);

        Map<String, Object> rulebooks = new LinkedHashMap<>();
        rulebooks.put("pumpStarted", rulebookPumpStarted);
        rulebooks.put("approved", approved);
        rulebooks.put("ingesting", ingesting);
        rulebooks.put("target", rulebookTarget);
        rulebooks.put("percentDone", rulebookPct);
        rulebooks.put("running", ingesting > 0 && !rulebookStop);
        rulebooks.put("stopRequested", rulebookStop);

        Map<String, Object> status = new LinkedHashMap<>();
        status.put("catalog", catalog);
        status.put("hydration", hydration);
        status.put("rulebooks", rulebooks);

        return ResponseEntity.ok(status);
    }

    // -------------------------------------------------------------------------
    // Start
    // -------------------------------------------------------------------------

    @PostMapping("/start/{step}")
    public ResponseEntity<Map<String, String>> start(@PathVariable String step) {
        return switch (step) {
            case "import" -> {
                dataSeedRunner.triggerImport();
                yield ok("Import triggered — downloading CSV and importing catalog.");
            }
            case "hydrate" -> {
                dataSeedRunner.triggerHydration();
                yield ok("BGG hydration triggered.");
            }
            case "rulebooks" -> {
                redis.delete(RulebookAutoFetchJob.INIT_FLAG_KEY);
                redis.delete(RulebookAutoFetchJob.STOP_FLAG_KEY);
                Thread.ofVirtual().name("rulebook-fetch-manual")
                        .start(() -> rulebookAutoFetchJob.runBatch(RULEBOOK_TARGET, RulebookAutoFetchJob.INIT_FLAG_KEY));
                yield ok("Rulebook pump triggered for top " + RULEBOOK_TARGET + " games.");
            }
            default -> ResponseEntity.badRequest()
                    .body(Map.of("error", "Unknown step. Use: import | hydrate | rulebooks"));
        };
    }

    // -------------------------------------------------------------------------
    // Stop
    // -------------------------------------------------------------------------

    @PostMapping("/stop/{step}")
    public ResponseEntity<Map<String, String>> stop(@PathVariable String step) {
        return switch (step) {
            case "hydrate" -> {
                redis.opsForValue().set(GameHydrationService.STOP_FLAG_KEY, "1");
                yield ok("Stop flag set for hydration. Will stop after current batch.");
            }
            case "rulebooks" -> {
                redis.opsForValue().set(RulebookAutoFetchJob.STOP_FLAG_KEY, "1");
                yield ok("Stop flag set for rulebook pump. Will stop after current game.");
            }
            default -> ResponseEntity.badRequest()
                    .body(Map.of("error", "Unknown step. Use: hydrate | rulebooks"));
        };
    }

    // -------------------------------------------------------------------------
    // Reset all flags
    // -------------------------------------------------------------------------

    @PostMapping("/reset")
    public ResponseEntity<Map<String, String>> reset() {
        redis.delete(DataSeedRunner.GAMES_IMPORTED_FLAG);
        redis.delete(DataSeedRunner.HYDRATION_STARTED_FLAG);
        redis.delete(RulebookAutoFetchJob.INIT_FLAG_KEY);
        redis.delete(GameHydrationService.STOP_FLAG_KEY);
        redis.delete(RulebookAutoFetchJob.STOP_FLAG_KEY);
        return ok("All setup flags cleared. Restart the server to re-run automatically, or use the Start buttons.");
    }

    // -------------------------------------------------------------------------
    // CSV accessibility probe
    // -------------------------------------------------------------------------

    @GetMapping("/check-csv")
    public ResponseEntity<Map<String, Object>> checkCsv() {
        String csvUrl = appProperties.getSeed().getCsvUrl();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("url", csvUrl);

        if (csvUrl == null || csvUrl.isBlank()) {
            result.put("accessible", false);
            result.put("error", "SEED_CSV_URL is not configured");
            return ResponseEntity.ok(result);
        }

        try {
            SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
            factory.setConnectTimeout(8_000);
            factory.setReadTimeout(8_000);

            RestClient client = RestClient.builder().requestFactory(factory).build();
            var response = client.head().uri(csvUrl).retrieve().toBodilessEntity();

            long bytes = response.getHeaders().getContentLength();
            String contentType = response.getHeaders().getFirst("Content-Type");

            result.put("accessible", true);
            result.put("httpStatus", response.getStatusCode().value());
            result.put("contentType", contentType);
            result.put("sizeBytes", bytes);
            result.put("sizeMb", bytes > 0 ? String.format("%.1f MB", bytes / 1_048_576.0) : "unknown");
            result.put("pass", bytes > 1_000_000);
            result.put("verdict", bytes > 1_000_000
                    ? "CSV is accessible and looks like a real file. Safe to start import."
                    : "File is too small or size unknown — verify the correct file is uploaded.");
        } catch (Exception e) {
            result.put("accessible", false);
            result.put("pass", false);
            result.put("error", e.getMessage());
            result.put("verdict", "Cannot reach the URL. Check R2 public access and custom domain settings.");
        }

        return ResponseEntity.ok(result);
    }

    private static ResponseEntity<Map<String, String>> ok(String message) {
        return ResponseEntity.ok(Map.of("message", message));
    }
}
