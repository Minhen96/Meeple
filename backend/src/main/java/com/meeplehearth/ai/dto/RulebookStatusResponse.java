package com.meeplehearth.ai.dto;

/**
 * GET /api/v1/games/{gameId}/rulebook/status response.
 *
 * @param hasRulebook      true if an approved rulebook exists
 * @param myStatus         status of the current user's pending submission, or null
 * @param myQueuePosition  queue position of the pending submission (0 = next in line), or null
 */
public record RulebookStatusResponse(
        boolean hasRulebook,
        String myStatus,
        Integer myQueuePosition
) {
    /** Convenience factory when no user context is needed. */
    public static RulebookStatusResponse approved() {
        return new RulebookStatusResponse(true, null, null);
    }

    public static RulebookStatusResponse noRulebook() {
        return new RulebookStatusResponse(false, null, null);
    }
}
