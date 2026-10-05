package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.dto.HowToPlayResponse;
import com.meeplehearth.ai.dto.RuleNoteResponse;
import com.meeplehearth.ai.repository.GameHowToPlayRepository;
import com.meeplehearth.ai.repository.GameRuleNoteRepository;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.ai.service.AiRateLimiter;
import com.meeplehearth.ai.service.HowToPlayExtractionService;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * GET  /api/v1/games/{gameId}/how-to-play        — fetch current state (never auto-triggers)
 * POST /api/v1/games/{gameId}/how-to-play/generate — explicitly start AI extraction
 *
 * Progress is pushed over WebSocket (/topic/how-to-play/{gameId}) so the
 * frontend does not need to poll.  The GET endpoint remains available as a
 * one-time status check on page load.
 */
@RestController
@RequestMapping("/api/v1/games")
public class HowToPlayController {

    static final int GENERATE_DAILY_LIMIT = 10;

    private final GameHowToPlayRepository howToPlayRepository;
    private final HowToPlayExtractionService extractionService;
    private final GameRepository gameRepository;
    private final GameRulebookRepository rulebookRepository;
    private final GameRuleNoteRepository gameRuleNoteRepository;
    private final AiRateLimiter rateLimiter;

    public HowToPlayController(GameHowToPlayRepository howToPlayRepository,
                                HowToPlayExtractionService extractionService,
                                GameRepository gameRepository,
                                GameRulebookRepository rulebookRepository,
                                GameRuleNoteRepository gameRuleNoteRepository,
                                AiRateLimiter rateLimiter) {
        this.rateLimiter = rateLimiter;
        this.howToPlayRepository = howToPlayRepository;
        this.extractionService = extractionService;
        this.gameRepository = gameRepository;
        this.rulebookRepository = rulebookRepository;
        this.gameRuleNoteRepository = gameRuleNoteRepository;
    }

    // -------------------------------------------------------------------------
    // GET — status check (no side-effects)
    // -------------------------------------------------------------------------

    @GetMapping("/{gameId}/how-to-play")
    public ResponseEntity<HowToPlayResponse> getHowToPlay(@PathVariable UUID gameId) {

        // Already generated — return content immediately
        var existing = howToPlayRepository.findByGame_Id(gameId);
        if (existing.isPresent()) {
            String rulebookUrl = resolveRulebookUrl(gameId);
            List<RuleNoteResponse> notes = gameRuleNoteRepository
                    .findByGame_IdAndStatusOrderByCreatedAtAsc(gameId, "approved")
                    .stream().map(RuleNoteResponse::from).collect(Collectors.toList());
            return ResponseEntity.ok(HowToPlayResponse.from(existing.get(), rulebookUrl, notes));
        }

        // Extraction in progress — return current progress (frontend already subscribed to WS)
        if (extractionService.isGenerating(gameId)) {
            return ResponseEntity.ok(HowToPlayResponse.generating(extractionService.getProgress(gameId)));
        }

        // Nothing yet — let the frontend show the generate button
        return ResponseEntity.ok(HowToPlayResponse.notGenerated());
    }

    // -------------------------------------------------------------------------
    // POST — explicit generate trigger
    // -------------------------------------------------------------------------

    /**
     * Limits: {@value #GENERATE_DAILY_LIMIT} generations per user per day (429 HOW_TO_PLAY_RATE_LIMIT),
     * and a per-game Redis lock so concurrent requests for one game start one extraction only.
     * Requests that hit a running extraction return "generating" without using quota.
     */
    @PostMapping("/{gameId}/how-to-play/generate")
    public ResponseEntity<HowToPlayResponse> generate(
            @PathVariable UUID gameId,
            @AuthenticationPrincipal UserDetails userDetails) {

        // Already done
        var existing = howToPlayRepository.findByGame_Id(gameId);
        if (existing.isPresent()) {
            String rulebookUrl = resolveRulebookUrl(gameId);
            List<RuleNoteResponse> notes = gameRuleNoteRepository
                    .findByGame_IdAndStatusOrderByCreatedAtAsc(gameId, "approved")
                    .stream().map(RuleNoteResponse::from).collect(Collectors.toList());
            return ResponseEntity.ok(HowToPlayResponse.from(existing.get(), rulebookUrl, notes));
        }

        // Already running
        if (extractionService.isGenerating(gameId)) {
            return ResponseEntity.ok(HowToPlayResponse.generating(extractionService.getProgress(gameId)));
        }

        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));

        // Per-game lock first, so duplicate clicks / concurrent users don't consume quota
        if (!extractionService.tryAcquireLock(gameId)) {
            return ResponseEntity.ok(HowToPlayResponse.generating(extractionService.getProgress(gameId)));
        }
        try {
            UUID userId = userDetails != null ? UUID.fromString(userDetails.getUsername()) : null;
            rateLimiter.checkDaily("ai:ratelimit:how-to-play:", userId, GENERATE_DAILY_LIMIT,
                    "HOW_TO_PLAY_RATE_LIMIT", "Daily How-to-Play generation limit reached. Try again tomorrow.");
            extractionService.extractAsyncWithLockHeld(gameId, game);
        } catch (RuntimeException e) {
            extractionService.releaseLock(gameId);
            throw e;
        }
        return ResponseEntity.ok(HowToPlayResponse.generating(0));
    }

    // -------------------------------------------------------------------------

    private String resolveRulebookUrl(UUID gameId) {
        return rulebookRepository.findFirstByGame_IdAndStatus(gameId, "approved")
                .map(r -> r.getPublicUrl() != null ? r.getPublicUrl() : r.getPdfUrl())
                .orElse(null);
    }
}
