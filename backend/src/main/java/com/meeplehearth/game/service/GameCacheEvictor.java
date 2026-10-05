package com.meeplehearth.game.service;

import com.meeplehearth.config.CacheConfig.CacheNames;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.UUID;

/**
 * Evicts the library caches. Inside a transaction the eviction runs after commit, so a concurrent
 * read cannot re-cache the pre-commit state; outside one it runs immediately. Failures are logged
 * and ignored (the TTL bounds staleness).
 */
@Component
public class GameCacheEvictor {

    private static final Logger log = LoggerFactory.getLogger(GameCacheEvictor.class);

    private final CacheManager cacheManager;

    public GameCacheEvictor(CacheManager cacheManager) {
        this.cacheManager = cacheManager;
    }

    public void evictCollection(UUID userId) {
        evict(CacheNames.USER_COLLECTION, userId);
    }

    public void evictGameDetail(UUID gameId) {
        evict(CacheNames.GAME_DETAIL, gameId);
    }

    private void evict(String cacheName, Object key) {
        if (key == null) return;
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCompletion(int status) {
                    // Also after a rollback: harmless, and the entry may have been read mid-transaction
                    evictNow(cacheName, key);
                }
            });
        } else {
            evictNow(cacheName, key);
        }
    }

    private void evictNow(String cacheName, Object key) {
        try {
            Cache cache = cacheManager.getCache(cacheName);
            if (cache != null) cache.evict(key);
        } catch (RuntimeException e) {
            log.warn("Evicting {} from cache '{}' failed", key, cacheName, e);
        }
    }
}
