package com.meeplehearth.notification.service;

import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.notification.dto.NotificationResponse;
import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.repository.NotificationRepository;
import com.meeplehearth.user.entity.User;
import com.meeplehearth.user.repository.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final WebSocketNotificationService webSocketNotificationService;

    public NotificationService(NotificationRepository notificationRepository,
                                UserRepository userRepository,
                                WebSocketNotificationService webSocketNotificationService) {
        this.notificationRepository = notificationRepository;
        this.userRepository = userRepository;
        this.webSocketNotificationService = webSocketNotificationService;
    }

    /**
     * Persist a notification and push it to the recipient's WebSocket topic.
     */
    @Transactional
    public void send(UUID recipientId, Notification.NotificationType type,
                     UUID actorId, UUID referenceId, String referenceType) {
        User recipient = userRepository.getReferenceById(recipientId);

        Notification n = new Notification();
        n.setRecipient(recipient);
        n.setType(type);
        n.setActorId(actorId);
        n.setReferenceId(referenceId);
        n.setReferenceType(referenceType);

        Notification saved = notificationRepository.save(n);
        webSocketNotificationService.push(recipientId, NotificationResponse.from(saved));
    }

    public PageResponse<NotificationResponse> getNotifications(UUID userId, int page, int size) {
        return PageResponse.of(
                notificationRepository.findByRecipientIdOrderByCreatedAtDesc(userId, PageRequest.of(page, size)),
                NotificationResponse::from
        );
    }

    public int getUnreadCount(UUID userId) {
        return notificationRepository.countByRecipientIdAndReadFalse(userId);
    }

    @Transactional
    public void markAllRead(UUID userId) {
        notificationRepository.markAllReadForUser(userId);
    }
}
