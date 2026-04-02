package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.dto.RulebookStatusResponse;
import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.job.RulebookAutoFetchJob;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.ai.service.RulebookQueueService;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/games")
public class RulebookUserController {

    private final GameRepository gameRepository;
    private final GameRulebookRepository rulebookRepository;
    private final RulebookAutoFetchJob autoFetchJob;
    private final RulebookQueueService queueService;
    private final UserRepository userRepository;

    public RulebookUserController(GameRepository gameRepository,
                                  GameRulebookRepository rulebookRepository,
                                  RulebookAutoFetchJob autoFetchJob,
                                  RulebookQueueService queueService,
                                  UserRepository userRepository) {
        this.gameRepository = gameRepository;
        this.rulebookRepository = rulebookRepository;
        this.autoFetchJob = autoFetchJob;
        this.queueService = queueService;
        this.userRepository = userRepository;
    }

    // -------------------------------------------------------------------------
    // POST /api/v1/games/{gameId}/rulebook  — user PDF upload
    // -------------------------------------------------------------------------

    /**
     * Authenticated users can submit a rulebook PDF for admin review.
     * Returns immediately with queue position; content goes live only after admin approval.
     */
    @PostMapping(value = "/{gameId}/rulebook", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<Map<String, Object>> uploadRulebook(
            @PathVariable UUID gameId,
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserDetails userDetails) {

        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));

        if (rulebookRepository.existsByGame_IdAndStatus(gameId, "approved")) {
            return ResponseEntity.ok(Map.of("status", "already_done"));
        }

        User uploader = resolveUser(userDetails);
        GameRulebook rulebook = queueService.handleUserUpload(game, uploader, file);

        return ResponseEntity.ok(Map.of(
                "status", "queued",
                "rulebookId", rulebook.getId(),
                "queuePosition", rulebook.getQueuePosition()
        ));
    }

    // -------------------------------------------------------------------------
    // POST /api/v1/games/{gameId}/rulebook/generate  — on-demand auto-fetch
    // -------------------------------------------------------------------------

    /**
     * Triggers an auto-fetch from rule-book.org / 1jour1jeu for games that
     * don't yet have a rulebook. Returns status immediately; poll /status for result.
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

    // -------------------------------------------------------------------------
    // GET /api/v1/games/{gameId}/rulebook/status
    // -------------------------------------------------------------------------

    /**
     * Returns rulebook status for this game. When authenticated, also includes
     * the calling user's pending submission status and queue position.
     */
    @GetMapping("/{gameId}/rulebook/status")
    public ResponseEntity<RulebookStatusResponse> status(
            @PathVariable UUID gameId,
            @AuthenticationPrincipal UserDetails userDetails) {

        boolean hasRulebook = rulebookRepository.existsByGame_IdAndStatus(gameId, "approved");

        if (userDetails == null) {
            return ResponseEntity.ok(hasRulebook
                    ? RulebookStatusResponse.approved()
                    : RulebookStatusResponse.noRulebook());
        }

        // Include the user's own pending submission info if any
        User user = resolveUser(userDetails);
        Optional<GameRulebook> mySubmission = rulebookRepository
                .findFirstByGame_IdAndUploadedBy_IdAndStatusIn(gameId, user.getId(),
                        List.of("pending_review", "rejected"));

        if (mySubmission.isEmpty()) {
            return ResponseEntity.ok(new RulebookStatusResponse(hasRulebook, null, null));
        }

        GameRulebook sub = mySubmission.get();
        return ResponseEntity.ok(new RulebookStatusResponse(
                hasRulebook, sub.getStatus(), sub.getQueuePosition()));
    }

    // -------------------------------------------------------------------------

    private User resolveUser(UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
    }
}
