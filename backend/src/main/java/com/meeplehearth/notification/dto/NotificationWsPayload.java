package com.meeplehearth.notification.dto;

/**
 * Frame on {@code /user/queue/notifications} (docs/GAP_ANALYSIS.md section 6.3):
 * {@code {notification: NotificationDto, unreadCount}}.
 */
public record NotificationWsPayload(NotificationResponse notification, long unreadCount) {
}
