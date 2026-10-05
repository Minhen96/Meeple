package com.meeplehearth.config;

import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.jsontype.BasicPolymorphicTypeValidator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.cache.CacheProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.cache.Cache;
import org.springframework.cache.annotation.CachingConfigurer;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.interceptor.CacheErrorHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext.SerializationPair;

import java.time.Duration;

/**
 * Spring Cache on Redis ({@code spring.cache.*} in application.yml).
 *
 * <p>Values are stored as JSON with type hints, so cached DTOs (records included) do not need to
 * implement {@code Serializable}. Cache errors (Redis down, unreadable entry after a DTO change)
 * are logged and treated as a miss: the method runs normally instead of failing the request.
 *
 * <p>Cache names are listed in {@link CacheNames}. A package that needs a TTL other than the
 * default declares its own {@code RedisCacheManagerBuilderCustomizer} bean in its own package.
 */
@Configuration
@EnableCaching
@EnableConfigurationProperties(CacheProperties.class)
public class CacheConfig implements CachingConfigurer {

    private static final Logger log = LoggerFactory.getLogger(CacheConfig.class);
    private static final Duration DEFAULT_TTL = Duration.ofMinutes(10);

    /** Shared cache names (docs/GAP_ANALYSIS.md section 6.2); owners in brackets. */
    public static final class CacheNames {
        /** [WP4] game detail by id. */
        public static final String GAME_DETAIL = "game-detail";
        /** [WP4] a user's collection. */
        public static final String USER_COLLECTION = "user-collection";
        /** [WP5] public user profile. */
        public static final String USER_PROFILE = "user-profile";
        /** [WP2] event detail. */
        public static final String EVENT_DETAIL = "event-detail";

        private CacheNames() {
        }
    }

    @Bean
    public RedisCacheConfiguration redisCacheConfiguration(CacheProperties cacheProperties,
                                                           ObjectMapper objectMapper) {
        CacheProperties.Redis redis = cacheProperties.getRedis();
        RedisCacheConfiguration config = RedisCacheConfiguration.defaultCacheConfig()
                .serializeValuesWith(SerializationPair.fromSerializer(cacheValueSerializer(objectMapper)))
                .entryTtl(redis.getTimeToLive() != null ? redis.getTimeToLive() : DEFAULT_TTL);
        if (!redis.isCacheNullValues()) {
            config = config.disableCachingNullValues();
        }
        if (redis.getKeyPrefix() != null) {
            config = config.prefixCacheNameWith(redis.getKeyPrefix());
        }
        if (!redis.isUseKeyPrefix()) {
            config = config.disableKeyPrefix();
        }
        return config;
    }

    /**
     * JSON serializer built from the application's ObjectMapper (java.time support), with type
     * hints restricted to application and JDK value types.
     */
    @SuppressWarnings("deprecation") // DefaultTyping.EVERYTHING: needed to type final classes (records)
    static GenericJackson2JsonRedisSerializer cacheValueSerializer(ObjectMapper applicationMapper) {
        ObjectMapper mapper = applicationMapper.copy();
        BasicPolymorphicTypeValidator typeValidator = BasicPolymorphicTypeValidator.builder()
                .allowIfSubType("com.meeplehearth.")
                .allowIfSubType("java.util.")
                .allowIfSubType("java.time.")
                .allowIfSubType("java.lang.")
                .allowIfSubType("java.math.")
                .allowIfSubTypeIsArray()
                .build();
        mapper.activateDefaultTyping(typeValidator, ObjectMapper.DefaultTyping.EVERYTHING,
                JsonTypeInfo.As.PROPERTY);
        return new GenericJackson2JsonRedisSerializer(mapper);
    }

    @Override
    public CacheErrorHandler errorHandler() {
        return new CacheErrorHandler() {
            @Override
            public void handleCacheGetError(RuntimeException e, Cache cache, Object key) {
                log.warn("Cache get failed for cache '{}'; treating as a miss", cache.getName(), e);
            }

            @Override
            public void handleCachePutError(RuntimeException e, Cache cache, Object key, Object value) {
                log.warn("Cache put failed for cache '{}'", cache.getName(), e);
            }

            @Override
            public void handleCacheEvictError(RuntimeException e, Cache cache, Object key) {
                log.warn("Cache evict failed for cache '{}'", cache.getName(), e);
            }

            @Override
            public void handleCacheClearError(RuntimeException e, Cache cache) {
                log.warn("Cache clear failed for cache '{}'", cache.getName(), e);
            }
        };
    }
}
