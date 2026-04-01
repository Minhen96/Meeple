package com.meeplehearth.config;

import org.springframework.context.annotation.Configuration;

/**
 * Redis is auto-configured by Spring Boot from spring.data.redis.url.
 *
 * Local:  redis://localhost:6379          (application-local.yml, via REDIS_URL env var)
 * Prod:   rediss://default:TOKEN@host:port (application-prod.yml, via REDIS_URL env var)
 *
 * The "rediss://" scheme (double-s) enables TLS automatically — required for Upstash.
 * StringRedisTemplate is auto-configured and available for injection without any setup here.
 */
@Configuration
public class RedisConfig {
}
