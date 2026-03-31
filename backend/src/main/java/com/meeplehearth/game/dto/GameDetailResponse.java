package com.meeplehearth.game.dto;

import com.meeplehearth.game.entity.Game;

import java.math.BigDecimal;
import java.util.UUID;

public record GameDetailResponse(
        UUID id,
        Long bggId,
        String title,
        String thumbnailUrl,
        String imageUrl,
        String description,
        Integer yearPublished,
        Integer minPlayers,
        Integer maxPlayers,
        Integer playTime,
        BigDecimal complexityWeight,
        BigDecimal bggRating,
        String[] categories,
        String[] mechanics
) {
    public static GameDetailResponse from(Game game) {
        var detail = game.getGameDetail();
        return new GameDetailResponse(
                game.getId(),
                game.getBggId(),
                game.getNameEn(),
                game.getThumbnailUrl(),
                game.getImageUrl(),
                detail != null ? detail.getDescription() : null,
                game.getYearPublished(),
                game.getMinPlayers(),
                game.getMaxPlayers(),
                game.getPlayTime(),
                detail != null ? detail.getComplexity() : null,
                game.getBggRating(),
                detail != null ? detail.getCategories() : null,
                detail != null ? detail.getMechanics() : null
        );
    }
}
