package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.dto.AiAnswerResponse;
import com.meeplehearth.ai.dto.AiQueryRequest;
import com.meeplehearth.ai.service.AiService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * POST /api/v1/ai/rules — RAG-based rules assistant with conversation history.
 */
@RestController
@RequestMapping("/api/v1/ai")
public class AiController {

    private final AiService aiService;

    public AiController(AiService aiService) {
        this.aiService = aiService;
    }

    @PostMapping("/rules")
    public ResponseEntity<AiAnswerResponse> askRules(
            @RequestBody @Valid AiQueryRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        UUID userId = null;
        if (userDetails != null) {
            try { userId = UUID.fromString(userDetails.getUsername()); } catch (IllegalArgumentException ignored) {}
        }

        return ResponseEntity.ok(aiService.ask(userId, request));
    }
}
