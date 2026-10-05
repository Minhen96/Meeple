package com.meeplehearth.post.repository;

import com.meeplehearth.feed.service.FeedCursor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Keyset-paged post lists (event memories, bookmarks) and bookmark writes. Native SQL because the
 * keyset predicate {@code (ts, id) < (:ts, :id)} needs a row-value comparison.
 */
@Repository
public class PostQueryRepository {

    /** Excludes posts whose author and {@code :viewerId} have blocked each other (post alias {@code p}). */
    private static final String NOT_BLOCKED = """
             AND NOT EXISTS (SELECT 1 FROM blocked_users bu
                             WHERE (bu.blocker_id = :viewerId AND bu.blocked_id = p.author_id)
                                OR (bu.blocker_id = p.author_id AND bu.blocked_id = :viewerId))
            """;

    private final NamedParameterJdbcTemplate jdbc;

    public PostQueryRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** A row of a keyset page: the post id and the timestamp the list is ordered by. */
    public record Ref(UUID id, Instant at) {
    }

    /** Active posts linked to {@code eventId} that the viewer may see, newest first. */
    public List<Ref> findEventPostRefs(UUID eventId, UUID viewerId, FeedCursor cursor, int limit) {
        String sql = """
                SELECT p.id, p.created_at AS at FROM posts p JOIN users u ON u.id = p.author_id
                WHERE p.event_id = :eventId AND p.deleted_at IS NULL AND u.deleted_at IS NULL
                """ + NOT_BLOCKED
                + (cursor == null ? "" : " AND (p.created_at, p.id) < (:cursorAt, :cursorId)")
                + " ORDER BY p.created_at DESC, p.id DESC LIMIT :limit";
        return jdbc.query(sql, params(viewerId, cursor, limit).addValue("eventId", eventId), (rs, i) ->
                new Ref(rs.getObject("id", UUID.class), rs.getObject("at", OffsetDateTime.class).toInstant()));
    }

    /** Active posts in which {@code taggedUserId} is tagged that the viewer may see, newest first. */
    public List<Ref> findTaggedPostRefs(UUID taggedUserId, UUID viewerId, FeedCursor cursor, int limit) {
        String sql = """
                SELECT p.id, p.created_at AS at FROM posts p JOIN users u ON u.id = p.author_id
                WHERE p.deleted_at IS NULL AND u.deleted_at IS NULL
                  AND EXISTS (SELECT 1 FROM post_tags t WHERE t.post_id = p.id AND t.tagged_user_id = :taggedUserId)
                """ + NOT_BLOCKED
                + (cursor == null ? "" : " AND (p.created_at, p.id) < (:cursorAt, :cursorId)")
                + " ORDER BY p.created_at DESC, p.id DESC LIMIT :limit";
        return jdbc.query(sql, params(viewerId, cursor, limit).addValue("taggedUserId", taggedUserId), (rs, i) ->
                new Ref(rs.getObject("id", UUID.class), rs.getObject("at", OffsetDateTime.class).toInstant()));
    }

    /** The viewer's saved posts that are still visible, most recently saved first. */
    public List<Ref> findBookmarkRefs(UUID viewerId, FeedCursor cursor, int limit) {
        String sql = """
                SELECT b.post_id AS id, b.saved_at AS at
                FROM bookmarks b JOIN posts p ON p.id = b.post_id JOIN users u ON u.id = p.author_id
                WHERE b.user_id = :viewerId AND p.deleted_at IS NULL AND u.deleted_at IS NULL
                """ + NOT_BLOCKED
                + (cursor == null ? "" : " AND (b.saved_at, b.post_id) < (:cursorAt, :cursorId)")
                + " ORDER BY b.saved_at DESC, b.post_id DESC LIMIT :limit";
        return jdbc.query(sql, params(viewerId, cursor, limit), (rs, i) ->
                new Ref(rs.getObject("id", UUID.class), rs.getObject("at", OffsetDateTime.class).toInstant()));
    }

    /** Idempotent: returns 1 if the bookmark was added, 0 if it already existed. */
    public int insertBookmark(UUID userId, UUID postId) {
        return jdbc.update("INSERT INTO bookmarks (user_id, post_id) VALUES (:userId, :postId) ON CONFLICT DO NOTHING",
                new MapSqlParameterSource("userId", userId).addValue("postId", postId));
    }

    public int deleteBookmark(UUID userId, UUID postId) {
        return jdbc.update("DELETE FROM bookmarks WHERE user_id = :userId AND post_id = :postId",
                new MapSqlParameterSource("userId", userId).addValue("postId", postId));
    }

    public int deleteBookmarksOfUser(UUID userId) {
        return jdbc.update("DELETE FROM bookmarks WHERE user_id = :userId", new MapSqlParameterSource("userId", userId));
    }

    /** Which of {@code postIds} the user has bookmarked. */
    public Set<UUID> findBookmarkedPostIds(UUID userId, Collection<UUID> postIds) {
        if (userId == null || postIds.isEmpty()) {
            return Set.of();
        }
        return new HashSet<>(jdbc.queryForList(
                "SELECT post_id FROM bookmarks WHERE user_id = :userId AND post_id IN (:postIds)",
                new MapSqlParameterSource("userId", userId).addValue("postIds", postIds), UUID.class));
    }

    /** Permanently removes every post the user authored (images, tags, likes, comments cascade). */
    public int hardDeletePostsOf(UUID userId) {
        return jdbc.update("DELETE FROM posts WHERE author_id = :userId", new MapSqlParameterSource("userId", userId));
    }

    private static MapSqlParameterSource params(UUID viewerId, FeedCursor cursor, int limit) {
        MapSqlParameterSource params = new MapSqlParameterSource("viewerId", viewerId).addValue("limit", limit);
        if (cursor != null) {
            params.addValue("cursorAt", OffsetDateTime.ofInstant(cursor.at(), ZoneOffset.UTC))
                    .addValue("cursorId", cursor.id());
        }
        return params;
    }
}
