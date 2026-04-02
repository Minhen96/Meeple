package com.meeplehearth.ai.dto;

/**
 * GET /api/v1/games/{gameId}/rulebook/status response.
 *
 * @param hasRulebook      true if an approved rulebook exists
 * @param isIngesting      true if a rulebook is currently being processed (not yet approved)
 * @param myStatus         status of the current user's pending submission, or null
 * @param myQueuePosition  queue position of the pending submission (0 = next in line), or null
 * @param hasHowToPlay     true if an AI-generated How-to-Play guide exists for this game
 */
public record RulebookStatusResponse(
        boolean hasRulebook,
        boolean isIngesting,
        String myStatus,
        Integer myQueuePosition,
        boolean hasHowToPlay
) {
    public static RulebookStatusResponse approved(boolean hasHowToPlay) {
        return new RulebookStatusResponse(true, false, null, null, hasHowToPlay);
    }

    public static RulebookStatusResponse noRulebook(boolean hasHowToPlay) {
        return new RulebookStatusResponse(false, false, null, null, hasHowToPlay);
    }

    public static RulebookStatusResponse ingesting(boolean hasHowToPlay) {
        return new RulebookStatusResponse(false, true, null, null, hasHowToPlay);
    }
}
