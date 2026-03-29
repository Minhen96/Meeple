package com.meeplehearth.match.dto;

import com.meeplehearth.game.dto.GameSummaryResponse;
import com.meeplehearth.match.entity.MatchRequest;

import java.time.Instant;
import java.util.UUID;

public record MatchRequestResponse(
        UUID id,
        GameSummaryResponse game,
        Instant availableFrom,
        Instant availableTo,
        String status,
        Instant createdAt
) {
    public static MatchRequestResponse from(MatchRequest mr) {
        return new MatchRequestResponse(
                mr.getId(),
                GameSummaryResponse.from(mr.getGame()),
                mr.getAvailableFrom(),
                mr.getAvailableTo(),
                mr.getStatus().name(),
                mr.getCreatedAt()
        );
    }
}
