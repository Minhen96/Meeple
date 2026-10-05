package com.meeplehearth.user.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "users")
@Getter
@Setter
public class User {

    @Id
    @UuidGenerator
    @Column(updatable = false, nullable = false)
    private UUID id;

    @Column(nullable = false, unique = true, length = 30)
    private String username;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash")
    private String passwordHash;

    @Column(name = "display_name", length = 50)
    private String displayName;

    @Column(name = "avatar_url", length = 500)
    private String avatarUrl;

    @Column(name = "bio", length = 300)
    private String bio;

    @Column(name = "location", length = 100)
    private String location;

    @Column(name = "google_id", unique = true, length = 255)
    private String googleId;

    @Column(name = "email_verified", nullable = false)
    private boolean emailVerified = false;

    @Column(name = "onboarding_completed", nullable = false)
    private boolean onboardingCompleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    @Column(name = "role", nullable = false, length = 20)
    private String role = "USER";

    @Column(name = "deleted_at")
    private Instant deletedAt;

    /**
     * Embedded in every access token. Incrementing it invalidates all access tokens
     * issued before the increment (password reset, session revocation).
     */
    @Column(name = "token_version", nullable = false)
    private int tokenVersion = 0;

    /** BoardGameGeek username used for collection import. */
    @Column(name = "bgg_username", length = 50)
    private String bggUsername;

    /** Verified badge (set by admins); unrelated to {@link #emailVerified}. */
    @Column(name = "is_verified", nullable = false)
    private boolean verified = false;

    /** Last username change; enforces the change cooldown. Null if never changed. */
    @Column(name = "username_changed_at")
    private Instant usernameChangedAt;

    /** UI and notification language: "en" or "zh-CN". */
    @Column(name = "preferred_language", nullable = false, length = 10)
    private String preferredLanguage = "en";

    /** IANA time zone (for example "Asia/Kuala_Lumpur"); null means unknown, treat as UTC. */
    @Column(name = "timezone", length = 50)
    private String timezone;

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
