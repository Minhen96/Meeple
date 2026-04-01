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

    boolean existsByGame_IdAndStatus(UUID gameId, String status);

    Optional<GameRulebook> findFirstByGame_IdAndStatus(UUID gameId, String status);

    List<GameRulebook> findByGame_IdAndStatusOrderByQueuePositionAsc(UUID gameId, String status);

    Optional<GameRulebook> findFirstByGame_IdAndUploadedBy_IdAndStatusIn(UUID gameId, UUID uploadedById, List<String> statuses);

    Page<GameRulebook> findByStatusOrderByCreatedAtAsc(String status, Pageable pageable);

    int countByGame_IdAndStatus(UUID gameId, String status);

    long countByStatus(String status);

    /**
     * Games that have no approved rulebook yet, ordered by BGG rank (highest-ranked first).
     * Used by RulebookAutoFetchJob to prioritize popular games.
     */
    /**
     * Games that need a rulebook fetch attempt:
     *  - No approved rulebook AND no currently-ingesting rulebook.
     *  - 'ingesting' entries older than 1 hour are considered crashed and retried.
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
                  AND r.createdAt > :ingestingCutoff
              )
            ORDER BY g.rank ASC NULLS LAST
            """)
    List<Game> findGamesWithoutApprovedRulebook(@Param("ingestingCutoff") Instant ingestingCutoff, Pageable pageable);
}
