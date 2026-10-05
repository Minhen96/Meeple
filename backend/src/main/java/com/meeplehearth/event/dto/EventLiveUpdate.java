package com.meeplehearth.event.dto;

import java.util.List;
import java.util.UUID;

/**
 * STOMP payload on {@code /topic/events/{eventId}} (GAP_ANALYSIS section 6.3), sent after every
 * committed change to an event's participants or status. {@code participants} holds accepted
 * participants only, since every viewer of the event may subscribe.
 */
public record EventLiveUpdate(
        UUID eventId,
        int participantCount,
        String status,
        List<EventResponse.ParticipantInfo> participants
) {
    public static String destination(UUID eventId) {
        return "/topic/events/" + eventId;
    }
}
