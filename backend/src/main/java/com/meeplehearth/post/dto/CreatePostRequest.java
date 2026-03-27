package com.meeplehearth.post.dto;

import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

public record CreatePostRequest(
        @Size(max = 2000) String caption,
        UUID gameId,
        UUID eventId,
        List<UUID> taggedUserIds,
        // R2 object keys returned from the presigned upload
        List<String> imageKeys
) {
}
