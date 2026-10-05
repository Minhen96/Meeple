package com.meeplehearth.game.repository;

import com.meeplehearth.game.dto.UserStatsResponse;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

/**
 * Read-only SQL for profile stats and the game-detail sessions list. These read the social and
 * post tables (owned by other packages) without mapping their entities, so each query is a single
 * round trip.
 */
@Repository
public class LibraryStatsQueries {

    /** Hides rows whose user {@code u} and the viewer have blocked each other (either way). */
    private static final String NOT_BLOCKED_WITH_VIEWER = """
            NOT EXISTS (SELECT 1 FROM blocked_users b
                        WHERE (b.blocker_id = :viewerId AND b.blocked_id = %1$s)
                           OR (b.blocker_id = %1$s AND b.blocked_id = :viewerId))
            """;

    private final NamedParameterJdbcTemplate jdbc;

    public LibraryStatsQueries(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** {@code [gamesOwned, sessions]} for the user: owned entries and the sum of play counts. */
    public long[] ownedAndSessions(UUID userId) {
        return jdbc.queryForObject("""
                SELECT COUNT(*) FILTER (WHERE is_owned), COALESCE(SUM(play_count), 0)
                FROM user_games WHERE user_id = :userId
                """, new MapSqlParameterSource("userId", userId),
                (rs, i) -> new long[]{rs.getLong(1), rs.getLong(2)});
    }

    /** Accepted friendships with users that are not soft-deleted. */
    public long friendCount(UUID userId) {
        Long n = jdbc.queryForObject("""
                SELECT COUNT(*) FROM friend_requests fr
                JOIN users u ON u.id = CASE WHEN fr.sender_id = :userId THEN fr.receiver_id ELSE fr.sender_id END
                WHERE (fr.sender_id = :userId OR fr.receiver_id = :userId)
                  AND fr.status = 'ACCEPTED' AND u.deleted_at IS NULL
                """, new MapSqlParameterSource("userId", userId), Long.class);
        return n == null ? 0 : n;
    }

    public UserStatsResponse.MostPlayedGame mostPlayedGame(UUID userId) {
        List<UserStatsResponse.MostPlayedGame> rows = jdbc.query("""
                SELECT g.id, g.name_en, ug.play_count
                FROM user_games ug JOIN games g ON g.id = ug.game_id
                WHERE ug.user_id = :userId AND ug.play_count > 0
                ORDER BY ug.play_count DESC, g.name_en ASC
                LIMIT 1
                """, new MapSqlParameterSource("userId", userId),
                (rs, i) -> new UserStatsResponse.MostPlayedGame(
                        rs.getObject(1, UUID.class), rs.getString(2), rs.getInt(3)));
        return rows.isEmpty() ? null : rows.get(0);
    }

    /**
     * The category with the most plays across the user's games; ties (and users without plays)
     * fall back to the category of the most games in the collection.
     */
    public String favoriteCategory(UUID userId) {
        List<String> rows = jdbc.queryForList("""
                SELECT cat FROM (
                    SELECT UNNEST(d.categories) AS cat, ug.play_count
                    FROM user_games ug JOIN game_details d ON d.game_id = ug.game_id
                    WHERE ug.user_id = :userId
                ) c
                GROUP BY cat
                ORDER BY SUM(play_count) DESC, COUNT(*) DESC, cat ASC
                LIMIT 1
                """, new MapSqlParameterSource("userId", userId), String.class);
        return rows.isEmpty() ? null : rows.get(0);
    }

    /**
     * The person who shared the most sessions (posts, as author or tagged) with the user. Deleted
     * users and users blocked with the viewer (either way) are left out.
     */
    public UserStatsResponse.MostPlayedWith mostPlayedWith(UUID userId, UUID viewerId) {
        String sql = """
                WITH sessions AS (
                    SELECT p.id, p.author_id FROM posts p
                    WHERE p.deleted_at IS NULL
                      AND (p.author_id = :userId
                           OR EXISTS (SELECT 1 FROM post_tags t WHERE t.post_id = p.id AND t.tagged_user_id = :userId))
                ), participants AS (
                    SELECT s.id AS post_id, s.author_id AS user_id FROM sessions s
                    UNION
                    SELECT t.post_id, t.tagged_user_id FROM post_tags t JOIN sessions s ON s.id = t.post_id
                )
                SELECT u.id, COALESCE(u.display_name, u.username), COUNT(DISTINCT pa.post_id) AS shared
                FROM participants pa JOIN users u ON u.id = pa.user_id
                WHERE pa.user_id <> :userId AND u.deleted_at IS NULL
                  AND %s
                GROUP BY u.id, u.display_name, u.username
                ORDER BY shared DESC, u.username ASC
                LIMIT 1
                """.formatted(NOT_BLOCKED_WITH_VIEWER.formatted("u.id"));
        List<UserStatsResponse.MostPlayedWith> rows = jdbc.query(sql,
                new MapSqlParameterSource("userId", userId).addValue("viewerId", viewerId),
                (rs, i) -> new UserStatsResponse.MostPlayedWith(
                        rs.getObject(1, UUID.class), rs.getString(2), rs.getLong(3)));
        return rows.isEmpty() ? null : rows.get(0);
    }

    public long totalPlayMinutes(UUID userId) {
        Long n = jdbc.queryForObject(
                "SELECT COALESCE(SUM(duration_minutes), 0) FROM play_logs WHERE user_id = :userId",
                new MapSqlParameterSource("userId", userId), Long.class);
        return n == null ? 0 : n;
    }

    /** A post id with its sort key, for cursor paging. */
    public record PostKey(UUID id, Instant createdAt) {
    }

    /**
     * Posts about {@code gameId} by {@code authorIds} (not deleted, author not deleted, no block
     * with the viewer), newest first, strictly after the {@code (createdAt, id)} cursor when given.
     * Returns up to {@code limit} keys.
     */
    public List<PostKey> sessionPostKeys(UUID gameId, Collection<UUID> authorIds, UUID viewerId,
                                         Instant cursorCreatedAt, UUID cursorId, int limit) {
        if (authorIds.isEmpty()) return List.of();
        MapSqlParameterSource params = new MapSqlParameterSource("gameId", gameId)
                .addValue("authorIds", authorIds)
                .addValue("viewerId", viewerId)
                .addValue("limit", limit);
        String cursorClause = "";
        if (cursorCreatedAt != null && cursorId != null) {
            cursorClause = "AND (p.created_at, p.id) < (:cursorAt, :cursorId)";
            params.addValue("cursorAt", Timestamp.from(cursorCreatedAt)).addValue("cursorId", cursorId);
        }
        String sql = """
                SELECT p.id, p.created_at FROM posts p JOIN users a ON a.id = p.author_id
                WHERE p.game_id = :gameId AND p.deleted_at IS NULL AND a.deleted_at IS NULL
                  AND p.author_id IN (:authorIds)
                  AND %s
                  %s
                ORDER BY p.created_at DESC, p.id DESC
                LIMIT :limit
                """.formatted(NOT_BLOCKED_WITH_VIEWER.formatted("p.author_id"), cursorClause);
        return jdbc.query(sql, params, (rs, i) -> new PostKey(
                rs.getObject(1, UUID.class), rs.getTimestamp(2).toInstant()));
    }
}
