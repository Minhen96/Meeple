package com.meeplehearth.game.repository;

import com.meeplehearth.game.entity.PlayLog;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PlayLogRepository extends JpaRepository<PlayLog, UUID> {

    @EntityGraph(attributePaths = "game")
    List<PlayLog> findByUserIdAndGameIdOrderByPlayedAtDesc(UUID userId, UUID gameId);

    @EntityGraph(attributePaths = "game")
    List<PlayLog> findByUserIdOrderByPlayedAtDesc(UUID userId, Pageable pageable);

    @EntityGraph(attributePaths = "game")
    Optional<PlayLog> findByIdAndUserId(UUID id, UUID userId);

    /**
     * Records the play of a post-tagged session at most once per (user, post): returns 1 if the
     * row was inserted, 0 if this post already recorded a play for the user.
     */
    @Modifying
    @Query(value = """
            INSERT INTO play_logs (id, user_id, game_id, played_at, post_id)
            VALUES (gen_random_uuid(), :userId, :gameId, :playedAt, :postId)
            ON CONFLICT (user_id, post_id) WHERE post_id IS NOT NULL DO NOTHING
            """, nativeQuery = true)
    int insertForPostIfAbsent(@Param("userId") UUID userId, @Param("gameId") UUID gameId,
                              @Param("playedAt") Instant playedAt, @Param("postId") UUID postId);

    @Modifying
    @Query(value = "DELETE FROM play_logs WHERE user_id = :userId", nativeQuery = true)
    int deleteAllByUserId(@Param("userId") UUID userId);
}
