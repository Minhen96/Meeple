package com.meeplehearth.event;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.event.repository.EventRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Participant rows only grant visibility while INVITED, ACCEPTED or DECLINED: someone who LEFT
 * loses INVITE_ONLY events and someone KICKED loses INVITE_ONLY and FRIENDS events (detail,
 * memories, live topic); a friend who LEFT a FRIENDS event still sees it as a friend, and PUBLIC
 * events stay public. The full location is for the host and ACCEPTED, plus non-public viewers
 * other than DECLINED.
 */
class EventVisibilityAfterLeavingIntegrationTest extends EventIntegrationTestBase {

    private static final String LOCATION = "12 Secret Street";

    @Autowired private EventRepository eventRepository;

    private UUID eventWithLocation(UUID host, String visibility) {
        UUID id = event(host, visibility, Instant.now().plus(Duration.ofDays(3)), 6);
        jdbc.update("UPDATE events SET location = ?, location_display = 'Downtown' WHERE id = ?", LOCATION, id);
        return id;
    }

    private JsonNode detail(UUID viewer, UUID eventId) throws Exception {
        return json(mvc.perform(get("/api/v1/events/" + eventId).with(as(viewer)))
                .andExpect(status().isOk()).andReturn()).get("data");
    }

    private void assertHidden(UUID viewer, UUID eventId) throws Exception {
        mvc.perform(get("/api/v1/events/" + eventId).with(as(viewer))).andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/posts").param("eventId", eventId.toString()).with(as(viewer)))
                .andExpect(status().isNotFound());
        assertThat(eventRepository.isVisibleTo(eventId, viewer)).isFalse();
    }

    private void assertMemoriesVisible(UUID viewer, UUID eventId) throws Exception {
        mvc.perform(get("/api/v1/posts").param("eventId", eventId.toString()).with(as(viewer)))
                .andExpect(status().isOk());
        assertThat(eventRepository.isVisibleTo(eventId, viewer)).isTrue();
    }

    private static String location(JsonNode event) {
        JsonNode location = event.get("location");
        return location == null || location.isNull() ? null : location.asText();
    }

    @Test
    void inviteOnlyEventsAreHiddenFromLeftAndKickedParticipants() throws Exception {
        UUID host = user();
        UUID invited = user();
        UUID accepted = user();
        UUID declined = user();
        UUID left = user();
        UUID kicked = user();
        UUID event = eventWithLocation(host, "INVITE_ONLY");
        participant(event, invited, "INVITED");
        participant(event, accepted, "ACCEPTED");
        participant(event, declined, "DECLINED");
        participant(event, left, "LEFT");
        participant(event, kicked, "KICKED");

        assertThat(location(detail(host, event))).isEqualTo(LOCATION);
        assertThat(location(detail(accepted, event))).isEqualTo(LOCATION);
        assertThat(location(detail(invited, event))).isEqualTo(LOCATION);
        // Declined keeps the basic info, not the address
        JsonNode declinedView = detail(declined, event);
        assertThat(location(declinedView)).isNull();
        assertThat(declinedView.get("locationDisplay").asText()).isEqualTo("Downtown");
        assertThat(declinedView.get("myRsvp").asText()).isEqualTo("DECLINED");
        assertMemoriesVisible(declined, event);

        assertHidden(left, event);
        assertHidden(kicked, event);
    }

    @Test
    void friendsEventsAreHiddenFromKickedFriendsButNotFromFriendsWhoLeft() throws Exception {
        UUID host = user();
        UUID friend = user();
        UUID friendWhoLeft = user();
        UUID friendKicked = user();
        UUID friendDeclined = user();
        friends(host, friend);
        friends(friendWhoLeft, host);
        friends(host, friendKicked);
        friends(host, friendDeclined);
        UUID event = eventWithLocation(host, "FRIENDS");
        participant(event, friendWhoLeft, "LEFT");
        participant(event, friendKicked, "KICKED");
        participant(event, friendDeclined, "DECLINED");

        assertThat(location(detail(friend, event))).isEqualTo(LOCATION);
        assertMemoriesVisible(friend, event);
        assertThat(location(detail(friendDeclined, event))).isNull();
        // Leaving voluntarily: still a friend of the host, so it stays visible like for any friend
        JsonNode leftView = detail(friendWhoLeft, event);
        assertThat(location(leftView)).isEqualTo(LOCATION);
        assertThat(leftView.get("myRsvp").asText()).isEqualTo("LEFT");
        assertMemoriesVisible(friendWhoLeft, event);
        assertHidden(friendKicked, event);

        // Not in their Upcoming list either
        JsonNode upcoming = json(mvc.perform(get("/api/v1/events").with(as(friendKicked)))
                .andExpect(status().isOk()).andReturn());
        assertThat(upcoming.toString()).doesNotContain(event.toString());

        // Invited again: visible again
        jdbc.update("UPDATE event_participants SET status = 'INVITED' WHERE event_id = ? AND user_id = ?",
                event, friendKicked);
        assertThat(location(detail(friendKicked, event))).isEqualTo(LOCATION);
    }

    @Test
    void publicEventsStayPublicButTheAddressNeedsAnAcceptedRsvp() throws Exception {
        UUID host = user();
        UUID kicked = user();
        UUID left = user();
        UUID accepted = user();
        UUID invited = user();
        UUID stranger = user();
        UUID event = eventWithLocation(host, "PUBLIC");
        participant(event, kicked, "KICKED");
        participant(event, left, "LEFT");
        participant(event, accepted, "ACCEPTED");
        participant(event, invited, "INVITED");

        assertThat(location(detail(kicked, event))).isNull();
        assertThat(location(detail(left, event))).isNull();
        assertThat(location(detail(stranger, event))).isNull();
        assertThat(location(detail(invited, event))).isNull();
        assertThat(location(detail(accepted, event))).isEqualTo(LOCATION);
        assertThat(location(detail(host, event))).isEqualTo(LOCATION);
        assertMemoriesVisible(kicked, event);
    }
}
