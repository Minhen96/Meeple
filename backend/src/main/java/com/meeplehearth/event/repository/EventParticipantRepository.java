package com.meeplehearth.event.repository;

import com.meeplehearth.event.entity.EventParticipant;
import com.meeplehearth.event.entity.EventParticipantId;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EventParticipantRepository extends JpaRepository<EventParticipant, EventParticipantId> {

    @EntityGraph(attributePaths = {"user"})
    @Query("SELECT ep FROM EventParticipant ep WHERE ep.id.eventId = :eventId")
    List<EventParticipant> findByEventId(UUID eventId);

    @Query("SELECT ep FROM EventParticipant ep WHERE ep.id.eventId = :eventId AND ep.id.userId = :userId")
    Optional<EventParticipant> findByEventIdAndUserId(UUID eventId, UUID userId);

    @Query("SELECT COUNT(ep) FROM EventParticipant ep WHERE ep.id.eventId = :eventId AND ep.status = 'ACCEPTED'")
    int countAcceptedByEventId(UUID eventId);

    /** Batch accepted counts: each row is [eventId (UUID), count (Long)]. */
    @Query("""
            SELECT ep.id.eventId, COUNT(ep) FROM EventParticipant ep
            WHERE ep.id.eventId IN :eventIds AND ep.status = 'ACCEPTED'
            GROUP BY ep.id.eventId
            """)
    List<Object[]> countAcceptedByEventIds(Collection<UUID> eventIds);

    /** The given user's participant rows for a batch of events. */
    @Query("SELECT ep FROM EventParticipant ep WHERE ep.id.userId = :userId AND ep.id.eventId IN :eventIds")
    List<EventParticipant> findByUserIdAndEventIds(UUID userId, Collection<UUID> eventIds);

    /** One event's participant rows for a batch of users. */
    @Query("SELECT ep FROM EventParticipant ep WHERE ep.id.eventId = :eventId AND ep.id.userId IN :userIds")
    List<EventParticipant> findByUserIdsForEvent(UUID eventId, Collection<UUID> userIds);

    /**
     * Participant rows (with users) of a batch of events, oldest first, leaving out users the
     * viewer blocked or who blocked the viewer. Callers narrow by status per viewer role.
     */
    @EntityGraph(attributePaths = {"user"})
    @Query("""
            SELECT ep FROM EventParticipant ep
            WHERE ep.id.eventId IN :eventIds
              AND NOT EXISTS (SELECT bu FROM BlockedUser bu
                              WHERE (bu.id.blockerId = :viewerId AND bu.id.blockedId = ep.id.userId)
                                 OR (bu.id.blockerId = ep.id.userId AND bu.id.blockedId = :viewerId))
            ORDER BY ep.joinedAt ASC, ep.id.userId ASC
            """)
    List<EventParticipant> findForEventsVisibleTo(Collection<UUID> eventIds, UUID viewerId);

    /** Accepted participant rows (with users) of one event, oldest first. */
    @EntityGraph(attributePaths = {"user"})
    @Query("""
            SELECT ep FROM EventParticipant ep
            WHERE ep.id.eventId = :eventId AND ep.status = 'ACCEPTED'
            ORDER BY ep.joinedAt ASC, ep.id.userId ASC
            """)
    List<EventParticipant> findAcceptedWithUsers(UUID eventId);

    /** User ids of an event's accepted participants (notification fan-out). */
    @Query("SELECT ep.id.userId FROM EventParticipant ep WHERE ep.id.eventId = :eventId AND ep.status = 'ACCEPTED'")
    List<UUID> findAcceptedUserIds(UUID eventId);

    @EntityGraph(attributePaths = {"event", "event.host", "event.game"})
    @Query("""
            SELECT ep FROM EventParticipant ep
            WHERE ep.id.userId = :userId AND ep.status = 'ACCEPTED'
              AND ep.event.deletedAt IS NULL AND ep.event.status <> 'CANCELLED'
            """)
    List<EventParticipant> findAcceptedByUserId(UUID userId);

    /**
     * Live (OPEN/FULL, not deleted) events the user has ACCEPTED and does not host, oldest first
     * (account hard delete: the user leaves them).
     */
    @Query("""
            SELECT ep.id.eventId FROM EventParticipant ep JOIN ep.event e
            WHERE ep.id.userId = :userId AND ep.status = 'ACCEPTED'
              AND e.deletedAt IS NULL AND e.status IN ('OPEN', 'FULL')
              AND (e.host IS NULL OR e.host.id <> :userId)
            ORDER BY e.scheduledAt ASC
            """)
    List<UUID> findLiveEventIdsJoinedBy(UUID userId);

    /** Sets the user's ACCEPTED rows on {@code eventIds} to LEFT; returns how many changed. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            UPDATE EventParticipant ep SET ep.status = 'LEFT'
            WHERE ep.id.userId = :userId AND ep.status = 'ACCEPTED' AND ep.id.eventId IN :eventIds
            """)
    int markLeft(UUID userId, Collection<UUID> eventIds);

    /**
     * Removes the user's still-pending invites to events that have not started yet (account
     * deletion). Returns the number of invites removed.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            DELETE FROM EventParticipant ep
            WHERE ep.id.userId = :userId AND ep.status = 'INVITED'
              AND ep.id.eventId IN (SELECT e.id FROM Event e WHERE e.scheduledAt > :now)
            """)
    int deletePendingInvitesForUser(UUID userId, Instant now);
}
