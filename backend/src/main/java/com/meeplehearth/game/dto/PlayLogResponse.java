package com.meeplehearth.game.dto;

import com.meeplehearth.game.entity.PlayLog;

import java.time.Instant;
import java.util.UUID;

public record PlayLogResponse(UUID id, Instant playedAt) {
    public static PlayLogResponse from(PlayLog p) {
        return new PlayLogResponse(p.getId(), p.getPlayedAt());
    }
}
