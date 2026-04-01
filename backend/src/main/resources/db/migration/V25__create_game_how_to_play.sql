-- How To Play: AI-extracted structured breakdown stored as JSONB per game
CREATE TABLE game_how_to_play (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id      UUID         NOT NULL UNIQUE REFERENCES games(id) ON DELETE CASCADE,
    content      JSONB        NOT NULL,
    -- rulebook = extracted from ingested PDF chunks (RAG)
    -- general  = extracted from GPT general knowledge + BGG description
    source_mode  VARCHAR(10)  NOT NULL CHECK (source_mode IN ('rulebook', 'general')),
    generated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
