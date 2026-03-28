package com.meeplehearth.game.dto;

import com.meeplehearth.game.entity.UserGame;

import java.math.BigDecimal;
import java.util.UUID;

public record UserGameResponse(
        UUID id,
        GameSummaryResponse game,
        boolean isOwned,
        boolean isWishlisted,
        boolean isFavorited,
        int playCount,
        BigDecimal personalRating,
        String notes
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
                ug.getNotes()
        );
    }
}
