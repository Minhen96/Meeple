package com.meeplehearth.notification.service;

import com.meeplehearth.config.WebSocketConfig;
import com.meeplehearth.notification.dto.NotificationResponse;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class WebSocketNotificationService {

    private final SimpMessagingTemplate messagingTemplate;

    public WebSocketNotificationService(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }

    /**
     * Delivers to the recipient's own sessions only. The STOMP principal name is the user id,
     * and clients receive it by subscribing to {@code /user/queue/notifications}.
     */
    public void push(UUID recipientId, NotificationResponse notification) {
        messagingTemplate.convertAndSendToUser(
                recipientId.toString(), WebSocketConfig.USER_NOTIFICATION_QUEUE, notification);
    }
}
