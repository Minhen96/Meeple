package com.meeplehearth.game.config;

import com.meeplehearth.config.CacheConfig.CacheNames;
import org.springframework.boot.autoconfigure.cache.RedisCacheManagerBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;

import java.time.Duration;

/**
 * TTLs of the library package's caches (ENGINEERING_STANDARDS section 6). Serialization, key
 * prefix and error handling come from the shared {@code config/CacheConfig}.
 */
@Configuration
public class GameCacheConfig {

    /** Catalog data changes rarely (BGG sync, rulebook approval evicts explicitly). */
    public static final Duration GAME_DETAIL_TTL = Duration.ofDays(7);
    /** A user's collection; every write evicts it, the TTL only bounds staleness from missed evictions. */
    public static final Duration USER_COLLECTION_TTL = Duration.ofMinutes(10);

    @Bean
    public RedisCacheManagerBuilderCustomizer gameCacheTtls(RedisCacheConfiguration base) {
        return builder -> builder
                .withCacheConfiguration(CacheNames.GAME_DETAIL, base.entryTtl(GAME_DETAIL_TTL))
                .withCacheConfiguration(CacheNames.USER_COLLECTION, base.entryTtl(USER_COLLECTION_TTL));
    }
}
