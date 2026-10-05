package com.meeplehearth.common.event;

import java.util.UUID;

/**
 * A soft-deleted user passed the grace period and is being permanently removed. Published by
 * the account package's hard-delete job; listeners delete or anonymise their package's rows.
 */
public record UserHardDeletedEvent(UUID userId) {
}
