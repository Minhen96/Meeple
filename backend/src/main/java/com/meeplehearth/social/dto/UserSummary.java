package com.meeplehearth.social.dto;

import com.meeplehearth.user.entity.User;

import java.util.UUID;

/**
 * Shared compact user reference (docs/GAP_ANALYSIS.md section 6.1):
 * {@code {id, username, displayName, avatarUrl, deleted}}. Clients render a soft-deleted user
 * as "Deleted User".
 */
public record UserSummary(UUID id, String username, String displayName, String avatarUrl, boolean deleted) {

    public static UserSummary from(User user) {
        return new UserSummary(user.getId(), user.getUsername(), user.getDisplayName(), user.getAvatarUrl(),
                user.getDeletedAt() != null);
    }
}
