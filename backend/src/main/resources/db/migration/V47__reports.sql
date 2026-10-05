-- WP3: user reports for manual admin review (FEATURES_COMPLETE 2.4). No automated action in MVP.
CREATE TABLE IF NOT EXISTS reports (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    target_type VARCHAR(20)  NOT NULL CHECK (target_type IN ('USER', 'POST', 'COMMENT')),
    target_id   UUID         NOT NULL,
    reason      VARCHAR(500) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_reports_reporter_target UNIQUE (reporter_id, target_type, target_id)
);

CREATE INDEX IF NOT EXISTS idx_reports_created ON reports (created_at DESC);
