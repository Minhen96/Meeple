package com.meeplehearth.event.repository;

import com.meeplehearth.event.entity.Event;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface EventRepository extends JpaRepository<Event, UUID> {

    // No N+1: load host and game in one query
    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.deletedAt IS NULL AND e.scheduledAt >= :from ORDER BY e.scheduledAt ASC")
    List<Event> findUpcomingEvents(Instant from);

    @EntityGraph(attributePaths = {"host", "game"})
    @Query("SELECT e FROM Event e WHERE e.host.id = :hostId AND e.deletedAt IS NULL")
    List<Event> findByHostId(UUID hostId);
}
