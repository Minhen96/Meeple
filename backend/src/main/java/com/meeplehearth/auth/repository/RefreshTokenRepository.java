package com.meeplehearth.auth.repository;

import com.meeplehearth.auth.entity.RefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
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

    /** Links a rotated token to the token that replaced it. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE RefreshToken r SET r.replacedBy = :successorId WHERE r.tokenHash = :tokenHash")
    int setReplacedBy(@Param("tokenHash") String tokenHash, @Param("successorId") UUID successorId);

    /** Current successor of a token, read from the database (not the persistence context). */
    @Query("SELECT r.replacedBy FROM RefreshToken r WHERE r.id = :id")
    Optional<UUID> findReplacedById(@Param("id") UUID id);

    /** Deletes a token only if it has never been used; returns 1 for the single caller that wins. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("DELETE FROM RefreshToken r WHERE r.id = :id AND r.usedAt IS NULL")
    int deleteUnusedById(@Param("id") UUID id);

    @Modifying
    @Query("DELETE FROM RefreshToken r WHERE r.tokenHash = :tokenHash")
    int deleteByTokenHash(@Param("tokenHash") String tokenHash);

    /** Live sessions of a user: unused, unexpired tokens (one per signed-in device), newest first. */
    @Query("SELECT r FROM RefreshToken r WHERE r.userId = :userId AND r.usedAt IS NULL AND r.expiresAt > :now "
            + "ORDER BY r.lastUsedAt DESC")
    List<RefreshToken> findActiveSessions(@Param("userId") UUID userId, @Param("now") Instant now);

    /** Deletes one session token of a user; returns 0 if it does not exist or belongs to someone else. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("DELETE FROM RefreshToken r WHERE r.id = :id AND r.userId = :userId")
    int deleteByIdAndUserId(@Param("id") UUID id, @Param("userId") UUID userId);

    /** Deletes every token of a user except the one with {@code keepHash} (the caller's own session). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("DELETE FROM RefreshToken r WHERE r.userId = :userId AND r.tokenHash <> :keepHash")
    int deleteByUserIdExceptHash(@Param("userId") UUID userId, @Param("keepHash") String keepHash);

    /** Removes expired tokens and rotated tokens older than the reuse-detection window. */
    @Transactional
    @Modifying
    @Query("DELETE FROM RefreshToken r WHERE r.expiresAt < :now OR r.usedAt < :usedBefore")
    int deleteExpiredOrUsedBefore(@Param("now") Instant now, @Param("usedBefore") Instant usedBefore);
}
