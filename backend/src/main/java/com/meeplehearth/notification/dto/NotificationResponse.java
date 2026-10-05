package com.meeplehearth.notification.dto;

import com.meeplehearth.notification.entity.Notification;
import com.meeplehearth.notification.service.NotificationMessageFactory;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * {@code NotificationDto} of docs/GAP_ANALYSIS.md section 6.1:
 * {@code {id, type, actor, referenceId, referenceType, title, body, data: {path, ...}, read, createdAt}}.
 * Sent by the REST list and inside the WebSocket payload.
 */
public record NotificationResponse(
        UUID id,
        String type,
        ActorSummary actor,
        UUID referenceId,
        String referenceType,
        String title,
        String body,
        Map<String, Object> data,
        boolean read,
        Instant createdAt
) {

    /**
     * Rows created before title/body/data existed (pre-V36) get the factory's default title and
     * path, computed without any lookup.
     */
    public static NotificationResponse from(Notification n, ActorSummary actor) {
        Map<String, Object> data = n.getData() == null ? new LinkedHashMap<>() : new LinkedHashMap<>(n.getData());
        if (!(data.get(NotificationMessageFactory.PATH) instanceof String)) {
            data.put(NotificationMessageFactory.PATH, NotificationMessageFactory.defaultPath(
                    n.getType(), n.getActorId(), n.getReferenceId(), n.getReferenceType()));
        }
        String title = n.getTitle() != null ? n.getTitle() : NotificationMessageFactory.defaultTitle(n.getType());
        return new NotificationResponse(
                n.getId(),
                n.getType().name(),
                actor,
                n.getReferenceId(),
                n.getReferenceType(),
                title,
                n.getBody(),
                data,
                n.isRead(),
                n.getCreatedAt()
        );
    }
}
