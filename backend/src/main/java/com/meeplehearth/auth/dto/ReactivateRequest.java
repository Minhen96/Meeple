package com.meeplehearth.auth.dto;

import jakarta.validation.constraints.Size;

/**
 * POST /api/v1/auth/reactivate. Password accounts send {@code emailOrUsername} + {@code password};
 * Google-only accounts send a Google ID token instead.
 */
public record ReactivateRequest(
        @Size(max = 255) String emailOrUsername,
        @Size(max = 128) String password,
        @Size(max = 4096) String googleIdToken
) {
    public boolean hasGoogleIdToken() {
        return googleIdToken != null && !googleIdToken.isBlank();
    }
}
