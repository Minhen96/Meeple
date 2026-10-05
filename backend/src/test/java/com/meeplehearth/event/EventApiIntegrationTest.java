package com.meeplehearth.event;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Events API end to end: JWT auth → EventController → EventService → real Postgres. */
class EventApiIntegrationTest extends ApiIntegrationTestBase {

    // -------------------------------------------------------------------------
    // Create
    // -------------------------------------------------------------------------

    @Test
    void createEventMakesHostAcceptedParticipantWithDefaults() throws Exception {
        UUID host = user();
        UUID gameId = game(2, 5);
        Instant when = Instant.now().plus(3, ChronoUnit.DAYS);

        JsonNode data = json(mvc.perform(post("/api/v1/events").with(as(host))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("Catan night", when, "PUBLIC", gameId, null))))
                .andExpect(status().isCreated())
                .andReturn()).get("data");

        UUID eventId = UUID.fromString(data.get("id").asText());
        assertThat(data.get("title").asText()).isEqualTo("Catan night");
        assertThat(data.get("host").get("id").asText()).isEqualTo(host.toString());
        assertThat(data.get("game").get("id").asText()).isEqualTo(gameId.toString());
        assertThat(data.get("maxParticipants").asInt()).isEqualTo(8);
        assertThat(data.get("participantCount").asInt()).isEqualTo(1);
        assertThat(data.get("myRsvp").asText()).isEqualTo("ACCEPTED");
        assertThat(data.get("status").asText()).isEqualTo("OPEN");
        assertThat(data.get("visibility").asText()).isEqualTo("PUBLIC");
        assertThat(string("SELECT status FROM event_participants WHERE event_id = ? AND user_id = ?", eventId, host))
                .isEqualTo("ACCEPTED");
    }

    @Test
    void createEventWithUnknownGameStoresNoGame() throws Exception {
        UUID host = user();
        mvc.perform(post("/api/v1/events").with(as(host))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("Mystery", Instant.now().plus(1, ChronoUnit.DAYS),
                                "FRIENDS", UUID.randomUUID(), 4))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.game").doesNotExist())
                .andExpect(jsonPath("$.data.maxParticipants").value(4));
    }

    @Test
    void createEventValidatesRequest() throws Exception {
        UUID host = user();
        Instant future = Instant.now().plus(1, ChronoUnit.DAYS);

        mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("Past", Instant.now().minus(1, ChronoUnit.DAYS), "PUBLIC", null, null))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("ab", future, "PUBLIC", null, null))))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("No visibility", future, null, null, null))))
                .andExpect(status().isBadRequest());

        assertThat(count("SELECT COUNT(*) FROM events WHERE host_id = ?", host)).isZero();
    }

    // -------------------------------------------------------------------------
    // List / get
    // -------------------------------------------------------------------------

    @Test
    void upcomingListRespectsVisibilityOrderingCancellationAndLimit() throws Exception {
        UUID host = user();
        UUID friend = user();
        UUID stranger = user();
        friends(host, friend);
        Instant now = Instant.now();
        UUID publicLater = event(host, "PUBLIC", now.plus(3, ChronoUnit.DAYS), 8);
        UUID publicSoon = event(host, "PUBLIC", now.plus(1, ChronoUnit.DAYS), 8);
        UUID friendsOnly = event(host, "FRIENDS", now.plus(2, ChronoUnit.DAYS), 8);
        UUID inviteOnly = event(host, "INVITE_ONLY", now.plus(2, ChronoUnit.DAYS), 8);
        UUID past = event(host, "PUBLIC", now.minus(1, ChronoUnit.DAYS), 8);
        UUID cancelled = event(host, "PUBLIC", now.plus(1, ChronoUnit.DAYS), 8);
        jdbc.update("UPDATE events SET status = 'CANCELLED' WHERE id = ?", cancelled);
        participant(publicSoon, friend, "ACCEPTED");

        List<UUID> forFriend = ids(json(mvc.perform(get("/api/v1/events").with(as(friend)))
                .andExpect(status().isOk()).andReturn()));
        assertThat(forFriend).containsSubsequence(publicSoon, friendsOnly, publicLater)
                .doesNotContain(inviteOnly, past, cancelled);

        List<UUID> forStranger = ids(json(mvc.perform(get("/api/v1/events").with(as(stranger)))
                .andExpect(status().isOk()).andReturn()));
        assertThat(forStranger).contains(publicSoon, publicLater).doesNotContain(friendsOnly, inviteOnly);

        // Batch-built counts and caller RSVP
        JsonNode friendList = json(mvc.perform(get("/api/v1/events").with(as(friend))).andReturn());
        JsonNode soon = find(friendList.get("data"), publicSoon);
        assertThat(soon.get("participantCount").asInt()).isEqualTo(2);
        assertThat(soon.get("myRsvp").asText()).isEqualTo("ACCEPTED");
        assertThat(find(friendList.get("data"), publicLater).get("myRsvp").isNull()).isTrue();

        // limit is clamped to at least 1
        mvc.perform(get("/api/v1/events").with(as(host)).param("limit", "0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1));
        mvc.perform(get("/api/v1/events").with(as(host)).param("limit", "2"))
                .andExpect(jsonPath("$.data.length()").value(2));
    }

    @Test
    void getEventReturnsVisibleEventAnd404Otherwise() throws Exception {
        UUID host = user();
        UUID stranger = user();
        UUID inviteOnly = event(host, "INVITE_ONLY", Instant.now().plus(1, ChronoUnit.DAYS), 8);

        mvc.perform(get("/api/v1/events/{id}", inviteOnly).with(as(host)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.myRsvp").value("ACCEPTED"))
                .andExpect(jsonPath("$.data.participantCount").value(1));
        mvc.perform(get("/api/v1/events/{id}", inviteOnly).with(as(stranger)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("EVENT_NOT_FOUND"));

        participant(inviteOnly, stranger, "INVITED");
        mvc.perform(get("/api/v1/events/{id}", inviteOnly).with(as(stranger)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.myRsvp").value("INVITED"));
    }

    @Test
    void myEventsListsOnlyAcceptedEvents() throws Exception {
        UUID host = user();
        UUID me = user();
        UUID accepted = event(host, "PUBLIC", Instant.now().plus(2, ChronoUnit.DAYS), 8);
        UUID declined = event(host, "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), 8);
        participant(accepted, me, "ACCEPTED");
        participant(declined, me, "DECLINED");

        mvc.perform(get("/api/v1/events/me").with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].id").value(accepted.toString()))
                .andExpect(jsonPath("$.data[0].participantCount").value(2));

        UUID nobody = user();
        mvc.perform(get("/api/v1/events/me").with(as(nobody)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(0));
    }

    // -------------------------------------------------------------------------
    // Update / delete
    // -------------------------------------------------------------------------

    @Test
    void hostCanPartiallyUpdateEvent() throws Exception {
        UUID host = user();
        UUID eventId = event(host, "INVITE_ONLY", Instant.now().plus(1, ChronoUnit.DAYS), 8);
        jdbc.update("UPDATE events SET description = 'keep me', location = 'Old place' WHERE id = ?", eventId);
        Instant newTime = Instant.now().plus(5, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);

        Map<String, Object> body = new HashMap<>();
        body.put("title", "Renamed night");
        body.put("location", "New place");
        body.put("scheduledAt", newTime.toString());
        body.put("visibility", "PUBLIC");
        body.put("maxParticipants", 3);

        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("Renamed night"))
                .andExpect(jsonPath("$.data.description").value("keep me"))
                .andExpect(jsonPath("$.data.location").value("New place"))
                .andExpect(jsonPath("$.data.visibility").value("PUBLIC"))
                .andExpect(jsonPath("$.data.maxParticipants").value(3));

        assertThat(string("SELECT visibility FROM events WHERE id = ?", eventId)).isEqualTo("PUBLIC");
        assertThat(jdbc.queryForObject("SELECT scheduled_at FROM events WHERE id = ?", java.sql.Timestamp.class,
                eventId).toInstant()).isEqualTo(newTime);
    }

    @Test
    void updateWithOnlyDescriptionKeepsEverythingElse() throws Exception {
        UUID host = user();
        JsonNode created = json(mvc.perform(post("/api/v1/events").with(as(host))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("No game night", Instant.now().plus(2, ChronoUnit.DAYS),
                                "PUBLIC", null, 6))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.game").doesNotExist())
                .andReturn()).get("data");
        UUID eventId = UUID.fromString(created.get("id").asText());

        // PUT shares CreateEventRequest validation, so title/scheduledAt/visibility are still required
        Map<String, Object> body = eventBody("No game night", Instant.parse(created.get("scheduledAt").asText()),
                "PUBLIC", null, null);
        body.put("description", "Bring snacks");
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.description").value("Bring snacks"))
                .andExpect(jsonPath("$.data.maxParticipants").value(6))
                .andExpect(jsonPath("$.data.title").value("No game night"));
    }

    @Test
    void leavingAFullEventAsADeclinedParticipantKeepsItFull() throws Exception {
        UUID host = user();
        UUID guest = user();
        UUID decliner = user();
        UUID eventId = event(host, "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), 2);
        participant(eventId, decliner, "DECLINED");
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(guest)).param("status", "ACCEPTED"))
                .andExpect(jsonPath("$.data.status").value("FULL"));

        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(decliner))).andExpect(status().isNoContent());

        assertThat(string("SELECT status FROM events WHERE id = ?", eventId)).isEqualTo("FULL");
    }

    @Test
    void nonHostUpdateOrDeleteIsForbiddenAndInvisibleEventIs404() throws Exception {
        UUID host = user();
        UUID other = user();
        UUID publicEvent = event(host, "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), 8);
        UUID hidden = event(host, "INVITE_ONLY", Instant.now().plus(1, ChronoUnit.DAYS), 8);
        String body = toJson(eventBody("Hijacked", Instant.now().plus(2, ChronoUnit.DAYS), "PUBLIC", null, null));

        mvc.perform(put("/api/v1/events/{id}", publicEvent).with(as(other))
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
        mvc.perform(delete("/api/v1/events/{id}", publicEvent).with(as(other)))
                .andExpect(status().isForbidden());
        mvc.perform(put("/api/v1/events/{id}", hidden).with(as(other))
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isNotFound());

        assertThat(string("SELECT title FROM events WHERE id = ?", publicEvent)).isEqualTo("PUBLIC night");
    }

    @Test
    void hostDeleteCancelsAndHidesEvent() throws Exception {
        UUID host = user();
        UUID guest = user();
        UUID eventId = event(host, "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), 8);
        participant(eventId, guest, "ACCEPTED");

        mvc.perform(delete("/api/v1/events/{id}", eventId).with(as(host))).andExpect(status().isNoContent());

        assertThat(string("SELECT status FROM events WHERE id = ?", eventId)).isEqualTo("CANCELLED");
        assertThat(count("SELECT COUNT(*) FROM events WHERE id = ? AND deleted_at IS NOT NULL", eventId)).isEqualTo(1);
        mvc.perform(get("/api/v1/events/{id}", eventId).with(as(host))).andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/events/me").with(as(guest))).andExpect(jsonPath("$.data.length()").value(0));
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(guest)).param("status", "DECLINED"))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(guest)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("EVENT_NOT_FOUND"));
    }

    // -------------------------------------------------------------------------
    // RSVP and capacity
    // -------------------------------------------------------------------------

    @Test
    void rsvpEnforcesCapacityAndTogglesFullStatus() throws Exception {
        UUID host = user();
        UUID a = user();
        UUID b = user();
        UUID eventId = event(host, "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), 2);

        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(a)).param("status", "ACCEPTED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FULL"))
                .andExpect(jsonPath("$.data.participantCount").value(2))
                .andExpect(jsonPath("$.data.myRsvp").value("ACCEPTED"));
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND type = 'EVENT_RSVP'"
                + " AND actor_id = ?", host, a)).isEqualTo(1);

        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(b)).param("status", "ACCEPTED"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVENT_FULL"));
        // Re-accepting when already accepted is not blocked by the capacity check
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(a)).param("status", "ACCEPTED"))
                .andExpect(status().isOk());
        // Declining on a full event is always allowed and frees a seat
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(b)).param("status", "DECLINED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.myRsvp").value("DECLINED"));

        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(a)).param("status", "DECLINED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("OPEN"))
                .andExpect(jsonPath("$.data.participantCount").value(1));

        // b switches DECLINED → ACCEPTED now that a seat is free
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(b)).param("status", "ACCEPTED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FULL"));
        assertThat(string("SELECT status FROM events WHERE id = ?", eventId)).isEqualTo("FULL");
        assertThat(count("SELECT COUNT(*) FROM event_participants WHERE event_id = ?", eventId)).isEqualTo(3);
    }

    @Test
    void hostRsvpDoesNotNotifyThemselves() throws Exception {
        UUID host = user();
        UUID eventId = event(host, "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), 8);

        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(host)).param("status", "ACCEPTED"))
                .andExpect(status().isOk());

        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ?", host)).isZero();
    }

    @Test
    void rsvpToInvisibleOrUnknownEventIs404() throws Exception {
        UUID host = user();
        UUID stranger = user();
        UUID invitee = user();
        UUID inviteOnly = event(host, "INVITE_ONLY", Instant.now().plus(1, ChronoUnit.DAYS), 8);
        participant(inviteOnly, invitee, "INVITED");

        mvc.perform(post("/api/v1/events/{id}/rsvp", inviteOnly).with(as(stranger)).param("status", "ACCEPTED"))
                .andExpect(status().isNotFound());
        mvc.perform(post("/api/v1/events/{id}/rsvp", UUID.randomUUID()).with(as(stranger)).param("status", "ACCEPTED"))
                .andExpect(status().isNotFound());
        assertThat(count("SELECT COUNT(*) FROM event_participants WHERE user_id = ?", stranger)).isZero();

        // An invited user may accept an invite-only event
        mvc.perform(post("/api/v1/events/{id}/rsvp", inviteOnly).with(as(invitee)).param("status", "ACCEPTED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.myRsvp").value("ACCEPTED"));
    }

    @Test
    void leaveEventRules() throws Exception {
        UUID host = user();
        UUID guest = user();
        UUID outsider = user();
        UUID eventId = event(host, "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), 2);

        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(outsider)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("RSVP_NOT_FOUND"));
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(host)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("HOST_CANNOT_LEAVE"));

        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(guest)).param("status", "ACCEPTED"))
                .andExpect(jsonPath("$.data.status").value("FULL"));
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(guest))).andExpect(status().isNoContent());

        assertThat(string("SELECT status FROM events WHERE id = ?", eventId)).isEqualTo("OPEN");
        assertThat(count("SELECT COUNT(*) FROM event_participants WHERE event_id = ? AND user_id = ?",
                eventId, guest)).isZero();

        // Leaving a non-full event keeps it OPEN
        participant(eventId, outsider, "DECLINED");
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(outsider))).andExpect(status().isNoContent());
        assertThat(string("SELECT status FROM events WHERE id = ?", eventId)).isEqualTo("OPEN");
    }

    @Test
    @Disabled("BUG: invalid ?status= on POST /events/{id}/rsvp fails @Pattern with a ConstraintViolationException"
            + " that GlobalExceptionHandler does not map, so the client gets 500 INTERNAL_ERROR instead of 400")
    void invalidRsvpStatusIsRejectedAsBadRequest() throws Exception {
        UUID host = user();
        UUID guest = user();
        UUID eventId = event(host, "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), 8);

        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(guest)).param("status", "MAYBE"))
                .andExpect(status().isBadRequest());
        assertThat(count("SELECT COUNT(*) FROM event_participants WHERE user_id = ?", guest)).isZero();
    }

    @Test
    @Disabled("BUG: CreateEventRequest.visibility is an unvalidated String; Event.Visibility.valueOf(\"SECRET\")"
            + " throws IllegalArgumentException in EventService.createEvent/updateEvent, returned as 500 instead of 400")
    void unknownVisibilityIsRejectedAsBadRequest() throws Exception {
        UUID host = user();
        mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("Secret night", Instant.now().plus(1, ChronoUnit.DAYS),
                                "SECRET", null, null))))
                .andExpect(status().isBadRequest());
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static Map<String, Object> eventBody(String title, Instant scheduledAt, String visibility,
                                                 UUID gameId, Integer maxParticipants) {
        Map<String, Object> body = new HashMap<>();
        body.put("title", title);
        body.put("scheduledAt", scheduledAt.toString());
        body.put("visibility", visibility);
        body.put("gameId", gameId);
        body.put("maxParticipants", maxParticipants);
        return body;
    }

    private UUID event(UUID host, String visibility, Instant scheduledAt, int maxParticipants) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, scheduled_at, visibility, max_participants)"
                        + " VALUES (?, ?, ?, ?, ?, ?)",
                id, host, visibility + " night", ts(scheduledAt), visibility, maxParticipants);
        participant(id, host, "ACCEPTED");
        return id;
    }

    private void participant(UUID eventId, UUID userId, String status) {
        jdbc.update("INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, ?)",
                eventId, userId, status);
    }

    private static List<UUID> ids(JsonNode list) {
        List<UUID> out = new ArrayList<>();
        list.get("data").forEach(n -> out.add(UUID.fromString(n.get("id").asText())));
        return out;
    }

    private static JsonNode find(JsonNode array, UUID id) {
        for (JsonNode n : array) {
            if (n.get("id").asText().equals(id.toString())) {
                return n;
            }
        }
        throw new AssertionError("event " + id + " not in response");
    }
}
