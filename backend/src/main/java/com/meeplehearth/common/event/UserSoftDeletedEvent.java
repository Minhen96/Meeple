package com.meeplehearth.common.event;

import java.util.UUID;

/**
 * A user soft-deleted their account ({@code users.deleted_at} set). Published by
 * {@code UserService.deleteMe}; listeners clean up their own package's data with
 * {@code @TransactionalEventListener(phase = AFTER_COMMIT)}, so nothing happens if the deletion
 * rolls back.
 */
public record UserSoftDeletedEvent(UUID userId) {
}
