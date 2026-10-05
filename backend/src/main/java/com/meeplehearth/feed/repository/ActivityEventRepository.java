package com.meeplehearth.feed.repository;

import com.meeplehearth.feed.entity.ActivityEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

@Repository
public interface ActivityEventRepository extends JpaRepository<ActivityEvent, UUID> {

    /** Active activities with their user, for feed hydration. Order is NOT guaranteed. */
    @Query("SELECT a FROM ActivityEvent a JOIN FETCH a.user WHERE a.id IN :ids AND a.deletedAt IS NULL")
    List<ActivityEvent> findActiveWithUserByIdIn(@Param("ids") Collection<UUID> ids);

    /** True when the user already has an activity of this type about {@code gameId} since {@code since}. */
    @Query(value = """
            SELECT EXISTS (SELECT 1 FROM activity_events
                           WHERE user_id = :userId AND type = :type AND deleted_at IS NULL
                             AND created_at >= :since AND data ->> 'gameId' = :gameId)
            """, nativeQuery = true)
    boolean existsRecentForGame(@Param("userId") UUID userId, @Param("type") String type,
                                @Param("gameId") String gameId, @Param("since") Instant since);

    @Modifying
    @Query(value = "DELETE FROM activity_events WHERE user_id = :userId", nativeQuery = true)
    int deleteByUserId(@Param("userId") UUID userId);
}
