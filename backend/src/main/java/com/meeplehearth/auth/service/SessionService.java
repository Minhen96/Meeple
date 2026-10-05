package com.meeplehearth.auth.service;

import org.springframework.beans.factory.annotation.Autowired;
import com.meeplehearth.auth.dto.SessionResponse;
import com.meeplehearth.auth.entity.RefreshToken;
import com.meeplehearth.auth.event.UserSessionsRevokedEvent;
import com.meeplehearth.auth.repository.RefreshTokenRepository;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Active sessions (SCREENS_AND_STATES section 11.4). A session is a live refresh token: unused
 * and unexpired. Rotated tokens stay in the table for reuse detection but are not sessions.
 */
@Service
public class SessionService {

    private final RefreshTokenRepository refreshTokenRepository;
    private final UserRepository userRepository;
    private final AuthService authService;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    @Autowired
    public SessionService(RefreshTokenRepository refreshTokenRepository,
                          UserRepository userRepository,
                          AuthService authService,
                          ApplicationEventPublisher eventPublisher) {
        this(refreshTokenRepository, userRepository, authService, eventPublisher, Clock.systemUTC());
    }

    SessionService(RefreshTokenRepository refreshTokenRepository,
                   UserRepository userRepository,
                   AuthService authService,
                   ApplicationEventPublisher eventPublisher,
                   Clock clock) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.userRepository = userRepository;
        this.authService = authService;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<SessionResponse> listSessions(UUID userId, HttpServletRequest request) {
        String currentHash = authService.currentRefreshTokenHash(request);
        return refreshTokenRepository.findActiveSessions(userId, Instant.now(clock)).stream()
                .map(token -> toResponse(token, currentHash))
                .toList();
    }

    /**
     * Signs one other device out: its refresh token is deleted, so it cannot renew its session.
     * Its current access token stays valid until it expires (at most 15 minutes). The caller's
     * own session is refused; logging out is the way to end it.
     */
    @Transactional
    public void revokeSession(UUID userId, UUID sessionId, HttpServletRequest request) {
        String currentHash = authService.currentRefreshTokenHash(request);
        RefreshToken token = refreshTokenRepository.findById(sessionId)
                .filter(t -> t.getUserId().equals(userId))
                .orElseThrow(() -> ApiException.notFound("SESSION_NOT_FOUND", "Session not found"));
        if (token.getTokenHash().equals(currentHash)) {
            throw ApiException.badRequest("CANNOT_REVOKE_CURRENT_SESSION",
                    "Use log out to end the session on this device");
        }
        refreshTokenRepository.deleteByIdAndUserId(sessionId, userId);
    }

    /**
     * Signs every other device out immediately: all other refresh tokens are deleted and the
     * token version is bumped, which invalidates every outstanding access token. The caller gets
     * a fresh access cookie so this device stays signed in, and open WebSockets are closed.
     */
    @Transactional
    public int revokeOtherSessions(UUID userId, HttpServletRequest request, HttpServletResponse response) {
        String currentHash = authService.currentRefreshTokenHash(request);
        if (currentHash == null) {
            throw ApiException.badRequest("CURRENT_SESSION_UNKNOWN",
                    "This device's session could not be identified");
        }
        User user = userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));

        int removed = refreshTokenRepository.deleteByUserIdExceptHash(userId, currentHash);
        user.setTokenVersion(user.getTokenVersion() + 1);
        userRepository.save(user);
        authService.reissueAccessCookie(user, response);
        eventPublisher.publishEvent(new UserSessionsRevokedEvent(userId));
        return removed;
    }

    private static SessionResponse toResponse(RefreshToken token, String currentHash) {
        Instant started = token.getSessionStartedAt() != null ? token.getSessionStartedAt() : token.getCreatedAt();
        return new SessionResponse(
                token.getId(),
                token.getDeviceInfo(),
                started,
                token.getLastUsedAt(),
                token.getTokenHash().equals(currentHash));
    }
}
