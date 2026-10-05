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

    /** Register or refresh one device; a null deviceInfo keeps the stored one. */
    @Modifying
    @Query(value = "INSERT INTO user_fcm_tokens (user_id, fcm_token, device_info, platform, updated_at)"
            + " VALUES (:userId, :token, CAST(:deviceInfo AS VARCHAR), :platform, now())"
            + " ON CONFLICT (user_id, fcm_token) DO UPDATE SET platform = EXCLUDED.platform,"
            + " device_info = COALESCE(EXCLUDED.device_info, user_fcm_tokens.device_info), updated_at = now()",
            nativeQuery = true)
    int upsert(@Param("userId") UUID userId, @Param("token") String token,
               @Param("deviceInfo") String deviceInfo, @Param("platform") String platform);

    /** Unregister one device of one user. */
    @Modifying
    @Query("DELETE FROM UserFcmToken t WHERE t.userId = :userId AND t.token = :token")
    int deleteByUserIdAndToken(@Param("userId") UUID userId, @Param("token") String token);

    /** A device now signed in as another user: drop its registration under every other account. */
    @Modifying
    @Query("DELETE FROM UserFcmToken t WHERE t.token = :token AND t.userId <> :userId")
    int deleteByTokenForOtherUsers(@Param("token") String token, @Param("userId") UUID userId);

    /** Stale tokens reported by FCM (UNREGISTERED / INVALID_ARGUMENT), under any account. */
    @Modifying
    @Query("DELETE FROM UserFcmToken t WHERE t.token IN :tokens")
    int deleteByTokenIn(@Param("tokens") Collection<String> tokens);

    @Modifying
    @Query("DELETE FROM UserFcmToken t WHERE t.userId = :userId")
    int deleteAllForUser(@Param("userId") UUID userId);
}
