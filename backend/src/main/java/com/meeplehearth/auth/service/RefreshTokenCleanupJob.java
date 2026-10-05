package com.meeplehearth.auth.service;

import com.meeplehearth.auth.repository.RefreshTokenRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;

/**
 * Deletes expired refresh tokens and rotated (used) tokens once they are older than the
 * reuse-detection window. Eagerly initialised because the app runs with lazy initialisation
 * and nothing else references this bean.
 */
@Component
@Lazy(false)
public class RefreshTokenCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(RefreshTokenCleanupJob.class);
    private static final String LOCK_KEY = "lock:refresh_token_cleanup_job";
    private static final Duration USED_TOKEN_RETENTION = Duration.ofDays(7);

    private final RefreshTokenRepository refreshTokenRepository;
    private final StringRedisTemplate redisTemplate;

    public RefreshTokenCleanupJob(RefreshTokenRepository refreshTokenRepository,
                                  StringRedisTemplate redisTemplate) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.redisTemplate = redisTemplate;
    }

    @Scheduled(cron = "0 17 3 * * *")
    @Transactional
    public void purgeStaleTokens() {
        Boolean locked = redisTemplate.opsForValue()
                .setIfAbsent(LOCK_KEY, "1", Duration.ofMinutes(10));
        if (!Boolean.TRUE.equals(locked)) {
            log.debug("Refresh token cleanup skipped — another instance holds the lock");
            return;
        }

        try {
            Instant now = Instant.now();
            int deleted = refreshTokenRepository.deleteExpiredOrUsedBefore(now, now.minus(USED_TOKEN_RETENTION));
            log.info("Refresh token cleanup removed {} rows", deleted);
        } finally {
            redisTemplate.delete(LOCK_KEY);
        }
    }
}
