ALTER TABLE game_details
    ADD COLUMN IF NOT EXISTS honors    TEXT[],
    ADD COLUMN IF NOT EXISTS expansions TEXT[];
