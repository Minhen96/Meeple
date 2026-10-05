package com.meeplehearth.ai.service;

import com.meeplehearth.common.exception.ApiException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

/**
 * Per-user daily rate limits and per-resource locks for AI / cost-bearing endpoints.
 *
 * Counter keys follow the AiService convention: {prefix}{userId}:{yyyy-mm-dd} (UTC).
 * INCR and EXPIRE run in one Lua script so a counter can never be left without a TTL.
 */
@Component
public class AiRateLimiter {

    private static final RedisScript<Long> INCR_WITH_TTL = new DefaultRedisScript<>(
            "local c = redis.call('INCR', KEYS[1]) "
                    + "if c == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end "
                    + "return c",
            Long.class);

    private static final Duration COUNTER_TTL = Duration.ofDays(1);

    private final StringRedisTemplate redisTemplate;

    public AiRateLimiter(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    /**
     * Increments today's counter for (keyPrefix, userId) and throws 429 if it exceeds {@code dailyLimit}.
     *
     * @param keyPrefix e.g. "ai:ratelimit:how-to-play:" (must end with ':')
     */
    public void checkDaily(String keyPrefix, UUID userId, int dailyLimit, String errorCode, String message) {
        if (userId == null) return;
        String key = keyPrefix + userId + ":" + LocalDate.now(ZoneOffset.UTC);
        Long count = redisTemplate.execute(INCR_WITH_TTL, List.of(key),
                String.valueOf(COUNTER_TTL.toSeconds()));
        if (count != null && count > dailyLimit) {
            throw ApiException.tooManyRequests(errorCode, message);
        }
    }

    /** Acquires a lock via SET NX with TTL. Returns true if this caller now holds it. */
    public boolean tryLock(String lockKey, Duration ttl) {
        return Boolean.TRUE.equals(redisTemplate.opsForValue().setIfAbsent(lockKey, "1", ttl));
    }

    public boolean isLocked(String lockKey) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(lockKey));
    }

    public void unlock(String lockKey) {
        redisTemplate.delete(lockKey);
    }
}
