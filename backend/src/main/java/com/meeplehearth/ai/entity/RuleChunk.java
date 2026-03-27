package com.meeplehearth.ai.entity;

import com.meeplehearth.game.entity.Game;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.util.UUID;

// Phase 3 entity — stores game rule text chunks + pgvector embeddings
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

    @Column(name = "chunk_text", nullable = false, columnDefinition = "TEXT")
    private String chunkText;

    @Column(name = "section_title")
    private String sectionTitle;

    // embedding stored as vector(1536) — pgvector type, mapped as String here until a pgvector dialect is wired
    @Column(name = "embedding", columnDefinition = "vector(1536)")
    private String embedding;
}
