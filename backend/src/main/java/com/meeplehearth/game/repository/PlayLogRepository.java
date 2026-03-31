package com.meeplehearth.game.repository;

import com.meeplehearth.game.entity.PlayLog;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PlayLogRepository extends JpaRepository<PlayLog, UUID> {

    List<PlayLog> findByUserIdAndGameIdOrderByPlayedAtDesc(UUID userId, UUID gameId);

    @EntityGraph(attributePaths = "game")
    List<PlayLog> findByUserIdOrderByPlayedAtDesc(UUID userId, Pageable pageable);
}
