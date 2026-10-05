package com.meeplehearth.common.event;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * A play session was recorded (a post with a game and tagged players). Published by the
 * social/feed package; the library package listens after commit to increment play counts and
 * write play logs for every user in {@code userIds}.
 *
 * @param userIds  the author plus every tagged user who played; never null
 * @param gameId   the game played
 * @param playedAt when the session was played
 * @param postId   the post that recorded the session
 */
public record SessionPlayedEvent(List<UUID> userIds, UUID gameId, Instant playedAt, UUID postId) {

    public SessionPlayedEvent {
        userIds = userIds == null ? List.of() : List.copyOf(userIds);
    }
}
