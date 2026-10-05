package com.meeplehearth.feed.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.Duration;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

/**
 * 60-second Redis cache of feed page <em>skeletons</em> (which items, in which order) under
 * {@code feed:{userId}:{cursor|first}} (docs/GAP_ANALYSIS.md section 6.2).
 *
 * <p>Only item references are cached; posts and activities are hydrated per request, so per-viewer
 * fields (liked, bookmarked), deletions and blocks are always current. Invalidation therefore only
 * needs to make <em>new</em> items appear: the first page of the affected users is dropped after
 * the writing transaction commits. Older pages are keyset pages and age out within the TTL.
 *
 * <p>Redis failures never fail a request: reads become misses and writes are skipped.
 */
@Component
public class FeedCache {

    private static final Logger log = LoggerFactory.getLogger(FeedCache.class);

    static final Duration TTL = Duration.ofSeconds(60);
    static final String FIRST_PAGE = "first";

    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;

    public FeedCache(StringRedisTemplate redis, ObjectMapper objectMapper) {
        this.redis = redis;
        this.objectMapper = objectMapper;
    }

    /** A cached page: item references in display order plus paging state. */
    public record Skeleton(int limit, List<FeedRef> refs, String nextCursor, boolean hasMore) {
    }

    /** One feed row: {@code kind} is {@code post} or {@code activity}. */
    public record FeedRef(String kind, UUID id, java.time.Instant createdAt) {
    }

    static String key(UUID userId, String cursor) {
        return "feed:" + userId + ":" + (cursor == null || cursor.isBlank() ? FIRST_PAGE : cursor);
    }

    public Optional<Skeleton> get(UUID userId, String cursor) {
        try {
            String json = redis.opsForValue().get(key(userId, cursor));
            return json == null ? Optional.empty() : Optional.of(objectMapper.readValue(json, Skeleton.class));
        } catch (JsonProcessingException | RuntimeException e) {
            log.warn("Feed cache read failed; treating as a miss", e);
            return Optional.empty();
        }
    }

    public void put(UUID userId, String cursor, Skeleton skeleton) {
        try {
            redis.opsForValue().set(key(userId, cursor), objectMapper.writeValueAsString(skeleton), TTL);
        } catch (JsonProcessingException | RuntimeException e) {
            log.warn("Feed cache write failed", e);
        }
    }

    /**
     * Drops the first feed page of each user once the current transaction commits (immediately
     * when there is none), so a concurrent reader cannot re-cache pre-commit data.
     */
    public void invalidateAfterCommit(Collection<UUID> userIds) {
        Set<UUID> ids = new LinkedHashSet<>(userIds);
        if (ids.isEmpty()) {
            return;
        }
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    invalidateNow(ids);
                }
            });
        } else {
            invalidateNow(ids);
        }
    }

    public void invalidateAfterCommit(UUID... userIds) {
        invalidateAfterCommit(List.of(userIds));
    }

    void invalidateNow(Collection<UUID> userIds) {
        try {
            redis.delete(userIds.stream().map(id -> key(id, null)).toList());
        } catch (RuntimeException e) {
            log.warn("Feed cache invalidation failed; entries expire within {}", TTL, e);
        }
    }
}
