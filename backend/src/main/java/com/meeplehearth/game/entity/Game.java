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

    @Column(name = "name_en", nullable = false)
    private String nameEn;

    @Column(name = "name_zh")
    private String nameZh;

    @Column(name = "alias_names", columnDefinition = "jsonb")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.JSON)
    private java.util.List<String> aliasNames = new java.util.ArrayList<>();

    @Column(name = "thumbnail_url")
    private String thumbnailUrl;

    @Column(name = "image_url")
    private String imageUrl;

    @Column(name = "min_players")
    private Integer minPlayers;

    @Column(name = "max_players")
    private Integer maxPlayers;

    @Column(name = "min_age")
    private Integer minAge;

    @Column(name = "rank")
    private Integer rank;

    @Column(name = "users_rated")
    private Integer usersRated;

    @Column(name = "play_time")
    private Integer playTime;

    @Column(name = "bgg_rating", precision = 4, scale = 2)
    private BigDecimal bggRating;

    @Column(name = "year_published")
    private Integer yearPublished;

    @Column(name = "game_type", length = 30)
    private String gameType = "boardgame";

    @OneToOne(mappedBy = "game", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private GameDetail gameDetail;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
