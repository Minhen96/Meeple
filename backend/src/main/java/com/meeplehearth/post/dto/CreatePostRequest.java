package com.meeplehearth.post.dto;

import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * {@code POST /api/v1/posts}. Images are optional (max 10, keys from the presigned upload);
 * {@code playedAt} may not be in the future; tagged users must be friends of the author (or the
 * author); tags of users who blocked the author are silently dropped (FEATURES_COMPLETE 5.2).
 */
public record CreatePostRequest(
        @Size(max = 2000) String caption,
        @Size(max = 100) String location,
        Instant playedAt,
        UUID gameId,
        UUID eventId,
        @Size(max = 20) List<UUID> taggedUserIds,
        @Size(max = 10) List<String> imageKeys  // R2 object keys returned from the presigned upload
) {
}
