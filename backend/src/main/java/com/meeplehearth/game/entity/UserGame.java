package com.meeplehearth.game.entity;

import com.meeplehearth.user.entity.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

// Multi-boolean collection model: is_owned / is_wishlisted / is_favorited (not a status enum)
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

    @Column(name = "user_rating")
    private Integer userRating;

    @Column(name = "user_notes", columnDefinition = "TEXT")
    private String userNotes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();
}
