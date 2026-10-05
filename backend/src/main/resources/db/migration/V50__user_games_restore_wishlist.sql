-- WP4 (docs/GAP_ANALYSIS.md C4): restore the wishlist flag dropped by V22. CLAUDE.md and
-- FEATURES_COMPLETE section 0 lock the multi-boolean collection model
-- (is_owned / is_wishlisted / is_favorited).

ALTER TABLE user_games ADD COLUMN IF NOT EXISTS is_wishlisted BOOLEAN NOT NULL DEFAULT FALSE;

-- Library tabs filter one flag per user; index only the rows each tab reads.
CREATE INDEX IF NOT EXISTS idx_user_games_user_owned
    ON user_games (user_id) WHERE is_owned;
CREATE INDEX IF NOT EXISTS idx_user_games_user_wishlisted
    ON user_games (user_id) WHERE is_wishlisted;
CREATE INDEX IF NOT EXISTS idx_user_games_user_favorited
    ON user_games (user_id) WHERE is_favorited;
