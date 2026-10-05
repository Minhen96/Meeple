-- WP5: account lifecycle.
-- The daily hard-delete job scans soft-deleted users only.
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON users (deleted_at) WHERE deleted_at IS NOT NULL;

-- Active sessions: refresh tokens already carry device_info and last_used_at (V1). Rotation
-- creates a new row per refresh, so the start of the device session is carried forward here.
ALTER TABLE refresh_tokens ADD COLUMN IF NOT EXISTS session_started_at TIMESTAMPTZ;
UPDATE refresh_tokens SET session_started_at = created_at WHERE session_started_at IS NULL;
