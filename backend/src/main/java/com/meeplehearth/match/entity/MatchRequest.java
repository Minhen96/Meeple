package com.meeplehearth.match.entity;

import com.meeplehearth.game.entity.Game;
import com.meeplehearth.user.entity.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "match_requests", uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "game_id"}))
@Getter
@Setter
public class MatchRequest {

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

    @Column(name = "available_from")
    private Instant availableFrom;

    @Column(name = "available_to")
    private Instant availableTo;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Status status = Status.ACTIVE;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public enum Status {
        ACTIVE, MATCHED, CANCELLED, EXPIRED
    }

    public boolean overlapsWith(MatchRequest other) {
        if (this.availableFrom == null || this.availableTo == null
                || other.availableFrom == null || other.availableTo == null) {
            return true; // no time constraint — always overlaps
        }
        return this.availableFrom.isBefore(other.availableTo)
                && other.availableFrom.isBefore(this.availableTo);
    }
}
