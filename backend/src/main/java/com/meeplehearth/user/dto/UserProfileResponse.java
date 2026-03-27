package com.meeplehearth.user.dto;

import java.util.UUID;

public record UserProfileResponse(
        UUID id,
        String username,
        String displayName,
        String avatarUrl,
        String bio
) {
}
