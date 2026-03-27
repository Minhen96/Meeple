package com.meeplehearth.ai.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

// Client sends the current question + last 3 Q&A pairs for conversation context
public record AiQueryRequest(
        @NotNull UUID gameId,
        @NotBlank @Size(max = 500) String question,
        @Size(max = 3) List<ConversationTurn> conversationHistory
) {
    public record ConversationTurn(String question, String answer) {}
}
