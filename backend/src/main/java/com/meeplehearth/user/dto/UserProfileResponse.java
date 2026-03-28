package com.meeplehearth.user.dto;

import com.meeplehearth.user.entity.User;

import java.time.Instant;
import java.util.UUID;

public record UserProfileResponse(
        UUID id,
        String username,
        String displayName,
        String avatarUrl,
        String bio,
        String location,
        Instant createdAt
) {
    public static UserProfileResponse from(User user) {
        return new UserProfileResponse(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getAvatarUrl(),
                user.getBio(),
                user.getLocation(),
                user.getCreatedAt()
        );
    }
}
