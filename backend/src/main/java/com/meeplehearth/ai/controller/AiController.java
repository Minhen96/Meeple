package com.meeplehearth.ai.controller;

import com.meeplehearth.ai.dto.AiAnswerResponse;
import com.meeplehearth.ai.dto.AiQueryRequest;
import com.meeplehearth.ai.service.AiService;
import com.meeplehearth.user.repository.UserRepository;
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
    private final UserRepository userRepository;

    public AiController(AiService aiService, UserRepository userRepository) {
        this.aiService = aiService;
        this.userRepository = userRepository;
    }

    @PostMapping("/rules")
    public ResponseEntity<AiAnswerResponse> askRules(
            @RequestBody @Valid AiQueryRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        UUID userId = null;
        if (userDetails != null) {
            userId = userRepository.findByUsernameIgnoreCase(userDetails.getUsername())
                    .map(u -> u.getId())
                    .orElse(null);
        }

        return ResponseEntity.ok(aiService.ask(userId, request));
    }
}
