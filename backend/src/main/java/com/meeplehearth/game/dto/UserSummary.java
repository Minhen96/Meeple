package com.meeplehearth.game.dto;

import com.meeplehearth.user.entity.User;

import java.util.UUID;

/** Shared user reference shape (docs/GAP_ANALYSIS.md section 6.1). */
public record UserSummary(UUID id, String username, String displayName, String avatarUrl, boolean deleted) {

    public static UserSummary from(User user) {
        return new UserSummary(user.getId(), user.getUsername(), user.getDisplayName(), user.getAvatarUrl(),
                user.getDeletedAt() != null);
    }
}
