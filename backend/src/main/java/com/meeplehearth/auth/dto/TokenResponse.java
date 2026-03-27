package com.meeplehearth.auth.dto;

// Tokens are set as httpOnly cookies; this DTO carries non-sensitive session info
public record TokenResponse(
        String userId,
        String username
) {
}
