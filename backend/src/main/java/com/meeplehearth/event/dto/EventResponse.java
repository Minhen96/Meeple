package com.meeplehearth.event.dto;

import com.meeplehearth.game.dto.GameSummaryResponse;
import com.meeplehearth.user.dto.UserProfileResponse;

import java.time.Instant;
import java.util.UUID;

public record EventResponse(
        UUID id,
        UserProfileResponse host,
        GameSummaryResponse game,
        String title,
        String description,
        String location,
        Instant scheduledAt,
        Integer maxPlayers,
        int participantCount,
        boolean isPublic,
        Instant createdAt
) {
}
