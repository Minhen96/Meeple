package com.meeplehearth.match.repository;

import com.meeplehearth.match.entity.MatchGroup;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface MatchGroupRepository extends JpaRepository<MatchGroup, UUID> {

    @EntityGraph(attributePaths = {"game", "members", "members.user"})
    @Query("""
            SELECT mg FROM MatchGroup mg
            JOIN mg.members m
            WHERE m.user.id = :userId
              AND mg.status = 'PENDING'
            """)
    List<MatchGroup> findPendingForUser(UUID userId);

    @Query("SELECT mg FROM MatchGroup mg WHERE mg.status = 'PENDING' AND mg.createdAt < :cutoff")
    List<MatchGroup> findExpiredGroups(Instant cutoff);
}
