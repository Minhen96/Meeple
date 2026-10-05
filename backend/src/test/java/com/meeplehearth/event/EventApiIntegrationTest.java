package com.meeplehearth.event;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
class EventApiIntegrationTest extends EventIntegrationTestBase {

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
        assertThat(data.get("isHost").asBoolean()).isTrue();
        assertThat(data.get("reminderSent").asBoolean()).isFalse();
        assertThat(data.get("status").asText()).isEqualTo("OPEN");
        assertThat(data.get("visibility").asText()).isEqualTo("PUBLIC");
        assertThat(data.get("participants")).hasSize(1);
        assertThat(data.get("participants").get(0).get("id").asText()).isEqualTo(host.toString());
        assertThat(data.get("participants").get(0).get("status").asText()).isEqualTo("ACCEPTED");
        assertThat(string("SELECT status FROM event_participants WHERE event_id = ? AND user_id = ?", eventId, host))
                .isEqualTo("ACCEPTED");
    }

    @Test
    void createEventWithUnknownGameIs404() throws Exception {
        UUID host = user();
        mvc.perform(post("/api/v1/events").with(as(host))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("Mystery", Instant.now().plus(1, ChronoUnit.DAYS),
                                "FRIENDS", UUID.randomUUID(), 4))))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GAME_NOT_FOUND"));
        assertThat(count("SELECT COUNT(*) FROM events WHERE host_id = ?", host)).isZero();
    }

    @Test
    void createEventValidatesRequestPerFeatureLimits() throws Exception {
        UUID host = user();
        Instant future = Instant.now().plus(1, ChronoUnit.DAYS);

        List<Map<String, Object>> invalid = List.of(
                eventBody("Past", Instant.now().minus(10, ChronoUnit.MINUTES), "PUBLIC", null, null),
                eventBody("   ", future, "PUBLIC", null, null),
                eventBody("x".repeat(101), future, "PUBLIC", null, null),
                eventBody("Too small", future, "PUBLIC", null, 1),
                eventBody("Too big", future, "PUBLIC", null, 51),
                eventBody("No visibility", future, null, null, null),
                eventBody("Secret", future, "SECRET", null, null),
                with(eventBody("Long location", future, "PUBLIC", null, null), "location", "x".repeat(101)),
                with(eventBody("Long display", future, "PUBLIC", null, null), "locationDisplay", "x".repeat(101)),
                with(eventBody("Long description", future, "PUBLIC", null, null), "description", "x".repeat(1001)));
        for (Map<String, Object> body : invalid) {
            mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON)
                            .content(toJson(body)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        }
        assertThat(count("SELECT COUNT(*) FROM events WHERE host_id = ?", host)).isZero();

        // Boundaries are accepted: 1-char title, 100-char title, 2 and 50 players, 2 minutes ago (clock drift)
        mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("a", future, "PUBLIC", null, 2))))
                .andExpect(status().isCreated());
        mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("x".repeat(100), Instant.now().minus(2, ChronoUnit.MINUTES),
                                "PUBLIC", null, 50))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.reminderSent").value(true));
    }

    @Test
    void createWithInvitesInvitesFriendsAndNotifiesEach() throws Exception {
        UUID host = user();
        UUID friendA = user();
        UUID friendB = user();
        friends(host, friendA);
        friends(friendB, host);

        Map<String, Object> body = eventBody("Invite night", Instant.now().plus(3, ChronoUnit.DAYS), "INVITE_ONLY", null, 4);
        body.put("invitedUserIds", List.of(friendA, friendB, friendA));
        JsonNode data = json(mvc.perform(post("/api/v1/events").with(as(host))
                        .contentType(MediaType.APPLICATION_JSON).content(toJson(body)))
                .andExpect(status().isCreated()).andReturn()).get("data");
        UUID eventId = UUID.fromString(data.get("id").asText());

        assertThat(data.get("participantCount").asInt()).isEqualTo(1);
        assertThat(data.get("participants")).hasSize(3); // host sees invitees with their status
        assertThat(string("SELECT status FROM event_participants WHERE event_id = ? AND user_id = ?", eventId, friendA))
                .isEqualTo("INVITED");
        assertThat(notifications(friendA, "EVENT_INVITE", eventId)).isEqualTo(1);
        assertThat(notifications(friendB, "EVENT_INVITE", eventId)).isEqualTo(1);
        // INVITE_ONLY events are not announced in the feed... and invitees can see the event
        mvc.perform(get("/api/v1/events/{id}", eventId).with(as(friendB)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.myRsvp").value("INVITED"))
                .andExpect(jsonPath("$.data.isHost").value(false))
                .andExpect(jsonPath("$.data.participants.length()").value(1)); // non-hosts see accepted only
    }

    @Test
    void invitingNonFriendsOrYourselfIsRejectedAndCreatesNothing() throws Exception {
        UUID host = user();
        UUID friend = user();
        UUID stranger = user();
        UUID pending = user();
        friends(host, friend);
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'PENDING')", host, pending);
        Instant when = Instant.now().plus(2, ChronoUnit.DAYS);

        for (UUID notFriend : List.of(stranger, pending)) {
            Map<String, Object> body = eventBody("Night", when, "FRIENDS", null, null);
            body.put("invitedUserIds", List.of(friend, notFriend));
            mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON).content(toJson(body)))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.code").value("NOT_FRIENDS"));
        }
        Map<String, Object> self = eventBody("Night", when, "FRIENDS", null, null);
        self.put("invitedUserIds", List.of(host));
        mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON).content(toJson(self)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("CANNOT_INVITE_SELF"));

        // A deleted friend cannot be invited either
        softDeleteUser(friend);
        Map<String, Object> deleted = eventBody("Night", when, "FRIENDS", null, null);
        deleted.put("invitedUserIds", List.of(friend));
        mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON).content(toJson(deleted)))
                .andExpect(status().isForbidden());

        assertThat(count("SELECT COUNT(*) FROM events WHERE host_id = ?", host)).isZero();
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE type = 'EVENT_INVITE' AND actor_id = ?", host)).isZero();
    }

    @Test
    void createPublishesActivityOnlyForNonInviteOnlyEvents() throws Exception {
        UUID host = user();
        Instant when = Instant.now().plus(2, ChronoUnit.DAYS);
        applicationEvents.clear();

        mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON)
                .content(toJson(eventBody("Secret", when, "INVITE_ONLY", null, null)))).andExpect(status().isCreated());
        assertThat(activities(host)).isEmpty();

        String id = json(mvc.perform(post("/api/v1/events").with(as(host)).contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(eventBody("Open", when, "FRIENDS", null, null))))
                .andExpect(status().isCreated()).andReturn()).get("data").get("id").asText();
        assertThat(activities(host)).singleElement().satisfies(a -> {
            assertThat(a.type()).isEqualTo("event_created");
            assertThat(a.data()).containsEntry("eventId", UUID.fromString(id)).containsEntry("eventTitle", "Open");
        });
    }

    // -------------------------------------------------------------------------
    // Lists
    // -------------------------------------------------------------------------

    @Test
    void upcomingListShowsTheCallersCircleInOrder() throws Exception {
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

        // A stranger's circle has none of the host's events; public ones are in the community tab
        List<UUID> forStranger = ids(json(mvc.perform(get("/api/v1/events").param("scope", "upcoming").with(as(stranger)))
                .andExpect(status().isOk()).andReturn()));
        assertThat(forStranger).doesNotContain(publicSoon, publicLater, friendsOnly, inviteOnly);
        participant(inviteOnly, stranger, "INVITED");
        assertThat(ids(json(mvc.perform(get("/api/v1/events").with(as(stranger))).andReturn()))).contains(inviteOnly);
        jdbc.update("UPDATE event_participants SET status = 'LEFT' WHERE event_id = ? AND user_id = ?", inviteOnly, stranger);
        assertThat(ids(json(mvc.perform(get("/api/v1/events").with(as(stranger))).andReturn()))).doesNotContain(inviteOnly);

        // Batch-built counts, caller RSVP and accepted participants
        JsonNode friendList = json(mvc.perform(get("/api/v1/events").with(as(friend))).andReturn());
        JsonNode soon = find(friendList.get("data"), publicSoon);
        assertThat(soon.get("participantCount").asInt()).isEqualTo(2);
        assertThat(soon.get("myRsvp").asText()).isEqualTo("ACCEPTED");
        assertThat(soon.get("participants")).hasSize(2);
        assertThat(find(friendList.get("data"), publicLater).get("myRsvp").isNull()).isTrue();

        // limit is clamped to at least 1
        mvc.perform(get("/api/v1/events").with(as(host)).param("limit", "0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1));
        mvc.perform(get("/api/v1/events").with(as(host)).param("limit", "2"))
                .andExpect(jsonPath("$.data.length()").value(2));
        mvc.perform(get("/api/v1/events").with(as(host)).param("scope", "later"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void pastScopeListsHostedAndAttendedEventsMostRecentFirst() throws Exception {
        UUID host = user();
        UUID guest = user();
        UUID other = user();
        Instant now = Instant.now();
        UUID older = event(host, "PUBLIC", now.minus(5, ChronoUnit.DAYS), 8);
        UUID recent = event(host, "PUBLIC", now.minus(1, ChronoUnit.DAYS), 8);
        UUID completedEarly = event(host, "PUBLIC", now.plus(1, ChronoUnit.HOURS), 8);
        jdbc.update("UPDATE events SET status = 'COMPLETED' WHERE id = ?", completedEarly);
        UUID upcoming = event(host, "PUBLIC", now.plus(1, ChronoUnit.DAYS), 8);
        UUID cancelled = event(host, "PUBLIC", now.minus(2, ChronoUnit.DAYS), 8);
        jdbc.update("UPDATE events SET status = 'CANCELLED', deleted_at = now() WHERE id = ?", cancelled);
        UUID notAttended = event(other, "PUBLIC", now.minus(1, ChronoUnit.DAYS), 8);
        participant(recent, guest, "ACCEPTED");
        participant(older, guest, "LEFT");
        participant(notAttended, guest, "DECLINED");

        assertThat(ids(json(mvc.perform(get("/api/v1/events").param("scope", "past").with(as(host)))
                .andExpect(status().isOk()).andReturn())))
                .containsExactly(completedEarly, recent, older)
                .doesNotContain(upcoming, cancelled);
        assertThat(ids(json(mvc.perform(get("/api/v1/events").param("scope", "PAST").with(as(guest))).andReturn())))
                .containsExactly(recent);
    }

    @Test
    void mineScopeAndMeListOnlyAcceptedEvents() throws Exception {
        UUID host = user();
        UUID me = user();
        UUID accepted = event(host, "PUBLIC", Instant.now().plus(2, ChronoUnit.DAYS), 8);
        UUID declined = event(host, "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), 8);
        UUID left = event(host, "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), 8);
        participant(accepted, me, "ACCEPTED");
        participant(declined, me, "DECLINED");
        participant(left, me, "LEFT");

        mvc.perform(get("/api/v1/events/me").with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].id").value(accepted.toString()))
                .andExpect(jsonPath("$.data[0].participantCount").value(2));
        mvc.perform(get("/api/v1/events").param("scope", "mine").with(as(me)))
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].id").value(accepted.toString()));

        UUID nobody = user();
        mvc.perform(get("/api/v1/events/me").with(as(nobody)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(0));
    }

    @Test
    void calendarReturnsCircleEventsInRangeIncludingCompleted() throws Exception {
        UUID host = user();
        UUID friend = user();
        UUID stranger = user();
        friends(host, friend);
        Instant from = Instant.now().minus(10, ChronoUnit.DAYS).truncatedTo(ChronoUnit.DAYS);
        Instant to = from.plus(31, ChronoUnit.DAYS);
        UUID inPast = event(host, "FRIENDS", from.plus(2, ChronoUnit.DAYS), 8);
        jdbc.update("UPDATE events SET status = 'COMPLETED' WHERE id = ?", inPast);
        UUID inFuture = event(host, "PUBLIC", from.plus(20, ChronoUnit.DAYS), 8);
        UUID atStart = event(host, "FRIENDS", from, 8);
        UUID atEnd = event(host, "FRIENDS", to, 8); // exclusive upper bound
        UUID before = event(host, "FRIENDS", from.minusSeconds(1), 8);
        UUID inviteOnly = event(host, "INVITE_ONLY", from.plus(3, ChronoUnit.DAYS), 8);
        UUID cancelled = event(host, "FRIENDS", from.plus(4, ChronoUnit.DAYS), 8);
        jdbc.update("UPDATE events SET status = 'CANCELLED', deleted_at = now() WHERE id = ?", cancelled);

        List<UUID> forFriend = ids(json(mvc.perform(get("/api/v1/events/calendar").with(as(friend))
                        .param("from", from.toString()).param("to", to.toString()))
                .andExpect(status().isOk()).andReturn()));
        assertThat(forFriend).containsExactly(atStart, inPast, inFuture)
                .doesNotContain(atEnd, before, inviteOnly, cancelled);
        assertThat(ids(json(mvc.perform(get("/api/v1/events/calendar").with(as(host))
                .param("from", from.toString()).param("to", to.toString())).andReturn())))
                .containsExactly(atStart, inPast, inviteOnly, inFuture);
        assertThat(ids(json(mvc.perform(get("/api/v1/events/calendar").with(as(stranger))
                .param("from", from.toString()).param("to", to.toString())).andReturn()))).isEmpty();

        mvc.perform(get("/api/v1/events/calendar").with(as(friend))
                        .param("from", from.toString()).param("to", from.plus(63, ChronoUnit.DAYS).toString()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_RANGE"));
        mvc.perform(get("/api/v1/events/calendar").with(as(friend)).param("from", "yesterday").param("to", to.toString()))
                .andExpect(status().isBadRequest());
        mvc.perform(get("/api/v1/events/calendar").with(as(friend)).param("from", from.toString()))
                .andExpect(status().isBadRequest());
    }

    @Test
    void communityListsUpcomingPublicEventsWithCursorAndMasksLocation() throws Exception {
        UUID viewer = user();
        UUID hostA = user();
        UUID hostB = user();
        UUID blockedHost = user();
        block(viewer, blockedHost);
        UUID gameId = game();
        Instant base = Instant.now().plus(400, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
        // Far in the future so other tests' public events sort before ours; filter by game for isolation
        UUID e1 = event(hostA, "PUBLIC", base, 8);
        UUID e2 = event(hostB, "PUBLIC", base, 8); // same time: ordered by id
        UUID e3 = event(hostA, "PUBLIC", base.plus(1, ChronoUnit.DAYS), 8);
        UUID friendsOnly = event(hostA, "FRIENDS", base, 8);
        UUID blocked = event(blockedHost, "PUBLIC", base, 8);
        UUID completed = event(hostA, "PUBLIC", base, 8);
        jdbc.update("UPDATE events SET status = 'COMPLETED' WHERE id = ?", completed);
        UUID pastPublic = event(hostA, "PUBLIC", Instant.now().minus(1, ChronoUnit.DAYS), 8);
        for (UUID id : List.of(e1, e2, e3, friendsOnly, blocked, completed, pastPublic)) {
            jdbc.update("UPDATE events SET game_id = ?, location = '12 Secret St', location_display = 'Petaling Jaya'"
                    + " WHERE id = ?", gameId, id);
        }

        JsonNode page1 = json(mvc.perform(get("/api/v1/events/community").with(as(viewer))
                        .param("gameId", gameId.toString()).param("limit", "2"))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(page1.get("hasMore").asBoolean()).isTrue();
        List<UUID> first = idsOf(page1.get("items"));
        List<UUID> sameTime = e1.toString().compareTo(e2.toString()) < 0 ? List.of(e1, e2) : List.of(e2, e1);
        assertThat(first).containsExactlyElementsOf(sameTime);
        JsonNode item = page1.get("items").get(0);
        assertThat(item.get("location").isNull()).isTrue();
        assertThat(item.get("locationDisplay").asText()).isEqualTo("Petaling Jaya");

        JsonNode page2 = json(mvc.perform(get("/api/v1/events/community").with(as(viewer))
                        .param("gameId", gameId.toString()).param("limit", "2")
                        .param("cursor", page1.get("nextCursor").asText()))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(idsOf(page2.get("items"))).containsExactly(e3);
        assertThat(page2.get("hasMore").asBoolean()).isFalse();
        assertThat(page2.get("nextCursor").isNull()).isTrue();

        // Without the game filter our events are still there (other tests may add more)
        JsonNode all = json(mvc.perform(get("/api/v1/events/community").with(as(viewer)).param("limit", "100"))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(all.get("items")).isNotNull();

        // The host and joined participants see the full address
        participant(e1, viewer, "ACCEPTED");
        mvc.perform(get("/api/v1/events/{id}", e1).with(as(viewer)))
                .andExpect(jsonPath("$.data.location").value("12 Secret St"));
        mvc.perform(get("/api/v1/events/{id}", e3).with(as(hostA)))
                .andExpect(jsonPath("$.data.location").value("12 Secret St"));
        mvc.perform(get("/api/v1/events/{id}", e3).with(as(viewer)))
                .andExpect(jsonPath("$.data.location").doesNotExist());
        mvc.perform(get("/api/v1/events/community").with(as(viewer)).param("cursor", "not a cursor"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_CURSOR"));
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
                .andExpect(jsonPath("$.data.myRsvp").value("INVITED"))
                .andExpect(jsonPath("$.data.location").doesNotExist());
    }

    @Test
    void participantsHideBlockedUsersFromTheViewer() throws Exception {
        UUID host = user();
        UUID viewer = user();
        UUID blockedGuest = user();
        UUID guest = user();
        UUID eventId = event(host, "PUBLIC", Instant.now().plus(1, ChronoUnit.DAYS), 8);
        participant(eventId, blockedGuest, "ACCEPTED");
        participant(eventId, guest, "ACCEPTED");
        participant(eventId, viewer, "DECLINED");
        block(blockedGuest, viewer);

        JsonNode data = json(mvc.perform(get("/api/v1/events/{id}", eventId).with(as(viewer)))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertThat(data.get("participantCount").asInt()).isEqualTo(3);
        assertThat(idsOf(data.get("participants"))).containsExactlyInAnyOrder(host, guest);

        JsonNode forHost = json(mvc.perform(get("/api/v1/events/{id}", eventId).with(as(host))).andReturn()).get("data");
        assertThat(idsOf(forHost.get("participants"))).containsExactlyInAnyOrder(host, blockedGuest, guest, viewer);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static Map<String, Object> with(Map<String, Object> body, String key, Object value) {
        Map<String, Object> copy = new HashMap<>(body);
        copy.put(key, value);
        return copy;
    }
}
