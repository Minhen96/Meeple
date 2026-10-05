package com.meeplehearth.notification.entity;

import com.meeplehearth.user.entity.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "notifications")
@Getter
@Setter
public class Notification {

    @Id
    @UuidGenerator
    @Column(updatable = false, nullable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recipient_id", nullable = false)
    private User recipient;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private NotificationType type;

    @Column(name = "actor_id")
    private UUID actorId;

    @Column(name = "reference_id")
    private UUID referenceId;

    @Column(name = "reference_type", length = 30)
    private String referenceType;

    @Column(nullable = false)
    private boolean read = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    /**
     * Complete list shared by every package (docs/GAP_ANALYSIS.md section 6.4). Stored as the
     * enum name in notifications.type (VARCHAR(40), no CHECK constraint).
     */
    public enum NotificationType {
        EVENT_INVITE, EVENT_RSVP, EVENT_LEAVE, EVENT_KICKED, EVENT_CANCELLED,
        EVENT_UPDATED, EVENT_REMINDER, EVENT_COMPLETED,
        MATCH_FOUND, MATCH_ACCEPTED,
        POST_LIKE, POST_COMMENT, COMMENT_MENTION, POST_TAG,
        FRIEND_REQUEST, FRIEND_ACCEPTED,
        RULE_NOTE_APPROVED, RULE_NOTE_REJECTED,
        RULEBOOK_APPROVED, RULEBOOK_REJECTED, RULEBOOK_UNDER_REVIEW,
        BGG_IMPORT_COMPLETED
    }
}
