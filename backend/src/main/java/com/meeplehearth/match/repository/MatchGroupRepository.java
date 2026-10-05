package com.meeplehearth.match.repository;

import com.meeplehearth.match.entity.MatchGroup;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
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

    @Query("SELECT mg.id FROM MatchGroup mg WHERE mg.status = 'PENDING' AND mg.createdAt < :cutoff")
    List<UUID> findExpiredGroupIds(Instant cutoff);

    /** Expires one group only if it is still PENDING (not accepted/dismissed concurrently). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE MatchGroup mg SET mg.status = 'EXPIRED', mg.updatedAt = :now"
            + " WHERE mg.id = :groupId AND mg.status = 'PENDING'")
    int expireIfPending(UUID groupId, Instant now);
}
