package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.dto.HowToPlayResponse;
import com.meeplehearth.ai.dto.RuleNoteResponse;
import com.meeplehearth.ai.repository.GameHowToPlayRepository;
import com.meeplehearth.ai.repository.GameRuleNoteRepository;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.ai.service.HowToPlayExtractionService;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * GET /api/v1/games/{gameId}/how-to-play
 *
 * Returns the AI-extracted How-to-Play guide for a game.
 * If not yet generated, triggers async extraction and returns { status: "generating" }.
 * Frontend polls every 2s while status = "generating".
 */
@RestController
@RequestMapping("/api/v1/games")
public class HowToPlayController {

    private final GameHowToPlayRepository howToPlayRepository;
    private final HowToPlayExtractionService extractionService;
    private final GameRepository gameRepository;
    private final GameRulebookRepository rulebookRepository;
    private final GameRuleNoteRepository gameRuleNoteRepository;

    public HowToPlayController(GameHowToPlayRepository howToPlayRepository,
                                HowToPlayExtractionService extractionService,
                                GameRepository gameRepository,
                                GameRulebookRepository rulebookRepository,
                                GameRuleNoteRepository gameRuleNoteRepository) {
        this.howToPlayRepository = howToPlayRepository;
        this.extractionService = extractionService;
        this.gameRepository = gameRepository;
        this.rulebookRepository = rulebookRepository;
        this.gameRuleNoteRepository = gameRuleNoteRepository;
    }

    @GetMapping("/{gameId}/how-to-play")
    public ResponseEntity<HowToPlayResponse> getHowToPlay(@PathVariable UUID gameId) {

        // Already generated — return immediately
        var existing = howToPlayRepository.findByGame_Id(gameId);
        if (existing.isPresent()) {
            String rulebookUrl = resolveRulebookUrl(gameId);
            List<RuleNoteResponse> notes = gameRuleNoteRepository
                    .findByGame_IdAndStatusOrderByCreatedAtAsc(gameId, "approved")
                    .stream().map(RuleNoteResponse::from).collect(Collectors.toList());
            return ResponseEntity.ok(HowToPlayResponse.from(existing.get(), rulebookUrl, notes));
        }

        // Extraction running — tell frontend to keep polling
        if (extractionService.isGenerating(gameId)) {
            return ResponseEntity.ok(HowToPlayResponse.generating());
        }

        // Trigger extraction
        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));

        extractionService.extractAsync(gameId, game);
        return ResponseEntity.ok(HowToPlayResponse.generating());
    }

    private String resolveRulebookUrl(UUID gameId) {
        return rulebookRepository.findFirstByGame_IdAndStatus(gameId, "approved")
                .map(r -> r.getPublicUrl() != null ? r.getPublicUrl() : r.getPdfUrl())
                .orElse(null);
    }
}
