package com.meeplehearth.user.dto;

import jakarta.validation.constraints.Size;

/**
 * DELETE /api/v1/users/me (C11). Accounts with a password confirm with {@code password}.
 * Accounts without one (Google sign-in only) confirm with a freshly issued {@code googleIdToken}
 * or by typing {@code confirm: "DELETE"}.
 */
public record DeleteAccountRequest(
        @Size(max = 128) String password,
        @Size(max = 4096) String googleIdToken,
        @Size(max = 16) String confirm
) {
}
