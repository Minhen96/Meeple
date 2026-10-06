package com.meeplehearth.event.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.entity.EventParticipant;
import com.meeplehearth.game.dto.GameSummaryResponse;
import com.meeplehearth.user.dto.UserSummary;
import com.meeplehearth.user.entity.User;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Event as seen by one viewer (FEATURES section 4.6, GAP_ANALYSIS section 6.1).
 *
 * <ul>
 *   <li>{@code location} (the full address) is shown to the host and ACCEPTED participants. For
 *       INVITE_ONLY/FRIENDS events also to INVITED viewers and friends of the host without a
 *       participant row, including a friend who LEFT a FRIENDS event (ENGINEERING_STANDARDS
 *       section 10: "show full location"), but not to someone who DECLINED or was KICKED. For
 *       PUBLIC events it is {@code null} until the viewer joins; {@code locationDisplay} is the
 *       area/venue shown instead.</li>
 *   <li>{@code participants}: the host sees every participant row with its status; anyone else
 *       sees accepted participants only. Users the viewer blocked, or who blocked the viewer, are
 *       left out. {@code participantCount} is always the full accepted count.</li>
 *   <li>{@code myRsvp}: INVITED | ACCEPTED | DECLINED | LEFT | KICKED | null.</li>
 *   <li>{@code host}: the shared {@link UserSummary}; {@code deleted=true} (no name or avatar)
 *       when the host's account is deleted, including after the hard delete set it to NULL
 *       ({@link UserSummary#deletedPlaceholder()}).</li>
 * </ul>
 */
public record EventResponse(
        UUID id,
        UserSummary host,
        GameSummaryResponse game,
        String title,
        String description,
        String location,
        String locationDisplay,
        Instant scheduledAt,
        int maxParticipants,
        int participantCount,
        String visibility,
        String status,
        String myRsvp,
        @JsonProperty("isHost") boolean isHost,
        boolean reminderSent,
        List<ParticipantInfo> participants,
        Instant createdAt
) {
    public record ParticipantInfo(UUID id, String username, String displayName, String avatarUrl, String status) {
        public static ParticipantInfo from(EventParticipant ep) {
            User u = ep.getUser();
            return new ParticipantInfo(u.getId(), u.getUsername(), u.getDisplayName(), u.getAvatarUrl(),
                    ep.getStatus().name());
        }
    }

    /**
     * @param participantCount accepted participants (including the host)
     * @param myRsvp           the viewer's participant status, or null
     * @param viewerId         the viewer (decides host flag and location masking)
     * @param participants     already filtered for this viewer
     */
    public static EventResponse from(Event event, int participantCount, String myRsvp, UUID viewerId,
                                     List<ParticipantInfo> participants) {
        User hostUser = event.getHost();
        UserSummary host = UserSummary.fromNullable(hostUser);
        GameSummaryResponse game = event.getGame() != null ? GameSummaryResponse.from(event.getGame()) : null;
        boolean isHost = hostUser != null && hostUser.getId().equals(viewerId);
        return new EventResponse(
                event.getId(),
                host,
                game,
                event.getTitle(),
                event.getDescription(),
                canSeeFullLocation(event, isHost, myRsvp) ? event.getLocation() : null,
                event.getLocationDisplay(),
                event.getScheduledAt(),
                event.getMaxParticipants(),
                participantCount,
                event.getVisibility().name(),
                event.getStatus().name(),
                myRsvp,
                isHost,
                event.isReminderSent(),
                List.copyOf(participants),
                event.getCreatedAt()
        );
    }

    /**
     * Full address: host and ACCEPTED always; for INVITE_ONLY/FRIENDS events also every other
     * viewer who can see the event (INVITED, friends of the host, a friend who LEFT) except
     * DECLINED and KICKED; for PUBLIC ones only once joined.
     */
    public static boolean canSeeFullLocation(Event event, boolean isHost, String myRsvp) {
        if (isHost || EventParticipant.RsvpStatus.ACCEPTED.name().equals(myRsvp)) {
            return true;
        }
        if (event.getVisibility() == Event.Visibility.PUBLIC) {
            return false;
        }
        return !EventParticipant.RsvpStatus.DECLINED.name().equals(myRsvp)
                && !EventParticipant.RsvpStatus.KICKED.name().equals(myRsvp);
    }
}
