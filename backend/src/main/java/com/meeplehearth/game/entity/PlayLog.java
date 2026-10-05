package com.meeplehearth.game.entity;

import com.meeplehearth.user.entity.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

/** One recorded play of a game by a user (manual log, or a post that tagged the user). */
@Entity
@Table(name = "play_logs",
        indexes = @Index(name = "idx_play_logs_user_game", columnList = "user_id, game_id"))
@Getter
@Setter
public class PlayLog {

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

    @Column(name = "played_at", nullable = false)
    private Instant playedAt = Instant.now();

    @Column(name = "notes", columnDefinition = "TEXT")
    private String notes;

    @Column(name = "duration_minutes")
    private Integer durationMinutes;

    @Column(name = "player_count")
    private Integer playerCount;

    /** The post that recorded this session; null for manual logs. Plain id: posts belong to the feed package. */
    @Column(name = "post_id")
    private UUID postId;
}
