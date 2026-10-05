package com.meeplehearth.notification.dto;

import com.meeplehearth.notification.entity.Notification;
import jakarta.validation.constraints.NotNull;

/** One row of {@code GET/PUT /notifications/preferences}: {@code {type, inAppEnabled, pushEnabled}}. */
public record NotificationPreferenceDto(
        @NotNull Notification.NotificationType type,
        @NotNull Boolean inAppEnabled,
        @NotNull Boolean pushEnabled
) {
}
