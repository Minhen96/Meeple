package com.meeplehearth.user.dto;

import com.meeplehearth.user.entity.User;

import java.util.UUID;

/**
 * Shared user reference shape (docs/GAP_ANALYSIS.md section 6.1):
 * {@code {id, username, displayName, avatarUrl, deleted}}. For a soft-deleted user the name and
 * avatar are withheld and {@code deleted} is true; clients render "Deleted User".
 */
public record UserSummary(UUID id, String username, String displayName, String avatarUrl, boolean deleted) {

    public static UserSummary from(User user) {
        if (user == null) {
            return null;
        }
        if (user.getDeletedAt() != null) {
            return new UserSummary(user.getId(), null, null, null, true);
        }
        return new UserSummary(user.getId(), user.getUsername(), user.getDisplayName(), user.getAvatarUrl(), false);
    }
}
