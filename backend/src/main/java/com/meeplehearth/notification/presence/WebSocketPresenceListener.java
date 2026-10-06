package com.meeplehearth.notification.presence;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.context.event.EventListener;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.security.Principal;
import java.time.Clock;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Online presence for push suppression (TECH_STACK section 6), safe with several backend
 * instances. {@code ws:online:{userId}} is a sorted set: one member per instance that holds a
 * live STOMP session of the user, scored with the time (epoch ms) that instance's claim expires.
 * <ul>
 *   <li>CONNECT and the heartbeat (every {@link #REFRESH_INTERVAL_MS} ms, for every user with a
 *       session on this instance) set this instance's member to now + {@link #TTL}, drop members
 *       already expired and keep the whole key alive for {@link #TTL}.</li>
 *   <li>When the user's last session on this instance disconnects, only this instance's member
 *       is removed: sessions on other instances keep the user online.</li>
 *   <li>{@link #isOnline} is true when any member has not expired. An instance that dies without
 *       disconnect events stops refreshing, so its member expires after {@link #TTL}.</li>
 * </ul>
 * Each operation is a single command or Lua script on one key: no SCAN, no cross-key races.
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

    /**
     * KEYS[1] presence key; ARGV: instance id, now (ms), claim expiry (ms), key TTL (ms). A key
     * of another type (the former string presence key) is replaced.
     */
    static final RedisScript<Long> MARK_ONLINE = new DefaultRedisScript<>(
            "local t = redis.call('type', KEYS[1]) "
                    + "if type(t) == 'table' then t = t['ok'] end "
                    + "if t ~= 'zset' and t ~= 'none' then redis.call('del', KEYS[1]) end "
                    + "redis.call('zadd', KEYS[1], ARGV[3], ARGV[1]) "
                    + "redis.call('zremrangebyscore', KEYS[1], '-inf', '(' .. ARGV[2]) "
                    + "redis.call('pexpire', KEYS[1], ARGV[4]) "
                    + "return 1",
            Long.class);

    private final StringRedisTemplate redis;
    private final Clock clock;
    /** This instance's member in every presence set. */
    private final String instanceId = UUID.randomUUID().toString();
    /** userId → live simp session ids on this instance. */
    private final Map<String, Set<String>> sessionsByUser = new ConcurrentHashMap<>();
    private final Map<String, String> userBySession = new ConcurrentHashMap<>();

    @Autowired
    public WebSocketPresenceListener(StringRedisTemplate redis) {
        this(redis, Clock.systemUTC());
    }

    public WebSocketPresenceListener(StringRedisTemplate redis, Clock clock) {
        this.redis = redis;
        this.clock = clock;
    }

    public static String key(UUID userId) {
        return KEY_PREFIX + userId;
    }

    public String instanceId() {
        return instanceId;
    }

    /** Whether the user has a live WebSocket session on any instance. */
    public boolean isOnline(UUID userId) {
        try {
            Long live = redis.opsForZSet().count(key(userId), clock.millis(), Double.POSITIVE_INFINITY);
            return live != null && live > 0;
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
                redis.opsForZSet().remove(KEY_PREFIX + userId, instanceId);
            } catch (RuntimeException e) {
                log.warn("Clearing presence failed; it expires in {}: {}", TTL, e.getMessage());
            }
        }
    }

    /** Heartbeat: keep this instance's claim alive for every locally connected user. */
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
        long now = clock.millis();
        try {
            redis.execute(MARK_ONLINE, List.of(KEY_PREFIX + userId), instanceId, Long.toString(now),
                    Long.toString(now + TTL.toMillis()), Long.toString(TTL.toMillis()));
        } catch (RuntimeException e) {
            log.warn("Recording presence failed: {}", e.getMessage());
        }
    }
}
