-- Access-token invalidation: every access JWT carries the user's token_version.
-- Bumping it (password reset, refresh-token reuse, account takeover protection)
-- immediately invalidates every access token issued before the bump.
ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0;

-- Refresh-token rotation: a rotated token is kept and marked used instead of deleted,
-- so a second presentation of it can be detected as reuse (theft) and revoke the user's sessions.
ALTER TABLE refresh_tokens ADD COLUMN IF NOT EXISTS used_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens (expires_at);
