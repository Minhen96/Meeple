package com.meeplehearth.notification.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

/**
 * A device's FCM registration token (table {@code user_fcm_tokens}, V1). One user can have several
 * devices; {@code (user_id, fcm_token)} is unique. Tokens are secrets of the device: never log them.
 */
@Entity
@Table(name = "user_fcm_tokens")
@Getter
@Setter
public class UserFcmToken {

    @Id
    @UuidGenerator
    @Column(updatable = false, nullable = false)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "fcm_token", nullable = false, length = 255)
    private String token;

    @Column(name = "device_info", length = 255)
    private String deviceInfo;

    /** {@code web} | {@code ios} | {@code android} (lowercase, V1 CHECK constraint). */
    @Column(length = 20)
    private String platform;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();
}
