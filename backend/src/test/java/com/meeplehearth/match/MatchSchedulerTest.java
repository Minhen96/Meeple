package com.meeplehearth.match;

import com.meeplehearth.common.job.JobLock;
import com.meeplehearth.match.service.MatchScheduler;
import com.meeplehearth.match.service.MatchService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.core.script.RedisScript;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Failure handling of the scheduled job; the happy path and lock contention run against real Redis in MatchApiIntegrationTest. */
class MatchSchedulerTest {

    private final MatchService matchService = mock(MatchService.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final MatchScheduler scheduler = new MatchScheduler(matchService, new JobLock(redis));

    @BeforeEach
    void setUp() {
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.setIfAbsent(eq("lock:matching_job"), anyString(), any(Duration.class))).thenReturn(true);
    }

    @Test
    void jobFailureIsLoggedAndLockStillReleased() {
        doThrow(new IllegalStateException("db down")).when(matchService).runMatchingAlgorithm();

        assertThatCode(scheduler::runMatchingJob).doesNotThrowAnyException();

        verify(redis).execute(any(RedisScript.class), eq(List.of("lock:matching_job")), anyString());
    }

    @Test
    void lockReleaseFailureIsSwallowedSoTheLockSimplyExpires() {
        when(redis.execute(any(RedisScript.class), anyList(), anyString()))
                .thenThrow(new IllegalStateException("redis gone"));

        assertThatCode(scheduler::runMatchingJob).doesNotThrowAnyException();

        verify(matchService).runMatchingAlgorithm();
    }

    @Test
    void expiryJobFailureIsLoggedAndLockStillReleased() {
        when(ops.setIfAbsent(eq("lock:match_request_expire"), anyString(), any(Duration.class))).thenReturn(true);
        doThrow(new IllegalStateException("db down")).when(matchService).expireStaleRequests(any(Instant.class));

        assertThatCode(scheduler::expireStaleRequests).doesNotThrowAnyException();

        verify(redis).execute(any(RedisScript.class), eq(List.of("lock:match_request_expire")), anyString());
    }
}
