-- Phase 3: AI Rules Assistant
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Game rules table for RAG
CREATE TABLE game_rules (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id       UUID NOT NULL REFERENCES games (id) ON DELETE CASCADE,
    chunk_text    TEXT NOT NULL,
    section_title VARCHAR(255),
    embedding     VECTOR(1536),                         -- pgvector type
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_game_rules_game ON game_rules (game_id);
