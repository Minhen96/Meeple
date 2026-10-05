package com.meeplehearth.notification;

import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.config.WebSocketConfig;
import com.meeplehearth.notification.dto.NotificationResponse;
import com.meeplehearth.notification.dto.NotificationWsPayload;
import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.presence.WebSocketPresenceListener;
import com.meeplehearth.notification.repository.NotificationRepository;
import com.meeplehearth.notification.service.FcmService;
import com.meeplehearth.notification.service.NotificationLookups;
import com.meeplehearth.notification.service.NotificationMessageFactory;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.notification.service.QuietHours;
import com.meeplehearth.notification.service.UnreadCounter;
import com.meeplehearth.notification.service.WebSocketNotificationService;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.time.Instant;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** The send pipeline's decisions with every collaborator mocked (no transaction: delivery runs inline). */
class NotificationServiceTest {

    private final NotificationRepository repository = mock(NotificationRepository.class);
    private final UserRepository userRepository = mock(UserRepository.class);
    private final WebSocketNotificationService ws = mock(WebSocketNotificationService.class);
    private final NotificationLookups lookups = mock(NotificationLookups.class);
    private final UnreadCounter counter = mock(UnreadCounter.class);
    private final WebSocketPresenceListener presence = mock(WebSocketPresenceListener.class);
    private final FcmService fcm = mock(FcmService.class);
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);

    private final UUID recipientId = UUID.randomUUID();
    private final UUID actorId = UUID.randomUUID();
    private final UUID referenceId = UUID.randomUUID();
    private final UUID savedId = UUID.randomUUID();
    private NotificationService service;

    @BeforeEach
    void setUp() {
        service = new NotificationService(repository, userRepository, ws, lookups, counter, presence, fcm, jdbc);
        User recipient = new User();
        recipient.setId(recipientId);
        when(userRepository.getReferenceById(recipientId)).thenReturn(recipient);
        when(repository.save(any(Notification.class))).thenAnswer(inv -> {
            Notification n = inv.getArgument(0);
            n.setId(savedId);
            return n;
        });
        when(lookups.context(anyString(), any(), any(), any(), any(), any()))
                .thenReturn(new NotificationMessageFactory.Context("en", "Ana", null, "Catan", null, null, null));
        when(counter.increment(recipientId)).thenReturn(3L);
        when(fcm.isEnabled()).thenReturn(true);
    }

    private void recipient(boolean inApp, boolean push, QuietHours quiet) {
        when(lookups.recipient(eq(recipientId), any(), any()))
                .thenReturn(new NotificationLookups.Recipient("en", false, inApp, push, quiet, false));
    }

    @Test
    void savesRenderedRowThenPushesFrameAndFcmWhenOffline() {
        recipient(true, true, QuietHours.NONE);

        service.send(recipientId, Notification.NotificationType.RULE_NOTE_APPROVED, actorId, referenceId, "RULE_NOTE");

        ArgumentCaptor<Notification> saved = ArgumentCaptor.forClass(Notification.class);
        verify(repository).save(saved.capture());
        assertThat(saved.getValue().isRead()).isFalse();
        assertThat(saved.getValue().getTitle()).isEqualTo("Rule Note Approved");
        assertThat(saved.getValue().getBody()).isEqualTo("Your rule note for Catan was approved");
        ArgumentCaptor<NotificationResponse> pushed = ArgumentCaptor.forClass(NotificationResponse.class);
        verify(ws).push(eq(recipientId), pushed.capture(), eq(3L));
        assertThat(pushed.getValue().id()).isEqualTo(savedId);
        assertThat(pushed.getValue().referenceType()).isEqualTo("RULE_NOTE");
        ArgumentCaptor<FcmService.PushMessage> push = ArgumentCaptor.forClass(FcmService.PushMessage.class);
        verify(fcm).sendAsync(push.capture());
        assertThat(push.getValue().unreadCount()).isEqualTo(3L);
        assertThat(push.getValue().data()).containsEntry("path", "/library");
    }

    @Test
    void onlineOrPushDisabledSkipsFcm() {
        recipient(true, true, QuietHours.NONE);
        when(presence.isOnline(recipientId)).thenReturn(true);
        service.send(recipientId, Notification.NotificationType.MATCH_FOUND, null, referenceId, "MATCH_GROUP");
        verify(fcm, never()).sendAsync(any());

        recipient(true, false, QuietHours.NONE);
        when(presence.isOnline(recipientId)).thenReturn(false);
        service.send(recipientId, Notification.NotificationType.MATCH_FOUND, null, referenceId, "MATCH_GROUP");
        verify(fcm, never()).sendAsync(any());
    }

    @Test
    void inAppDisabledSavesAsReadWithoutFrameOrCount() {
        recipient(false, true, QuietHours.NONE);
        when(counter.get(recipientId)).thenReturn(0L);

        service.send(recipientId, Notification.NotificationType.POST_TAG, actorId, referenceId, "POST", Map.of());

        ArgumentCaptor<Notification> saved = ArgumentCaptor.forClass(Notification.class);
        verify(repository).save(saved.capture());
        assertThat(saved.getValue().isRead()).isTrue();
        verify(counter, never()).increment(any());
        verify(ws, never()).push(any(), any(), anyLong());
        verify(fcm).sendAsync(any());
    }

    @Test
    void quietHoursCountButDeliverNothing() {
        LocalTime now = LocalTime.now(QuietHours.UTC);
        recipient(true, true, new QuietHours(true, now.minusHours(1), now.plusHours(1), QuietHours.UTC));

        service.send(recipientId, Notification.NotificationType.POST_TAG, actorId, referenceId, "POST");

        verify(counter).increment(recipientId);
        verify(ws, never()).push(any(), any(), anyLong());
        verify(fcm, never()).sendAsync(any());
    }

    @Test
    void deliveryFailureNeverReachesTheCaller() {
        recipient(true, true, QuietHours.NONE);
        when(counter.increment(recipientId)).thenThrow(new IllegalStateException("redis down"));

        service.send(recipientId, Notification.NotificationType.POST_TAG, actorId, referenceId, "POST");

        verify(repository).save(any(Notification.class));
    }

    @Test
    void markReadAndDeleteOfMissingRowsAre404() {
        UUID id = UUID.randomUUID();
        when(repository.findOwned(id, recipientId)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.markRead(recipientId, id)).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> service.delete(recipientId, id)).isInstanceOf(ApiException.class);
    }

    @Test
    void readAllResetsTheCounter() {
        service.markAllRead(recipientId);
        verify(repository).markAllReadForUser(recipientId);
        verify(counter).reset(recipientId);
    }

    @Test
    void listWithoutRowsHasNoCursor() {
        when(repository.findFirstPage(recipientId, 31)).thenReturn(List.of());
        assertThat(service.list(recipientId, null, null).nextCursor()).isNull();
        when(repository.findFirstPage(recipientId, 51)).thenReturn(List.of());
        assertThat(service.list(recipientId, " ", 500).hasMore()).isFalse();
    }

    @Test
    void pushGoesToTheRecipientsOwnUserQueueAndSwallowsBrokerErrors() {
        SimpMessagingTemplate template = mock(SimpMessagingTemplate.class);
        NotificationResponse payload = new NotificationResponse(UUID.randomUUID(), "POST_COMMENT", null, null, null,
                "New Comment", null, Map.of("path", "/"), false, Instant.now());

        new WebSocketNotificationService(template).push(recipientId, payload, 4);

        verify(template).convertAndSendToUser(recipientId.toString(), WebSocketConfig.USER_NOTIFICATION_QUEUE,
                new NotificationWsPayload(payload, 4));
        doThrow(new MessageDeliveryException("closed")).when(template)
                .convertAndSendToUser(anyString(), anyString(), any(Object.class));
        new WebSocketNotificationService(template).push(recipientId, payload, 5);
    }
}
