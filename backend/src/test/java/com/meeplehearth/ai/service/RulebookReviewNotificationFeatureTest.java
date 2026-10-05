package com.meeplehearth.ai.service;

import com.meeplehearth.ai.entity.GameRulebook;
import com.meeplehearth.ai.repository.GameRulebookRepository;
import com.meeplehearth.config.AppProperties;
import com.meeplehearth.game.entity.Game;
import com.meeplehearth.notification.entity.Notification.NotificationType;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.user.entity.User;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionStatus;
import org.springframework.transaction.support.SimpleTransactionStatus;
import software.amazon.awssdk.services.s3.S3Client;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** RULEBOOK_APPROVED / REJECTED / UNDER_REVIEW notifications to uploaders (AI_PLAN feature 3). */
class RulebookReviewNotificationFeatureTest {

    private final GameRulebookRepository repository = mock(GameRulebookRepository.class);
    private final ApplicationEventPublisher publisher = mock(ApplicationEventPublisher.class);
    private final RulebookQueueService queueService = new RulebookQueueService(repository,
            mock(PdfValidationService.class), mock(S3Client.class), new AppProperties(), mock(AiRateLimiter.class),
            publisher, mock(PlatformTransactionManager.class));

    private final Game game = game();
    private final User admin = user();

    private static Game game() {
        Game g = new Game();
        g.setId(UUID.randomUUID());
        g.setNameEn("Catan");
        return g;
    }

    private static User user() {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setUsername("u" + u.getId().toString().substring(0, 6));
        return u;
    }

    private GameRulebook pending(User uploader, int position) {
        GameRulebook r = new GameRulebook();
        r.setId(UUID.randomUUID());
        r.setGame(game);
        r.setSource(uploader == null ? "auto" : "user");
        r.setStatus("pending_review");
        r.setQueuePosition(position);
        r.setUploadedBy(uploader);
        return r;
    }

    private List<RulebookReviewedEvent> reviewedEvents() {
        ArgumentCaptor<Object> captor = ArgumentCaptor.forClass(Object.class);
        verify(publisher, atLeastOnce()).publishEvent(captor.capture());
        return captor.getAllValues().stream()
                .filter(RulebookReviewedEvent.class::isInstance).map(RulebookReviewedEvent.class::cast).toList();
    }

    @Test
    void approveNotifiesTheUploaderAndRejectedCompetitors() {
        User alice = user();
        User bob = user();
        GameRulebook approved = pending(alice, 0);
        GameRulebook other = pending(bob, 1);
        GameRulebook anonymous = pending(null, 2);
        when(repository.findByIdWithGame(approved.getId())).thenReturn(Optional.of(approved));
        when(repository.findByGame_IdAndStatusOrderByQueuePositionAsc(game.getId(), "pending_review"))
                .thenReturn(List.of(approved, other, anonymous));

        queueService.approve(approved.getId(), admin);

        assertThat(reviewedEvents()).containsExactlyInAnyOrder(
                new RulebookReviewedEvent(bob.getId(), NotificationType.RULEBOOK_REJECTED, game.getId(), admin.getId()),
                new RulebookReviewedEvent(alice.getId(), NotificationType.RULEBOOK_APPROVED, game.getId(), admin.getId()));
    }

    @Test
    void rejectNotifiesTheUploaderAndTheNextInLine() {
        User alice = user();
        User bob = user();
        User carol = user();
        GameRulebook rejected = pending(alice, 0);
        GameRulebook next = pending(bob, 1);
        GameRulebook later = pending(carol, 2);
        when(repository.findByIdWithGame(rejected.getId())).thenReturn(Optional.of(rejected));
        when(repository.findByGame_IdAndStatusOrderByQueuePositionAsc(game.getId(), "pending_review"))
                .thenReturn(List.of(next, later));

        queueService.reject(rejected.getId(), null, "Wrong game");

        assertThat(reviewedEvents()).containsExactly(
                new RulebookReviewedEvent(alice.getId(), NotificationType.RULEBOOK_REJECTED, game.getId(), null),
                new RulebookReviewedEvent(bob.getId(), NotificationType.RULEBOOK_UNDER_REVIEW, game.getId(), null));
        assertThat(next.getQueuePosition()).isZero();
        assertThat(later.getQueuePosition()).isEqualTo(1);
    }

    // -------------------------------------------------------------------------
    // Listener
    // -------------------------------------------------------------------------

    private RulebookNotificationListener listener(NotificationService notifications) {
        PlatformTransactionManager tm = mock(PlatformTransactionManager.class);
        TransactionStatus status = new SimpleTransactionStatus();
        when(tm.getTransaction(any())).thenReturn(status);
        return new RulebookNotificationListener(notifications, tm);
    }

    @Test
    void listenerSendsAGameReferencedNotification() {
        NotificationService notifications = mock(NotificationService.class);
        UUID uploader = UUID.randomUUID();
        UUID gameId = UUID.randomUUID();
        UUID reviewer = UUID.randomUUID();

        listener(notifications).onRulebookReviewed(
                new RulebookReviewedEvent(uploader, NotificationType.RULEBOOK_APPROVED, gameId, reviewer));

        verify(notifications).send(uploader, NotificationType.RULEBOOK_APPROVED, reviewer, gameId, "GAME");
    }

    @Test
    void listenerSkipsSelfReviewsAndSwallowsFailures() {
        NotificationService notifications = mock(NotificationService.class);
        UUID adminId = UUID.randomUUID();
        RulebookNotificationListener listener = listener(notifications);

        listener.onRulebookReviewed(new RulebookReviewedEvent(adminId, NotificationType.RULEBOOK_REJECTED,
                UUID.randomUUID(), adminId));
        listener.onRulebookReviewed(new RulebookReviewedEvent(null, NotificationType.RULEBOOK_REJECTED,
                UUID.randomUUID(), null));
        verify(notifications, never()).send(any(), any(), any(), any(), any());

        UUID uploader = UUID.randomUUID();
        doThrow(new IllegalStateException("db down")).when(notifications)
                .send(any(), any(), any(), any(), any());
        listener.onRulebookReviewed(new RulebookReviewedEvent(uploader, NotificationType.RULEBOOK_UNDER_REVIEW,
                UUID.randomUUID(), null)); // no exception escapes
    }
}
