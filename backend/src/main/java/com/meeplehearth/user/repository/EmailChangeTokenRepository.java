package com.meeplehearth.user.repository;

import com.meeplehearth.user.entity.EmailChangeToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmailChangeTokenRepository extends JpaRepository<EmailChangeToken, UUID> {

    Optional<EmailChangeToken> findByTokenHash(String tokenHash);

    /** Invalidates earlier pending requests: only the newest change link works. */
    @Modifying(flushAutomatically = true)
    @Query("DELETE FROM EmailChangeToken t WHERE t.userId = :userId AND t.usedAt IS NULL")
    int deletePendingByUserId(@Param("userId") UUID userId);
}
