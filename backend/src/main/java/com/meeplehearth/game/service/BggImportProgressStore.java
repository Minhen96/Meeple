package com.meeplehearth.game.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.meeplehearth.game.dto.BggImportStatusResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.UUID;

/**
 * BGG import progress in Redis (docs/GAP_ANALYSIS.md section 6.2): {@code bgg:import:{userId}}
 * holds the latest {@link BggImportStatusResponse} as JSON for a day; {@code bgg:import:{userId}:lock}
 * marks a running import (one per user). If the lock expires while the progress still says
 * "running" (the instance died mid-import), the status is reported as failed.
 */
@Component
public class BggImportProgressStore {

    private static final Logger log = LoggerFactory.getLogger(BggImportProgressStore.class);

    static final String KEY_PREFIX = "bgg:import:";
    static final Duration PROGRESS_TTL = Duration.ofDays(1);
    static final Duration LOCK_TTL = Duration.ofMinutes(30);

    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;

    public BggImportProgressStore(StringRedisTemplate redis, ObjectMapper objectMapper) {
        this.redis = redis;
        this.objectMapper = objectMapper;
    }

    static String progressKey(UUID userId) {
        return KEY_PREFIX + userId;
    }

    static String lockKey(UUID userId) {
        return KEY_PREFIX + userId + ":lock";
    }

    /** @return true if no import was running for the user and this caller now owns the run */
    public boolean tryLock(UUID userId) {
        return Boolean.TRUE.equals(redis.opsForValue().setIfAbsent(lockKey(userId), "1", LOCK_TTL));
    }

    public void unlock(UUID userId) {
        redis.delete(lockKey(userId));
    }

    /** Extends the lock while a long import makes progress. */
    public void touchLock(UUID userId) {
        redis.expire(lockKey(userId), LOCK_TTL);
    }

    public void save(UUID userId, BggImportStatusResponse status) {
        try {
            redis.opsForValue().set(progressKey(userId), objectMapper.writeValueAsString(status), PROGRESS_TTL);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Cannot serialize BGG import status", e);
        }
    }

    public BggImportStatusResponse get(UUID userId) {
        String json = redis.opsForValue().get(progressKey(userId));
        if (json == null) {
            return BggImportStatusResponse.idle();
        }
        BggImportStatusResponse status;
        try {
            status = objectMapper.readValue(json, BggImportStatusResponse.class);
        } catch (JsonProcessingException e) {
            log.warn("Unreadable BGG import status for user {}; reporting idle", userId);
            return BggImportStatusResponse.idle();
        }
        if (status.isRunning() && !Boolean.TRUE.equals(redis.hasKey(lockKey(userId)))) {
            return new BggImportStatusResponse(BggImportStatusResponse.FAILED, status.total(), status.processed(),
                    status.imported(), status.skipped(), status.failed(), BggCollectionImportService.BGG_API_UNAVAILABLE,
                    status.preview());
        }
        return status;
    }

    public void clear(UUID userId) {
        redis.delete(java.util.List.of(progressKey(userId), lockKey(userId)));
    }
}
