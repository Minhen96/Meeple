package com.meeplehearth.game.controller;

import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.game.job.DataSeedRunner;
import com.meeplehearth.game.repository.GameRepository;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Admin-only setup status endpoints.
 * Secured via SecurityConfig: /api/v1/admin/** requires ROLE_ADMIN.
 *
 * GET  /api/v1/admin/setup/status  — live progress for all 3 seed steps
 * POST /api/v1/admin/setup/reset   — clear Redis flags so next restart re-runs
 */
@RestController
@RequestMapping("/api/v1/admin/setup")
public class AdminSetupController {

    private static final String RULEBOOK_PUMP_FLAG = "init:rulebook-fetch";
    private static final int    RULEBOOK_TARGET    = 10_000;

    private final StringRedisTemplate redis;
    private final GameRepository gameRepository;
    private final GameRulebookRepository rulebookRepository;

    public AdminSetupController(StringRedisTemplate redis,
                                GameRepository gameRepository,
                                GameRulebookRepository rulebookRepository) {
        this.redis = redis;
        this.gameRepository = gameRepository;
        this.rulebookRepository = rulebookRepository;
    }

    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getStatus() {
        boolean catalogImported    = Boolean.TRUE.equals(redis.hasKey(DataSeedRunner.GAMES_IMPORTED_FLAG));
        boolean hydrationStarted   = Boolean.TRUE.equals(redis.hasKey(DataSeedRunner.HYDRATION_STARTED_FLAG));
        boolean rulebookPumpStarted = Boolean.TRUE.equals(redis.hasKey(RULEBOOK_PUMP_FLAG));

        long total       = gameRepository.count();
        long unhydrated  = gameRepository.countByMinPlayersIsNull();
        long hydrated    = total - unhydrated;
        long approved    = rulebookRepository.countByStatus("approved");

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

        Map<String, Object> rulebooks = new LinkedHashMap<>();
        rulebooks.put("pumpStarted", rulebookPumpStarted);
        rulebooks.put("approved", approved);
        rulebooks.put("target", rulebookTarget);
        rulebooks.put("percentDone", rulebookPct);

        Map<String, Object> status = new LinkedHashMap<>();
        status.put("catalog", catalog);
        status.put("hydration", hydration);
        status.put("rulebooks", rulebooks);

        return ResponseEntity.ok(status);
    }

    @PostMapping("/reset")
    public ResponseEntity<Map<String, String>> reset() {
        redis.delete(DataSeedRunner.GAMES_IMPORTED_FLAG);
        redis.delete(DataSeedRunner.HYDRATION_STARTED_FLAG);
        redis.delete(RULEBOOK_PUMP_FLAG);
        return ResponseEntity.ok(Map.of("message", "Setup flags cleared. Restart the server to re-run all seed steps."));
    }
}
