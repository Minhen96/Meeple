package com.meeplehearth.game.dto;

import com.meeplehearth.event.entity.EventParticipant;
import com.meeplehearth.game.entity.PlayLog;
import com.meeplehearth.post.entity.Post;
import com.meeplehearth.post.entity.PostImage;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record ActivityLogResponse(
        UUID id,
        String type,            // "play" | "event" | "post"
        GameSummaryResponse game,
        Instant playedAt,
        String eventTitle,
        UUID eventId,
        Instant scheduledAt,
        String location,
        String caption,
        List<String> imageUrls
) {
    public static ActivityLogResponse fromPlay(PlayLog p) {
        return new ActivityLogResponse(
                p.getId(), "play", GameSummaryResponse.from(p.getGame()), p.getPlayedAt(), 
                null, null, null, null, null, null);
    }

    /** The event with its full address (the activity owner's own view). */
    public static ActivityLogResponse fromEvent(EventParticipant ep) {
        return fromEvent(ep, ep.getEvent().getLocation());
    }

    /**
     * @param location what this viewer may see: the full address, or the public area/venue
     *                 ({@code locationDisplay}) when the viewer neither hosts nor joined the event
     */
    public static ActivityLogResponse fromEvent(EventParticipant ep, String location) {
        var event = ep.getEvent();
        GameSummaryResponse game = event.getGame() != null ? GameSummaryResponse.from(event.getGame()) : null;
        return new ActivityLogResponse(
                ep.getId().getEventId(), 
                "event", 
                game, 
                event.getCreatedAt(), 
                event.getTitle(), 
                ep.getId().getEventId(),
                event.getScheduledAt(),
                location,
                null, null
        );
    }

    public static ActivityLogResponse fromPost(Post p) {
        GameSummaryResponse game = p.getGame() != null ? GameSummaryResponse.from(p.getGame()) : null;
        List<String> images = p.getImages().stream().map(PostImage::getUrl).toList();
        return new ActivityLogResponse(
                p.getId(), "post", game, p.getCreatedAt(), 
                null, null, null, p.getLocation(), p.getCaption(), images);
    }

    /** Keep backward-compat factory used before events were added. */
    public static ActivityLogResponse from(PlayLog p) {
        return fromPlay(p);
    }
}
