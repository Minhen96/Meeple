package com.meeplehearth.event.repository;

import com.meeplehearth.event.entity.Event;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EventRepository extends JpaRepository<Event, UUID> {

    /**
     * Visibility predicate for event alias {@code e} and viewer {@code :viewerId}.
     * Visible when the viewer and host have not blocked each other AND one of:
     * PUBLIC, viewer is host, viewer has a participant row (invited/accepted/declined),
     * or FRIENDS and viewer is an accepted friend of the host.
     * INVITE_ONLY therefore resolves to host + participants only.
     */
    String VISIBLE_TO_VIEWER = """
            (e.visibility = 'PUBLIC'
               OR e.host.id = :viewerId
               OR EXISTS (SELECT ep FROM EventParticipant ep
                          WHERE ep.id.eventId = e.id AND ep.id.userId = :viewerId)
               OR (e.visibility = 'FRIENDS' AND EXISTS (
                      SELECT fr FROM FriendRequest fr
                      WHERE fr.status = 'ACCEPTED'
                        AND ((fr.sender.id = :viewerId AND fr.receiver.id = e.host.id)
                          OR (fr.receiver.id = :viewerId AND fr.sender.id = e.host.id)))))
            AND NOT EXISTS (SELECT bu FROM BlockedUser bu
                            WHERE (bu.id.blockerId = :viewerId AND bu.id.blockedId = e.host.id)
                               OR (bu.id.blockerId = e.host.id AND bu.id.blockedId = :viewerId))
            """;

    // No N+1: load host and game in one query; visibility enforced in SQL
    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.deletedAt IS NULL AND e.status <> 'CANCELLED'"
            + " AND e.scheduledAt >= :from AND " + VISIBLE_TO_VIEWER
            + " ORDER BY e.scheduledAt ASC, e.id ASC")
    List<Event> findUpcomingVisibleEvents(Instant from, UUID viewerId, Pageable pageable);

    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.id = :eventId AND e.deletedAt IS NULL AND " + VISIBLE_TO_VIEWER)
    Optional<Event> findVisibleById(UUID eventId, UUID viewerId);

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
}
