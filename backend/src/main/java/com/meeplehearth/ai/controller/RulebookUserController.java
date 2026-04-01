package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.job.RulebookAutoFetchJob;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.scheduling.annotation.Async;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/games")
public class RulebookUserController {

    private final GameRepository gameRepository;
    private final GameRulebookRepository rulebookRepository;
    private final RulebookAutoFetchJob autoFetchJob;

    public RulebookUserController(GameRepository gameRepository,
                                  GameRulebookRepository rulebookRepository,
                                  RulebookAutoFetchJob autoFetchJob) {
        this.gameRepository = gameRepository;
        this.rulebookRepository = rulebookRepository;
        this.autoFetchJob = autoFetchJob;
    }

    /**
     * POST /api/v1/games/{gameId}/rulebook/generate
     *
     * On-demand trigger for the "Generate Rules" button in the How To Play tab.
     * Tries to find a PDF from rule-book.org / 1jour1jeu and ingest it.
     *
     * Response:
     *   { status: "generating" }   — PDF found, ingestion started (poll how-to-play endpoint)
     *   { status: "not_found" }    — No PDF source found; How To Play will use GPT general knowledge
     *   { status: "already_done" } — Approved rulebook already exists for this game
     */
    @PostMapping("/{gameId}/rulebook/generate")
    public ResponseEntity<Map<String, String>> generate(@PathVariable UUID gameId) {
        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));

        if (rulebookRepository.existsByGame_IdAndStatus(gameId, "approved")) {
            return ResponseEntity.ok(Map.of("status", "already_done"));
        }

        boolean found = autoFetchJob.fetchForGame(game);
        return ResponseEntity.ok(Map.of("status", found ? "generating" : "not_found"));
    }

    /**
     * GET /api/v1/games/{gameId}/rulebook/status
     *
     * Returns whether an approved rulebook exists for this game.
     * Used by the frontend to decide whether to show the "Generate Rules" button.
     */
    @GetMapping("/{gameId}/rulebook/status")
    public ResponseEntity<Map<String, Object>> status(@PathVariable UUID gameId) {
        boolean hasRulebook = rulebookRepository.existsByGame_IdAndStatus(gameId, "approved");
        return ResponseEntity.ok(Map.of("hasRulebook", hasRulebook));
    }
}
