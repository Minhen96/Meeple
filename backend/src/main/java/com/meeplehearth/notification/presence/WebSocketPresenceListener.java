package com.meeplehearth.notification.presence;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.context.event.EventListener;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.security.Principal;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Online presence for push suppression (TECH_STACK section 6): while a user has a live STOMP
 * session the Redis key {@code ws:online:{userId}} exists with a {@link #TTL} expiry. It is set on
 * CONNECT, refreshed every {@link #REFRESH_INTERVAL_MS} ms as a heartbeat for every user with a
 * session on this instance, and deleted when the user's last local session disconnects. If an
 * instance dies without disconnect events, its keys simply expire.
 *
 * <p>Eagerly created ({@code @Lazy(false)}) so the {@code @Scheduled} refresh is registered under
 * {@code spring.main.lazy-initialization=true}. No job lock: each instance refreshes only its own
 * in-memory sessions.
 */
@Component
@Lazy(false)
public class WebSocketPresenceListener {

    private static final Logger log = LoggerFactory.getLogger(WebSocketPresenceListener.class);

    public static final String KEY_PREFIX = "ws:online:";
    static final Duration TTL = Duration.ofSeconds(30);
    static final long REFRESH_INTERVAL_MS = 10_000;

    private final StringRedisTemplate redis;
    /** userId → live simp session ids on this instance. */
    private final Map<String, Set<String>> sessionsByUser = new ConcurrentHashMap<>();
    private final Map<String, String> userBySession = new ConcurrentHashMap<>();

    public WebSocketPresenceListener(StringRedisTemplate redis) {
        this.redis = redis;
    }

    public static String key(UUID userId) {
        return KEY_PREFIX + userId;
    }

    /** Whether the user has a live WebSocket session on any instance. */
    public boolean isOnline(UUID userId) {
        try {
            return Boolean.TRUE.equals(redis.hasKey(key(userId)));
        } catch (RuntimeException e) {
            // Unknown: treat as offline so the push is not lost
            log.warn("Presence lookup failed: {}", e.getMessage());
            return false;
        }
    }

    @EventListener
    public void onConnected(SessionConnectedEvent event) {
        Principal user = event.getUser();
        String sessionId = SimpMessageHeaderAccessor.getSessionId(event.getMessage().getHeaders());
        if (user == null || sessionId == null) {
            return;
        }
        connected(user.getName(), sessionId);
    }

    @EventListener
    public void onDisconnect(SessionDisconnectEvent event) {
        disconnected(event.getSessionId());
    }

    void connected(String userId, String sessionId) {
        userBySession.put(sessionId, userId);
        sessionsByUser.compute(userId, (k, ids) -> {
            Set<String> set = ids != null ? ids : ConcurrentHashMap.newKeySet();
            set.add(sessionId);
            return set;
        });
        markOnline(userId);
    }

    void disconnected(String sessionId) {
        if (sessionId == null) {
            return;
        }
        String userId = userBySession.remove(sessionId);
        if (userId == null) {
            return;
        }
        boolean[] lastSession = {false};
        sessionsByUser.computeIfPresent(userId, (k, ids) -> {
            ids.remove(sessionId);
            if (ids.isEmpty()) {
                lastSession[0] = true;
                return null;
            }
            return ids;
        });
        if (lastSession[0]) {
            try {
                redis.delete(KEY_PREFIX + userId);
            } catch (RuntimeException e) {
                log.warn("Clearing presence failed; it expires in {}: {}", TTL, e.getMessage());
            }
        }
    }

    /** Heartbeat: keep every locally connected user's key alive. */
    @Scheduled(fixedDelay = REFRESH_INTERVAL_MS, initialDelay = REFRESH_INTERVAL_MS)
    public void refresh() {
        for (String userId : List.copyOf(sessionsByUser.keySet())) {
            markOnline(userId);
        }
    }

    int localSessionCount(String userId) {
        Set<String> ids = sessionsByUser.get(userId);
        return ids == null ? 0 : ids.size();
    }

    private void markOnline(String userId) {
        try {
            redis.opsForValue().set(KEY_PREFIX + userId, "1", TTL);
        } catch (RuntimeException e) {
            log.warn("Recording presence failed: {}", e.getMessage());
        }
    }
}
