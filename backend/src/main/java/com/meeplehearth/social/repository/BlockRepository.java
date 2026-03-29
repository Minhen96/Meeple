package com.meeplehearth.social.repository;

import com.meeplehearth.social.entity.BlockedUser;
import com.meeplehearth.social.entity.BlockedUserId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface BlockRepository extends JpaRepository<BlockedUser, BlockedUserId> {

    boolean existsByIdBlockerIdAndIdBlockedId(UUID blockerId, UUID blockedId);
}
