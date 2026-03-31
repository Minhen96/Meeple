package com.meeplehearth.game.dto;

import com.meeplehearth.game.entity.Game;

import java.math.BigDecimal;
import java.util.UUID;

public record GameSummaryResponse(
        UUID id,
        Long bggId,
        String title,
        String thumbnailUrl,
        Integer yearPublished,
        Integer minPlayers,
        Integer maxPlayers,
        Integer playTime,
        Integer minAge,
        Integer rank,
        Integer usersRated,
        BigDecimal bggRating
) {
    public static GameSummaryResponse from(Game game) {
        return new GameSummaryResponse(
                game.getId(),
                game.getBggId(),
                game.getNameEn(),
                game.getThumbnailUrl(),
                game.getYearPublished(),
                game.getMinPlayers(),
                game.getMaxPlayers(),
                game.getPlayTime(),
                game.getMinAge(),
                game.getRank(),
                game.getUsersRated(),
                game.getBggRating()
        );
    }
}
