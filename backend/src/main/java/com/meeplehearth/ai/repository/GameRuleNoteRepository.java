package com.meeplehearth.ai.repository;

import com.meeplehearth.ai.entity.GameRuleNote;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface GameRuleNoteRepository extends JpaRepository<GameRuleNote, UUID> {

    Optional<GameRuleNote> findByGame_IdAndUser_Id(UUID gameId, UUID userId);

    List<GameRuleNote> findByGame_IdAndStatusOrderByCreatedAtAsc(UUID gameId, String status);

    @EntityGraph(attributePaths = {"game", "user"})
    Page<GameRuleNote> findByStatusOrderByCreatedAtAsc(String status, Pageable pageable);

    long countByStatus(String status);
}
