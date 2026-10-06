package com.meeplehearth.event.dto;

import java.util.UUID;

/**
 * STOMP payload on {@code /topic/events/{eventId}} (GAP_ANALYSIS section 6.3), sent after every
 * committed change to an event's participants or status. Every viewer of the event may subscribe
 * and the payload is the same for all of them, so it carries no roster: who is shown depends on
 * the viewer (blocks either way, host-only statuses). Clients refetch {@code GET /events/{id}}.
 */
public record EventLiveUpdate(
        UUID eventId,
        int participantCount,
        String status
) {
    public static String destination(UUID eventId) {
        return "/topic/events/" + eventId;
    }
}
