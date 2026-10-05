package com.meeplehearth.social.repository;

import com.meeplehearth.social.entity.BlockedUser;
import com.meeplehearth.social.entity.BlockedUserId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Set;
import java.util.UUID;

@Repository
public interface BlockRepository extends JpaRepository<BlockedUser, BlockedUserId> {

    boolean existsByIdBlockerIdAndIdBlockedId(UUID blockerId, UUID blockedId);

    /** True if either user has blocked the other. */
    @Query("""
            SELECT CASE WHEN COUNT(bu) > 0 THEN true ELSE false END
            FROM BlockedUser bu
            WHERE (bu.id.blockerId = :userA AND bu.id.blockedId = :userB)
               OR (bu.id.blockerId = :userB AND bu.id.blockedId = :userA)
            """)
    boolean existsBlockBetween(UUID userA, UUID userB);

    /** Every user the viewer has blocked or been blocked by (hidden from each other everywhere). */
    @Query("""
            SELECT CASE WHEN bu.id.blockerId = :userId THEN bu.id.blockedId ELSE bu.id.blockerId END
            FROM BlockedUser bu
            WHERE bu.id.blockerId = :userId OR bu.id.blockedId = :userId
            """)
    Set<UUID> findBlockedEitherWay(UUID userId);
}
