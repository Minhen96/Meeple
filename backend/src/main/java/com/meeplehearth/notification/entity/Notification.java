package com.meeplehearth.notification.entity;

import com.meeplehearth.user.entity.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * One notification for one recipient. {@code actorId}/{@code referenceId}/{@code referenceType}
 * say who did what to which object; {@code title}, {@code body} and {@code data} (always holding
 * {@code data.path}, the deep link) are rendered server-side by
 * {@link com.meeplehearth.notification.service.NotificationMessageFactory} when the row is created
 * (docs/GAP_ANALYSIS.md C7). Rows written before V36 have no title/body/data; readers fall back
 * to the factory's defaults.
 */
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

    @Column(length = 255)
    private String title;

    @Column(columnDefinition = "text")
    private String body;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private Map<String, Object> data = new LinkedHashMap<>();

    @Column(nullable = false)
    private boolean read = false;

    @Column(name = "is_pushed", nullable = false)
    private boolean pushed = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "deleted_at")
    private Instant deletedAt;

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
