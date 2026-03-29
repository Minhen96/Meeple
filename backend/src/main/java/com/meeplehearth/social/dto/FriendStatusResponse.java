package com.meeplehearth.social.dto;

import java.util.UUID;

/**
 * Friendship status from the perspective of currentUserId towards targetUserId.
 * status: NONE | PENDING_SENT | PENDING_RECEIVED | FRIENDS | BLOCKED
 */
public record FriendStatusResponse(
        String status,
        UUID requestId
) {
    public static FriendStatusResponse none() {
        return new FriendStatusResponse("NONE", null);
    }

    public static FriendStatusResponse pendingSent(UUID requestId) {
        return new FriendStatusResponse("PENDING_SENT", requestId);
    }

    public static FriendStatusResponse pendingReceived(UUID requestId) {
        return new FriendStatusResponse("PENDING_RECEIVED", requestId);
    }

    public static FriendStatusResponse friends(UUID requestId) {
        return new FriendStatusResponse("FRIENDS", requestId);
    }

    public static FriendStatusResponse blocked() {
        return new FriendStatusResponse("BLOCKED", null);
    }
}
