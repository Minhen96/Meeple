package com.meeplehearth.social.dto;

import com.meeplehearth.user.entity.User;

import java.util.UUID;

/**
 * A search result row: a user plus the viewer's relationship with them
 * (docs/GAP_ANALYSIS.md section 6.1).
 *
 * @param friendshipStatus {@link #NONE} | {@link #PENDING_SENT} | {@link #PENDING_RECEIVED} | {@link #FRIENDS}
 */
public record UserSummaryWithStatus(UUID id, String username, String displayName, String avatarUrl,
                                    String friendshipStatus) {

    public static final String NONE = "none";
    public static final String PENDING_SENT = "pending_sent";
    public static final String PENDING_RECEIVED = "pending_received";
    public static final String FRIENDS = "friends";

    public static UserSummaryWithStatus of(User user, String friendshipStatus) {
        return new UserSummaryWithStatus(user.getId(), user.getUsername(), user.getDisplayName(),
                user.getAvatarUrl(), friendshipStatus);
    }
}
