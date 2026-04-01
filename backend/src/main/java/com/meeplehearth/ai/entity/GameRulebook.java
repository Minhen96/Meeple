package com.meeplehearth.ai.entity;

import com.meeplehearth.game.entity.Game;
import com.meeplehearth.user.entity.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "game_rulebooks")
@Getter
@Setter
public class GameRulebook {

    @Id
    @UuidGenerator
    @Column(updatable = false, nullable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "game_id", nullable = false)
    private Game game;

    /** rule_book_org | onj | user | admin */
    @Column(nullable = false, length = 20)
    private String source;

    /** ingesting | approved | pending_review | rejected */
    @Column(nullable = false, length = 20)
    private String status = "pending_review";

    /** CDN URL for auto-fetched sources (rule_book_org / onj) */
    @Column(name = "pdf_url")
    private String pdfUrl;

    /** R2 object key for user/admin uploads */
    @Column(name = "storage_key")
    private String storageKey;

    /** R2 public URL for user/admin uploads */
    @Column(name = "public_url")
    private String publicUrl;

    @Column(name = "reject_reason")
    private String rejectReason;

    /** Position in the pending queue for this game (user uploads only) */
    @Column(name = "queue_position")
    private Integer queuePosition;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "uploaded_by")
    private User uploadedBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewed_by")
    private User reviewedBy;

    @Column(name = "reviewed_at")
    private Instant reviewedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();
}
