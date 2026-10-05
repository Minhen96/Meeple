package com.meeplehearth.event.entity;

import com.meeplehearth.user.entity.User;
import com.meeplehearth.game.entity.Game;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "events")
@Getter
@Setter
public class Event {

    @Id
    @UuidGenerator
    @Column(updatable = false, nullable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "host_id", nullable = false)
    private User host;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "game_id")
    private Game game;

    @Column(nullable = false, length = 255)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "location", length = 255)
    private String location;

    /** Area or venue name shown on PUBLIC events to viewers who have not joined (V41). */
    @Column(name = "location_display", length = 100)
    private String locationDisplay;

    @Column(name = "location_lat", precision = 9, scale = 6)
    private java.math.BigDecimal locationLat;

    @Column(name = "location_lng", precision = 9, scale = 6)
    private java.math.BigDecimal locationLng;

    @Column(name = "scheduled_at", nullable = false)
    private Instant scheduledAt;

    @Column(name = "max_participants", nullable = false)
    private int maxParticipants = 8;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Visibility visibility = Visibility.INVITE_ONLY;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private EventStatus status = EventStatus.OPEN;

    /** Set once the 24h reminder went out, or at creation when the event starts within 24h (V41). */
    @Column(name = "reminder_sent", nullable = false)
    private boolean reminderSent = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    @Column(name = "deleted_at")
    private Instant deletedAt;

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }

    public enum Visibility { INVITE_ONLY, FRIENDS, PUBLIC }
    public enum EventStatus { OPEN, FULL, COMPLETED, CANCELLED }
}
