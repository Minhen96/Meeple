package com.meeplehearth.common.job;

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
 * Redis distributed lock for scheduled jobs (CLAUDE.md: every scheduled job runs under one), so
 * only one instance executes a job at a time.
 *
 * <p>The lock is the key {@code lock:{name}}, set with {@code SET NX PX} to a random token.
 * Release is compare-and-delete in a Lua script: an instance whose run outlived the TTL never
 * deletes a lock that another instance has since acquired. Pick a TTL comfortably above the
 * job's worst-case runtime.
 */
@Component
public class JobLock {

    private static final Logger log = LoggerFactory.getLogger(JobLock.class);

    static final String KEY_PREFIX = "lock:";

    /** Delete the key only if it still holds our token (never release another instance's lock). */
    static final RedisScript<Long> RELEASE_SCRIPT = new DefaultRedisScript<>(
            "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
            Long.class);

    private final StringRedisTemplate redisTemplate;

    public JobLock(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    /**
     * Runs {@code task} only if this instance acquires {@code lock:{name}}; otherwise skips it.
     * Exceptions thrown by the task propagate to the caller after the lock is released. A failure
     * to release is logged and the lock simply expires after {@code ttl}.
     *
     * @return {@code true} if the task ran, {@code false} if another instance held the lock
     */
    public boolean runWithLock(String name, Duration ttl, Runnable task) {
        String key = KEY_PREFIX + name;
        String token = UUID.randomUUID().toString();

        if (!Boolean.TRUE.equals(redisTemplate.opsForValue().setIfAbsent(key, token, ttl))) {
            log.debug("Job '{}' skipped: another instance holds the lock", name);
            return false;
        }

        try {
            task.run();
            return true;
        } finally {
            try {
                redisTemplate.execute(RELEASE_SCRIPT, List.of(key), token);
            } catch (RuntimeException e) {
                log.warn("Failed to release lock for job '{}'; it will expire after {}", name, ttl, e);
            }
        }
    }
}
