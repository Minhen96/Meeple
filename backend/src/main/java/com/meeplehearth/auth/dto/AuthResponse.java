package com.meeplehearth.auth.dto;

import java.util.UUID;

public record AuthResponse(
        UUID id,
        String username,
        String displayName,
        String avatarUrl,
        String email,
        boolean onboardingCompleted
) {
}
