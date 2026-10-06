package com.meeplehearth.game.dto;

import com.meeplehearth.game.entity.UserGame;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * A collection entry. {@code id} is null when an update removed the entry (every flag cleared and
 * nothing else left to keep); the flags are then all false. {@code notes} are only ever returned
 * to the owner; {@code personalRating} to the owner and their friends ({@link #forOtherViewer}).
 */
public record UserGameResponse(
        UUID id,
        GameSummaryResponse game,
        boolean isOwned,
        boolean isWishlisted,
        boolean isFavorited,
        int playCount,
        BigDecimal personalRating,
        String notes,
        Instant addedAt
) {
    public static UserGameResponse from(UserGame ug) {
        return new UserGameResponse(
                ug.getId(),
                GameSummaryResponse.from(ug.getGame()),
                ug.isOwned(),
                ug.isWishlisted(),
                ug.isFavorited(),
                ug.getPlayCount(),
                ug.getPersonalRating(),
                ug.getNotes(),
                ug.getCreatedAt()
        );
    }

    /**
     * This entry as another user sees it: private notes never leave the owner, and the personal
     * rating is kept only when {@code keepRating} (the viewer is an accepted friend of the owner).
     */
    public UserGameResponse forOtherViewer(boolean keepRating) {
        return new UserGameResponse(id, game, isOwned, isWishlisted, isFavorited, playCount,
                keepRating ? personalRating : null, null, addedAt);
    }

    /** The response for an entry that was deleted because nothing was left on it. */
    public static UserGameResponse removed(UserGame ug) {
        return new UserGameResponse(null, GameSummaryResponse.from(ug.getGame()),
                false, false, false, 0, null, null, null);
    }
}
