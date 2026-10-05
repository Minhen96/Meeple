package com.meeplehearth.game.dto;

import java.util.UUID;

/** Profile stats ({@code GET /users/{id}/stats}, FEATURES_COMPLETE section 9.1). */
public record UserStatsResponse(
        long gamesOwned,
        long sessions,
        long friends,
        MostPlayedGame mostPlayedGame,
        String favoriteCategory,
        MostPlayedWith mostPlayedWith,
        long totalPlayMinutes
) {
    public record MostPlayedGame(UUID gameId, String title, int playCount) {
    }

    public record MostPlayedWith(UUID userId, String displayName, long sharedSessions) {
    }
}
