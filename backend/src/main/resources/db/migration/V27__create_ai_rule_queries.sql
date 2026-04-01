-- AI query log: every non-cached user question + answer stored for analytics / FAQ mining
CREATE TABLE ai_rule_queries (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        REFERENCES users(id) ON DELETE SET NULL,
    game_id     UUID        NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    question    TEXT        NOT NULL,
    answer      TEXT        NOT NULL,
    source_mode VARCHAR(10) NOT NULL CHECK (source_mode IN ('rulebook', 'general')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ai_rule_queries_game ON ai_rule_queries (game_id);
CREATE INDEX idx_ai_rule_queries_user ON ai_rule_queries (user_id);
