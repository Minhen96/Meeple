package com.meeplehearth.notification.service;

import com.meeplehearth.notification.repository.NotificationRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.List;
import java.util.UUID;

/**
 * Unread badge count cached in Redis as {@code notif:unread:{userId}} (FEATURES_COMPLETE section
 * 7.4). The database is the source of truth: a missing key is recomputed from it, increments and
 * decrements only touch an existing key (so a cold key is never initialised to a wrong value), and
 * the key expires after {@link #TTL} so any drift heals. Redis errors fall back to the database.
 */
@Component
public class UnreadCounter {

    private static final Logger log = LoggerFactory.getLogger(UnreadCounter.class);

    static final String KEY_PREFIX = "notif:unread:";
    static final Duration TTL = Duration.ofDays(1);

    /** INCR only an existing key; returns the new value, or -1 when the key is missing. */
    static final RedisScript<Long> INCREMENT_IF_PRESENT = new DefaultRedisScript<>(
            "if redis.call('exists', KEYS[1]) == 1 then return redis.call('incr', KEYS[1]) else return -1 end",
            Long.class);

    /** DECR only an existing positive key; returns the new value, or -1 when the key is missing. */
    static final RedisScript<Long> DECREMENT_IF_PRESENT = new DefaultRedisScript<>(
            "local v = redis.call('get', KEYS[1]) "
                    + "if not v then return -1 end "
                    + "if tonumber(v) > 0 then return redis.call('decr', KEYS[1]) end "
                    + "return 0",
            Long.class);

    private final StringRedisTemplate redis;
    private final NotificationRepository notificationRepository;

    public UnreadCounter(StringRedisTemplate redis, NotificationRepository notificationRepository) {
        this.redis = redis;
        this.notificationRepository = notificationRepository;
    }

    static String key(UUID userId) {
        return KEY_PREFIX + userId;
    }

    /** Current unread count: Redis, else the database (and the key is primed). */
    public long get(UUID userId) {
        try {
            String cached = redis.opsForValue().get(key(userId));
            if (cached != null) {
                return Math.max(0, Long.parseLong(cached));
            }
        } catch (RuntimeException e) {
            log.warn("Reading the unread counter failed; using the database: {}", e.getMessage());
            return notificationRepository.countUnread(userId);
        }
        long count = notificationRepository.countUnread(userId);
        try {
            redis.opsForValue().set(key(userId), Long.toString(count), TTL);
        } catch (RuntimeException e) {
            log.warn("Priming the unread counter failed: {}", e.getMessage());
        }
        return count;
    }

    /** One more unread notification; returns the new count. */
    public long increment(UUID userId) {
        try {
            Long value = redis.execute(INCREMENT_IF_PRESENT, List.of(key(userId)));
            if (value != null && value >= 0) {
                return value;
            }
        } catch (RuntimeException e) {
            log.warn("Incrementing the unread counter failed: {}", e.getMessage());
            return notificationRepository.countUnread(userId);
        }
        return get(userId);
    }

    /** One notification went from unread to read (or an unread one was deleted). */
    public void decrement(UUID userId) {
        try {
            redis.execute(DECREMENT_IF_PRESENT, List.of(key(userId)));
        } catch (RuntimeException e) {
            log.warn("Decrementing the unread counter failed; evicting it: {}", e.getMessage());
            evict(userId);
        }
    }

    /** Everything was read. */
    public void reset(UUID userId) {
        try {
            redis.opsForValue().set(key(userId), "0", TTL);
        } catch (RuntimeException e) {
            log.warn("Resetting the unread counter failed; evicting it: {}", e.getMessage());
            evict(userId);
        }
    }

    /** Forget the cached value; the next read recomputes it. */
    public void evict(UUID userId) {
        try {
            redis.delete(key(userId));
        } catch (RuntimeException e) {
            log.warn("Evicting the unread counter failed: {}", e.getMessage());
        }
    }
}
