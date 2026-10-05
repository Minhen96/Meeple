package com.meeplehearth.common.ratelimit;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.List;

/**
 * Fixed-window counters in Redis. INCR and the window TTL are applied in one Lua script,
 * so a crash between the two can never leave a counter without an expiry.
 */
@Component
public class RedisRateLimiter {

    private static final RedisScript<Long> INCREMENT_WITH_TTL = new DefaultRedisScript<>(
            "local count = redis.call('INCR', KEYS[1]) "
                    + "if redis.call('PTTL', KEYS[1]) < 0 then redis.call('PEXPIRE', KEYS[1], ARGV[1]) end "
                    + "return count",
            Long.class);

    private final StringRedisTemplate redisTemplate;

    public RedisRateLimiter(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    /** Increments the counter for {@code key} and returns the new count within the current window. */
    public long increment(String key, Duration window) {
        Long count = redisTemplate.execute(INCREMENT_WITH_TTL, List.of(key), String.valueOf(window.toMillis()));
        return count == null ? 0L : count;
    }

    /** Counts one attempt and returns true while the window's count is still within {@code limit}. */
    public boolean tryAcquire(String key, long limit, Duration window) {
        return increment(key, window) <= limit;
    }
}
