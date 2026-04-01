package com.meeplehearth.ai.dto;

/**
 * Response from POST /api/v1/ai/rules.
 *
 * @param answer      The AI-generated answer text.
 * @param sourceMode  "rulebook" — answer came from indexed PDF chunks.
 *                    "general"  — no rulebook, used GPT general knowledge.
 * @param disclaimer  Short user-facing note about answer reliability.
 * @param cached      true if this answer was served from Redis cache (no token cost).
 */
public record AiAnswerResponse(
        String answer,
        String sourceMode,
        String disclaimer,
        boolean cached
) {
    private static final String RULEBOOK_DISCLAIMER =
            "AI-generated from the official rulebook. Verify for tournament play.";
    private static final String GENERAL_DISCLAIMER =
            "No rulebook uploaded yet. Based on AI general knowledge — may not be fully accurate.";

    public static AiAnswerResponse rulebook(String answer, boolean cached) {
        return new AiAnswerResponse(answer, "rulebook", RULEBOOK_DISCLAIMER, cached);
    }

    public static AiAnswerResponse general(String answer, boolean cached) {
        return new AiAnswerResponse(answer, "general", GENERAL_DISCLAIMER, cached);
    }
}
