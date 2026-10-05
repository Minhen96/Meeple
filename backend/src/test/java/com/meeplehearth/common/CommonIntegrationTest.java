package com.meeplehearth.common;

import com.meeplehearth.common.ratelimit.RedisRateLimiter;
import com.meeplehearth.support.auth.AuthWebIntegrationTest;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Response envelope, error mapping and the Redis rate limiter, exercised against the real stack. */
class CommonIntegrationTest extends AuthWebIntegrationTest {

    @Autowired private RedisRateLimiter rateLimiter;

    // ------------------------------------------------------------------ RedisRateLimiter

    @Test
    void rateLimiterCountsWithinAWindowThatExpires() {
        String key = "test:ratelimit:" + UUID.randomUUID();
        trackRedisKey(key);

        assertThat(rateLimiter.increment(key, Duration.ofMinutes(5))).isEqualTo(1);
        assertThat(rateLimiter.increment(key, Duration.ofMinutes(5))).isEqualTo(2);
        long ttlMs = redis.getExpire(key, TimeUnit.MILLISECONDS);
        assertThat(ttlMs).isBetween(1L, Duration.ofMinutes(5).toMillis());

        // Later increments never extend the window
        rateLimiter.increment(key, Duration.ofHours(10));
        assertThat(redis.getExpire(key, TimeUnit.MILLISECONDS)).isLessThanOrEqualTo(ttlMs);
    }

    @Test
    void tryAcquireAllowsExactlyTheLimit() {
        String key = "test:ratelimit:" + UUID.randomUUID();
        trackRedisKey(key);

        assertThat(rateLimiter.tryAcquire(key, 2, Duration.ofMinutes(1))).isTrue();
        assertThat(rateLimiter.tryAcquire(key, 2, Duration.ofMinutes(1))).isTrue();
        assertThat(rateLimiter.tryAcquire(key, 2, Duration.ofMinutes(1))).isFalse();
    }

    @Test
    void counterWithoutTtlGetsOneOnTheNextIncrement() {
        String key = "test:ratelimit:" + UUID.randomUUID();
        trackRedisKey(key);
        redis.opsForValue().set(key, "7");

        assertThat(rateLimiter.increment(key, Duration.ofSeconds(30))).isEqualTo(8);
        assertThat(redis.getExpire(key)).isBetween(1L, 30L);
    }

    @Test
    void windowExpiryResetsTheCount() throws Exception {
        String key = "test:ratelimit:" + UUID.randomUUID();
        trackRedisKey(key);

        rateLimiter.increment(key, Duration.ofMillis(50));
        Thread.sleep(120);

        assertThat(rateLimiter.increment(key, Duration.ofMinutes(1))).isEqualTo(1);
    }

    // ------------------------------------------------------------------ envelope & errors over HTTP

    @Test
    void successBodiesAreWrappedAndErrorsAreFlat() throws Exception {
        User user = persistUser(true);

        mockMvc.perform(get("/api/v1/users/me").cookie(accessCookie(user)))
                .andExpect(jsonPath("$.data.id").value(user.getId().toString()))
                .andExpect(jsonPath("$.id").doesNotExist());
        mockMvc.perform(get("/api/v1/users/" + UUID.randomUUID()).cookie(accessCookie(user)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("User not found"))
                .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"))
                .andExpect(jsonPath("$.data").doesNotExist());
    }

    @Test
    void unmappedPathsAreA404InTheStandardErrorShape() throws Exception {
        User user = persistUser(true);

        mockMvc.perform(get("/api/v1/does-not-exist").cookie(accessCookie(user)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"))
                .andExpect(jsonPath("$.error").value("Resource not found"));
    }

    // ------------------------------------------------------------------ known bugs

    @Test
    void clientErrorsAreNotReportedAsServerErrors() throws Exception {
        User user = persistUser(true);

        // Malformed UUID path variable
        mockMvc.perform(get("/api/v1/users/not-a-uuid").cookie(accessCookie(user)))
                .andExpect(status().isBadRequest());
        // Missing required query parameter
        mockMvc.perform(get("/api/v1/users/search").cookie(accessCookie(user)))
                .andExpect(status().isBadRequest());
        // Malformed JSON body
        mockMvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON).content("{not json"))
                .andExpect(status().isBadRequest());
        // Wrong HTTP method
        mockMvc.perform(patch("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isMethodNotAllowed());
        // Unsupported content type
        mockMvc.perform(post("/api/v1/auth/login").contentType(MediaType.TEXT_PLAIN).content("x"))
                .andExpect(status().isUnsupportedMediaType());
    }
}
