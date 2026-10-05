-- WP3 (docs/GAP_ANALYSIS.md section 5): system-generated feed items (FEATURES_COMPLETE 5.1).
-- Rows are written by the feed package when another package publishes an ActivityRecordedEvent.
CREATE TABLE IF NOT EXISTS activity_events (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type       VARCHAR(50) NOT NULL CHECK (type IN ('collection_add', 'event_created', 'event_joined')),
    data       JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_activity_events_user_created
    ON activity_events (user_id, created_at DESC);
