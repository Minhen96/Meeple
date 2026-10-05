package com.meeplehearth.match.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.List;
import java.util.UUID;

/**
 * Eagerly created ({@code @Lazy(false)}) because the application runs with
 * {@code spring.main.lazy-initialization=true}; a lazy bean would never be instantiated
 * and its {@code @Scheduled} method would never be registered.
 */
@Component
@Lazy(false)
public class MatchScheduler {

    private static final Logger log = LoggerFactory.getLogger(MatchScheduler.class);
    private static final String LOCK_KEY = "lock:matching_job";

    /** Comfortably above the expected runtime so the lock cannot lapse mid-run. */
    static final Duration LOCK_TTL = Duration.ofMinutes(20);

    /** Delete the key only if it still holds our token (never release another instance's lock). */
    static final RedisScript<Long> RELEASE_SCRIPT = new DefaultRedisScript<>(
            "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
            Long.class);

    private final MatchService matchService;
    private final StringRedisTemplate redisTemplate;

    public MatchScheduler(MatchService matchService, StringRedisTemplate redisTemplate) {
        this.matchService = matchService;
        this.redisTemplate = redisTemplate;
    }

    @Scheduled(fixedDelayString = "${meeple.match.interval-ms:1800000}")
    public void runMatchingJob() {
        String token = UUID.randomUUID().toString();
        Boolean locked = redisTemplate.opsForValue().setIfAbsent(LOCK_KEY, token, LOCK_TTL);

        if (!Boolean.TRUE.equals(locked)) {
            log.debug("Matching job skipped — another instance holds the lock");
            return;
        }

        try {
            log.info("Running matching job");
            matchService.runMatchingAlgorithm();
            log.info("Matching job complete");
        } catch (Exception e) {
            log.error("Matching job failed", e);
        } finally {
            try {
                redisTemplate.execute(RELEASE_SCRIPT, List.of(LOCK_KEY), token);
            } catch (Exception e) {
                log.warn("Failed to release matching job lock; it will expire after {}", LOCK_TTL, e);
            }
        }
    }
}
