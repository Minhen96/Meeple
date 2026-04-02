package com.meeplehearth.game.dto;

import com.meeplehearth.event.entity.EventParticipant;
import com.meeplehearth.game.entity.PlayLog;

import java.time.Instant;
import java.util.UUID;

public record ActivityLogResponse(
        UUID id,
        String type,            // "play" | "event"
        GameSummaryResponse game,
        Instant playedAt,
        String eventTitle,
        UUID eventId
) {
    public static ActivityLogResponse fromPlay(PlayLog p) {
        return new ActivityLogResponse(
                p.getId(), "play", GameSummaryResponse.from(p.getGame()), p.getPlayedAt(), null, null);
    }

    public static ActivityLogResponse fromEvent(EventParticipant ep) {
        var event = ep.getEvent();
        GameSummaryResponse game = event.getGame() != null ? GameSummaryResponse.from(event.getGame()) : null;
        return new ActivityLogResponse(
                ep.getId().getEventId(), "event", game, event.getScheduledAt(), event.getTitle(), ep.getId().getEventId());
    }

    /** Keep backward-compat factory used before events were added. */
    public static ActivityLogResponse from(PlayLog p) {
        return fromPlay(p);
    }
}
