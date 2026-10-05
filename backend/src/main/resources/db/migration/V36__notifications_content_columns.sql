-- WP1 (docs/GAP_ANALYSIS.md section 5, C7): notifications keep actor/reference and the uppercase
-- type enum, and gain the server-rendered content (title, body, data with data.path), the push
-- flag and a soft-delete column for per-item delete.

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS title      VARCHAR(255);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS body       TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS data       JSONB;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_pushed  BOOLEAN     NOT NULL DEFAULT FALSE;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Cursor pagination: ORDER BY created_at DESC, id DESC per recipient
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created
    ON notifications (recipient_id, created_at DESC, id DESC);

-- Unread count (DB fallback when the Redis counter is missing)
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
    ON notifications (recipient_id)
    WHERE read = FALSE AND deleted_at IS NULL;

-- Like batching: latest notification of a type about a reference for a recipient
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_type_ref
    ON notifications (recipient_id, type, reference_id, created_at DESC);

-- Account hard delete removes notifications the user triggered (actor_id has no FK)
CREATE INDEX IF NOT EXISTS idx_notifications_actor ON notifications (actor_id);

-- 90-day retention job
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications (created_at);
