package com.meeplehearth.ai.dto;

import com.meeplehearth.ai.entity.GameHowToPlay;

import java.util.Map;

/**
 * Response from GET /api/v1/games/{gameId}/how-to-play.
 *
 * @param status      "ready" | "generating"
 * @param data        Extracted How-to-Play structure. Null while generating.
 * @param sourceMode  "rulebook" | "general". Null while generating.
 * @param disclaimer  User-facing note about content reliability. Null while generating.
 */
public record HowToPlayResponse(
        String status,
        Map<String, Object> data,
        String sourceMode,
        String disclaimer
) {
    private static final String RULEBOOK_DISCLAIMER =
            "Based on the official rulebook.";
    private static final String GENERAL_DISCLAIMER =
            "Based on AI general knowledge — no rulebook has been uploaded yet.";

    public static HowToPlayResponse generating() {
        return new HowToPlayResponse("generating", null, null, null);
    }

    public static HowToPlayResponse from(GameHowToPlay entity) {
        String disclaimer = "rulebook".equals(entity.getSourceMode())
                ? RULEBOOK_DISCLAIMER
                : GENERAL_DISCLAIMER;
        return new HowToPlayResponse("ready", entity.getContent(), entity.getSourceMode(), disclaimer);
    }
}
