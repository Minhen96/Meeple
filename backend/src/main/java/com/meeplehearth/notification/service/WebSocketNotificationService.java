package com.meeplehearth.notification.service;

import com.meeplehearth.config.WebSocketConfig;
import com.meeplehearth.notification.dto.NotificationResponse;
import com.meeplehearth.notification.dto.NotificationWsPayload;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class WebSocketNotificationService {

    private static final Logger log = LoggerFactory.getLogger(WebSocketNotificationService.class);

    private final SimpMessagingTemplate messagingTemplate;

    public WebSocketNotificationService(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }

    /**
     * Delivers {@code {notification, unreadCount}} to the recipient's own sessions only. The STOMP
     * principal name is the user id, and clients receive it by subscribing to
     * {@code /user/queue/notifications}. A delivery failure is logged, never thrown: the
     * notification is already stored and the client catches up on its next fetch.
     */
    public void push(UUID recipientId, NotificationResponse notification, long unreadCount) {
        try {
            messagingTemplate.convertAndSendToUser(recipientId.toString(), WebSocketConfig.USER_NOTIFICATION_QUEUE,
                    new NotificationWsPayload(notification, unreadCount));
        } catch (MessagingException e) {
            log.warn("WebSocket delivery of notification {} failed: {}", notification.id(), e.getMessage());
        }
    }
}
