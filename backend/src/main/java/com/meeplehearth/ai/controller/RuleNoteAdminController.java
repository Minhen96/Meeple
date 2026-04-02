package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.dto.RuleNoteAdminItem;
import com.meeplehearth.ai.entity.GameRuleNote;
import com.meeplehearth.ai.repository.GameRuleNoteRepository;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Admin endpoints for the rule note review queue.
 * Secured at the SecurityConfig level: /api/v1/admin/** requires ROLE_ADMIN.
 */
@RestController
@RequestMapping("/api/v1/admin/rule-notes")
public class RuleNoteAdminController {

    private final GameRuleNoteRepository ruleNoteRepository;
    private final UserRepository userRepository;

    public RuleNoteAdminController(GameRuleNoteRepository ruleNoteRepository,
                                    UserRepository userRepository) {
        this.ruleNoteRepository = ruleNoteRepository;
        this.userRepository = userRepository;
    }

    // -------------------------------------------------------------------------
    // GET /api/v1/admin/rule-notes?page=0&size=20
    // -------------------------------------------------------------------------

    @GetMapping
    public ResponseEntity<Page<RuleNoteAdminItem>> listPending(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Page<GameRuleNote> notes = ruleNoteRepository.findByStatusOrderByCreatedAtAsc(
                "pending", PageRequest.of(page, size));

        List<RuleNoteAdminItem> items = notes.getContent().stream()
                .map(RuleNoteAdminItem::from)
                .collect(Collectors.toList());

        Page<RuleNoteAdminItem> result = new PageImpl<>(items, notes.getPageable(), notes.getTotalElements());
        return ResponseEntity.ok(result);
    }

    // -------------------------------------------------------------------------
    // POST /api/v1/admin/rule-notes/{id}/approve
    // -------------------------------------------------------------------------

    @PostMapping("/{id}/approve")
    public ResponseEntity<Map<String, String>> approve(
            @PathVariable UUID id,
            @AuthenticationPrincipal UserDetails userDetails) {

        GameRuleNote note = findNote(id);
        User admin = resolveUser(userDetails);

        note.setStatus("approved");
        note.setReviewedBy(admin);
        note.setReviewedAt(Instant.now());
        note.setUpdatedAt(Instant.now());

        ruleNoteRepository.save(note);
        return ResponseEntity.ok(Map.of("status", "approved"));
    }

    // -------------------------------------------------------------------------
    // POST /api/v1/admin/rule-notes/{id}/reject
    // -------------------------------------------------------------------------

    @PostMapping("/{id}/reject")
    public ResponseEntity<Map<String, String>> reject(
            @PathVariable UUID id,
            @RequestBody(required = false) RejectRequest body,
            @AuthenticationPrincipal UserDetails userDetails) {

        GameRuleNote note = findNote(id);
        User admin = resolveUser(userDetails);
        String reason = body != null ? body.reason() : null;

        note.setStatus("rejected");
        note.setRejectReason(reason);
        note.setReviewedBy(admin);
        note.setReviewedAt(Instant.now());
        note.setUpdatedAt(Instant.now());

        ruleNoteRepository.save(note);
        return ResponseEntity.ok(Map.of("status", "rejected"));
    }

    // -------------------------------------------------------------------------

    private GameRuleNote findNote(UUID id) {
        return ruleNoteRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("RULE_NOTE_NOT_FOUND", "Rule note not found"));
    }

    private User resolveUser(UserDetails userDetails) {
        UUID userId = UUID.fromString(userDetails.getUsername());
        return userRepository.findById(userId)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));
    }

    public record RejectRequest(String reason) {}
}
