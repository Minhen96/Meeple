package com.meeplehearth.integration;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.event.dto.UpdateEventRequest;
import com.meeplehearth.event.dto.EventResponse;
import com.meeplehearth.event.repository.EventRepository;
import com.meeplehearth.event.service.EventService;
import com.meeplehearth.match.entity.MatchRequest;
import com.meeplehearth.match.repository.MatchGroupRepository;
import com.meeplehearth.match.repository.MatchRequestRepository;
import com.meeplehearth.match.service.MatchService;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Event visibility / block filtering and match-request reactivation against the real Postgres
 * schema (JPQL + native SQL that mocked-repository unit tests cannot cover).
 */
@SpringBootTest
@Transactional
class EventAndMatchQueryIntegrationTest {

    @Autowired private JdbcTemplate jdbc;
    @Autowired private EventRepository eventRepository;
    @Autowired private EventService eventService;
    @Autowired private MatchRequestRepository matchRequestRepository;
    @Autowired private MatchGroupRepository matchGroupRepository;
    @Autowired private MatchService matchService;
    @PersistenceContext private EntityManager entityManager;

    private UUID host;
    private UUID friend;
    private UUID stranger;
    private UUID invitee;
    private UUID blocked;
    private UUID gameId;

    private UUID publicEvent;
    private UUID friendsEvent;
    private UUID inviteOnlyEvent;

    @BeforeEach
    void seed() {
        host = user();
        friend = user();
        stranger = user();
        invitee = user();
        blocked = user();
        gameId = game();

        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'ACCEPTED')",
                friend, host);
        // Pending request is not friendship
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'PENDING')",
                stranger, host);
        // blocked user is also a friend and a participant: the block must still win
        jdbc.update("INSERT INTO friend_requests (sender_id, receiver_id, status) VALUES (?, ?, 'ACCEPTED')",
                host, blocked);
        jdbc.update("INSERT INTO blocked_users (blocker_id, blocked_id) VALUES (?, ?)", host, blocked);

        publicEvent = event("PUBLIC");
        friendsEvent = event("FRIENDS");
        inviteOnlyEvent = event("INVITE_ONLY");

        participant(inviteOnlyEvent, invitee, "INVITED");
        participant(publicEvent, blocked, "ACCEPTED");
        participant(inviteOnlyEvent, blocked, "ACCEPTED");
    }

    // -------------------------------------------------------------------------
    // Event visibility
    // -------------------------------------------------------------------------

    @Test
    void publicEventIsVisibleToEveryoneExceptBlocked() {
        assertThat(eventRepository.isVisibleTo(publicEvent, host)).isTrue();
        assertThat(eventRepository.isVisibleTo(publicEvent, stranger)).isTrue();
        assertThat(eventRepository.isVisibleTo(publicEvent, friend)).isTrue();
        assertThat(eventRepository.isVisibleTo(publicEvent, blocked)).isFalse();
        assertThat(eventRepository.findVisibleById(publicEvent, blocked)).isEmpty();
    }

    @Test
    void friendsEventIsVisibleToHostAndAcceptedFriendsOnly() {
        assertThat(eventRepository.findVisibleById(friendsEvent, host)).isPresent();
        assertThat(eventRepository.findVisibleById(friendsEvent, friend)).isPresent();
        assertThat(eventRepository.findVisibleById(friendsEvent, stranger)).isEmpty();
        assertThat(eventRepository.findVisibleById(friendsEvent, invitee)).isEmpty();
        assertThat(eventRepository.findVisibleById(friendsEvent, blocked)).isEmpty();
    }

    @Test
    void inviteOnlyEventIsVisibleToHostAndParticipantsOnly() {
        assertThat(eventRepository.isVisibleTo(inviteOnlyEvent, host)).isTrue();
        assertThat(eventRepository.isVisibleTo(inviteOnlyEvent, invitee)).isTrue();
        assertThat(eventRepository.isVisibleTo(inviteOnlyEvent, friend)).isFalse();
        assertThat(eventRepository.isVisibleTo(inviteOnlyEvent, stranger)).isFalse();
        assertThat(eventRepository.isVisibleTo(inviteOnlyEvent, blocked)).isFalse();
    }

    @Test
    void blockInEitherDirectionHidesEvent() {
        UUID blocker = user();
        jdbc.update("INSERT INTO blocked_users (blocker_id, blocked_id) VALUES (?, ?)", blocker, host);
        assertThat(eventRepository.isVisibleTo(publicEvent, blocker)).isFalse();
    }

    @Test
    void deletedEventIsNotFoundEvenForHost() {
        jdbc.update("UPDATE events SET deleted_at = now() WHERE id = ?", publicEvent);
        assertThat(eventRepository.findVisibleById(publicEvent, host)).isEmpty();
    }

    // -------------------------------------------------------------------------
    // getMyEvents block filtering
    // -------------------------------------------------------------------------

    @Test
    void myEventsExcludesEventsWhoseHostBlockedTheCaller() {
        assertThat(eventService.getMyEvents(blocked)).isEmpty();

        // Without the block the same accepted events are listed
        jdbc.update("DELETE FROM blocked_users WHERE blocker_id = ? AND blocked_id = ?", host, blocked);
        assertThat(eventService.getMyEvents(blocked)).extracting(EventResponse::id)
                .containsExactlyInAnyOrder(publicEvent, inviteOnlyEvent);
    }

    @Test
    void myEventsExcludesEventsWhoseHostTheCallerBlocked() {
        UUID attendee = user();
        participant(publicEvent, attendee, "ACCEPTED");
        assertThat(eventService.getMyEvents(attendee)).extracting(EventResponse::id).containsExactly(publicEvent);

        jdbc.update("INSERT INTO blocked_users (blocker_id, blocked_id) VALUES (?, ?)", attendee, host);
        assertThat(eventService.getMyEvents(attendee)).isEmpty();
    }

    @Test
    void myEventsListsOnlyAcceptedNonCancelledEvents() {
        assertThat(eventService.getMyEvents(invitee)).isEmpty(); // INVITED, not ACCEPTED
        assertThat(eventService.getMyEvents(host)).extracting(EventResponse::id)
                .containsExactlyInAnyOrder(publicEvent, friendsEvent, inviteOnlyEvent);

        jdbc.update("UPDATE events SET status = 'CANCELLED' WHERE id = ?", friendsEvent);
        assertThat(eventService.getMyEvents(host)).extracting(EventResponse::id)
                .containsExactlyInAnyOrder(publicEvent, inviteOnlyEvent);
    }

    // -------------------------------------------------------------------------
    // Host-only mutations: 404 when not visible, 403 when visible but not host
    // -------------------------------------------------------------------------

    @Test
    void hostOnlyMutationsDoNotLeakInvisibleEvents() {
        UpdateEventRequest update = new UpdateEventRequest("Renamed", null, null, null, null, null, null, null);

        assertStatus(() -> eventService.updateEvent(stranger, inviteOnlyEvent, update), HttpStatus.NOT_FOUND);
        assertStatus(() -> eventService.cancelEvent(stranger, friendsEvent), HttpStatus.NOT_FOUND);
        assertStatus(() -> eventService.cancelEvent(blocked, publicEvent), HttpStatus.NOT_FOUND);
        assertStatus(() -> eventService.updateEvent(stranger, UUID.randomUUID(), update), HttpStatus.NOT_FOUND);

        assertStatus(() -> eventService.updateEvent(friend, friendsEvent, update), HttpStatus.FORBIDDEN);
        assertStatus(() -> eventService.cancelEvent(stranger, publicEvent), HttpStatus.FORBIDDEN);

        assertThat(eventService.updateEvent(host, friendsEvent, update).title()).isEqualTo("Renamed");
    }

    // -------------------------------------------------------------------------
    // Match request reactivation
    // -------------------------------------------------------------------------

    @Test
    void reactivationSkipsRowsThatAlreadyHaveAnActiveRequest() {
        UUID conflicting = matchRequest(friend, "MATCHED");
        matchRequest(friend, "ACTIVE"); // created by the user while the old one was matched
        UUID free = matchRequest(stranger, "MATCHED");

        int updated = matchRequestRepository.reactivateIfNoActive(List.of(conflicting, free));

        assertThat(updated).isEqualTo(1);
        assertThat(status(conflicting)).isEqualTo("MATCHED");
        assertThat(status(free)).isEqualTo("ACTIVE");
        assertThat(jdbc.queryForObject(
                "SELECT COUNT(*) FROM match_requests WHERE user_id = ? AND game_id = ? AND status = 'ACTIVE'",
                Integer.class, friend, gameId)).isEqualTo(1);
    }

    @Test
    void reactivationOnlyTouchesMatchedRows() {
        UUID cancelled = matchRequest(friend, "CANCELLED");
        assertThat(matchRequestRepository.reactivateIfNoActive(List.of(cancelled))).isZero();
        assertThat(status(cancelled)).isEqualTo("CANCELLED");
    }

    @Test
    void reactivatableQueryReturnsGroupMembersRequestsWithoutActiveDuplicate() {
        UUID group = UUID.randomUUID();
        jdbc.update("INSERT INTO match_groups (id, game_id, status) VALUES (?, ?, 'EXPIRED')", group, gameId);
        jdbc.update("INSERT INTO match_group_members (group_id, user_id) VALUES (?, ?), (?, ?)",
                group, friend, group, stranger);
        UUID friendOld = matchRequest(friend, "MATCHED");
        matchRequest(friend, "ACTIVE");
        UUID strangerOld = matchRequest(stranger, "MATCHED");
        matchRequest(invitee, "MATCHED"); // not a member

        assertThat(matchRequestRepository.findReactivatableForGroups(List.of(group)))
                .extracting(MatchRequest::getId)
                .containsExactly(strangerOld)
                .doesNotContain(friendOld);
    }

    @Test
    void markMatchedOnlyClaimsActiveRows() {
        UUID active = matchRequest(friend, "ACTIVE");
        UUID cancelled = matchRequest(stranger, "CANCELLED");

        assertThat(matchRequestRepository.markMatchedIfActive(List.of(active, cancelled))).isEqualTo(1);
        assertThat(status(active)).isEqualTo("MATCHED");
        assertThat(status(cancelled)).isEqualTo("CANCELLED");
    }

    @Test
    void expireIfPendingOnlyExpiresStalePendingGroups() {
        UUID stale = UUID.randomUUID();
        UUID accepted = UUID.randomUUID();
        UUID fresh = UUID.randomUUID();
        Timestamp old = Timestamp.from(Instant.now().minus(3, ChronoUnit.DAYS));
        jdbc.update("INSERT INTO match_groups (id, game_id, status, created_at) VALUES (?, ?, 'PENDING', ?)",
                stale, gameId, old);
        jdbc.update("INSERT INTO match_groups (id, game_id, status, created_at) VALUES (?, ?, 'ACCEPTED', ?)",
                accepted, gameId, old);
        jdbc.update("INSERT INTO match_groups (id, game_id, status) VALUES (?, ?, 'PENDING')", fresh, gameId);

        List<UUID> expiredIds = matchGroupRepository.findExpiredGroupIds(Instant.now().minus(48, ChronoUnit.HOURS));
        assertThat(expiredIds).contains(stale).doesNotContain(accepted, fresh);

        assertThat(matchGroupRepository.expireIfPending(stale, Instant.now())).isEqualTo(1);
        assertThat(matchGroupRepository.expireIfPending(stale, Instant.now())).isZero();
        assertThat(matchGroupRepository.expireIfPending(accepted, Instant.now())).isZero();
        assertThat(jdbc.queryForObject("SELECT status FROM match_groups WHERE id = ?", String.class, stale))
                .isEqualTo("EXPIRED");
    }

    @Test
    void matchingRunExpiresStaleGroupsReactivatesSafelyAndMatchesFriends() {
        // Stale group: invitee's old request is reactivated; stranger already re-requested so is skipped
        UUID stale = UUID.randomUUID();
        jdbc.update("INSERT INTO match_groups (id, game_id, status, created_at) VALUES (?, ?, 'PENDING', ?)",
                stale, gameId, Timestamp.from(Instant.now().minus(3, ChronoUnit.DAYS)));
        jdbc.update("INSERT INTO match_group_members (group_id, user_id) VALUES (?, ?), (?, ?)",
                stale, invitee, stale, stranger);
        UUID inviteeOld = matchRequest(invitee, "MATCHED");
        UUID strangerOld = matchRequest(stranger, "MATCHED");
        UUID strangerNew = matchRequest(stranger, "ACTIVE");

        // Two accepted friends (host <-> friend) with ACTIVE requests for a fresh game
        UUID otherGame = game();
        UUID hostReq = UUID.randomUUID();
        UUID friendReq = UUID.randomUUID();
        jdbc.update("INSERT INTO match_requests (id, user_id, game_id, status) VALUES (?, ?, ?, 'ACTIVE'), (?, ?, ?, 'ACTIVE')",
                hostReq, host, otherGame, friendReq, friend, otherGame);

        matchService.runMatchingAlgorithm();
        entityManager.flush(); // group runs join the test transaction, so flush before reading via JDBC

        assertThat(jdbc.queryForObject("SELECT status FROM match_groups WHERE id = ?", String.class, stale))
                .isEqualTo("EXPIRED");
        assertThat(status(inviteeOld)).isEqualTo("ACTIVE");
        assertThat(status(strangerOld)).isEqualTo("MATCHED");
        assertThat(status(strangerNew)).isEqualTo("ACTIVE");

        assertThat(status(hostReq)).isEqualTo("MATCHED");
        assertThat(status(friendReq)).isEqualTo("MATCHED");
        assertThat(jdbc.queryForObject(
                "SELECT COUNT(*) FROM match_groups g WHERE g.game_id = ? AND g.status = 'PENDING'"
                        + " AND (SELECT COUNT(*) FROM match_group_members m WHERE m.group_id = g.id) = 2",
                Integer.class, otherGame)).isEqualTo(1);
    }

    // -------------------------------------------------------------------------
    // Seeding helpers
    // -------------------------------------------------------------------------

    private UUID user() {
        UUID id = UUID.randomUUID();
        String suffix = id.toString().replace("-", "").substring(0, 12);
        jdbc.update("INSERT INTO users (id, username, email) VALUES (?, ?, ?)",
                id, "ev_" + suffix, "ev_" + suffix + "@example.test");
        return id;
    }

    private UUID game() {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO games (id, bgg_id, name_en) VALUES (?, ?, ?)",
                id, -ThreadLocalRandom.current().nextInt(1_000_000, Integer.MAX_VALUE), "Event IT Game");
        return id;
    }

    private UUID event(String visibility) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO events (id, host_id, title, scheduled_at, visibility) VALUES (?, ?, ?, ?, ?)",
                id, host, visibility + " night", Timestamp.from(Instant.now().plus(1, ChronoUnit.DAYS)), visibility);
        participant(id, host, "ACCEPTED");
        return id;
    }

    private void participant(UUID eventId, UUID userId, String status) {
        jdbc.update("INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, ?)",
                eventId, userId, status);
    }

    private UUID matchRequest(UUID userId, String status) {
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO match_requests (id, user_id, game_id, status) VALUES (?, ?, ?, ?)",
                id, userId, gameId, status);
        return id;
    }

    private String status(UUID matchRequestId) {
        return jdbc.queryForObject("SELECT status FROM match_requests WHERE id = ?", String.class, matchRequestId);
    }

    private static void assertStatus(Runnable call, HttpStatus expected) {
        assertThatThrownBy(call::run)
                .isInstanceOf(ApiException.class)
                .satisfies(e -> assertThat(((ApiException) e).getStatus()).isEqualTo(expected));
    }
}
