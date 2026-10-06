package com.meeplehearth.event;

import com.meeplehearth.event.dto.EventLiveUpdate;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Update, cancel, invites, RSVP / leave / kick rules and live updates, end to end. */
class EventParticipationApiIntegrationTest extends EventIntegrationTestBase {

    private static Instant tomorrow() {
        return Instant.now().plus(1, ChronoUnit.DAYS);
    }

    // -------------------------------------------------------------------------
    // Update
    // -------------------------------------------------------------------------

    @Test
    void hostCanPartiallyUpdateEvent() throws Exception {
        UUID host = user();
        UUID gameId = game();
        UUID eventId = event(host, "INVITE_ONLY", tomorrow(), 8);
        jdbc.update("UPDATE events SET description = 'keep me', location = 'Old place' WHERE id = ?", eventId);
        Instant newTime = Instant.now().plus(5, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);

        Map<String, Object> body = new HashMap<>();
        body.put("title", "Renamed night");
        body.put("location", "New place");
        body.put("locationDisplay", "Downtown");
        body.put("scheduledAt", newTime.toString());
        body.put("visibility", "PUBLIC");
        body.put("maxParticipants", 3);
        body.put("gameId", gameId);

        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("Renamed night"))
                .andExpect(jsonPath("$.data.description").value("keep me"))
                .andExpect(jsonPath("$.data.location").value("New place"))
                .andExpect(jsonPath("$.data.locationDisplay").value("Downtown"))
                .andExpect(jsonPath("$.data.visibility").value("PUBLIC"))
                .andExpect(jsonPath("$.data.game.id").value(gameId.toString()))
                .andExpect(jsonPath("$.data.maxParticipants").value(3))
                .andExpect(jsonPath("$.data.reminderSent").value(false));

        assertThat(string("SELECT visibility FROM events WHERE id = ?", eventId)).isEqualTo("PUBLIC");
        assertThat(jdbc.queryForObject("SELECT scheduled_at FROM events WHERE id = ?", java.sql.Timestamp.class,
                eventId).toInstant()).isEqualTo(newTime);

        // Empty strings clear optional text; only-description bodies are fine (all fields optional)
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"description\":\"\",\"location\":\"\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.description").doesNotExist())
                .andExpect(jsonPath("$.data.location").doesNotExist())
                .andExpect(jsonPath("$.data.title").value("Renamed night"));
    }

    @Test
    void updateValidatesFields() throws Exception {
        UUID host = user();
        UUID eventId = event(host, "PUBLIC", tomorrow(), 8);
        for (String body : List.of("{\"title\":\"  \"}", "{\"title\":\"" + "x".repeat(101) + "\"}",
                "{\"maxParticipants\":51}", "{\"maxParticipants\":1}", "{\"visibility\":\"SECRET\"}",
                "{\"scheduledAt\":\"" + Instant.now().minus(1, ChronoUnit.HOURS) + "\"}",
                "{\"location\":\"" + "x".repeat(101) + "\"}")) {
            mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host))
                            .contentType(MediaType.APPLICATION_JSON).content(body))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        }
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"gameId\":\"" + UUID.randomUUID() + "\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GAME_NOT_FOUND"));
    }

    @Test
    void timeChangeNotifiesAcceptedParticipantsAndRearmsReminder() throws Exception {
        UUID host = user();
        UUID going = user();
        UUID invited = user();
        UUID eventId = event(host, "PUBLIC", Instant.now().plus(3, ChronoUnit.HOURS), 8);
        jdbc.update("UPDATE events SET reminder_sent = TRUE WHERE id = ?", eventId);
        participant(eventId, going, "ACCEPTED");
        participant(eventId, invited, "INVITED");

        // Same time and other fields: nobody is notified
        String sameTime = jdbc.queryForObject("SELECT scheduled_at FROM events WHERE id = ?", java.sql.Timestamp.class,
                eventId).toInstant().toString();
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"scheduledAt\":\"" + sameTime + "\",\"title\":\"New title\"}"))
                .andExpect(status().isOk());
        assertThat(notifications(going, "EVENT_UPDATED", eventId)).isZero();

        Instant later = Instant.now().plus(4, ChronoUnit.DAYS);
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"scheduledAt\":\"" + later + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.reminderSent").value(false));
        assertThat(notifications(going, "EVENT_UPDATED", eventId)).isEqualTo(1);
        assertThat(notifications(invited, "EVENT_UPDATED", eventId)).isZero();
        assertThat(notifications(host, "EVENT_UPDATED", eventId)).isZero();
    }

    @Test
    void maxCannotDropBelowAcceptedAndChangingItTogglesFull() throws Exception {
        UUID host = user();
        UUID a = user();
        UUID b = user();
        UUID eventId = event(host, "PUBLIC", tomorrow(), 4);
        participant(eventId, a, "ACCEPTED");
        participant(eventId, b, "INVITED");

        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"maxParticipants\":2}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FULL"));
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"maxParticipants\":2}"))
                .andExpect(status().isOk());
        jdbc.update("UPDATE event_participants SET status = 'ACCEPTED' WHERE event_id = ? AND user_id = ?", eventId, b);
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"maxParticipants\":2}"))
                .andExpect(status().isOk());
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"maxParticipants\":3,\"title\":\"x\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FULL"));
        jdbc.update("UPDATE event_participants SET status = 'LEFT' WHERE event_id = ? AND user_id = ?", eventId, b);
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"maxParticipants\":1}"))
                .andExpect(status().isBadRequest());
        jdbc.update("UPDATE event_participants SET status = 'ACCEPTED' WHERE event_id = ? AND user_id = ?", eventId, b);
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"maxParticipants\":2}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("MAX_BELOW_ACCEPTED"));
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"maxParticipants\":10}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("OPEN"));
    }

    @Test
    void gameCannotChangeOnceCompleted() throws Exception {
        UUID host = user();
        UUID game1 = game();
        UUID game2 = game();
        UUID eventId = event(host, "PUBLIC", Instant.now().minus(1, ChronoUnit.DAYS), 8);
        jdbc.update("UPDATE events SET status = 'COMPLETED', game_id = ? WHERE id = ?", game1, eventId);

        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"gameId\":\"" + game2 + "\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVENT_COMPLETED"));
        // Same game and other fields are still editable
        mvc.perform(put("/api/v1/events/{id}", eventId).with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"gameId\":\"" + game1 + "\",\"description\":\"Great night\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.description").value("Great night"));
    }

    @Test
    void nonHostMutationsAreForbiddenAndInvisibleEventIs404() throws Exception {
        UUID host = user();
        UUID other = user();
        UUID publicEvent = event(host, "PUBLIC", tomorrow(), 8);
        UUID hidden = event(host, "INVITE_ONLY", tomorrow(), 8);
        String body = "{\"title\":\"Hijacked\"}";

        mvc.perform(put("/api/v1/events/{id}", publicEvent).with(as(other))
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_HOST"));
        mvc.perform(delete("/api/v1/events/{id}", publicEvent).with(as(other))).andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/events/{id}/cancel", publicEvent).with(as(other))).andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/events/{id}/invites", publicEvent).with(as(other))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"userIds\":[\"" + host + "\"]}"))
                .andExpect(status().isForbidden());
        mvc.perform(delete("/api/v1/events/{id}/participants/{uid}", publicEvent, host).with(as(other)))
                .andExpect(status().isForbidden());
        mvc.perform(put("/api/v1/events/{id}", hidden).with(as(other))
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isNotFound());
        mvc.perform(post("/api/v1/events/{id}/cancel", hidden).with(as(other))).andExpect(status().isNotFound());

        assertThat(string("SELECT title FROM events WHERE id = ?", publicEvent)).isEqualTo("PUBLIC night");
    }

    // -------------------------------------------------------------------------
    // Cancel
    // -------------------------------------------------------------------------

    @Test
    void cancelNotifiesAcceptedParticipantsAndKeepsEventForThem() throws Exception {
        UUID host = user();
        UUID guest = user();
        UUID invitee = user();
        UUID decliner = user();
        UUID stranger = user();
        UUID eventId = event(host, "PUBLIC", tomorrow(), 8);
        participant(eventId, guest, "ACCEPTED");
        participant(eventId, invitee, "INVITED");
        participant(eventId, decliner, "DECLINED");
        clearLiveUpdates();

        mvc.perform(post("/api/v1/events/{id}/cancel", eventId).with(as(host))).andExpect(status().isNoContent());

        assertThat(eventStatus(eventId)).isEqualTo("CANCELLED");
        assertThat(count("SELECT COUNT(*) FROM events WHERE id = ? AND deleted_at IS NOT NULL", eventId)).isEqualTo(1);
        assertThat(notifications(guest, "EVENT_CANCELLED", eventId)).isEqualTo(1);
        assertThat(notifications(invitee, "EVENT_CANCELLED", eventId)).isZero();
        assertThat(notifications(host, "EVENT_CANCELLED", eventId)).isZero();
        EventLiveUpdate update = lastLiveUpdate(eventId);
        assertThat(update.status()).isEqualTo("CANCELLED");

        // Host, going and invited users still see it (with the cancelled banner); others do not
        for (UUID viewer : List.of(host, guest, invitee)) {
            mvc.perform(get("/api/v1/events/{id}", eventId).with(as(viewer)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.status").value("CANCELLED"));
        }
        for (UUID viewer : List.of(decliner, stranger)) {
            mvc.perform(get("/api/v1/events/{id}", eventId).with(as(viewer))).andExpect(status().isNotFound());
        }
        mvc.perform(get("/api/v1/events/me").with(as(guest))).andExpect(jsonPath("$.data.length()").value(0));
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(invitee)).param("status", "ACCEPTED"))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(guest)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("EVENT_NOT_FOUND"));
        mvc.perform(post("/api/v1/events/{id}/cancel", eventId).with(as(host))).andExpect(status().isNotFound());
    }

    @Test
    void deleteIsAnAliasOfCancelAndCompletedEventsCannotBeCancelled() throws Exception {
        UUID host = user();
        UUID guest = user();
        UUID eventId = event(host, "FRIENDS", tomorrow(), 8);
        participant(eventId, guest, "ACCEPTED");
        mvc.perform(delete("/api/v1/events/{id}", eventId).with(as(host))).andExpect(status().isNoContent());
        assertThat(eventStatus(eventId)).isEqualTo("CANCELLED");
        assertThat(notifications(guest, "EVENT_CANCELLED", eventId)).isEqualTo(1);

        UUID done = event(host, "FRIENDS", Instant.now().minus(1, ChronoUnit.DAYS), 8);
        jdbc.update("UPDATE events SET status = 'COMPLETED' WHERE id = ?", done);
        mvc.perform(post("/api/v1/events/{id}/cancel", done).with(as(host)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVENT_COMPLETED"));
    }

    // -------------------------------------------------------------------------
    // Invites
    // -------------------------------------------------------------------------

    @Test
    void hostInvitesFriendsReinvitesFormerParticipantsAndSkipsCurrentOnes() throws Exception {
        UUID host = user();
        UUID fresh = user();
        UUID declined = user();
        UUID kicked = user();
        UUID going = user();
        UUID invited = user();
        for (UUID f : List.of(fresh, declined, kicked, going, invited)) {
            friends(host, f);
        }
        UUID eventId = event(host, "FRIENDS", tomorrow(), 8);
        participant(eventId, declined, "DECLINED");
        participant(eventId, kicked, "KICKED");
        participant(eventId, going, "ACCEPTED");
        participant(eventId, invited, "INVITED");

        mvc.perform(post("/api/v1/events/{id}/invites", eventId).with(as(host))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(Map.of("userIds", List.of(fresh, declined, kicked, going, invited)))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.participants.length()").value(6));

        for (UUID u : List.of(fresh, declined, kicked, invited)) {
            assertThat(participantStatus(eventId, u)).isEqualTo("INVITED");
        }
        assertThat(participantStatus(eventId, going)).isEqualTo("ACCEPTED");
        for (UUID u : List.of(fresh, declined, kicked)) {
            assertThat(notifications(u, "EVENT_INVITE", eventId)).isEqualTo(1);
        }
        assertThat(notifications(going, "EVENT_INVITE", eventId)).isZero();
        assertThat(notifications(invited, "EVENT_INVITE", eventId)).isZero();

        // A re-invited user who was kicked can now join the FRIENDS event
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(kicked)).param("status", "ACCEPTED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.myRsvp").value("ACCEPTED"));
    }

    @Test
    void inviteValidation() throws Exception {
        UUID host = user();
        UUID stranger = user();
        UUID eventId = event(host, "PUBLIC", tomorrow(), 8);

        mvc.perform(post("/api/v1/events/{id}/invites", eventId).with(as(host))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"userIds\":[]}"))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/events/{id}/invites", eventId).with(as(host))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("userIds", List.of(stranger)))))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_FRIENDS"));
        mvc.perform(post("/api/v1/events/{id}/invites", eventId).with(as(host))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("userIds", List.of(host)))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("CANNOT_INVITE_SELF"));

        jdbc.update("UPDATE events SET status = 'COMPLETED' WHERE id = ?", eventId);
        friends(host, stranger);
        mvc.perform(post("/api/v1/events/{id}/invites", eventId).with(as(host))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(Map.of("userIds", List.of(stranger)))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVENT_COMPLETED"));
        assertThat(count("SELECT COUNT(*) FROM event_participants WHERE user_id = ?", stranger)).isZero();
    }

    // -------------------------------------------------------------------------
    // RSVP and join rules (decision C9)
    // -------------------------------------------------------------------------

    @Test
    void publicEventsAreOpenJoinWithCapacity() throws Exception {
        UUID host = user();
        UUID a = user();
        UUID b = user();
        UUID eventId = event(host, "PUBLIC", tomorrow(), 2);
        jdbc.update("UPDATE events SET location = 'Secret address', location_display = 'Downtown' WHERE id = ?", eventId);
        applicationEvents.clear();
        clearLiveUpdates();

        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(a)).param("status", "ACCEPTED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FULL"))
                .andExpect(jsonPath("$.data.participantCount").value(2))
                .andExpect(jsonPath("$.data.myRsvp").value("ACCEPTED"))
                .andExpect(jsonPath("$.data.location").value("Secret address"));
        assertThat(notifications(host, "EVENT_RSVP", eventId)).isEqualTo(1);
        assertThat(activities(a)).singleElement().satisfies(act -> assertThat(act.type()).isEqualTo("event_joined"));
        EventLiveUpdate update = lastLiveUpdate(eventId);
        assertThat(update.participantCount()).isEqualTo(2);
        assertThat(update.status()).isEqualTo("FULL");
        // No roster in the broadcast (blocks are per viewer): clients refetch the event
        assertThat(lastLiveUpdateJson(eventId).has("participants")).isFalse();

        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(b)).param("status", "ACCEPTED"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVENT_FULL"));
        // Re-accepting when already accepted is a no-op
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(a)).param("status", "ACCEPTED"))
                .andExpect(status().isOk());
        assertThat(notifications(host, "EVENT_RSVP", eventId)).isEqualTo(1);
        // Without an invite there is nothing to decline
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(b)).param("status", "DECLINED"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_INVITED"));
        // Going → declined is not a way to leave
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(a)).param("status", "DECLINED"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_STATUS_TRANSITION"));
        // The host is always going
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(host)).param("status", "ACCEPTED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.isHost").value(true));
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(host)).param("status", "DECLINED"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("HOST_CANNOT_LEAVE"));
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE recipient_id = ? AND actor_id = ?", host, host)).isZero();

        // After leaving, a public event can be joined again
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(a))).andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(b)).param("status", "ACCEPTED"))
                .andExpect(status().isOk());
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(b))).andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(a)).param("status", "ACCEPTED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.myRsvp").value("ACCEPTED"));
    }

    @Test
    void friendsAndInviteOnlyEventsNeedAnInvite() throws Exception {
        UUID host = user();
        UUID friend = user();
        UUID invitedFriend = user();
        friends(host, friend);
        friends(host, invitedFriend);
        UUID friendsEvent = event(host, "FRIENDS", tomorrow(), 8);
        UUID inviteOnly = event(host, "INVITE_ONLY", tomorrow(), 8);
        participant(friendsEvent, invitedFriend, "INVITED");

        // A friend can see the FRIENDS event but cannot join it uninvited
        mvc.perform(get("/api/v1/events/{id}", friendsEvent).with(as(friend))).andExpect(status().isOk());
        mvc.perform(post("/api/v1/events/{id}/rsvp", friendsEvent).with(as(friend)).param("status", "ACCEPTED"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_INVITED"));
        // An invite-only event is invisible to a non-invited friend
        mvc.perform(post("/api/v1/events/{id}/rsvp", inviteOnly).with(as(friend)).param("status", "ACCEPTED"))
                .andExpect(status().isNotFound());
        assertThat(count("SELECT COUNT(*) FROM event_participants WHERE user_id = ?", friend)).isZero();

        // Invited: decline, change to going, leave; leaving needs a new invite to come back
        mvc.perform(post("/api/v1/events/{id}/rsvp", friendsEvent).with(as(invitedFriend)).param("status", "DECLINED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.myRsvp").value("DECLINED"));
        mvc.perform(post("/api/v1/events/{id}/rsvp", friendsEvent).with(as(invitedFriend)).param("status", "ACCEPTED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.myRsvp").value("ACCEPTED"));
        mvc.perform(delete("/api/v1/events/{id}/rsvp", friendsEvent).with(as(invitedFriend)))
                .andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/events/{id}/rsvp", friendsEvent).with(as(invitedFriend)).param("status", "ACCEPTED"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_INVITED"));
        assertThat(activities(invitedFriend)).extracting(a -> a.type()).containsExactly("event_joined");

        // Invite-only joins are not announced
        participant(inviteOnly, friend, "INVITED");
        applicationEvents.clear();
        mvc.perform(post("/api/v1/events/{id}/rsvp", inviteOnly).with(as(friend)).param("status", "ACCEPTED"))
                .andExpect(status().isOk());
        assertThat(activities(friend)).isEmpty();
    }

    @Test
    void rsvpToCompletedOrUnknownEventIsRejected() throws Exception {
        UUID host = user();
        UUID guest = user();
        UUID eventId = event(host, "PUBLIC", Instant.now().minus(1, ChronoUnit.DAYS), 8);
        jdbc.update("UPDATE events SET status = 'COMPLETED' WHERE id = ?", eventId);
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(guest)).param("status", "ACCEPTED"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVENT_COMPLETED"));
        mvc.perform(post("/api/v1/events/{id}/rsvp", UUID.randomUUID()).with(as(guest)).param("status", "ACCEPTED"))
                .andExpect(status().isNotFound());
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(guest)).param("status", "MAYBE"))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(guest)).param("status", "INVITED"))
                .andExpect(status().isBadRequest());
        assertThat(count("SELECT COUNT(*) FROM event_participants WHERE user_id = ?", guest)).isZero();
    }

    /** Acceptance criterion: two concurrent accepts for the last spot, exactly one succeeds. */
    @Test
    void lastSpotRaceLetsExactlyOneJoin() throws Exception {
        UUID host = user();
        UUID a = user();
        UUID b = user();
        UUID eventId = event(host, "PUBLIC", tomorrow(), 2);

        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Callable<Integer> joinA = () -> {
                start.await();
                return join(eventId, a).getResponse().getStatus();
            };
            Callable<Integer> joinB = () -> {
                start.await();
                return join(eventId, b).getResponse().getStatus();
            };
            Future<Integer> fa = pool.submit(joinA);
            Future<Integer> fb = pool.submit(joinB);
            start.countDown();
            List<Integer> statuses = List.of(fa.get(30, TimeUnit.SECONDS), fb.get(30, TimeUnit.SECONDS));
            assertThat(statuses).containsExactlyInAnyOrder(200, 409);
        } finally {
            pool.shutdownNow();
        }
        assertThat(count("SELECT COUNT(*) FROM event_participants WHERE event_id = ? AND status = 'ACCEPTED'", eventId))
                .isEqualTo(2);
        assertThat(eventStatus(eventId)).isEqualTo("FULL");
    }

    private MvcResult join(UUID eventId, UUID userId) throws Exception {
        return mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(userId)).param("status", "ACCEPTED"))
                .andReturn();
    }

    // -------------------------------------------------------------------------
    // Leave
    // -------------------------------------------------------------------------

    @Test
    void leaveSetsLeftNotifiesHostAndReopensFullEvent() throws Exception {
        UUID host = user();
        UUID guest = user();
        UUID outsider = user();
        UUID invitee = user();
        UUID eventId = event(host, "PUBLIC", tomorrow(), 2);
        participant(eventId, invitee, "INVITED");

        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(outsider)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("RSVP_NOT_FOUND"));
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(host)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("HOST_CANNOT_LEAVE"));
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(invitee)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("NOT_PARTICIPANT"));

        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(guest)).param("status", "ACCEPTED"))
                .andExpect(jsonPath("$.data.status").value("FULL"));
        clearLiveUpdates();
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(guest))).andExpect(status().isNoContent());

        assertThat(eventStatus(eventId)).isEqualTo("OPEN");
        assertThat(participantStatus(eventId, guest)).isEqualTo("LEFT");
        assertThat(notifications(host, "EVENT_LEAVE", eventId)).isEqualTo(1);
        assertThat(lastLiveUpdate(eventId).participantCount()).isEqualTo(1);
        mvc.perform(get("/api/v1/events/{id}", eventId).with(as(guest)))
                .andExpect(jsonPath("$.data.myRsvp").value("LEFT"));

        // Leaving twice is a no-op
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(guest))).andExpect(status().isNoContent());
        assertThat(notifications(host, "EVENT_LEAVE", eventId)).isEqualTo(1);

        // A completed event cannot be left
        participant(eventId, outsider, "ACCEPTED");
        jdbc.update("UPDATE events SET status = 'COMPLETED' WHERE id = ?", eventId);
        mvc.perform(delete("/api/v1/events/{id}/rsvp", eventId).with(as(outsider)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVENT_COMPLETED"));
    }

    // -------------------------------------------------------------------------
    // Kick
    // -------------------------------------------------------------------------

    @Test
    void kickReopensFullEventNotifiesAndBlocksRejoin() throws Exception {
        UUID host = user();
        UUID guest = user();
        UUID eventId = event(host, "PUBLIC", tomorrow(), 2);
        participant(eventId, guest, "ACCEPTED");
        jdbc.update("UPDATE events SET status = 'FULL' WHERE id = ?", eventId);
        clearLiveUpdates();

        mvc.perform(delete("/api/v1/events/{id}/participants/{uid}", eventId, guest).with(as(host)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("OPEN"))
                .andExpect(jsonPath("$.data.participantCount").value(1));

        assertThat(participantStatus(eventId, guest)).isEqualTo("KICKED");
        assertThat(notifications(guest, "EVENT_KICKED", eventId)).isEqualTo(1);
        assertThat(lastLiveUpdate(eventId).status()).isEqualTo("OPEN");
        mvc.perform(post("/api/v1/events/{id}/rsvp", eventId).with(as(guest)).param("status", "ACCEPTED"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("KICKED"));

        // Kicking again is a no-op (no second notification)
        mvc.perform(delete("/api/v1/events/{id}/participants/{uid}", eventId, guest).with(as(host)))
                .andExpect(status().isOk());
        assertThat(notifications(guest, "EVENT_KICKED", eventId)).isEqualTo(1);
    }

    @Test
    void kickRules() throws Exception {
        UUID host = user();
        UUID outsider = user();
        UUID declined = user();
        UUID eventId = event(host, "PUBLIC", tomorrow(), 8);
        participant(eventId, declined, "DECLINED");

        mvc.perform(delete("/api/v1/events/{id}/participants/{uid}", eventId, host).with(as(host)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("CANNOT_KICK_HOST"));
        mvc.perform(delete("/api/v1/events/{id}/participants/{uid}", eventId, outsider).with(as(host)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_PARTICIPANT"));
        clearLiveUpdates();
        // Removing someone who declined blocks a later open join but sends nothing
        mvc.perform(delete("/api/v1/events/{id}/participants/{uid}", eventId, declined).with(as(host)))
                .andExpect(status().isOk());
        assertThat(participantStatus(eventId, declined)).isEqualTo("KICKED");
        assertThat(notifications(declined, "EVENT_KICKED", eventId)).isZero();
        assertThat(liveUpdates(eventId)).isEmpty();

        jdbc.update("UPDATE events SET status = 'COMPLETED' WHERE id = ?", eventId);
        mvc.perform(delete("/api/v1/events/{id}/participants/{uid}", eventId, declined).with(as(host)))
                .andExpect(status().isConflict());
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private EventLiveUpdate lastLiveUpdate(UUID eventId) {
        List<EventLiveUpdate> all = liveUpdates(eventId);
        assertThat(all).as("live updates for %s", eventId).isNotEmpty();
        return all.get(all.size() - 1);
    }
}
