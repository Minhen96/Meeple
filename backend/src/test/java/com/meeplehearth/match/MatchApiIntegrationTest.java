package com.meeplehearth.match;

import com.fasterxml.jackson.databind.JsonNode;
import com.meeplehearth.match.service.MatchScheduler;
import com.meeplehearth.support.social.ApiIntegrationTestBase;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import java.time.Duration;
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
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Matching end to end: match requests via the API, the scheduler job (real Redis lock, real
 * Postgres), suggestions, accept (creates an event) and dismiss.
 */
class MatchApiIntegrationTest extends ApiIntegrationTestBase {

    private static final String LOCK_KEY = "lock:matching_job";

    @Autowired private MatchScheduler matchScheduler;
    @Autowired private StringRedisTemplate redis;

    @AfterEach
    void releaseLock() {
        redis.delete(LOCK_KEY);
    }

    // -------------------------------------------------------------------------
    // Requests
    // -------------------------------------------------------------------------

    @Test
    void createRequestIsIdempotentPerGameAndListedUntilCancelled() throws Exception {
        UUID me = user();
        UUID gameId = game(2, 4);
        Instant from = Instant.now().plus(1, ChronoUnit.HOURS).truncatedTo(ChronoUnit.SECONDS);
        Instant to = from.plus(3, ChronoUnit.HOURS);

        UUID requestId = UUID.fromString(json(createRequest(me, gameId, from, to)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ACTIVE"))
                .andExpect(jsonPath("$.data.game.id").value(gameId.toString()))
                .andReturn()).get("data").get("id").asText());

        // Same game again: the existing ACTIVE request's window is updated, no second row
        Instant newTo = to.plus(1, ChronoUnit.HOURS);
        createRequest(me, gameId, from, newTo)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(requestId.toString()))
                .andExpect(jsonPath("$.data.availableTo").value(newTo.toString()));
        assertThat(count("SELECT COUNT(*) FROM match_requests WHERE user_id = ?", me)).isEqualTo(1);

        mvc.perform(get("/api/v1/matches/requests/me").with(as(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].id").value(requestId.toString()));

        UUID other = user();
        mvc.perform(delete("/api/v1/matches/requests/{id}", requestId).with(as(other)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
        mvc.perform(delete("/api/v1/matches/requests/{id}", UUID.randomUUID()).with(as(me)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("REQUEST_NOT_FOUND"));
        mvc.perform(delete("/api/v1/matches/requests/{id}", requestId).with(as(me)))
                .andExpect(status().isNoContent());

        assertThat(string("SELECT status FROM match_requests WHERE id = ?", requestId)).isEqualTo("CANCELLED");
        mvc.perform(get("/api/v1/matches/requests/me").with(as(me)))
                .andExpect(jsonPath("$.data.length()").value(0));
    }

    @Test
    void createRequestValidatesTimeWindowGameAndBody() throws Exception {
        UUID me = user();
        UUID gameId = game();
        Instant soon = Instant.now().plus(1, ChronoUnit.HOURS);

        createRequest(me, gameId, soon, soon)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_TIME"));
        createRequest(me, gameId, soon.plus(2, ChronoUnit.HOURS), soon)
                .andExpect(status().isBadRequest());
        createRequest(me, gameId, soon, Instant.now().plus(8, ChronoUnit.DAYS))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_TIME"));
        createRequest(me, UUID.randomUUID(), null, null)
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GAME_NOT_FOUND"));
        mvc.perform(post("/api/v1/matches/requests").with(as(me))
                        .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        assertThat(count("SELECT COUNT(*) FROM match_requests WHERE user_id = ?", me)).isZero();
    }

    @Test
    void atMostFiveActiveRequests() throws Exception {
        UUID me = user();
        for (int i = 0; i < 5; i++) {
            createRequest(me, game(), null, null).andExpect(status().isOk());
        }
        createRequest(me, game(), null, null)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("TOO_MANY_REQUESTS"));
        assertThat(count("SELECT COUNT(*) FROM match_requests WHERE user_id = ? AND status = 'ACTIVE'", me))
                .isEqualTo(5);
    }

    // -------------------------------------------------------------------------
    // Scheduler + suggestions + accept / dismiss
    // -------------------------------------------------------------------------

    @Test
    void schedulerMatchesFriendsWithOverlappingWindowsAndAcceptCreatesEvent() throws Exception {
        UUID alice = user();
        UUID bob = user();
        UUID outsider = user();
        friends(alice, bob);
        UUID gameId = game(2, 5);
        Instant base = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
        createRequest(alice, gameId, base, base.plus(4, ChronoUnit.HOURS)).andExpect(status().isOk());
        createRequest(bob, gameId, base.plus(1, ChronoUnit.HOURS), base.plus(6, ChronoUnit.HOURS))
                .andExpect(status().isOk());

        matchScheduler.runMatchingJob();

        assertThat(redis.hasKey(LOCK_KEY)).isFalse(); // lock released after the run
        assertThat(count("SELECT COUNT(*) FROM match_requests WHERE user_id IN (?, ?) AND status = 'MATCHED'",
                alice, bob)).isEqualTo(2);
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE type = 'MATCH_FOUND' AND recipient_id IN (?, ?)",
                alice, bob)).isEqualTo(2);
        mvc.perform(get("/api/v1/matches/requests/me").with(as(alice)))
                .andExpect(jsonPath("$.data.length()").value(0));

        JsonNode suggestion = json(mvc.perform(get("/api/v1/matches/suggestions").with(as(alice)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andReturn()).get("data").get(0);
        UUID groupId = UUID.fromString(suggestion.get("id").asText());
        assertThat(suggestion.get("status").asText()).isEqualTo("PENDING");
        assertThat(suggestion.get("game").get("id").asText()).isEqualTo(gameId.toString());
        assertThat(Instant.parse(suggestion.get("overlapStart").asText())).isEqualTo(base.plus(1, ChronoUnit.HOURS));
        assertThat(Instant.parse(suggestion.get("overlapEnd").asText())).isEqualTo(base.plus(4, ChronoUnit.HOURS));
        assertThat(suggestion.get("members")).extracting(m -> m.get("id").asText())
                .containsExactlyInAnyOrder(alice.toString(), bob.toString());

        mvc.perform(post("/api/v1/matches/{id}/accept", groupId).with(as(outsider)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NOT_MEMBER"));

        JsonNode event = json(mvc.perform(post("/api/v1/matches/{id}/accept", groupId).with(as(bob)))
                .andExpect(status().isOk())
                .andReturn()).get("data");
        UUID eventId = UUID.fromString(event.get("id").asText());
        assertThat(event.get("title").asText()).isEqualTo("IT Game Night");
        assertThat(event.get("host").get("id").asText()).isEqualTo(bob.toString());
        assertThat(event.get("visibility").asText()).isEqualTo("FRIENDS");
        assertThat(event.get("maxParticipants").asInt()).isEqualTo(5);
        assertThat(Instant.parse(event.get("scheduledAt").asText())).isEqualTo(base.plus(1, ChronoUnit.HOURS));

        assertThat(string("SELECT status FROM match_groups WHERE id = ?", groupId)).isEqualTo("ACCEPTED");
        assertThat(count("SELECT COUNT(*) FROM notifications WHERE type = 'EVENT_INVITE' AND recipient_id = ?"
                + " AND actor_id = ? AND reference_id = ?", alice, bob, eventId)).isEqualTo(1);
        // Alice (a friend of the host) can see the FRIENDS event
        mvc.perform(get("/api/v1/events/{id}", eventId).with(as(alice))).andExpect(status().isOk());

        mvc.perform(post("/api/v1/matches/{id}/accept", groupId).with(as(alice)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("GROUP_NOT_PENDING"));
        mvc.perform(get("/api/v1/matches/suggestions").with(as(alice)))
                .andExpect(jsonPath("$.data.length()").value(0));
    }

    @Test
    void acceptWithoutTimeWindowSchedulesEventTomorrowWithDefaultCapacity() throws Exception {
        UUID alice = user();
        UUID bob = user();
        friends(alice, bob);
        UUID gameId = game(null, null);
        UUID groupId = group(gameId, "PENDING", Instant.now(), alice, bob);

        JsonNode event = json(mvc.perform(post("/api/v1/matches/{id}/accept", groupId).with(as(alice)))
                .andExpect(status().isOk()).andReturn()).get("data");

        assertThat(event.get("maxParticipants").asInt()).isEqualTo(8);
        assertThat(Instant.parse(event.get("scheduledAt").asText()))
                .isBetween(Instant.now().plus(23, ChronoUnit.HOURS), Instant.now().plus(25, ChronoUnit.HOURS));
        mvc.perform(post("/api/v1/matches/{id}/accept", UUID.randomUUID()).with(as(alice)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GROUP_NOT_FOUND"));
    }

    @Test
    void schedulerDoesNotMatchStrangersBlockedFriendsDisjointWindowsOrTooFewPlayers() throws Exception {
        Instant base = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);

        // Strangers
        UUID gameA = game();
        UUID s1 = user();
        UUID s2 = user();
        UUID s1Req = activeRequest(s1, gameA, null, null);
        UUID s2Req = activeRequest(s2, gameA, null, null);

        // Friends who have since blocked each other (block row without removing friendship)
        UUID gameB = game();
        UUID b1 = user();
        UUID b2 = user();
        friends(b1, b2);
        block(b2, b1);
        UUID b1Req = activeRequest(b1, gameB, null, null);
        UUID b2Req = activeRequest(b2, gameB, null, null);

        // Friends with non-overlapping windows
        UUID gameC = game();
        UUID d1 = user();
        UUID d2 = user();
        friends(d1, d2);
        UUID d1Req = activeRequest(d1, gameC, base, base.plus(1, ChronoUnit.HOURS));
        UUID d2Req = activeRequest(d2, gameC, base.plus(2, ChronoUnit.HOURS), base.plus(3, ChronoUnit.HOURS));

        // Friends, but the game needs at least 3 players
        UUID gameD = game(3, 6);
        UUID m1 = user();
        UUID m2 = user();
        friends(m1, m2);
        UUID m1Req = activeRequest(m1, gameD, null, null);
        UUID m2Req = activeRequest(m2, gameD, null, null);

        matchScheduler.runMatchingJob();

        for (UUID req : List.of(s1Req, s2Req, b1Req, b2Req, d1Req, d2Req, m1Req, m2Req)) {
            assertThat(string("SELECT status FROM match_requests WHERE id = ?", req)).as("request %s", req)
                    .isEqualTo("ACTIVE");
        }
        assertThat(count("SELECT COUNT(*) FROM match_groups WHERE game_id IN (?, ?, ?, ?)",
                gameA, gameB, gameC, gameD)).isZero();
    }

    @Test
    void schedulerMatchesAChainOfFriendsIntoOneGroupWhenGameNeedsThree() throws Exception {
        UUID gameId = game(3, 4);
        UUID a = user();
        UUID b = user();
        UUID c = user();
        friends(a, b);
        friends(b, c); // a and c are not friends: union-find still joins them through b
        activeRequest(a, gameId, null, null);
        activeRequest(b, gameId, null, null);
        activeRequest(c, gameId, null, null);

        matchScheduler.runMatchingJob();

        UUID groupId = jdbc.queryForObject("SELECT id FROM match_groups WHERE game_id = ?", UUID.class, gameId);
        assertThat(count("SELECT COUNT(*) FROM match_group_members WHERE group_id = ?", groupId)).isEqualTo(3);
        assertThat(jdbc.queryForObject("SELECT overlap_start FROM match_groups WHERE id = ?",
                java.sql.Timestamp.class, groupId)).isNull(); // no windows → no overlap bounds
    }

    @Test
    void schedulerSkipsRunWhileAnotherInstanceHoldsTheLock() {
        UUID a = user();
        UUID b = user();
        friends(a, b);
        UUID gameId = game();
        UUID aReq = activeRequest(a, gameId, null, null);
        activeRequest(b, gameId, null, null);
        redis.opsForValue().set(LOCK_KEY, "other-instance", Duration.ofMinutes(1));

        matchScheduler.runMatchingJob();

        assertThat(string("SELECT status FROM match_requests WHERE id = ?", aReq)).isEqualTo("ACTIVE");
        assertThat(redis.opsForValue().get(LOCK_KEY)).isEqualTo("other-instance"); // not released by us
    }

    @Test
    void schedulerExpiresStalePendingGroupsAndReactivatesTheirRequests() {
        UUID a = user();
        UUID b = user();
        UUID gameId = game();
        UUID stale = group(gameId, "PENDING", Instant.now().minus(3, ChronoUnit.DAYS), a, b);
        UUID aReq = request(a, gameId, "MATCHED");
        UUID bReq = request(b, gameId, "MATCHED");

        matchScheduler.runMatchingJob();

        assertThat(string("SELECT status FROM match_groups WHERE id = ?", stale)).isEqualTo("EXPIRED");
        assertThat(string("SELECT status FROM match_requests WHERE id = ?", aReq)).isEqualTo("ACTIVE");
        assertThat(string("SELECT status FROM match_requests WHERE id = ?", bReq)).isEqualTo("ACTIVE");
    }

    @Test
    void dismissByAllMembersDismissesGroupAndReactivatesRequests() throws Exception {
        UUID a = user();
        UUID b = user();
        UUID outsider = user();
        UUID gameId = game();
        UUID groupId = group(gameId, "PENDING", Instant.now(), a, b);
        UUID aReq = request(a, gameId, "MATCHED");
        UUID bReq = request(b, gameId, "MATCHED");

        mvc.perform(post("/api/v1/matches/{id}/dismiss", groupId).with(as(outsider)))
                .andExpect(status().isForbidden());

        mvc.perform(post("/api/v1/matches/{id}/dismiss", groupId).with(as(a))).andExpect(status().isNoContent());
        assertThat(string("SELECT status FROM match_groups WHERE id = ?", groupId)).isEqualTo("PENDING");
        assertThat(string("SELECT status FROM match_group_members WHERE group_id = ? AND user_id = ?", groupId, a))
                .isEqualTo("DISMISSED");
        assertThat(string("SELECT status FROM match_requests WHERE id = ?", aReq)).isEqualTo("MATCHED");

        mvc.perform(post("/api/v1/matches/{id}/dismiss", groupId).with(as(b))).andExpect(status().isNoContent());
        assertThat(string("SELECT status FROM match_groups WHERE id = ?", groupId)).isEqualTo("DISMISSED");
        assertThat(string("SELECT status FROM match_requests WHERE id = ?", aReq)).isEqualTo("ACTIVE");
        assertThat(string("SELECT status FROM match_requests WHERE id = ?", bReq)).isEqualTo("ACTIVE");

        mvc.perform(post("/api/v1/matches/{id}/dismiss", groupId).with(as(b)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("GROUP_NOT_PENDING"));
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private ResultActions createRequest(UUID userId, UUID gameId, Instant from, Instant to) throws Exception {
        Map<String, Object> body = new HashMap<>();
        body.put("gameId", gameId);
        body.put("availableFrom", from == null ? null : from.toString());
        body.put("availableTo", to == null ? null : to.toString());
        return mvc.perform(post("/api/v1/matches/requests").with(as(userId))
                .contentType(MediaType.APPLICATION_JSON).content(toJson(body)));
    }

    private UUID activeRequest(UUID userId, UUID gameId, Instant from, Instant to) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO match_requests (id, user_id, game_id, status, available_from, available_to)"
                        + " VALUES (?, ?, ?, 'ACTIVE', ?, ?)",
                id, userId, gameId, from == null ? null : ts(from), to == null ? null : ts(to));
        return id;
    }

    private UUID request(UUID userId, UUID gameId, String status) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO match_requests (id, user_id, game_id, status) VALUES (?, ?, ?, ?)",
                id, userId, gameId, status);
        return id;
    }

    private UUID group(UUID gameId, String status, Instant createdAt, UUID... members) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO match_groups (id, game_id, status, created_at) VALUES (?, ?, ?, ?)",
                id, gameId, status, ts(createdAt));
        for (UUID m : members) {
            jdbc.update("INSERT INTO match_group_members (group_id, user_id) VALUES (?, ?)", id, m);
        }
        return id;
    }
}
