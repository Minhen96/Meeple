package com.meeplehearth.ai.repository;

import com.meeplehearth.ai.entity.AiRuleQuery;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AiRuleQueryRepository extends JpaRepository<AiRuleQuery, UUID> {

    /**
     * Most-asked questions for a game — used to seed the FAQ and surface common answers.
     * Grouped by normalized question text, ordered by frequency descending.
     */
    @Query(value = """
            SELECT question, answer, COUNT(*) AS frequency
            FROM ai_rule_queries
            WHERE game_id = :gameId
            GROUP BY question, answer
            ORDER BY frequency DESC
            """, nativeQuery = true)
    List<Object[]> findFrequentQuestionsForGame(UUID gameId, Pageable pageable);
}
