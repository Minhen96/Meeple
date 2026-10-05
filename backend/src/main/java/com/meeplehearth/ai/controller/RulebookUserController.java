package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.dto.RulebookStatusResponse;
import com.meeplehearth.ai.dto.RulebookUploadResponse;
import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.job.RulebookAutoFetchJob;
import com.meeplehearth.ai.repository.GameHowToPlayRepository;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.ai.service.AiRateLimiter;
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

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/games")
public class RulebookUserController {

    static final int GENERATE_DAILY_LIMIT = 10;

    private final GameRepository gameRepository;
    private final GameRulebookRepository rulebookRepository;
    private final RulebookAutoFetchJob autoFetchJob;
    private final RulebookQueueService queueService;
    private final UserRepository userRepository;
    private final GameHowToPlayRepository howToPlayRepository;
    private final AiRateLimiter rateLimiter;

    public RulebookUserController(GameRepository gameRepository,
            GameRulebookRepository rulebookRepository,
            RulebookAutoFetchJob autoFetchJob,
            RulebookQueueService queueService,
            UserRepository userRepository,
            GameHowToPlayRepository howToPlayRepository,
            AiRateLimiter rateLimiter) {
        this.rateLimiter = rateLimiter;
        this.gameRepository = gameRepository;
        this.rulebookRepository = rulebookRepository;
        this.autoFetchJob = autoFetchJob;
        this.queueService = queueService;
        this.userRepository = userRepository;
        this.howToPlayRepository = howToPlayRepository;
    }

    // -------------------------------------------------------------------------
    // POST /api/v1/games/{gameId}/rulebook — user PDF upload
    // -------------------------------------------------------------------------

    /**
     * Authenticated users can submit a rulebook PDF for admin review.
     * Returns immediately with queue position; content goes live only after admin
     * approval.
     */
    @PostMapping(value = "/{gameId}/rulebook", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<RulebookUploadResponse> uploadRulebook(
            @PathVariable UUID gameId,
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserDetails userDetails) {

        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));

        if (rulebookRepository.existsByGame_IdAndStatus(gameId, "approved")) {
            return ResponseEntity.ok(RulebookUploadResponse.alreadyDone());
        }

        User uploader = resolveUser(userDetails);
        GameRulebook rulebook = queueService.handleUserUpload(game, uploader, file);

        // queuePosition may be null; Map.of would throw on it
        return ResponseEntity.ok(RulebookUploadResponse.pendingReview(rulebook.getId(), rulebook.getQueuePosition()));
    }

    // -------------------------------------------------------------------------
    // POST /api/v1/games/{gameId}/rulebook/generate — on-demand auto-fetch
    // -------------------------------------------------------------------------

    /**
     * Triggers an auto-fetch from rule-book.org / 1jour1jeu for games that
     * don't yet have a rulebook. Returns status immediately; poll /status for
     * result.
     *
     * Limits: {@value #GENERATE_DAILY_LIMIT} requests per user per day (429 RULEBOOK_GENERATE_RATE_LIMIT),
     * and a per-game lock so concurrent requests for one game run only once.
     * Requests that hit an in-progress fetch return "generating" without using quota.
     */
    @PostMapping("/{gameId}/rulebook/generate")
    public ResponseEntity<Map<String, String>> generate(
            @PathVariable UUID gameId,
            @AuthenticationPrincipal UserDetails userDetails) {
        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));

        if (rulebookRepository.existsByGame_IdAndStatus(gameId, "approved")) {
            return ResponseEntity.ok(Map.of("status", "already_done"));
        }
        if (rateLimiter.isLocked(RulebookAutoFetchJob.GAME_LOCK_PREFIX + gameId)
                || rulebookRepository.existsActiveIngestion(gameId,
                        Instant.now().minus(RulebookAutoFetchJob.STALE_INGESTING_AFTER))) {
            return ResponseEntity.ok(Map.of("status", "generating"));
        }

        UUID userId = userDetails != null ? UUID.fromString(userDetails.getUsername()) : null;
        rateLimiter.checkDaily("ai:ratelimit:rulebook-generate:", userId, GENERATE_DAILY_LIMIT,
                "RULEBOOK_GENERATE_RATE_LIMIT", "Daily rulebook generation limit reached. Try again tomorrow.");

        String status = switch (autoFetchJob.fetchForGame(game)) {
            case QUEUED, IN_PROGRESS -> "generating";
            case ALREADY_APPROVED -> "already_done";
            case NOT_FOUND, ERROR -> "not_found";
        };
        return ResponseEntity.ok(Map.of("status", status));
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
        Instant ingestingCutoff = Instant.now().minus(RulebookAutoFetchJob.STALE_INGESTING_AFTER);
        boolean isIngesting = !hasRulebook
                && rulebookRepository.existsActiveIngestion(gameId, ingestingCutoff);
        boolean hasHowToPlay = howToPlayRepository.existsByGame_Id(gameId);

        if (userDetails == null) {
            if (hasRulebook)
                return ResponseEntity.ok(RulebookStatusResponse.approved(hasHowToPlay));
            if (isIngesting)
                return ResponseEntity.ok(RulebookStatusResponse.ingesting(hasHowToPlay));
            return ResponseEntity.ok(RulebookStatusResponse.noRulebook(hasHowToPlay));
        }

        // Include the user's own pending submission info if any
        User user = resolveUser(userDetails);
        Optional<GameRulebook> mySubmission = rulebookRepository
                .findFirstByGame_IdAndUploadedBy_IdAndStatusIn(gameId, user.getId(),
                        List.of("pending_review", "rejected"));

        if (mySubmission.isEmpty()) {
            return ResponseEntity.ok(new RulebookStatusResponse(hasRulebook, isIngesting, null, null, hasHowToPlay));
        }

        GameRulebook sub = mySubmission.get();
        return ResponseEntity.ok(new RulebookStatusResponse(
                hasRulebook, isIngesting, sub.getStatus(), sub.getQueuePosition(), hasHowToPlay));
    }

    // -------------------------------------------------------------------------

    private User resolveUser(UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
    }
}
