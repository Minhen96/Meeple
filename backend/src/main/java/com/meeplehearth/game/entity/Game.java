package com.meeplehearth.game.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

// Mirrors BGG game data cached in local DB
@Entity
@Table(name = "games")
@Getter
@Setter
public class Game {

    @Id
    @UuidGenerator
    @Column(updatable = false, nullable = false)
    private UUID id;

    @Column(name = "bgg_id", unique = true)
    private Long bggId;

    @Column(name = "name", nullable = false)
    private String title;

    // Added via V7 migration
    @Column(name = "thumbnail_url")
    private String thumbnailUrl;

    @Column(name = "image_url")
    private String imageUrl;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "min_players")
    private Integer minPlayers;

    @Column(name = "max_players")
    private Integer maxPlayers;

    @Column(name = "min_duration")
    private Integer minPlaytime;

    @Column(name = "max_duration")
    private Integer maxPlaytime;

    @Column(name = "complexity", precision = 3, scale = 2)
    private BigDecimal complexityWeight;

    @Column(name = "bgg_rating", precision = 4, scale = 2)
    private BigDecimal bggRating;

    @Column(name = "year_published")
    private Integer yearPublished;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
