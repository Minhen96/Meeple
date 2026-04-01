package com.meeplehearth.ai.entity;

import com.meeplehearth.game.entity.Game;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.util.UUID;

@Entity
@Table(name = "game_rules")
@Getter
@Setter
public class RuleChunk {

    @Id
    @UuidGenerator
    @Column(updatable = false, nullable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "game_id", nullable = false)
    private Game game;

    // FK to game_rulebooks — stored as raw UUID to avoid circular dependency with GameRulebook entity
    @Column(name = "rulebook_id")
    private UUID rulebookId;

    @Column(name = "chunk_text", nullable = false, columnDefinition = "TEXT")
    private String chunkText;

    @Column(name = "section_title")
    private String sectionTitle;

    // Position of this chunk within the document (0-based)
    @Column(name = "chunk_index", nullable = false)
    private int chunkIndex;

    @Column(name = "token_count")
    private Integer tokenCount;

    // Stored as pgvector literal: "[v1,v2,...,v1536]"
    // Use EmbeddingService.toVectorString(float[]) to convert before setting.
    @Column(name = "embedding", columnDefinition = "vector(1536)")
    private String embedding;
}
