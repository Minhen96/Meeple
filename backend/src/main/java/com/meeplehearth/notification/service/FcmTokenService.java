package com.meeplehearth.notification.service;

import com.meeplehearth.notification.dto.RegisterFcmTokenRequest;
import com.meeplehearth.notification.entity.UserFcmToken;
import com.meeplehearth.notification.repository.UserFcmTokenRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Device registration for push (FEATURES_COMPLETE section 1.4: one row per device in
 * {@code user_fcm_tokens}). Registering is idempotent and refreshes the row; a token moves to the
 * account that registered it last (a shared device must not receive the previous user's pushes).
 */
@Service
public class FcmTokenService {

    /** Devices kept per user; the least recently registered are dropped beyond this. */
    static final int MAX_TOKENS_PER_USER = 10;

    private final UserFcmTokenRepository tokenRepository;

    public FcmTokenService(UserFcmTokenRepository tokenRepository) {
        this.tokenRepository = tokenRepository;
    }

    @Transactional
    public void register(UUID userId, RegisterFcmTokenRequest request) {
        String token = request.token().trim();
        tokenRepository.deleteByTokenForOtherUsers(token, userId);

        String deviceInfo = request.deviceInfo() == null || request.deviceInfo().isBlank()
                ? null : request.deviceInfo().trim();
        tokenRepository.upsert(userId, token, deviceInfo, request.platform());

        List<UserFcmToken> all = tokenRepository.findByUserIdOrderByUpdatedAtDesc(userId);
        if (all.size() > MAX_TOKENS_PER_USER) {
            tokenRepository.deleteAll(all.subList(MAX_TOKENS_PER_USER, all.size()));
        }
    }

    /** Idempotent: unknown tokens are ignored. */
    @Transactional
    public void unregister(UUID userId, String token) {
        if (token == null || token.isBlank()) return;
        tokenRepository.deleteByUserIdAndToken(userId, token.trim());
    }
}
