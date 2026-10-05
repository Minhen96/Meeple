package com.meeplehearth.notification.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * A user's delivery choice for one notification type. A missing row means both channels are
 * enabled (FEATURES_COMPLETE section 7.3, "default: all enabled").
 */
@Entity
@Table(name = "notification_preferences")
@IdClass(NotificationPreference.Key.class)
@Getter
@Setter
public class NotificationPreference {

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Id
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, updatable = false, length = 40)
    private Notification.NotificationType type;

    @Column(name = "in_app_enabled", nullable = false)
    private boolean inAppEnabled = true;

    @Column(name = "push_enabled", nullable = false)
    private boolean pushEnabled = true;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    public NotificationPreference() {
    }

    public NotificationPreference(UUID userId, Notification.NotificationType type) {
        this.userId = userId;
        this.type = type;
    }

    /** Composite primary key {@code (user_id, type)}. */
    public static class Key implements Serializable {
        private UUID userId;
        private Notification.NotificationType type;

        public Key() {
        }

        public Key(UUID userId, Notification.NotificationType type) {
            this.userId = userId;
            this.type = type;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key other)) return false;
            return Objects.equals(userId, other.userId) && type == other.type;
        }

        @Override
        public int hashCode() {
            return Objects.hash(userId, type);
        }
    }
}
