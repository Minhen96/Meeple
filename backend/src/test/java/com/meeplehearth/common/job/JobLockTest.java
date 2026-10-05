package com.meeplehearth.common.job;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class JobLockTest {

    private static final Duration TTL = Duration.ofMinutes(5);

    @Mock
    private StringRedisTemplate redisTemplate;
    @Mock
    private ValueOperations<String, String> valueOps;

    private JobLock jobLock;

    @BeforeEach
    void setUp() {
        when(redisTemplate.opsForValue()).thenReturn(valueOps);
        jobLock = new JobLock(redisTemplate);
    }

    @Test
    void runsTaskAndReleasesWithTheSameTokenItAcquiredWith() {
        when(valueOps.setIfAbsent(eq("lock:demo"), anyString(), eq(TTL))).thenReturn(true);
        AtomicInteger runs = new AtomicInteger();

        boolean ran = jobLock.runWithLock("demo", TTL, runs::incrementAndGet);

        assertThat(ran).isTrue();
        assertThat(runs).hasValue(1);
        ArgumentCaptor<String> acquiredToken = ArgumentCaptor.forClass(String.class);
        verify(valueOps).setIfAbsent(eq("lock:demo"), acquiredToken.capture(), eq(TTL));
        // Compare-and-delete: the release script gets our key and our token, never a plain DEL
        verify(redisTemplate).execute(JobLock.RELEASE_SCRIPT, List.of("lock:demo"), acquiredToken.getValue());
        verify(redisTemplate, never()).delete(anyString());
    }

    @Test
    void skipsTaskWhenAnotherInstanceHoldsTheLock() {
        when(valueOps.setIfAbsent(eq("lock:demo"), anyString(), eq(TTL))).thenReturn(false);
        AtomicInteger runs = new AtomicInteger();

        boolean ran = jobLock.runWithLock("demo", TTL, runs::incrementAndGet);

        assertThat(ran).isFalse();
        assertThat(runs).hasValue(0);
        verify(redisTemplate, never()).execute(eq(JobLock.RELEASE_SCRIPT), eq(List.of("lock:demo")), anyString());
    }

    @Test
    void releasesLockAndPropagatesWhenTaskThrows() {
        when(valueOps.setIfAbsent(eq("lock:demo"), anyString(), eq(TTL))).thenReturn(true);

        assertThatThrownBy(() -> jobLock.runWithLock("demo", TTL, () -> {
            throw new IllegalStateException("boom");
        })).isInstanceOf(IllegalStateException.class).hasMessage("boom");

        verify(redisTemplate).execute(eq(JobLock.RELEASE_SCRIPT), eq(List.of("lock:demo")), anyString());
    }

    @Test
    void releaseFailureDoesNotFailTheJob() {
        when(valueOps.setIfAbsent(eq("lock:demo"), anyString(), eq(TTL))).thenReturn(true);
        when(redisTemplate.execute(eq(JobLock.RELEASE_SCRIPT), eq(List.of("lock:demo")), anyString()))
                .thenThrow(new IllegalStateException("redis down"));

        assertThat(jobLock.runWithLock("demo", TTL, () -> { })).isTrue();
    }
}
