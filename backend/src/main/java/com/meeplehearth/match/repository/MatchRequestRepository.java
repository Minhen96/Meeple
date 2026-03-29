package com.meeplehearth.match.repository;

import com.meeplehearth.match.entity.MatchRequest;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MatchRequestRepository extends JpaRepository<MatchRequest, UUID> {

    @EntityGraph(attributePaths = {"game"})
    List<MatchRequest> findByUserIdAndStatus(UUID userId, MatchRequest.Status status);

    int countByUserIdAndStatus(UUID userId, MatchRequest.Status status);

    Optional<MatchRequest> findByUserIdAndGameIdAndStatus(UUID userId, UUID gameId, MatchRequest.Status status);

    @EntityGraph(attributePaths = {"user", "game"})
    @Query("SELECT mr FROM MatchRequest mr WHERE mr.status = 'ACTIVE'")
    List<MatchRequest> findAllActive();
}
