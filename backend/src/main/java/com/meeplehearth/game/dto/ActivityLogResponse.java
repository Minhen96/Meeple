package com.meeplehearth.game.dto;

import com.meeplehearth.game.entity.PlayLog;

import java.time.Instant;
import java.util.UUID;

public record ActivityLogResponse(UUID id, GameSummaryResponse game, Instant playedAt) {
    public static ActivityLogResponse from(PlayLog p) {
        return new ActivityLogResponse(p.getId(), GameSummaryResponse.from(p.getGame()), p.getPlayedAt());
    }
}
