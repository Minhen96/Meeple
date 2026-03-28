package com.meeplehearth.event.dto;

import com.meeplehearth.event.entity.Event;
import com.meeplehearth.game.dto.GameSummaryResponse;

import java.time.Instant;
import java.util.UUID;

public record EventResponse(
        UUID id,
        HostInfo host,
        GameSummaryResponse game,
        String title,
        String description,
        String location,
        Instant scheduledAt,
        int maxParticipants,
        int participantCount,
        String visibility,
        String status,
        String myRsvp,        // "ACCEPTED" | "DECLINED" | "INVITED" | null
        Instant createdAt
) {
    public record HostInfo(UUID id, String username, String displayName, String avatarUrl) {}

    public static EventResponse from(Event event, int participantCount, String myRsvp) {
        HostInfo host = new HostInfo(
                event.getHost().getId(),
                event.getHost().getUsername(),
                event.getHost().getDisplayName(),
                event.getHost().getAvatarUrl()
        );
        GameSummaryResponse game = event.getGame() != null
                ? GameSummaryResponse.from(event.getGame())
                : null;
        return new EventResponse(
                event.getId(),
                host,
                game,
                event.getTitle(),
                event.getDescription(),
                event.getLocation(),
                event.getScheduledAt(),
                event.getMaxParticipants(),
                participantCount,
                event.getVisibility().name(),
                event.getStatus().name(),
                myRsvp,
                event.getCreatedAt()
        );
    }
}
