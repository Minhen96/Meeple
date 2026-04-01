-- Rulebook Pipeline: track every rulebook source per game
CREATE TABLE game_rulebooks (
    id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id        UUID         NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    -- Source: rule_book_org/onj = auto-fetched; user/admin = uploaded
    source         VARCHAR(20)  NOT NULL
                   CHECK (source IN ('rule_book_org', 'onj', 'user', 'admin')),
    -- ingesting: PDF found, chunks being written. approved: chunks ready. pending_review: user upload awaiting admin.
    status         VARCHAR(20)  NOT NULL DEFAULT 'pending_review'
                   CHECK (status IN ('ingesting', 'approved', 'pending_review', 'rejected')),
    pdf_url        TEXT,        -- original CDN URL (auto-fetched sources)
    storage_key    TEXT,        -- R2 object key (user/admin uploads)
    public_url     TEXT,        -- R2 public URL (user/admin uploads)
    reject_reason  TEXT,
    queue_position INTEGER,     -- ordering within pending queue for same game
    uploaded_by    UUID         REFERENCES users(id) ON DELETE SET NULL,
    reviewed_by    UUID         REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at    TIMESTAMPTZ,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_game_rulebooks_game   ON game_rulebooks (game_id);
CREATE INDEX idx_game_rulebooks_status ON game_rulebooks (status);

-- Extend game_rules with rulebook FK and chunk ordering
ALTER TABLE game_rules
    ADD COLUMN rulebook_id  UUID        REFERENCES game_rulebooks(id) ON DELETE SET NULL,
    ADD COLUMN chunk_index  INTEGER     NOT NULL DEFAULT 0,
    ADD COLUMN token_count  INTEGER;

CREATE INDEX idx_game_rules_rulebook ON game_rules (rulebook_id);
