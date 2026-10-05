package com.meeplehearth.user.dto;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * PUT /api/v1/users/me. Every field is optional; null leaves it unchanged. Limits follow
 * FEATURES_COMPLETE section 12.1 (C12). Usernames follow the registration rule and may change
 * once every 30 days.
 */
public record UpdateProfileRequest(
        @Size(min = 1, max = 50) String displayName,
        @Size(max = 200) String bio,
        @Size(max = 100) String location,
        @Size(max = 500) String avatarUrl,
        Boolean onboardingCompleted,
        @Size(min = 3, max = 20) @Pattern(regexp = "^[a-z0-9][a-z0-9_]*$",
                message = "must be lowercase letters, digits or underscores") String username,
        @Pattern(regexp = "^(en|zh-CN)$", message = "must be en or zh-CN") String preferredLanguage,
        @Size(max = 50) String timezone
) {
}
