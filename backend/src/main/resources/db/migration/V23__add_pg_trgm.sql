-- Smart Search: pg_trgm fuzzy/partial/typo-tolerant matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Alias names for alternate game titles (language variants, known aliases)
ALTER TABLE games ADD COLUMN IF NOT EXISTS alias_names JSONB NOT NULL DEFAULT '[]';

-- GIN trigram indexes — enable fast similarity search on name and aliases
-- "name" must be quoted: it conflicts with the built-in pg_catalog.name type
CREATE INDEX IF NOT EXISTS idx_games_name_trgm        ON games USING GIN ("name_en" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_games_alias_names_trgm ON games USING GIN ((alias_names::text) gin_trgm_ops);
