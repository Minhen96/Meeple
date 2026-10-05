package com.meeplehearth.search.repository;

import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.repository.EventRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Event title search for the unified search overlay. Reuses the events package's visibility rule
 * ({@link EventRepository#VISIBLE_TO_VIEWER}) without editing that package.
 */
@Repository
public class EventSearchRepository {

    @PersistenceContext
    private EntityManager entityManager;

    /**
     * Visible, non-deleted, non-cancelled events whose title contains {@code pattern} (lower-cased,
     * LIKE-escaped with {@code \}): upcoming ones first (soonest first), then past ones (latest first).
     */
    public List<Event> search(UUID viewerId, String pattern, int limit) {
        return entityManager.createQuery("SELECT e FROM Event e LEFT JOIN FETCH e.game"
                        + " WHERE e.deletedAt IS NULL AND e.status <> 'CANCELLED'"
                        + " AND LOWER(e.title) LIKE :pattern ESCAPE '\\'"
                        + " AND " + EventRepository.VISIBLE_TO_VIEWER
                        + " ORDER BY CASE WHEN e.scheduledAt >= :now THEN 0 ELSE 1 END,"
                        + " CASE WHEN e.scheduledAt >= :now THEN e.scheduledAt END ASC,"
                        + " e.scheduledAt DESC, e.id", Event.class)
                .setParameter("pattern", pattern)
                .setParameter("viewerId", viewerId)
                .setParameter("now", Instant.now())
                .setMaxResults(limit)
                .getResultList();
    }
}
