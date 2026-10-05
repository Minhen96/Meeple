package com.meeplehearth.game.entity;

import com.meeplehearth.user.entity.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

// Multi-boolean collection model (CLAUDE.md): is_owned / is_wishlisted / is_favorited.
// A row with every flag false and no rating, notes or plays is invalid and is deleted instead.
@Entity
@Table(name = "user_games", uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "game_id"}))
@Getter
@Setter
public class UserGame {

    @Id
    @UuidGenerator
    @Column(updatable = false, nullable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "game_id", nullable = false)
    private Game game;

    @Column(name = "is_owned", nullable = false)
    private boolean isOwned = false;

    @Column(name = "is_wishlisted", nullable = false)
    private boolean isWishlisted = false;

    @Column(name = "is_favorited", nullable = false)
    private boolean isFavorited = false;

    @Column(name = "play_count", nullable = false)
    private int playCount = 0;

    @Column(name = "personal_rating", precision = 3, scale = 1)
    private BigDecimal personalRating;

    @Column(name = "notes", columnDefinition = "TEXT")
    private String notes;

    @Column(name = "added_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }

    /**
     * True when the row carries nothing worth keeping: no flag set and no rating, notes or plays
     * (FEATURES_COMPLETE section 3.1: such a row is invalid and must be deleted).
     */
    public boolean isEmpty() {
        return !isOwned && !isWishlisted && !isFavorited
                && playCount <= 0
                && personalRating == null
                && (notes == null || notes.isBlank());
    }
}
