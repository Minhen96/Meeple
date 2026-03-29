package com.meeplehearth.notification.service;

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

    public void push(UUID recipientId, NotificationResponse notification) {
        messagingTemplate.convertAndSend("/topic/notifications/" + recipientId, notification);
    }
}
