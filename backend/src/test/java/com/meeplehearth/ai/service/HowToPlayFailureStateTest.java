package com.meeplehearth.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.meeplehearth.ai.controller.HowToPlayController;
import com.meeplehearth.ai.repository.GameRuleNoteRepository;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.game.repository.GameRepository;
import com.meeplehearth.ai.dto.HowToPlayResponse;
import com.meeplehearth.ai.repository.GameHowToPlayRepository;
import com.meeplehearth.ai.repository.RuleChunkRepository;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.game.repository.GameDetailRepository;
import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class HowToPlayFailureStateTest {

    private final GameHowToPlayRepository howToPlayRepository = mock(GameHowToPlayRepository.class);
    private final RuleChunkRepository ruleChunkRepository = mock(RuleChunkRepository.class);
    private final AiCompletionService completionService = mock(AiCompletionService.class);
    private final StringRedisTemplate redisTemplate = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> values = mock(ValueOperations.class);
    private final SimpMessagingTemplate messagingTemplate = mock(SimpMessagingTemplate.class);
    private final HowToPlayExtractionService service = new HowToPlayExtractionService(howToPlayRepository,
            ruleChunkRepository, completionService, redisTemplate, new ObjectMapper(), messagingTemplate,
            mock(GameDetailRepository.class));

    private final UUID gameId = UUID.randomUUID();
    private final Game game = new Game();

    HowToPlayFailureStateTest() {
        game.setId(gameId);
        game.setNameEn("Catan");
        when(redisTemplate.opsForValue()).thenReturn(values);
    }

    @Test
    void failedGenerationRecordsUserSafeFailureAndPublishesTerminalMessage() {
        when(completionService.complete(any(), anyInt(), anyDouble()))
                .thenThrow(new RuntimeException("Completion failed: API returned 500 sk-secret"));

        service.extractAsyncWithLockHeld(gameId, game);

        String failedKey = "howtoplay:failed:" + gameId;
        InOrder order = inOrder(redisTemplate, values, messagingTemplate);
        order.verify(redisTemplate).delete(failedKey);
        order.verify(values).set(failedKey, HowToPlayExtractionService.GENERIC_FAILURE_MESSAGE,
                HowToPlayExtractionService.FAILED_TTL);
        order.verify(messagingTemplate).convertAndSend("/topic/how-to-play/" + gameId, (Object) Map.of(
                "status", "failed", "progress", 0,
                "errorMessage", HowToPlayExtractionService.GENERIC_FAILURE_MESSAGE));
        // The lock is released only after the failure is visible to GET
        order.verify(redisTemplate).delete("lock:how-to-play:" + gameId);
    }

    @Test
    void successClearsPreviousFailure() {
        when(completionService.complete(any(), anyInt(), anyDouble())).thenReturn("{\"overview\":\"x\"}");
        when(howToPlayRepository.findByGame_Id(gameId)).thenReturn(Optional.empty());

        service.extractAsyncWithLockHeld(gameId, game);

        verify(values, never()).set(eq("howtoplay:failed:" + gameId), anyString(), any());
        verify(messagingTemplate).convertAndSend("/topic/how-to-play/" + gameId,
                (Object) Map.of("status", "ready", "progress", 100));
    }

    @Test
    void openCircuitGetsAiUnavailableMessage() {
        CallNotPermittedException open = CallNotPermittedException.createCallNotPermittedException(
                CircuitBreaker.ofDefaults("openai"));
        assertThat(HowToPlayExtractionService.failureMessage(new RuntimeException(open)))
                .isEqualTo(HowToPlayExtractionService.AI_UNAVAILABLE_MESSAGE);
        assertThat(HowToPlayExtractionService.failureMessage(new IllegalStateException("db down")))
                .isEqualTo(HowToPlayExtractionService.GENERIC_FAILURE_MESSAGE);
    }

    @Test
    void getReportsFailedOnlyWhenNothingIsRunning() {
        HowToPlayExtractionService extraction = mock(HowToPlayExtractionService.class);
        HowToPlayController controller = new HowToPlayController(howToPlayRepository, extraction,
                mock(GameRepository.class), mock(GameRulebookRepository.class), mock(GameRuleNoteRepository.class),
                mock(AiRateLimiter.class));
        when(howToPlayRepository.findByGame_Id(gameId)).thenReturn(Optional.empty());

        when(extraction.isGenerating(gameId)).thenReturn(false);
        when(extraction.getFailureMessage(gameId)).thenReturn(Optional.of("We couldn't generate it."));
        HowToPlayResponse failed = controller.getHowToPlay(gameId).getBody();
        assertThat(failed.status()).isEqualTo("failed");
        assertThat(failed.errorMessage()).isEqualTo("We couldn't generate it.");

        when(extraction.isGenerating(gameId)).thenReturn(true);
        when(extraction.getProgress(gameId)).thenReturn(15);
        HowToPlayResponse generating = controller.getHowToPlay(gameId).getBody();
        assertThat(generating.status()).isEqualTo("generating");
        assertThat(generating.errorMessage()).isNull();

        when(extraction.isGenerating(gameId)).thenReturn(false);
        when(extraction.getFailureMessage(gameId)).thenReturn(Optional.empty());
        assertThat(controller.getHowToPlay(gameId).getBody().status()).isEqualTo("not_generated");
    }
}
