-- 1. Modify existing games table (Core Table for Fast Browsing)
ALTER TABLE games RENAME COLUMN name TO name_en;
ALTER TABLE games ADD COLUMN name_zh VARCHAR(255);
ALTER TABLE games ADD COLUMN alias_names JSONB DEFAULT '[]'::jsonb;

-- Core Dataset fields from Dataset 1 & 2 needed for the All Games List
ALTER TABLE games ADD COLUMN min_age INTEGER;
ALTER TABLE games ADD COLUMN rank INTEGER;          -- mapped to rank_overall
ALTER TABLE games ADD COLUMN users_rated INTEGER;   -- mapped to num_ratings
ALTER TABLE games ADD COLUMN play_time INTEGER;     -- mapped to max_playtime or average

-- Remove duplicates/moved columns to clean up 'games' list view performance
ALTER TABLE games DROP COLUMN IF EXISTS min_duration;
ALTER TABLE games DROP COLUMN IF EXISTS max_duration;
ALTER TABLE games DROP COLUMN IF EXISTS designer;
ALTER TABLE games DROP COLUMN IF EXISTS publisher;
ALTER TABLE games DROP COLUMN IF EXISTS description;
ALTER TABLE games DROP COLUMN IF EXISTS complexity;
ALTER TABLE games DROP COLUMN IF EXISTS categories;
ALTER TABLE games DROP COLUMN IF EXISTS mechanics;

-- Add indices for fast robust querying
-- Note: Using standard b-tree/lowercase indexes as pg_trgm might not be enabled by default. We can enable the extension later if deep fuzzy search is required.
CREATE INDEX idx_games_name_en ON games (LOWER(name_en));
CREATE INDEX idx_games_name_zh ON games (LOWER(name_zh));
CREATE INDEX idx_games_players ON games (min_players, max_players);
CREATE INDEX idx_games_ranking ON games (rank);

-- 2. Create game_details table (Extended Data & Enrichment)
CREATE TABLE game_details (
    game_id         UUID PRIMARY KEY REFERENCES games(id) ON DELETE CASCADE,
    description     TEXT,                  -- Massive text field goes here
    complexity      DECIMAL(3, 2),
    
    -- Categorization arrays
    categories      TEXT[] DEFAULT '{}',
    mechanics       TEXT[] DEFAULT '{}',
    families        TEXT[] DEFAULT '{}',
    
    -- People
    designers       TEXT[] DEFAULT '{}',
    artists         TEXT[] DEFAULT '{}',
    publishers      TEXT[] DEFAULT '{}',
    
    -- Sub-rankings from Dataset 2 parameters
    rank_strategy   INTEGER,
    rank_thematic   INTEGER,
    rank_family     INTEGER,
    rank_war        INTEGER,
    rank_customizable INTEGER,
    rank_abstract   INTEGER,
    rank_party      INTEGER,
    rank_childrens  INTEGER,
    
    -- Community metrics
    owned           INTEGER DEFAULT 0,
    wishlisted      INTEGER DEFAULT 0,
    fans            INTEGER DEFAULT 0,
    total_plays     INTEGER DEFAULT 0,
    std_deviation   DECIMAL(5, 4),
    
    bgg_url         VARCHAR(500),          -- Link to official BGG
    last_synced_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
