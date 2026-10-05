package com.meeplehearth.auth.event;

import java.util.UUID;

/**
 * Published whenever every existing session of a user must end: the user's token_version was
 * incremented (password reset, refresh-token reuse, Google takeover of an unverified account)
 * or the account was soft-deleted. Listeners act on it only after the publishing transaction
 * commits, so a rolled-back revocation never disconnects anyone.
 */
public record UserSessionsRevokedEvent(UUID userId) {
}
