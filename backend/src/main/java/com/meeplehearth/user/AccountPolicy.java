package com.meeplehearth.user;

import java.time.Duration;
import java.time.Instant;

/** Account lifecycle rules shared by the auth and user packages (FEATURES_COMPLETE section 1.6, 1.7). */
public final class AccountPolicy {

    /** A soft-deleted account can be reactivated for this long; the hard-delete job removes it afterwards. */
    public static final Duration DELETION_GRACE = Duration.ofDays(30);

    /** Minimum time between two username changes. */
    public static final Duration USERNAME_CHANGE_COOLDOWN = Duration.ofDays(30);

    /** Typed confirmation accepted for deleting an account that has no password. */
    public static final String DELETE_CONFIRMATION = "DELETE";

    private AccountPolicy() {
    }

    /** True while an account soft-deleted at {@code deletedAt} can still be reactivated. */
    public static boolean withinDeletionGrace(Instant deletedAt, Instant now) {
        return deletedAt != null && deletedAt.plus(DELETION_GRACE).isAfter(now);
    }

    /** When the username may next be changed, or null if it may be changed now. */
    public static Instant usernameChangeAvailableAt(Instant usernameChangedAt, Instant now) {
        if (usernameChangedAt == null) {
            return null;
        }
        Instant available = usernameChangedAt.plus(USERNAME_CHANGE_COOLDOWN);
        return available.isAfter(now) ? available : null;
    }
}
