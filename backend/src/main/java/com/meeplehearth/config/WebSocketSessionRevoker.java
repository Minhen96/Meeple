package com.meeplehearth.config;

import com.meeplehearth.auth.event.UserSessionsRevokedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.WebSocketHandlerDecorator;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.io.IOException;
import java.security.Principal;
import java.time.Clock;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Tracks the live STOMP WebSocket sessions of each user so they can be closed when the user's
 * access tokens are revoked (token_version bump or account soft-delete). The token version is
 * only checked on STOMP CONNECT, so without this an already-open socket would keep receiving
 * the user's notifications after a password reset or a detected token theft.
 *
 * <p>Raw {@link WebSocketSession}s are captured by a handler decorator (registered in
 * {@link WebSocketConfig#configureWebSocketTransport}) and bound to the authenticated principal
 * once the STOMP session is connected. The simp session id equals the WebSocket session id.
 *
 * <p>Revocations are remembered for {@link #REVOCATION_MEMORY}: a CONNECT that was authenticated
 * before a revocation but registered after it (the token check and the revoking commit raced)
 * is closed as soon as it registers.
 *
 * <p>Sessions whose CONNECT access token has expired are closed by a periodic sweep
 * ({@link #closeExpiredSessions}), so a listen-only socket that never sends SUBSCRIBE/SEND
 * again cannot keep receiving messages past its token's lifetime.
 *
 * <p>The registry is per application instance, like the simple STOMP broker it serves.
 * Eagerly created ({@code @Lazy(false)}) because the application runs with lazy
 * initialization and the {@code @Scheduled} sweep would otherwise never be registered.
 */
@Component
@Lazy(false)
public class WebSocketSessionRevoker {

    private static final Logger log = LoggerFactory.getLogger(WebSocketSessionRevoker.class);

    /** Session attribute: expiry (epoch millis) of the access token presented on CONNECT. */
    public static final String TOKEN_EXPIRES_AT_ATTR = "meeple.ws.tokenExpiresAt";
    /** Session attribute: time (epoch millis) just before the CONNECT token was checked against the DB. */
    public static final String AUTHENTICATED_AT_ATTR = "meeple.ws.authenticatedAt";

    static final Duration REVOCATION_MEMORY = Duration.ofMinutes(5);
    static final CloseStatus REVOKED = CloseStatus.POLICY_VIOLATION.withReason("Session revoked");
    static final CloseStatus TOKEN_EXPIRED = CloseStatus.POLICY_VIOLATION.withReason("Access token expired");

    private final Map<String, WebSocketSession> sessionsById = new ConcurrentHashMap<>();
    private final Map<String, String> userBySessionId = new ConcurrentHashMap<>();
    private final Map<String, Set<String>> sessionIdsByUser = new ConcurrentHashMap<>();
    private final Map<String, Long> revokedAtByUser = new ConcurrentHashMap<>();
    private final Clock clock;

    public WebSocketSessionRevoker() {
        this(Clock.systemUTC());
    }

    WebSocketSessionRevoker(Clock clock) {
        this.clock = clock;
    }

    long currentTimeMillis() {
        return clock.millis();
    }

    // -------------------------------------------------------------------------
    // Session tracking
    // -------------------------------------------------------------------------

    /** Wraps the STOMP sub-protocol handler so every raw WebSocket session is tracked by id. */
    public WebSocketHandler decorate(WebSocketHandler handler) {
        return new WebSocketHandlerDecorator(handler) {
            @Override
            public void afterConnectionEstablished(WebSocketSession session) throws Exception {
                sessionsById.put(session.getId(), session);
                super.afterConnectionEstablished(session);
            }

            @Override
            public void afterConnectionClosed(WebSocketSession session, CloseStatus closeStatus) throws Exception {
                try {
                    super.afterConnectionClosed(session, closeStatus);
                } finally {
                    unregister(session.getId());
                }
            }
        };
    }

    @EventListener
    public void onSessionConnected(SessionConnectedEvent event) {
        String sessionId = SimpMessageHeaderAccessor.getSessionId(event.getMessage().getHeaders());
        Principal user = event.getUser();
        if (sessionId == null || user == null) {
            return;
        }
        bind(sessionId, user.getName());
    }

    @EventListener
    public void onSessionDisconnect(SessionDisconnectEvent event) {
        unregister(event.getSessionId());
    }

    void bind(String sessionId, String userName) {
        userBySessionId.put(sessionId, userName);
        sessionIdsByUser.compute(userName, (key, ids) -> {
            Set<String> set = ids != null ? ids : ConcurrentHashMap.newKeySet();
            set.add(sessionId);
            return set;
        });

        // Registered after the session was put in the user's set, and revokeUser records the
        // revocation before reading that set: one of the two always sees the other
        Long revokedAt = revokedAtByUser.get(userName);
        if (revokedAt != null) {
            WebSocketSession session = sessionsById.get(sessionId);
            if (session != null) {
                Object authenticatedAt = session.getAttributes().get(AUTHENTICATED_AT_ATTR);
                if (!(authenticatedAt instanceof Long at) || at <= revokedAt) {
                    close(session, REVOKED);
                }
            }
        }
    }

    void unregister(String sessionId) {
        if (sessionId == null) {
            return;
        }
        sessionsById.remove(sessionId);
        String userName = userBySessionId.remove(sessionId);
        if (userName != null) {
            sessionIdsByUser.computeIfPresent(userName, (key, ids) -> {
                ids.remove(sessionId);
                return ids.isEmpty() ? null : ids;
            });
        }
    }

    // -------------------------------------------------------------------------
    // Revocation
    // -------------------------------------------------------------------------

    /**
     * Runs after the transaction that revoked the user's tokens commits (or immediately when
     * the event is published outside a transaction).
     */
    @TransactionalEventListener(fallbackExecution = true)
    public void onUserSessionsRevoked(UserSessionsRevokedEvent event) {
        revokeUser(event.userId());
    }

    /** Closes every live WebSocket session of the user with {@link CloseStatus#POLICY_VIOLATION}. */
    public void revokeUser(UUID userId) {
        if (userId == null) {
            return;
        }
        String userName = userId.toString();
        long now = currentTimeMillis();
        long memoryMs = REVOCATION_MEMORY.toMillis();
        revokedAtByUser.entrySet().removeIf(entry -> now - entry.getValue() > memoryMs);
        revokedAtByUser.put(userName, now);

        Set<String> ids = sessionIdsByUser.get(userName);
        if (ids == null || ids.isEmpty()) {
            return;
        }
        List<String> snapshot = List.copyOf(ids);
        for (String sessionId : snapshot) {
            close(sessionsById.get(sessionId), REVOKED);
        }
        log.info("Closed {} WebSocket session(s) of user {} after token revocation", snapshot.size(), userId);
    }

    /** Closes one session by its (simp / WebSocket) session id, if it is still open. */
    public void closeSession(String sessionId, CloseStatus status) {
        if (sessionId != null) {
            close(sessionsById.get(sessionId), status);
        }
    }

    // -------------------------------------------------------------------------
    // Token expiry
    // -------------------------------------------------------------------------

    /**
     * Closes every tracked session whose CONNECT access token has expired, with
     * {@link #TOKEN_EXPIRED}. Sessions that have not completed CONNECT carry no expiry and are
     * left alone.
     */
    // No Redis lock: each instance sweeps only its own in-memory sessions, not shared state.
    @Scheduled(fixedDelayString = "${meeple.ws.expiry-sweep-interval-ms:60000}",
            initialDelayString = "${meeple.ws.expiry-sweep-interval-ms:60000}")
    public void closeExpiredSessions() {
        long now = currentTimeMillis();
        int closed = 0;
        for (WebSocketSession session : List.copyOf(sessionsById.values())) {
            Object expiresAt = session.getAttributes().get(TOKEN_EXPIRES_AT_ATTR);
            if (expiresAt instanceof Long exp && now >= exp && session.isOpen()) {
                close(session, TOKEN_EXPIRED);
                closed++;
            }
        }
        if (closed > 0) {
            log.info("Closed {} WebSocket session(s) with an expired access token", closed);
        }
    }

    /** Number of tracked sessions currently bound to the user. */
    int sessionCount(UUID userId) {
        Set<String> ids = sessionIdsByUser.get(userId.toString());
        return ids == null ? 0 : ids.size();
    }

    private static void close(WebSocketSession session, CloseStatus status) {
        if (session == null || !session.isOpen()) {
            return;
        }
        try {
            session.close(status);
        } catch (IOException | RuntimeException e) {
            log.debug("Failed to close WebSocket session {}: {}", session.getId(), e.getMessage());
        }
    }
}
