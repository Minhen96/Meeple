-- Phase 2: Matchmaking
CREATE TABLE match_requests (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    game_id        UUID NOT NULL REFERENCES games (id) ON DELETE CASCADE,
    available_from TIMESTAMPTZ,
    available_to   TIMESTAMPTZ,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, game_id)
);

CREATE INDEX idx_match_requests_user ON match_requests (user_id);
CREATE INDEX idx_match_requests_game ON match_requests (game_id);
