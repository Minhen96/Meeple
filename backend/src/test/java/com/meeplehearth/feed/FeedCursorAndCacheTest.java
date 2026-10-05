package com.meeplehearth.feed;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.feed.service.FeedCache;
import com.meeplehearth.feed.service.FeedCursor;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FeedCursorAndCacheTest {

    // -------------------------------------------------------------------------
    // FeedCursor
    // -------------------------------------------------------------------------

    @Test
    void cursorRoundTripsAndIsUrlSafe() {
        Instant at = Instant.parse("2026-10-01T12:34:56.123456Z");
        UUID id = UUID.randomUUID();

        String encoded = FeedCursor.encode(at, id);

        assertThat(encoded).matches("[A-Za-z0-9_-]+");
        assertThat(FeedCursor.parse(encoded)).isEqualTo(new FeedCursor(at, id));
        assertThat(FeedCursor.parse("  " + encoded + " ")).isEqualTo(new FeedCursor(at, id));
    }

    @Test
    void blankCursorIsTheFirstPageAndBareInstantPairsWithTheSmallestId() {
        assertThat(FeedCursor.parse(null)).isNull();
        assertThat(FeedCursor.parse("  ")).isNull();
        assertThat(FeedCursor.parse("2026-04-05T20:00:00Z"))
                .isEqualTo(new FeedCursor(Instant.parse("2026-04-05T20:00:00Z"), new UUID(0, 0)));
    }

    @Test
    void malformedCursorsAre400() {
        String noBar = b64("2026-04-05T20:00:00Z");
        String badId = b64("2026-04-05T20:00:00Z|nope");
        String badTime = b64("yesterday|" + UUID.randomUUID());
        for (String cursor : List.of("%%%", noBar, badId, badTime, "2026-13-45")) {
            assertThatThrownBy(() -> FeedCursor.parse(cursor))
                    .as(cursor)
                    .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.getCode()).isEqualTo("INVALID_CURSOR"));
        }
    }

    private static String b64(String raw) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    // -------------------------------------------------------------------------
    // FeedCache resilience
    // -------------------------------------------------------------------------

    @Test
    @SuppressWarnings("unchecked")
    void redisFailuresDegradeToMissesAndSkippedWrites() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.get(anyString())).thenThrow(new IllegalStateException("redis down"));
        org.mockito.Mockito.doThrow(new IllegalStateException("redis down"))
                .when(ops).set(anyString(), anyString(), any(Duration.class));
        when(redis.delete(anyCollection())).thenThrow(new IllegalStateException("redis down"));
        FeedCache cache = new FeedCache(redis, mapper());
        UUID user = UUID.randomUUID();

        assertThat(cache.get(user, null)).isEmpty();
        cache.put(user, null, new FeedCache.Skeleton(20, List.of(), null, false)); // no exception
        cache.invalidateAfterCommit(user); // no exception
    }

    @Test
    @SuppressWarnings("unchecked")
    void unreadableEntryIsAMissAndValidEntryRoundTrips() throws Exception {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        FeedCache cache = new FeedCache(redis, mapper());
        UUID user = UUID.randomUUID();
        FeedCache.Skeleton skeleton = new FeedCache.Skeleton(2,
                List.of(new FeedCache.FeedRef("post", UUID.randomUUID(), Instant.parse("2026-10-01T00:00:00Z"))),
                "abc", true);

        when(ops.get("feed:" + user + ":first")).thenReturn("{not json");
        assertThat(cache.get(user, null)).isEmpty();

        when(ops.get("feed:" + user + ":cur")).thenReturn(mapper().writeValueAsString(skeleton));
        assertThat(cache.get(user, "cur")).contains(skeleton);
    }

    @Test
    void invalidationWaitsForCommitWhenATransactionIsActive() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        FeedCache cache = new FeedCache(redis, mapper());
        UUID user = UUID.randomUUID();

        TransactionSynchronizationManager.initSynchronization();
        try {
            cache.invalidateAfterCommit(user);
            verify(redis, never()).delete(anyCollection());
            List<TransactionSynchronization> syncs = TransactionSynchronizationManager.getSynchronizations();
            assertThat(syncs).hasSize(1);
            syncs.get(0).afterCommit();
            verify(redis).delete(List.of("feed:" + user + ":first"));
        } finally {
            TransactionSynchronizationManager.clearSynchronization();
        }

        cache.invalidateAfterCommit(List.of());
        verify(redis).delete(anyCollection()); // still only the one call above
    }

    private static ObjectMapper mapper() {
        return new ObjectMapper().registerModule(new JavaTimeModule());
    }
}
