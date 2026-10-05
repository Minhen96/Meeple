package com.meeplehearth.ai.service;

import com.meeplehearth.ai.client.SafePdfDownloader;
import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.game.entity.Game;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.core.task.TaskExecutor;
import org.springframework.core.task.TaskRejectedException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import software.amazon.awssdk.services.s3.S3Client;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class RulebookRetryAndRejectionTest {

    private final GameRulebookRepository rulebookRepository = mock(GameRulebookRepository.class);
    private final ApplicationEventPublisher eventPublisher = mock(ApplicationEventPublisher.class);
    private final RulebookQueueService queueService = new RulebookQueueService(rulebookRepository,
            mock(PdfValidationService.class), mock(S3Client.class), new AppProperties(), mock(AiRateLimiter.class),
            eventPublisher, mock(PlatformTransactionManager.class));

    private GameRulebook rulebook(String status, Instant reviewedAt) {
        Game game = new Game();
        game.setId(UUID.randomUUID());
        game.setNameEn("Catan");
        GameRulebook rulebook = new GameRulebook();
        rulebook.setId(UUID.randomUUID());
        rulebook.setGame(game);
        rulebook.setStatus(status);
        rulebook.setReviewedAt(reviewedAt);
        when(rulebookRepository.findByIdWithGame(rulebook.getId())).thenReturn(Optional.of(rulebook));
        return rulebook;
    }

    @Test
    void failedAndStalledRulebooksCanBeRetried() {
        for (GameRulebook rulebook : new GameRulebook[]{
                rulebook("failed", Instant.now().minus(Duration.ofDays(1))),
                rulebook("ingesting", Instant.now().minus(Duration.ofHours(2)))}) {
            queueService.retry(rulebook.getId(), null);

            assertThat(rulebook.getStatus()).isEqualTo("ingesting");
            assertThat(rulebook.getReviewedAt()).isAfter(Instant.now().minus(Duration.ofMinutes(1)));
            verify(eventPublisher).publishEvent(new RulebookIngestionRequestedEvent(rulebook.getId()));
        }
    }

    @Test
    void activeOrApprovedRulebooksCannotBeRetried() {
        for (GameRulebook rulebook : new GameRulebook[]{
                rulebook("ingesting", Instant.now().minus(Duration.ofMinutes(5))),
                rulebook("approved", null),
                rulebook("pending_review", null)}) {
            assertThatThrownBy(() -> queueService.retry(rulebook.getId(), null))
                    .isInstanceOf(ApiException.class);
        }
        verify(eventPublisher, never()).publishEvent(any(Object.class));
    }

    @Test
    void executorRejectionMarksRulebookFailed() {
        RulebookChunkWriter chunkWriter = mock(RulebookChunkWriter.class);
        TaskExecutor executor = mock(TaskExecutor.class);
        doThrow(new TaskRejectedException("full")).when(executor).execute(any());
        RulebookIngestionService service = new RulebookIngestionService(rulebookRepository, chunkWriter,
                mock(EmbeddingService.class), mock(HowToPlayExtractionService.class), mock(SafePdfDownloader.class),
                mock(S3Client.class), new AppProperties(), mock(StringRedisTemplate.class), executor);
        UUID id = UUID.randomUUID();

        service.onIngestionRequested(new RulebookIngestionRequestedEvent(id));

        verify(chunkWriter).markFailed(id);
    }
}
