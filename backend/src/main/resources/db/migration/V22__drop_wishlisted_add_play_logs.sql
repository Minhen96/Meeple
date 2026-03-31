-- Remove wishlist concept (favourite is sufficient)
ALTER TABLE user_games DROP COLUMN IF EXISTS is_wishlisted;

-- Play logs: individual play sessions per user per game
CREATE TABLE play_logs (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES users  (id) ON DELETE CASCADE,
    game_id    UUID        NOT NULL REFERENCES games  (id) ON DELETE CASCADE,
    played_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_play_logs_user_game ON play_logs (user_id, game_id);
CREATE INDEX idx_play_logs_user      ON play_logs (user_id);
