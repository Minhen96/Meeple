package com.meeplehearth.social.repository;

import com.meeplehearth.social.entity.BlockedUser;
import com.meeplehearth.social.entity.BlockedUserId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

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
}
