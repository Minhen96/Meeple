package com.meeplehearth.post.dto;

import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record CreatePostRequest(
        @Size(max = 2000) String caption,
        @Size(max = 255) String location,
        Instant playedAt,
        UUID gameId,
        UUID eventId,
        List<UUID> taggedUserIds,
        List<String> imageKeys  // R2 object keys returned from the presigned upload
) {
}
