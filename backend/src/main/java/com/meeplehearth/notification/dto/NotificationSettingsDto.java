package com.meeplehearth.notification.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * {@code GET/PUT /notifications/settings}:
 * {@code {quietHoursEnabled, quietHoursStart: "HH:mm"|null, quietHoursEnd, timezone}}.
 * {@code timezone} is an IANA zone id (e.g. {@code Asia/Shanghai}); in a PUT, null keeps the
 * account's timezone (falling back to UTC).
 */
public record NotificationSettingsDto(
        @NotNull Boolean quietHoursEnabled,
        @Pattern(regexp = HH_MM, message = "quietHoursStart must be HH:mm") String quietHoursStart,
        @Pattern(regexp = HH_MM, message = "quietHoursEnd must be HH:mm") String quietHoursEnd,
        @Size(max = 50) String timezone
) {
    public static final String HH_MM = "^([01]\\d|2[0-3]):[0-5]\\d$";
}
