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
        Integer minPlaytime,
        Integer maxPlaytime,
        BigDecimal complexityWeight,
        BigDecimal bggRating
) {
    public static GameDetailResponse from(Game game) {
        return new GameDetailResponse(
                game.getId(),
                game.getBggId(),
                game.getTitle(),
                game.getThumbnailUrl(),
                game.getImageUrl(),
                game.getDescription(),
                game.getYearPublished(),
                game.getMinPlayers(),
                game.getMaxPlayers(),
                game.getMinPlaytime(),
                game.getMaxPlaytime(),
                game.getComplexityWeight(),
                game.getBggRating()
        );
    }
}
