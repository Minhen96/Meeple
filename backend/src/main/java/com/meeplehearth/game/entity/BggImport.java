package com.meeplehearth.game.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

/** Audit row for one BoardGameGeek collection import (live progress lives in Redis). */
@Entity
@Table(name = "bgg_imports")
@Getter
@Setter
public class BggImport {

    public enum Status { RUNNING, DONE, FAILED }

    @Id
    @UuidGenerator
    @Column(updatable = false, nullable = false)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "bgg_username", nullable = false, length = 50)
    private String bggUsername;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Status status = Status.RUNNING;

    @Column(nullable = false)
    private int total;

    @Column(nullable = false)
    private int imported;

    @Column(nullable = false)
    private int skipped;

    @Column(nullable = false)
    private int failed;

    @Column(name = "error_code", length = 40)
    private String errorCode;

    @Column(name = "started_at", nullable = false, updatable = false)
    private Instant startedAt = Instant.now();

    @Column(name = "finished_at")
    private Instant finishedAt;
}
