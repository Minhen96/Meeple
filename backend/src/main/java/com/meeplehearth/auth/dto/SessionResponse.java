package com.meeplehearth.auth.dto;

import java.time.Instant;
import java.util.UUID;

/** One signed-in device (GET /api/v1/auth/sessions). {@code current} marks the caller's own session. */
public record SessionResponse(
        UUID id,
        String deviceInfo,
        Instant createdAt,
        Instant lastUsedAt,
        boolean current
) {
}
