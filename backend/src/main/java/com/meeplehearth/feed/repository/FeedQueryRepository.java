package com.meeplehearth.feed.repository;

import com.meeplehearth.event.entity.Event;
import com.meeplehearth.event.repository.EventRepository;
import com.meeplehearth.feed.service.FeedCache.FeedRef;
import com.meeplehearth.feed.service.FeedCursor;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

/**
 * The feed union query: the viewer's and their accepted friends' posts and activity items, newest
 * first, keyset-paged on {@code (created_at, id)} (FEATURES_COMPLETE 5.1, 5.5).
 *
 * <p>Each branch is limited separately so Postgres can walk the per-author indexes, then the
 * merged result is limited again. Soft-deleted posts, activities and authors are excluded here;
 * blocks are enforced again at hydration time (a block also removes the friendship).
 */
@Repository
public class FeedQueryRepository {

    private static final String AUTHORS_CTE = """
            WITH authors AS (
                SELECT CAST(:viewerId AS uuid) AS id
                UNION
                SELECT CASE WHEN fr.sender_id = :viewerId THEN fr.receiver_id ELSE fr.sender_id END
                FROM friend_requests fr
                WHERE fr.status = 'ACCEPTED' AND (fr.sender_id = :viewerId OR fr.receiver_id = :viewerId)
            )
            """;

    private final NamedParameterJdbcTemplate jdbc;

    @PersistenceContext
    private EntityManager entityManager;

    public FeedQueryRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Up to {@code limit} feed rows strictly before {@code cursor} (all rows when it is null). */
    public List<FeedRef> findPage(UUID viewerId, FeedCursor cursor, int limit) {
        String postKeyset = cursor == null ? "" : " AND (p.created_at, p.id) < (:cursorAt, :cursorId)";
        String activityKeyset = cursor == null ? "" : " AND (a.created_at, a.id) < (:cursorAt, :cursorId)";
        String sql = AUTHORS_CTE + """
                (SELECT 'post' AS kind, p.id, p.created_at
                 FROM posts p JOIN users u ON u.id = p.author_id
                 WHERE p.deleted_at IS NULL AND u.deleted_at IS NULL
                   AND p.author_id IN (SELECT id FROM authors)""" + postKeyset + """

                 ORDER BY p.created_at DESC, p.id DESC
                 LIMIT :limit)
                UNION ALL
                (SELECT 'activity' AS kind, a.id, a.created_at
                 FROM activity_events a JOIN users u ON u.id = a.user_id
                 WHERE a.deleted_at IS NULL AND u.deleted_at IS NULL
                   AND a.user_id IN (SELECT id FROM authors)""" + activityKeyset + """

                 ORDER BY a.created_at DESC, a.id DESC
                 LIMIT :limit)
                ORDER BY created_at DESC, id DESC
                LIMIT :limit
                """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("viewerId", viewerId)
                .addValue("limit", limit);
        if (cursor != null) {
            params.addValue("cursorAt", OffsetDateTime.ofInstant(cursor.at(), ZoneOffset.UTC))
                    .addValue("cursorId", cursor.id());
        }
        return jdbc.query(sql, params, (rs, i) -> new FeedRef(
                rs.getString("kind"),
                rs.getObject("id", UUID.class),
                rs.getObject("created_at", OffsetDateTime.class).toInstant()));
    }

    /**
     * The events among {@code eventIds} that the viewer may currently see (not deleted, not
     * cancelled, visible per the events package's rule), loaded with their game in one query.
     */
    public List<Event> findVisibleEvents(Collection<UUID> eventIds, UUID viewerId) {
        if (eventIds.isEmpty()) {
            return List.of();
        }
        return entityManager.createQuery("SELECT e FROM Event e LEFT JOIN FETCH e.game"
                        + " WHERE e.id IN :ids AND e.deletedAt IS NULL AND e.status <> 'CANCELLED'"
                        + " AND " + EventRepository.VISIBLE_TO_VIEWER, Event.class)
                .setParameter("ids", eventIds)
                .setParameter("viewerId", viewerId)
                .getResultList();
    }
}
