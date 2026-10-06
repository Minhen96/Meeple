package com.meeplehearth.auth.service;

import org.springframework.beans.factory.annotation.Autowired;
import com.meeplehearth.auth.dto.SessionResponse;
import com.meeplehearth.auth.entity.RefreshToken;
import com.meeplehearth.auth.event.UserSessionsRevokedEvent;
import com.meeplehearth.auth.repository.RefreshTokenRepository;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.notification.repository.UserFcmTokenRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Active sessions (SCREENS_AND_STATES section 11.4). A session is a refresh-token family (V62):
 * the token issued at login and every token rotated from it. It is live while it holds an unused,
 * unexpired token; rotated tokens stay in the table for reuse detection. The session id clients
 * see is the family id, so it does not change when the device refreshes.
 */
@Service
public class SessionService {

    private final RefreshTokenRepository refreshTokenRepository;
    private final UserRepository userRepository;
    private final AuthService authService;
    private final UserFcmTokenRepository fcmTokenRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    @Autowired
    public SessionService(RefreshTokenRepository refreshTokenRepository,
                          UserRepository userRepository,
                          AuthService authService,
                          UserFcmTokenRepository fcmTokenRepository,
                          ApplicationEventPublisher eventPublisher) {
        this(refreshTokenRepository, userRepository, authService, fcmTokenRepository, eventPublisher,
                Clock.systemUTC());
    }

    SessionService(RefreshTokenRepository refreshTokenRepository,
                   UserRepository userRepository,
                   AuthService authService,
                   UserFcmTokenRepository fcmTokenRepository,
                   ApplicationEventPublisher eventPublisher,
                   Clock clock) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.userRepository = userRepository;
        this.authService = authService;
        this.fcmTokenRepository = fcmTokenRepository;
        this.eventPublisher = eventPublisher;
        this.clock = clock;
    }

    /** One entry per live session (family); its id is the family id, stable across refreshes. */
    @Transactional(readOnly = true)
    public List<SessionResponse> listSessions(UUID userId, HttpServletRequest request) {
        String currentHash = authService.currentRefreshTokenHash(request);
        Map<UUID, SessionResponse> byFamily = new LinkedHashMap<>();
        for (RefreshToken token : refreshTokenRepository.findActiveSessions(userId, Instant.now(clock))) {
            byFamily.merge(token.getFamilyId(), toResponse(token, currentHash), (a, b) -> b.current() ? b : a);
        }
        return List.copyOf(byFamily.values());
    }

    /**
     * The session (family) of the caller's refresh cookie, when it is a live token of
     * {@code userId}; used to link push registrations to the session they came from.
     */
    @Transactional(readOnly = true)
    public Optional<UUID> currentFamily(UUID userId, HttpServletRequest request) {
        return authService.currentLiveRefreshToken(userId, request).map(RefreshToken::getFamilyId);
    }

    /**
     * Signs one other device out: every refresh token of that session family is deleted, so it
     * cannot renew its session, and the push registrations made from it are removed. Its current
     * access token stays valid until it expires (at most 15 minutes); nothing else is bumped.
     * Unknown ids, ids of other users and sessions that are no longer live answer 404. The
     * caller's own session is refused; logging out is the way to end it.
     */
    @Transactional
    public void revokeSession(UUID userId, UUID sessionId, HttpServletRequest request) {
        if (!refreshTokenRepository.existsActiveInFamily(userId, sessionId, Instant.now(clock))) {
            throw ApiException.notFound("SESSION_NOT_FOUND", "Session not found");
        }
        String currentHash = authService.currentRefreshTokenHash(request);
        boolean current = currentHash != null && refreshTokenRepository.findByTokenHash(currentHash)
                .filter(t -> t.getUserId().equals(userId))
                .map(t -> sessionId.equals(t.getFamilyId()))
                .orElse(false);
        if (current) {
            throw ApiException.badRequest("CANNOT_REVOKE_CURRENT_SESSION",
                    "Use log out to end the session on this device");
        }
        refreshTokenRepository.deleteFamily(userId, sessionId);
        fcmTokenRepository.deleteByUserIdAndFamilyId(userId, sessionId);
    }

    /**
     * Signs every other device out immediately: all refresh tokens outside this device's session
     * family are deleted and the token version is bumped, which invalidates every outstanding
     * access token. The caller gets a fresh access cookie so this device stays signed in, open
     * WebSockets are closed and push registrations of other sessions are removed.
     *
     * <p>The refresh_token cookie must be a live token of this user (400 without one, 401 for a
     * rotated, expired or foreign one): a bogus cookie never signs every device out.
     */
    @Transactional
    public int revokeOtherSessions(UUID userId, HttpServletRequest request, HttpServletResponse response) {
        if (authService.currentRefreshTokenHash(request) == null) {
            throw ApiException.badRequest("CURRENT_SESSION_UNKNOWN",
                    "This device's session could not be identified");
        }
        RefreshToken current = authService.currentLiveRefreshToken(userId, request)
                .orElseThrow(() -> ApiException.unauthorized("SESSION_INVALID",
                        "This device's session is no longer valid; sign in again"));
        User user = userRepository.findById(userId)
                .filter(u -> u.getDeletedAt() == null)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "User not found"));

        UUID family = current.getFamilyId();
        int revoked = refreshTokenRepository.countOtherActiveFamilies(userId, family, Instant.now(clock));
        refreshTokenRepository.deleteByUserIdExceptFamily(userId, family);
        fcmTokenRepository.deleteByUserIdExceptFamily(userId, family);
        user.setTokenVersion(user.getTokenVersion() + 1);
        userRepository.save(user);
        authService.reissueAccessCookie(user, response);
        eventPublisher.publishEvent(new UserSessionsRevokedEvent(userId));
        return revoked;
    }

    private static SessionResponse toResponse(RefreshToken token, String currentHash) {
        Instant started = token.getSessionStartedAt() != null ? token.getSessionStartedAt() : token.getCreatedAt();
        return new SessionResponse(
                token.getFamilyId(),
                token.getDeviceInfo(),
                started,
                token.getLastUsedAt(),
                token.getTokenHash().equals(currentHash));
    }
}
