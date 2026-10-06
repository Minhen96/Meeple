package com.meeplehearth.notification.repository;

import com.meeplehearth.notification.entity.UserFcmToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserFcmTokenRepository extends JpaRepository<UserFcmToken, UUID> {

    /** The user's devices, most recently registered first. */
    List<UserFcmToken> findByUserIdOrderByUpdatedAtDesc(UUID userId);

    Optional<UserFcmToken> findByUserIdAndToken(UUID userId, String token);

    /**
     * Register or refresh one device; a null deviceInfo keeps the stored one, and so does a null
     * familyId (registration without a refresh cookie).
     */
    @Modifying
    @Query(value = "INSERT INTO user_fcm_tokens (user_id, fcm_token, device_info, platform, family_id, updated_at)"
            + " VALUES (:userId, :token, CAST(:deviceInfo AS VARCHAR), :platform, CAST(:familyId AS UUID), now())"
            + " ON CONFLICT (user_id, fcm_token) DO UPDATE SET platform = EXCLUDED.platform,"
            + " device_info = COALESCE(EXCLUDED.device_info, user_fcm_tokens.device_info),"
            + " family_id = COALESCE(EXCLUDED.family_id, user_fcm_tokens.family_id), updated_at = now()",
            nativeQuery = true)
    int upsert(@Param("userId") UUID userId, @Param("token") String token,
               @Param("deviceInfo") String deviceInfo, @Param("platform") String platform,
               @Param("familyId") UUID familyId);

    /** Push registrations made from one session (refresh-token family) of a user: that session was revoked. */
    @Modifying
    @Query(value = "DELETE FROM user_fcm_tokens WHERE user_id = :userId AND family_id = :familyId",
            nativeQuery = true)
    int deleteByUserIdAndFamilyId(@Param("userId") UUID userId, @Param("familyId") UUID familyId);

    /** Every push registration of a user except those made from session {@code keepFamilyId}. */
    @Modifying
    @Query(value = "DELETE FROM user_fcm_tokens WHERE user_id = :userId"
            + " AND (family_id IS NULL OR family_id <> :keepFamilyId)", nativeQuery = true)
    int deleteByUserIdExceptFamily(@Param("userId") UUID userId, @Param("keepFamilyId") UUID keepFamilyId);

    /** Unregister one device of one user. */
    @Modifying
    @Query("DELETE FROM UserFcmToken t WHERE t.userId = :userId AND t.token = :token")
    int deleteByUserIdAndToken(@Param("userId") UUID userId, @Param("token") String token);

    /** A device now signed in as another user: drop its registration under every other account. */
    @Modifying
    @Query("DELETE FROM UserFcmToken t WHERE t.token = :token AND t.userId <> :userId")
    int deleteByTokenForOtherUsers(@Param("token") String token, @Param("userId") UUID userId);

    /** Stale tokens reported by FCM (UNREGISTERED, SENDER_ID_MISMATCH, invalid token), under any account. */
    @Modifying
    @Query("DELETE FROM UserFcmToken t WHERE t.token IN :tokens")
    int deleteByTokenIn(@Param("tokens") Collection<String> tokens);

    @Modifying
    @Query("DELETE FROM UserFcmToken t WHERE t.userId = :userId")
    int deleteAllForUser(@Param("userId") UUID userId);
}
