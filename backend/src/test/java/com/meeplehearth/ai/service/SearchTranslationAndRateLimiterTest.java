package com.meeplehearth.ai.service;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.support.ai.AiGameIntegrationTestBase;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;

import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** CJK detection for search translation (through the fake LLM) and the Redis-backed rate limiter / locks. */
class SearchTranslationAndRateLimiterTest extends AiGameIntegrationTestBase {

    @Autowired private SearchTranslationService translationService;
    @Autowired private AiRateLimiter rateLimiter;

    @ParameterizedTest
    @ValueSource(strings = {"卡坦島", "㐀字", "かたん", "カタン", "카탄"})
    void everyCjkScriptIsTranslated(String query) {
        OPENAI.onCompletion(body -> "Catan");

        SearchTranslationService.TranslationResult result = translationService.translateIfNeeded(query);

        assertThat(result.query()).isEqualTo("Catan");
        assertThat(result.translatedFrom()).isEqualTo(query);
        assertThat(OPENAI.completionRequests()).hasSize(1);
        assertThat(OPENAI.completionRequests().get(0).path("max_tokens").asInt()).isEqualTo(50);
    }

    @Test
    void nonCjkOrEmptyQueriesAreReturnedUnchanged() {
        assertThat(translationService.translateIfNeeded("Catan")).isEqualTo(new SearchTranslationService.TranslationResult("Catan", null));
        assertThat(translationService.translateIfNeeded("Café ñ ü — Ελληνικά")).extracting(SearchTranslationService.TranslationResult::translatedFrom).isNull();
        assertThat(translationService.translateIfNeeded(" ").query()).isEqualTo(" ");
        assertThat(translationService.translateIfNeeded(null).query()).isNull();
        assertThat(OPENAI.completionRequests()).isEmpty();
    }

    @Test
    void dailyCounterExpiresAndRejectsOverLimit() {
        UUID user = createUser();
        String key = "test:limit:" + user + ":" + LocalDate.now(ZoneOffset.UTC);

        rateLimiter.checkDaily("test:limit:", user, 2, "LIMIT", "slow down");
        rateLimiter.checkDaily("test:limit:", user, 2, "LIMIT", "slow down");
        assertThat(redis.getExpire(key)).isBetween(1L, Duration.ofDays(1).toSeconds());

        assertThatThrownBy(() -> rateLimiter.checkDaily("test:limit:", user, 2, "LIMIT", "slow down"))
                .isInstanceOfSatisfying(ApiException.class, e -> {
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(e.getCode()).isEqualTo("LIMIT");
                    assertThat(e.getMessage()).isEqualTo("slow down");
                });
        assertThat(redis.opsForValue().get(key)).isEqualTo("3");

        // Anonymous callers are not counted
        rateLimiter.checkDaily("test:limit:", null, 0, "LIMIT", "x");
    }

    @Test
    void locksAreExclusiveUntilReleased() {
        String lock = "test:lock:" + UUID.randomUUID();
        try {
            assertThat(rateLimiter.isLocked(lock)).isFalse();
            assertThat(rateLimiter.tryLock(lock, Duration.ofMinutes(1))).isTrue();
            assertThat(rateLimiter.tryLock(lock, Duration.ofMinutes(1))).isFalse();
            assertThat(rateLimiter.isLocked(lock)).isTrue();
            assertThat(redis.getExpire(lock)).isPositive();
            rateLimiter.unlock(lock);
            assertThat(rateLimiter.isLocked(lock)).isFalse();
        } finally {
            redis.delete(lock);
        }
    }
}
