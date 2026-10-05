package com.meeplehearth.auth.repository;

import com.meeplehearth.auth.entity.RefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    @Modifying
    @Query("DELETE FROM RefreshToken r WHERE r.userId = :userId")
    int deleteByUserId(@Param("userId") UUID userId);

    void deleteByUserIdAndTokenHash(UUID userId, String tokenHash);

    /**
     * Atomically marks an unused token as used. Returns 1 only for the single caller that
     * wins the rotation; a concurrent or repeated presentation of the same token gets 0.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE RefreshToken r SET r.usedAt = :now, r.lastUsedAt = :now "
            + "WHERE r.tokenHash = :tokenHash AND r.usedAt IS NULL")
    int markUsed(@Param("tokenHash") String tokenHash, @Param("now") Instant now);

    @Modifying
    @Query("DELETE FROM RefreshToken r WHERE r.tokenHash = :tokenHash")
    int deleteByTokenHash(@Param("tokenHash") String tokenHash);

    /** Removes expired tokens and rotated tokens older than the reuse-detection window. */
    @Transactional
    @Modifying
    @Query("DELETE FROM RefreshToken r WHERE r.expiresAt < :now OR r.usedAt < :usedBefore")
    int deleteExpiredOrUsedBefore(@Param("now") Instant now, @Param("usedBefore") Instant usedBefore);
}
