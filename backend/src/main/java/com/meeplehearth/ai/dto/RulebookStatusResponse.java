package com.meeplehearth.ai.dto;

/**
 * GET /api/v1/games/{gameId}/rulebook/status response.
 *
 * @param hasRulebook      true if an approved rulebook exists
 * @param isIngesting      true if a rulebook is currently being processed (not yet approved)
 * @param myStatus         status of the current user's pending submission, or null
 * @param myQueuePosition  queue position of the pending submission (0 = next in line), or null
 */
public record RulebookStatusResponse(
        boolean hasRulebook,
        boolean isIngesting,
        String myStatus,
        Integer myQueuePosition
) {
    public static RulebookStatusResponse approved() {
        return new RulebookStatusResponse(true, false, null, null);
    }

    public static RulebookStatusResponse noRulebook() {
        return new RulebookStatusResponse(false, false, null, null);
    }

    public static RulebookStatusResponse ingesting() {
        return new RulebookStatusResponse(false, true, null, null);
    }
}
