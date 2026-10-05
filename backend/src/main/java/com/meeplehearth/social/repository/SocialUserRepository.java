package com.meeplehearth.social.repository;

import com.meeplehearth.user.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

/**
 * Read-only user queries for the social graph (search, suggestions, blocked list). Lives in the
 * social package so the account package's {@code UserRepository} stays untouched.
 */
public interface SocialUserRepository extends Repository<User, UUID> {

    /**
     * Active users whose username or display name contains {@code pattern} (already lower-cased and
     * LIKE-escaped with {@code \}), excluding the viewer and anyone blocked either way.
     */
    @Query(value = """
            SELECT u FROM User u
            WHERE u.deletedAt IS NULL
              AND u.id <> :viewerId
              AND (LOWER(u.username) LIKE :pattern ESCAPE '\\'
                   OR LOWER(u.displayName) LIKE :pattern ESCAPE '\\')
              AND NOT EXISTS (SELECT bu FROM BlockedUser bu
                              WHERE (bu.id.blockerId = :viewerId AND bu.id.blockedId = u.id)
                                 OR (bu.id.blockerId = u.id AND bu.id.blockedId = :viewerId))
            ORDER BY CASE WHEN LOWER(u.username) = :exact THEN 0 ELSE 1 END, u.username ASC
            """,
            countQuery = """
            SELECT COUNT(u) FROM User u
            WHERE u.deletedAt IS NULL
              AND u.id <> :viewerId
              AND (LOWER(u.username) LIKE :pattern ESCAPE '\\'
                   OR LOWER(u.displayName) LIKE :pattern ESCAPE '\\')
              AND NOT EXISTS (SELECT bu FROM BlockedUser bu
                              WHERE (bu.id.blockerId = :viewerId AND bu.id.blockedId = u.id)
                                 OR (bu.id.blockerId = u.id AND bu.id.blockedId = :viewerId))
            """)
    Page<User> searchVisible(@Param("viewerId") UUID viewerId, @Param("pattern") String pattern,
                             @Param("exact") String exact, Pageable pageable);

    /** Users blocked by {@code blockerId}, most recent block first. */
    @Query("""
            SELECT u FROM BlockedUser bu JOIN bu.blocked u
            WHERE bu.id.blockerId = :blockerId
            ORDER BY bu.createdAt DESC
            """)
    List<User> findBlockedBy(@Param("blockerId") UUID blockerId);

    /**
     * Suggestion candidates ranked by how many games in the viewer's collection they also own.
     * Excludes the viewer, deleted users, friends, pending requests in either direction and blocks
     * in either direction. Row: {@code [id, sharedGames]}.
     */
    @Query(value = """
            SELECT u.id AS id, COUNT(DISTINCT theirs.game_id) AS shared
            FROM user_games mine
            JOIN user_games theirs ON theirs.game_id = mine.game_id
                                  AND theirs.user_id <> mine.user_id
                                  AND theirs.is_owned = TRUE
            JOIN users u ON u.id = theirs.user_id AND u.deleted_at IS NULL
            WHERE mine.user_id = :viewerId
              AND mine.is_owned = TRUE
              AND NOT EXISTS (SELECT 1 FROM friend_requests fr
                              WHERE fr.status IN ('ACCEPTED', 'PENDING')
                                AND ((fr.sender_id = :viewerId AND fr.receiver_id = u.id)
                                  OR (fr.sender_id = u.id AND fr.receiver_id = :viewerId)))
              AND NOT EXISTS (SELECT 1 FROM blocked_users bu
                              WHERE (bu.blocker_id = :viewerId AND bu.blocked_id = u.id)
                                 OR (bu.blocker_id = u.id AND bu.blocked_id = :viewerId))
            GROUP BY u.id, u.created_at
            ORDER BY shared DESC, u.created_at DESC, u.id
            LIMIT :limit
            """, nativeQuery = true)
    List<Object[]> findSuggestionsByGameOverlap(@Param("viewerId") UUID viewerId, @Param("limit") int limit);

    /** Newest eligible users (same exclusions as above), used to top up the overlap ranking. */
    @Query(value = """
            SELECT u.id FROM users u
            WHERE u.deleted_at IS NULL
              AND u.id <> :viewerId
              AND u.id NOT IN (:excludeIds)
              AND NOT EXISTS (SELECT 1 FROM friend_requests fr
                              WHERE fr.status IN ('ACCEPTED', 'PENDING')
                                AND ((fr.sender_id = :viewerId AND fr.receiver_id = u.id)
                                  OR (fr.sender_id = u.id AND fr.receiver_id = :viewerId)))
              AND NOT EXISTS (SELECT 1 FROM blocked_users bu
                              WHERE (bu.blocker_id = :viewerId AND bu.blocked_id = u.id)
                                 OR (bu.blocker_id = u.id AND bu.blocked_id = :viewerId))
            ORDER BY u.created_at DESC, u.id
            LIMIT :limit
            """, nativeQuery = true)
    List<UUID> findNewestSuggestionIds(@Param("viewerId") UUID viewerId,
                                       @Param("excludeIds") Collection<UUID> excludeIds,
                                       @Param("limit") int limit);

    @Query("SELECT u FROM User u WHERE u.id IN :ids")
    List<User> findAllByIdIn(@Param("ids") Collection<UUID> ids);
}
