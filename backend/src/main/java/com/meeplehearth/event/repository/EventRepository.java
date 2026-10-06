package com.meeplehearth.event.repository;

import com.meeplehearth.event.entity.Event;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EventRepository extends JpaRepository<Event, UUID> {

    /**
     * Visibility predicate for event alias {@code e} and viewer {@code :viewerId}.
     * Visible when the viewer and host have not blocked each other AND one of:
     * <ul>
     *   <li>PUBLIC;</li>
     *   <li>the viewer is the host;</li>
     *   <li>the viewer is INVITED, ACCEPTED or DECLINED (a LEFT or KICKED row grants nothing);</li>
     *   <li>FRIENDS, the viewer is an accepted friend of the host and has not LEFT or been KICKED
     *       from the event.</li>
     * </ul>
     * INVITE_ONLY therefore resolves to host + invited/accepted/declined participants. Someone
     * who left or was removed loses the event, its live topic and its memories unless it is
     * PUBLIC (or they are invited again).
     */
    String VISIBLE_TO_VIEWER = """
            (e.visibility = 'PUBLIC'
               OR e.host.id = :viewerId
               OR EXISTS (SELECT ep FROM EventParticipant ep
                          WHERE ep.id.eventId = e.id AND ep.id.userId = :viewerId
                            AND ep.status IN ('INVITED', 'ACCEPTED', 'DECLINED'))
               OR (e.visibility = 'FRIENDS'
                   AND EXISTS (
                      SELECT fr FROM FriendRequest fr
                      WHERE fr.status = 'ACCEPTED'
                        AND ((fr.sender.id = :viewerId AND fr.receiver.id = e.host.id)
                          OR (fr.receiver.id = :viewerId AND fr.sender.id = e.host.id)))
                   AND NOT EXISTS (
                      SELECT gone FROM EventParticipant gone
                      WHERE gone.id.eventId = e.id AND gone.id.userId = :viewerId
                        AND gone.status IN ('LEFT', 'KICKED'))))
            AND NOT EXISTS (SELECT bu FROM BlockedUser bu
                            WHERE (bu.id.blockerId = :viewerId AND bu.id.blockedId = e.host.id)
                               OR (bu.id.blockerId = e.host.id AND bu.id.blockedId = :viewerId))
            """;

    /**
     * The viewer's own circle (the default "Upcoming" tab, the calendar): events they host, events
     * they were invited to / accepted / declined, and non-INVITE_ONLY events hosted by their
     * friends (ENGINEERING_STANDARDS section 10, "Friends tab"). Strangers' PUBLIC events are in
     * the Community tab instead. Combine with {@link #VISIBLE_TO_VIEWER} for the block check.
     */
    String IN_VIEWER_CIRCLE = """
            (e.host.id = :viewerId
               OR EXISTS (SELECT cp FROM EventParticipant cp
                          WHERE cp.id.eventId = e.id AND cp.id.userId = :viewerId
                            AND cp.status IN ('INVITED', 'ACCEPTED', 'DECLINED'))
               OR (e.visibility <> 'INVITE_ONLY' AND EXISTS (
                      SELECT cf FROM FriendRequest cf
                      WHERE cf.status = 'ACCEPTED'
                        AND ((cf.sender.id = :viewerId AND cf.receiver.id = e.host.id)
                          OR (cf.receiver.id = :viewerId AND cf.sender.id = e.host.id)))))
            """;

    /** Neither the viewer nor the host has blocked the other. */
    String NOT_BLOCKED_WITH_HOST = """
            NOT EXISTS (SELECT bu FROM BlockedUser bu
                        WHERE (bu.id.blockerId = :viewerId AND bu.id.blockedId = e.host.id)
                           OR (bu.id.blockerId = e.host.id AND bu.id.blockedId = :viewerId))
            """;

    // ---------------------------------------------------------------------------------------------
    // Lists (host and game fetched in the same query: no N+1)
    // ---------------------------------------------------------------------------------------------

    /** Upcoming events in the viewer's circle, soonest first. */
    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.deletedAt IS NULL AND e.status <> 'CANCELLED'"
            + " AND e.scheduledAt >= :from AND " + IN_VIEWER_CIRCLE + " AND " + VISIBLE_TO_VIEWER
            + " ORDER BY e.scheduledAt ASC, e.id ASC")
    List<Event> findUpcomingInCircle(Instant from, UUID viewerId, Pageable pageable);

    /**
     * Past events the viewer hosted or attended (accepted), most recent first. An event counts
     * as past once its start time has passed or it was completed.
     */
    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.deletedAt IS NULL AND e.status <> 'CANCELLED'"
            + " AND (e.scheduledAt < :now OR e.status = 'COMPLETED')"
            + " AND (e.host.id = :viewerId OR EXISTS (SELECT acc FROM EventParticipant acc"
            + "      WHERE acc.id.eventId = e.id AND acc.id.userId = :viewerId AND acc.status = 'ACCEPTED'))"
            + " AND " + VISIBLE_TO_VIEWER
            + " ORDER BY e.scheduledAt DESC, e.id DESC")
    List<Event> findPastForViewer(Instant now, UUID viewerId, Pageable pageable);

    /** Events in the viewer's circle starting in {@code [from, to)}, any non-cancelled status. */
    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.deletedAt IS NULL AND e.status <> 'CANCELLED'"
            + " AND e.scheduledAt >= :from AND e.scheduledAt < :to"
            + " AND " + IN_VIEWER_CIRCLE + " AND " + VISIBLE_TO_VIEWER
            + " ORDER BY e.scheduledAt ASC, e.id ASC")
    List<Event> findCalendarForViewer(Instant from, Instant to, UUID viewerId, Pageable pageable);

    /**
     * Community tab: upcoming OPEN/FULL PUBLIC events, soonest first, keyset-paginated after
     * {@code (afterTime, afterId)}. The first page passes {@code (now, all-zero UUID)}.
     */
    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.deletedAt IS NULL AND e.visibility = 'PUBLIC'"
            + " AND e.status IN ('OPEN', 'FULL') AND e.scheduledAt >= :now"
            + " AND (e.scheduledAt > :afterTime OR (e.scheduledAt = :afterTime AND e.id > :afterId))"
            + " AND " + NOT_BLOCKED_WITH_HOST
            + " ORDER BY e.scheduledAt ASC, e.id ASC")
    List<Event> findCommunityPage(Instant now, Instant afterTime, UUID afterId, UUID viewerId, Pageable pageable);

    /** {@link #findCommunityPage} filtered to one game. */
    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.deletedAt IS NULL AND e.visibility = 'PUBLIC'"
            + " AND e.status IN ('OPEN', 'FULL') AND e.scheduledAt >= :now AND e.game.id = :gameId"
            + " AND (e.scheduledAt > :afterTime OR (e.scheduledAt = :afterTime AND e.id > :afterId))"
            + " AND " + NOT_BLOCKED_WITH_HOST
            + " ORDER BY e.scheduledAt ASC, e.id ASC")
    List<Event> findCommunityPageForGame(Instant now, Instant afterTime, UUID afterId, UUID viewerId,
                                         UUID gameId, Pageable pageable);

    /**
     * Events the viewer has ACCEPTED that are still visible to them: excludes events whose host
     * has blocked the viewer or been blocked by them since the RSVP.
     */
    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.deletedAt IS NULL AND e.status <> 'CANCELLED'"
            + " AND EXISTS (SELECT acc FROM EventParticipant acc WHERE acc.id.eventId = e.id"
            + " AND acc.id.userId = :viewerId AND acc.status = 'ACCEPTED')"
            + " AND " + VISIBLE_TO_VIEWER
            + " ORDER BY e.scheduledAt ASC, e.id ASC")
    List<Event> findAcceptedVisibleByUserId(UUID viewerId);

    // ---------------------------------------------------------------------------------------------
    // Single event
    // ---------------------------------------------------------------------------------------------

    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.id = :eventId AND e.deletedAt IS NULL AND " + VISIBLE_TO_VIEWER)
    Optional<Event> findVisibleById(UUID eventId, UUID viewerId);

    /**
     * A cancelled (soft-deleted) event, for its host and the people who were invited or going,
     * so they can still open it and see the "cancelled" banner (SCREENS section 6.4).
     */
    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.id = :eventId AND e.deletedAt IS NOT NULL AND e.status = 'CANCELLED'"
            + " AND (e.host.id = :viewerId OR EXISTS (SELECT ep FROM EventParticipant ep"
            + "      WHERE ep.id.eventId = e.id AND ep.id.userId = :viewerId AND ep.status IN ('INVITED', 'ACCEPTED')))"
            + " AND " + NOT_BLOCKED_WITH_HOST)
    Optional<Event> findCancelledForParticipant(UUID eventId, UUID viewerId);

    /** Any event by id, deleted or not, with host and game (live-update payloads). */
    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.id = :eventId")
    Optional<Event> findWithHostAndGameById(UUID eventId);

    @Query("SELECT CASE WHEN COUNT(e) > 0 THEN true ELSE false END FROM Event e"
            + " WHERE e.id = :eventId AND " + VISIBLE_TO_VIEWER)
    boolean isVisibleTo(UUID eventId, UUID viewerId);

    /** Row-locks the event for the duration of the transaction (serialises RSVPs). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT e FROM Event e WHERE e.id = :eventId AND e.deletedAt IS NULL")
    Optional<Event> findActiveByIdForUpdate(UUID eventId);

    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.host.id = :hostId AND e.deletedAt IS NULL")
    List<Event> findByHostId(UUID hostId);

    // ---------------------------------------------------------------------------------------------
    // Invites
    // ---------------------------------------------------------------------------------------------

    /** The subset of {@code userIds} that are active (not deleted) accepted friends of {@code hostId}. */
    @Query("""
            SELECT u.id FROM User u
            WHERE u.id IN :userIds AND u.deletedAt IS NULL
              AND EXISTS (SELECT fr FROM FriendRequest fr
                          WHERE fr.status = 'ACCEPTED'
                            AND ((fr.sender.id = :hostId AND fr.receiver.id = u.id)
                              OR (fr.receiver.id = :hostId AND fr.sender.id = u.id)))
            """)
    List<UUID> findFriendIdsAmong(UUID hostId, Collection<UUID> userIds);

    /** The subset of {@code userIds} that are active and not blocked with {@code userId} either way. */
    @Query("""
            SELECT u.id FROM User u
            WHERE u.id IN :userIds AND u.deletedAt IS NULL
              AND NOT EXISTS (SELECT bu FROM BlockedUser bu
                              WHERE (bu.id.blockerId = :userId AND bu.id.blockedId = u.id)
                                 OR (bu.id.blockerId = u.id AND bu.id.blockedId = :userId))
            """)
    List<UUID> findActiveNotBlockedWith(UUID userId, Collection<UUID> userIds);

    // ---------------------------------------------------------------------------------------------
    // Jobs
    // ---------------------------------------------------------------------------------------------

    /** Live events that started before {@code cutoff} (auto-complete after 12h). */
    @Query("SELECT e.id FROM Event e WHERE e.deletedAt IS NULL AND e.status IN ('OPEN', 'FULL')"
            + " AND e.scheduledAt < :cutoff ORDER BY e.scheduledAt ASC")
    List<UUID> findIdsDueForCompletion(Instant cutoff);

    /** Completes one event only if it is still live; returns 1 when this call completed it. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Event e SET e.status = 'COMPLETED', e.updatedAt = :now"
            + " WHERE e.id = :eventId AND e.deletedAt IS NULL AND e.status IN ('OPEN', 'FULL')")
    int completeIfLive(UUID eventId, Instant now);

    /** Live events starting in {@code [from, to]} whose reminder has not gone out. */
    @Query("SELECT e.id FROM Event e WHERE e.deletedAt IS NULL AND e.status IN ('OPEN', 'FULL')"
            + " AND e.reminderSent = false AND e.scheduledAt BETWEEN :from AND :to ORDER BY e.scheduledAt ASC")
    List<UUID> findIdsDueForReminder(Instant from, Instant to);

    /** Live (OPEN/FULL, not deleted) events hosted by {@code hostId} that start after {@code now}. */
    @Query("SELECT e.id FROM Event e WHERE e.host.id = :hostId AND e.deletedAt IS NULL"
            + " AND e.status IN ('OPEN', 'FULL') AND e.scheduledAt > :now ORDER BY e.scheduledAt ASC")
    List<UUID> findUpcomingLiveIdsHostedBy(UUID hostId, Instant now);

    /**
     * Cancels (status CANCELLED plus soft delete, like a host cancel) the given events if they are
     * still live; returns how many changed. A bulk update, so it is written before any later JDBC
     * statement in the same transaction (the account hard delete removes the user row next).
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Event e SET e.status = 'CANCELLED', e.deletedAt = :now, e.updatedAt = :now"
            + " WHERE e.id IN :eventIds AND e.deletedAt IS NULL AND e.status IN ('OPEN', 'FULL')")
    int cancelLive(Collection<UUID> eventIds, Instant now);

    /** Claims one event's reminder; returns 1 only for the call that flipped the flag. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Event e SET e.reminderSent = true"
            + " WHERE e.id = :eventId AND e.reminderSent = false AND e.deletedAt IS NULL")
    int markReminderSent(UUID eventId);
}
