package com.meeplehearth.game.dto;

import com.meeplehearth.game.entity.PlayLog;

import java.time.Instant;
import java.util.UUID;

/** One play. {@code postId} is set when the play was recorded by a post that tagged the user. */
public record PlayLogResponse(
        UUID id,
        UUID gameId,
        Instant playedAt,
        String notes,
        Integer durationMinutes,
        Integer playerCount,
        UUID postId
) {
    public static PlayLogResponse from(PlayLog p) {
        return new PlayLogResponse(p.getId(), p.getGame().getId(), p.getPlayedAt(), p.getNotes(),
                p.getDurationMinutes(), p.getPlayerCount(), p.getPostId());
    }
}
