CREATE TABLE game_rule_notes (
    id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id        UUID         NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    user_id        UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content        TEXT         NOT NULL,
    status         VARCHAR(20)  NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'approved', 'rejected')),
    reject_reason  TEXT,
    reviewed_by    UUID         REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at    TIMESTAMPTZ,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
-- One note per user per game (upsert pattern)
CREATE UNIQUE INDEX uq_game_rule_notes_user_game ON game_rule_notes(game_id, user_id);
CREATE INDEX idx_game_rule_notes_game_status ON game_rule_notes(game_id, status);
CREATE INDEX idx_game_rule_notes_status ON game_rule_notes(status, created_at);
