package com.meeplehearth.ai.repository;

import com.meeplehearth.ai.entity.RuleChunk;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

// Phase 3 — pgvector similarity search on game_rules table
@Repository
public interface RuleChunkRepository extends JpaRepository<RuleChunk, UUID> {

    // TODO: Native query using <-> cosine distance operator once pgvector extension is active
    @Query(value = """
            SELECT * FROM game_rules
            WHERE game_id = :gameId
            ORDER BY embedding <-> CAST(:queryEmbedding AS vector)
            LIMIT :limit
            """, nativeQuery = true)
    List<RuleChunk> findSimilarChunks(UUID gameId, float[] queryEmbedding, int limit);
}
