package com.meeplehearth.game.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "game_details")
@Getter
@Setter
public class GameDetail {

    @Id
    @Column(name = "game_id")
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @MapsId
    @JoinColumn(name = "game_id")
    private Game game;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "complexity", precision = 3, scale = 2)
    private BigDecimal complexity;

    @Column(name = "categories", columnDefinition = "text[]")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.ARRAY)
    private String[] categories;

    @Column(name = "mechanics", columnDefinition = "text[]")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.ARRAY)
    private String[] mechanics;

    /** BGG subdomains e.g. "Strategy Games", "Thematic Games" */
    @Column(name = "families", columnDefinition = "text[]")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.ARRAY)
    private String[] families;

    @Column(name = "honors", columnDefinition = "text[]")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.ARRAY)
    private String[] honors;

    /** BGG IDs of expansions as strings — look up via findByBggIdIn for in-app linking */
    @Column(name = "expansions", columnDefinition = "text[]")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.ARRAY)
    private String[] expansions;

    @Column(name = "designers", columnDefinition = "text[]")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.ARRAY)
    private String[] designers;

    @Column(name = "artists", columnDefinition = "text[]")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.ARRAY)
    private String[] artists;

    @Column(name = "publishers", columnDefinition = "text[]")
    @org.hibernate.annotations.JdbcTypeCode(org.hibernate.type.SqlTypes.ARRAY)
    private String[] publishers;

    @Column(name = "rank_strategy")
    private Integer rankStrategy;

    @Column(name = "rank_thematic")
    private Integer rankThematic;

    @Column(name = "rank_family")
    private Integer rankFamily;

    @Column(name = "rank_war")
    private Integer rankWar;

    @Column(name = "rank_customizable")
    private Integer rankCustomizable;

    @Column(name = "rank_abstract")
    private Integer rankAbstract;

    @Column(name = "rank_party")
    private Integer rankParty;

    @Column(name = "rank_childrens")
    private Integer rankChildrens;

    @Column(name = "owned")
    private Integer owned = 0;

    @Column(name = "wishlisted")
    private Integer wishlisted = 0;

    @Column(name = "fans")
    private Integer fans = 0;

    @Column(name = "total_plays")
    private Integer totalPlays = 0;

    @Column(name = "std_deviation", precision = 5, scale = 4)
    private BigDecimal stdDeviation;

    @Column(name = "bgg_url")
    private String bggUrl;

    @Column(name = "last_synced_at", nullable = false)
    private Instant lastSyncedAt = Instant.now();
}
