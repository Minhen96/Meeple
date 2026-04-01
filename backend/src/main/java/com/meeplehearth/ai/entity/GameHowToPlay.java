package com.meeplehearth.ai.entity;

import com.meeplehearth.game.entity.Game;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "game_how_to_play")
@Getter
@Setter
public class GameHowToPlay {

    @Id
    @UuidGenerator
    @Column(updatable = false, nullable = false)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "game_id", nullable = false, unique = true)
    private Game game;

    /** Full extracted How-to-Play structure as JSONB. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "content", nullable = false, columnDefinition = "jsonb")
    private Map<String, Object> content;

    /** "rulebook" — extracted from ingested PDF chunks via RAG.
     *  "general"  — generated from GPT general knowledge + BGG description. */
    @Column(name = "source_mode", nullable = false, length = 10)
    private String sourceMode;

    @Column(name = "generated_at", nullable = false)
    private Instant generatedAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();
}
