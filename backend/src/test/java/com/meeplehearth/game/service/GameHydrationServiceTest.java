package com.meeplehearth.game.service;

import com.meeplehearth.game.client.BggApiClient;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameDetailRepository;
import com.meeplehearth.game.repository.GameRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.Pageable;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.transaction.PlatformTransactionManager;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atMost;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class GameHydrationServiceTest {

    @Mock private GameRepository gameRepository;
    @Mock private GameDetailRepository gameDetailRepository;
    @Mock private BggApiClient bggApiClient;
    @Mock private StringRedisTemplate redis;
    @Mock private ValueOperations<String, String> valueOps;
    @Mock private PlatformTransactionManager transactionManager;

    private GameHydrationService service;

    @BeforeEach
    void setUp() {
        when(redis.opsForValue()).thenReturn(valueOps);
        when(valueOps.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(true);
        when(redis.hasKey(anyString())).thenReturn(false);
        // No sleeping in tests
        service = new GameHydrationService(gameRepository, gameDetailRepository, bggApiClient, redis,
                transactionManager, 0, 0, 168);
    }

    private static Game game(long bggId) {
        Game g = new Game();
        g.setId(UUID.randomUUID());
        g.setBggId(bggId);
        g.setNameEn("Game " + bggId);
        return g;
    }

    @Test
    @Timeout(5)
    void bulkRunTerminatesWhenBggReturnsNothingEvenIfSameGamesKeepComingBack() {
        // Worst case: the repository keeps returning the same unhydrated batch forever
        List<Game> batch = List.of(game(1), game(2), game(3));
        when(gameRepository.findHydrationCandidates(any(Instant.class), any(Pageable.class))).thenReturn(batch);
        when(bggApiClient.getDetails(anyList())).thenReturn(List.of());

        int hydrated = service.runBulkHydration();

        assertThat(hydrated).isZero();
        verify(bggApiClient, times(GameHydrationService.MAX_CONSECUTIVE_EMPTY_BATCHES)).getDetails(anyList());
        verify(gameRepository, times(GameHydrationService.MAX_CONSECUTIVE_EMPTY_BATCHES))
                .markHydrationAttempted(anyCollection(), any(Instant.class));
        verify(redis).delete(GameHydrationService.RUN_LOCK_KEY);
    }

    @Test
    @Timeout(5)
    void bulkRunTerminatesAfterConsecutiveBggFailures() {
        when(gameRepository.findHydrationCandidates(any(Instant.class), any(Pageable.class)))
                .thenReturn(List.of(game(1)));
        when(bggApiClient.getDetails(anyList()))
                .thenThrow(new BggApiClient.BggUnavailableException("circuit open"));

        int hydrated = service.runBulkHydration();

        assertThat(hydrated).isZero();
        verify(bggApiClient, times(GameHydrationService.MAX_CONSECUTIVE_FAILURES)).getDetails(anyList());
        // Failed batches are NOT marked attempted (they will be retried on the next run)
        verify(gameRepository, never()).markHydrationAttempted(anyCollection(), any(Instant.class));
    }

    @Test
    @Timeout(5)
    void bulkRunStopsWhenNoCandidatesRemain() {
        when(gameRepository.findHydrationCandidates(any(Instant.class), any(Pageable.class)))
                .thenReturn(List.of());

        assertThat(service.runBulkHydration()).isZero();
        verify(bggApiClient, never()).getDetails(anyList());
    }

    @Test
    void bulkRunSkippedWhenAnotherRunHoldsTheLock() {
        when(valueOps.setIfAbsent(eq(GameHydrationService.RUN_LOCK_KEY), anyString(), any(Duration.class)))
                .thenReturn(false);

        assertThat(service.runBulkHydration()).isZero();
        verify(gameRepository, never()).findHydrationCandidates(any(Instant.class), any(Pageable.class));
        verify(redis, never()).delete(GameHydrationService.RUN_LOCK_KEY);
    }

    @Test
    void syncHydrationSwallowsBggOutage() {
        when(bggApiClient.getDetails(anyList()))
                .thenThrow(new BggApiClient.BggUnavailableException("down"));

        assertThat(service.hydrateImageSync(game(42))).isFalse();
        verify(bggApiClient, atMost(1)).getDetails(anyList());
    }
}
