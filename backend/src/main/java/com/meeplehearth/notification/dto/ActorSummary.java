package com.meeplehearth.notification.dto;

import com.meeplehearth.user.entity.User;

import java.util.UUID;

/**
 * Who triggered a notification: the shared {@code UserSummary} shape
 * {@code {id, username, displayName, avatarUrl, deleted}}. A soft-deleted actor keeps only its id.
 */
public record ActorSummary(UUID id, String username, String displayName, String avatarUrl, boolean deleted) {

    public static ActorSummary from(User user) {
        if (user.getDeletedAt() != null) {
            return new ActorSummary(user.getId(), null, null, null, true);
        }
        return new ActorSummary(user.getId(), user.getUsername(), user.getDisplayName(), user.getAvatarUrl(), false);
    }
}
