package com.meeplehearth.notification.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalTime;
import java.util.UUID;

/**
 * Per-user notification settings: quiet hours. {@code timezone} is the IANA zone the quiet hours
 * are evaluated in; when null, {@code users.timezone} and then UTC are used.
 */
@Entity
@Table(name = "notification_settings")
@Getter
@Setter
public class NotificationSettings {

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "quiet_hours_enabled", nullable = false)
    private boolean quietHoursEnabled = false;

    @Column(name = "quiet_hours_start")
    private LocalTime quietHoursStart;

    @Column(name = "quiet_hours_end")
    private LocalTime quietHoursEnd;

    @Column(length = 50)
    private String timezone;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    public NotificationSettings() {
    }

    public NotificationSettings(UUID userId) {
        this.userId = userId;
    }
}
