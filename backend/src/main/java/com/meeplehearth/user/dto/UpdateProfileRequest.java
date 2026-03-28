package com.meeplehearth.user.dto;

import jakarta.validation.constraints.Size;

public record UpdateProfileRequest(
        @Size(min = 2, max = 50) String displayName,
        @Size(max = 300) String bio,
        @Size(max = 100) String location,
        @Size(max = 500) String avatarUrl,
        Boolean onboardingCompleted
) {
}
