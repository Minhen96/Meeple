package com.meeplehearth.post.dto;

import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * {@code PUT /api/v1/posts/{id}} (author only, within 48h of creation; FEATURES_COMPLETE 5.4).
 * Every field is optional: {@code null} leaves it unchanged. An empty caption or location clears
 * it, {@code taggedUserIds} replaces the tag list and {@code clearGame} removes the game.
 * Images cannot be changed.
 */
public record UpdatePostRequest(
        @Size(max = 2000) String caption,
        @Size(max = 100) String location,
        Instant playedAt,
        UUID gameId,
        Boolean clearGame,
        @Size(max = 20) List<UUID> taggedUserIds
) {
}
