package com.meeplehearth.ai.repository;

import com.meeplehearth.ai.entity.RuleChunk;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Repository
public interface RuleChunkRepository extends JpaRepository<RuleChunk, UUID> {

    boolean existsByGame_Id(UUID gameId);

    /** First N chunks for a game in document order — used by HowToPlayExtractionService. */
    List<RuleChunk> findByGame_IdOrderByChunkIndexAsc(UUID gameId, org.springframework.data.domain.Pageable pageable);

    /**
     * pgvector HNSW cosine similarity search.
     *
     * @param gameId         filter to a single game
     * @param queryEmbedding vector literal in "[v1,v2,...]" format (use EmbeddingService.toVectorString)
     * @param limit          max results to return (typically 5)
     */
    @Query(value = """
            SELECT * FROM game_rules
            WHERE game_id = :gameId
            ORDER BY embedding <-> CAST(:queryEmbedding AS vector)
            LIMIT :limit
            """, nativeQuery = true)
    List<RuleChunk> findSimilarChunks(UUID gameId, String queryEmbedding, int limit);

    /**
     * Delete all chunks for a game before re-ingesting a new rulebook.
     * Called within a transaction in RulebookIngestionService.
     */
    @Modifying
    @Transactional
    @Query("DELETE FROM RuleChunk r WHERE r.game.id = :gameId")
    void deleteByGameId(UUID gameId);
}
