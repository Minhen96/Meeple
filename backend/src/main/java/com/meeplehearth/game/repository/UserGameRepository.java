package com.meeplehearth.game.repository;

import com.meeplehearth.game.entity.UserGame;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserGameRepository extends JpaRepository<UserGame, UUID> {

    Optional<UserGame> findByUserIdAndGameId(UUID userId, UUID gameId);

    // No N+1: JOIN FETCH game eagerly
    @Query("SELECT ug FROM UserGame ug JOIN FETCH ug.game WHERE ug.user.id = :userId ORDER BY ug.createdAt DESC, ug.id")
    List<UserGame> findAllByUserId(@Param("userId") UUID userId);

    /** Entries for the given BGG ids (BGG import upsert), with the game fetched. */
    @Query("SELECT ug FROM UserGame ug JOIN FETCH ug.game g WHERE ug.user.id = :userId AND g.bggId IN :bggIds")
    List<UserGame> findByUserIdAndGameBggIdIn(@Param("userId") UUID userId, @Param("bggIds") Collection<Long> bggIds);

    // -------------------------------------------------------------------------
    // Friends' entries for one game (game detail). Callers pass a non-empty id list.
    // -------------------------------------------------------------------------

    /** Friends who own the game, most played first. */
    @Query("""
            SELECT ug FROM UserGame ug JOIN FETCH ug.user u
            WHERE ug.game.id = :gameId AND u.id IN :userIds AND u.deletedAt IS NULL AND ug.isOwned = true
            ORDER BY ug.playCount DESC, u.username ASC
            """)
    List<UserGame> findOwnersAmong(@Param("gameId") UUID gameId, @Param("userIds") Collection<UUID> userIds,
                                   Pageable pageable);

    /** Friends who rated the game or wrote notes about it, most recently updated first. */
    @Query("""
            SELECT ug FROM UserGame ug JOIN FETCH ug.user u
            WHERE ug.game.id = :gameId AND u.id IN :userIds AND u.deletedAt IS NULL
              AND (ug.personalRating IS NOT NULL OR (ug.notes IS NOT NULL AND TRIM(ug.notes) <> ''))
            ORDER BY ug.updatedAt DESC, u.username ASC
            """)
    List<UserGame> findReviewsAmong(@Param("gameId") UUID gameId, @Param("userIds") Collection<UUID> userIds,
                                    Pageable pageable);

    /** {@code [avg(personal_rating), count(personal_rating)]} over the given users' entries for the game. */
    @Query("""
            SELECT AVG(ug.personalRating), COUNT(ug.personalRating) FROM UserGame ug
            WHERE ug.game.id = :gameId AND ug.user.id IN :userIds AND ug.user.deletedAt IS NULL
              AND ug.personalRating IS NOT NULL
            """)
    List<Object[]> ratingAggregateAmong(@Param("gameId") UUID gameId, @Param("userIds") Collection<UUID> userIds);

    // -------------------------------------------------------------------------
    // Atomic writes (session listener, play deletion, account deletion)
    // -------------------------------------------------------------------------

    /**
     * Adds one play, creating the entry (all flags false) if it does not exist. Flags are never
     * changed. Atomic under concurrency thanks to the UNIQUE (user_id, game_id) constraint.
     */
    @Modifying
    @Query(value = """
            INSERT INTO user_games (id, user_id, game_id, play_count)
            VALUES (gen_random_uuid(), :userId, :gameId, 1)
            ON CONFLICT (user_id, game_id)
            DO UPDATE SET play_count = user_games.play_count + 1, updated_at = NOW()
            """, nativeQuery = true)
    int incrementPlayCount(@Param("userId") UUID userId, @Param("gameId") UUID gameId);

    @Modifying
    @Query(value = """
            UPDATE user_games SET play_count = GREATEST(play_count - 1, 0), updated_at = NOW()
            WHERE user_id = :userId AND game_id = :gameId
            """, nativeQuery = true)
    int decrementPlayCount(@Param("userId") UUID userId, @Param("gameId") UUID gameId);

    /** Deletes the entry if it has nothing left on it (FEATURES_COMPLETE section 3.1). */
    @Modifying
    @Query(value = """
            DELETE FROM user_games
            WHERE user_id = :userId AND game_id = :gameId
              AND NOT is_owned AND NOT is_wishlisted AND NOT is_favorited
              AND play_count = 0 AND personal_rating IS NULL AND (notes IS NULL OR BTRIM(notes) = '')
            """, nativeQuery = true)
    int deleteIfEmpty(@Param("userId") UUID userId, @Param("gameId") UUID gameId);

    @Modifying
    @Query(value = "DELETE FROM user_games WHERE user_id = :userId", nativeQuery = true)
    int deleteAllByUserId(@Param("userId") UUID userId);
}
