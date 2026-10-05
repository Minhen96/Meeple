package com.meeplehearth.ai.repository;

import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.game.entity.Game;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface GameRulebookRepository extends JpaRepository<GameRulebook, UUID> {

    @Query("SELECT r FROM GameRulebook r JOIN FETCH r.game WHERE r.id = :id")
    Optional<GameRulebook> findByIdWithGame(@Param("id") UUID id);

    boolean existsByGame_IdAndStatus(UUID gameId, String status);

    boolean existsByGame_IdAndStatusAndCreatedAtAfter(UUID gameId, String status, Instant cutoff);

    Optional<GameRulebook> findFirstByGame_IdAndStatus(UUID gameId, String status);

    List<GameRulebook> findByGame_IdAndStatusOrderByQueuePositionAsc(UUID gameId, String status);

    Optional<GameRulebook> findFirstByGame_IdAndUploadedBy_IdAndStatusIn(UUID gameId, UUID uploadedById, List<String> statuses);

    Page<GameRulebook> findByStatusOrderByCreatedAtAsc(String status, Pageable pageable);

    int countByGame_IdAndStatus(UUID gameId, String status);

    long countByStatus(String status);

    /**
     * True if the game has an 'ingesting' rulebook that started after {@code cutoff}.
     * Ingestion start = reviewedAt (admin approval / admin upload) or createdAt (auto-fetch).
     * Older 'ingesting' rows are considered crashed (stale) and may be retried.
     */
    @Query("""
            SELECT CASE WHEN COUNT(r) > 0 THEN true ELSE false END FROM GameRulebook r
            WHERE r.game.id = :gameId
              AND r.status = 'ingesting'
              AND COALESCE(r.reviewedAt, r.createdAt) > :cutoff
            """)
    boolean existsActiveIngestion(@Param("gameId") UUID gameId, @Param("cutoff") Instant cutoff);

    /**
     * Games that need a rulebook fetch attempt, ordered by BGG rank (highest-ranked first):
     *  - No approved rulebook AND no currently-ingesting rulebook.
     *  - 'ingesting' entries older than the cutoff are considered crashed and retried.
     */
    @Query("""
            SELECT g FROM Game g
            WHERE g.gameType = 'boardgame'
              AND g.nameEn IS NOT NULL
              AND NOT EXISTS (
                SELECT 1 FROM GameRulebook r
                WHERE r.game = g AND r.status = 'approved'
              )
              AND NOT EXISTS (
                SELECT 1 FROM GameRulebook r
                WHERE r.game = g AND r.status = 'ingesting'
                  AND COALESCE(r.reviewedAt, r.createdAt) > :ingestingCutoff
              )
            ORDER BY g.rank ASC NULLS LAST
            """)
    List<Game> findGamesWithoutApprovedRulebook(@Param("ingestingCutoff") Instant ingestingCutoff, Pageable pageable);
}
