package com.meeplehearth.game.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record GameSummaryResponse(
        UUID id,
        Long bggId,
        String title,
        String thumbnailUrl,
        Integer minPlayers,
        Integer maxPlayers,
        Integer minPlaytime,
        Integer maxPlaytime,
        BigDecimal complexityWeight,
        BigDecimal bggRating
) {
}
