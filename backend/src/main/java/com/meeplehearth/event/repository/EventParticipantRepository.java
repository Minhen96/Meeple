package com.meeplehearth.event.repository;

import com.meeplehearth.event.entity.EventParticipant;
import com.meeplehearth.event.entity.EventParticipantId;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

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

    @EntityGraph(attributePaths = {"event", "event.host", "event.game"})
    @Query("SELECT ep FROM EventParticipant ep WHERE ep.id.userId = :userId AND ep.status = 'ACCEPTED'")
    List<EventParticipant> findAcceptedByUserId(UUID userId);
}
