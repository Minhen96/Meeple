package com.meeplehearth.notification;

import com.meeplehearth.config.WebSocketConfig;
import com.meeplehearth.notification.dto.NotificationResponse;
import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.repository.NotificationRepository;
import com.meeplehearth.notification.service.NotificationService;
import com.meeplehearth.notification.service.WebSocketNotificationService;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class NotificationServiceTest {

    @Test
    void sendPersistsThenPushesTheSavedNotificationToTheRecipient() {
        NotificationRepository repository = mock(NotificationRepository.class);
        UserRepository userRepository = mock(UserRepository.class);
        WebSocketNotificationService push = mock(WebSocketNotificationService.class);
        UUID recipientId = UUID.randomUUID();
        UUID actorId = UUID.randomUUID();
        UUID referenceId = UUID.randomUUID();
        User recipient = new User();
        recipient.setId(recipientId);
        when(userRepository.getReferenceById(recipientId)).thenReturn(recipient);
        UUID savedId = UUID.randomUUID();
        when(repository.save(any(Notification.class))).thenAnswer(inv -> {
            Notification n = inv.getArgument(0);
            n.setId(savedId);
            return n;
        });

        new NotificationService(repository, userRepository, push)
                .send(recipientId, Notification.NotificationType.RULE_NOTE_APPROVED, actorId, referenceId, "RULE_NOTE");

        ArgumentCaptor<Notification> saved = ArgumentCaptor.forClass(Notification.class);
        verify(repository).save(saved.capture());
        assertThat(saved.getValue().getRecipient()).isSameAs(recipient);
        assertThat(saved.getValue().isRead()).isFalse();
        ArgumentCaptor<NotificationResponse> pushed = ArgumentCaptor.forClass(NotificationResponse.class);
        verify(push).push(org.mockito.ArgumentMatchers.eq(recipientId), pushed.capture());
        assertThat(pushed.getValue().id()).isEqualTo(savedId);
        assertThat(pushed.getValue().type()).isEqualTo("RULE_NOTE_APPROVED");
        assertThat(pushed.getValue().actorId()).isEqualTo(actorId);
        assertThat(pushed.getValue().referenceId()).isEqualTo(referenceId);
        assertThat(pushed.getValue().referenceType()).isEqualTo("RULE_NOTE");
    }

    @Test
    void pushGoesToTheRecipientsOwnUserQueue() {
        SimpMessagingTemplate template = mock(SimpMessagingTemplate.class);
        UUID recipientId = UUID.randomUUID();
        NotificationResponse payload = new NotificationResponse(UUID.randomUUID(), "POST_COMMENT", null, null, null,
                false, Instant.now());

        new WebSocketNotificationService(template).push(recipientId, payload);

        verify(template).convertAndSendToUser(recipientId.toString(), WebSocketConfig.USER_NOTIFICATION_QUEUE, payload);
        assertThat(WebSocketConfig.USER_NOTIFICATION_QUEUE).isEqualTo("/queue/notifications");
    }
}
