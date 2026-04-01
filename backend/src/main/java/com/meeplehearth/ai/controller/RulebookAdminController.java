package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.dto.RulebookQueueItem;
import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.ai.service.RulebookQueueService;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;
import java.util.UUID;

/**
 * Admin endpoints for the rulebook review queue.
 * Secured at the SecurityConfig level: /api/v1/admin/** requires ROLE_ADMIN.
 */
@RestController
@RequestMapping("/api/v1/admin")
public class RulebookAdminController {

    private final GameRulebookRepository rulebookRepository;
    private final RulebookQueueService queueService;
    private final GameRepository gameRepository;
    private final UserRepository userRepository;

    public RulebookAdminController(GameRulebookRepository rulebookRepository,
                                   RulebookQueueService queueService,
                                   GameRepository gameRepository,
                                   UserRepository userRepository) {
        this.rulebookRepository = rulebookRepository;
        this.queueService = queueService;
        this.gameRepository = gameRepository;
        this.userRepository = userRepository;
    }

    // -------------------------------------------------------------------------
    // GET /api/v1/admin/rulebooks?status=pending_review&page=0&size=20
    // -------------------------------------------------------------------------

    /**
     * Paginated list of rulebooks filtered by status.
     * Defaults to pending_review. Ordered by createdAt ASC (oldest first).
     */
    @GetMapping("/rulebooks")
    public ResponseEntity<Page<RulebookQueueItem>> listQueue(
            @RequestParam(defaultValue = "pending_review") String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Page<GameRulebook> rulebooks = rulebookRepository.findByStatusOrderByCreatedAtAsc(
                status, PageRequest.of(page, size, Sort.by("createdAt").ascending()));

        return ResponseEntity.ok(rulebooks.map(RulebookQueueItem::from));
    }

    // -------------------------------------------------------------------------
    // POST /api/v1/admin/rulebooks/{id}/approve
    // -------------------------------------------------------------------------

    @PostMapping("/rulebooks/{id}/approve")
    public ResponseEntity<Map<String, String>> approve(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {

        GameRulebook rulebook = findRulebook(id);
        User admin = resolveUser(userDetails);
        queueService.approve(rulebook, admin);
        return ResponseEntity.ok(Map.of("status", "ingesting"));
    }

    // -------------------------------------------------------------------------
    // POST /api/v1/admin/rulebooks/{id}/reject
    // -------------------------------------------------------------------------

    @PostMapping("/rulebooks/{id}/reject")
    public ResponseEntity<Map<String, String>> reject(
            @PathVariable UUID id,
            @RequestBody(required = false) RejectRequest body,
            @AuthenticationPrincipal UserDetails userDetails) {

        GameRulebook rulebook = findRulebook(id);
        User admin = resolveUser(userDetails);
        String reason = body != null ? body.reason() : null;
        queueService.reject(rulebook, admin, reason);
        return ResponseEntity.ok(Map.of("status", "rejected"));
    }

    // -------------------------------------------------------------------------
    // POST /api/v1/admin/games/{gameId}/rulebook  — admin PDF upload (auto-approved)
    // -------------------------------------------------------------------------

    /**
     * Admin uploads a PDF directly — bypasses review queue, starts ingestion immediately.
     */
    @PostMapping(value = "/games/{gameId}/rulebook", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<Map<String, Object>> adminUpload(
            @PathVariable UUID gameId,
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal UserDetails userDetails) {

        Game game = gameRepository.findById(gameId)
                .orElseThrow(() -> ApiException.notFound("GAME_NOT_FOUND", "Game not found"));
        User admin = resolveUser(userDetails);

        GameRulebook rulebook = queueService.handleAdminUpload(game, admin, file);
        return ResponseEntity.ok(Map.of(
                "status", "ingesting",
                "rulebookId", rulebook.getId()
        ));
    }

    // -------------------------------------------------------------------------

    private GameRulebook findRulebook(UUID id) {
        return rulebookRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("RULEBOOK_NOT_FOUND", "Rulebook not found"));
    }

    private User resolveUser(UserDetails userDetails) {
        return userRepository.findByUsernameIgnoreCase(userDetails.getUsername())
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
    }

    public record RejectRequest(String reason) {}
}
