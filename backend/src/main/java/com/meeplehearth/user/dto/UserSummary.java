package com.meeplehearth.user.dto;

import com.meeplehearth.user.entity.User;

import java.util.UUID;

/**
 * Shared user reference shape (docs/GAP_ANALYSIS.md section 6.1):
 * {@code {id, username, displayName, avatarUrl, deleted}}. For a soft-deleted user the name and
 * avatar are withheld and {@code deleted} is true; clients render "Deleted User".
 */
public record UserSummary(UUID id, String username, String displayName, String avatarUrl, boolean deleted) {

    /**
     * Id carried by {@link #deletedPlaceholder()}: the all-zero UUID, which no account ever has.
     * A real value (rather than null) keeps clients that require a non-null id parsing the row.
     */
    public static final UUID DELETED_USER_ID = new UUID(0L, 0L);

    private static final UserSummary DELETED_PLACEHOLDER = new UserSummary(DELETED_USER_ID, null, null, null, true);

    public static UserSummary from(User user) {
        if (user == null) {
            return null;
        }
        if (user.getDeletedAt() != null) {
            return new UserSummary(user.getId(), null, null, null, true);
        }
        return new UserSummary(user.getId(), user.getUsername(), user.getDisplayName(), user.getAvatarUrl(), false);
    }

    /**
     * Stand-in for a reference whose account was permanently deleted (the column was set to NULL
     * by the hard delete, FEATURES_COMPLETE section 1.6): {@code deleted=true}, no name or avatar.
     */
    public static UserSummary deletedPlaceholder() {
        return DELETED_PLACEHOLDER;
    }

    /** {@link #from} for a reference that may be null: a null user becomes {@link #deletedPlaceholder()}. */
    public static UserSummary fromNullable(User user) {
        return user == null ? DELETED_PLACEHOLDER : from(user);
    }
}
