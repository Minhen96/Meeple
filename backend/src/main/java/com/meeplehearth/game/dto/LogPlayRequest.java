package com.meeplehearth.game.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

import java.time.Instant;

/** Body of {@code POST /users/me/games/{gameId}/plays}; every field is optional. */
public record LogPlayRequest(
        Instant playedAt,
        @Size(max = 1000) String notes,
        @Min(1) @Max(1440) Integer durationMinutes,
        @Min(1) @Max(100) Integer playerCount
) {
    public static LogPlayRequest empty() {
        return new LogPlayRequest(null, null, null, null);
    }
}
