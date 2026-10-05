-- WP5: change email (POST /api/v1/users/me/change-email, confirmed with
-- POST /api/v1/auth/confirm-email-change). Only the SHA-256 of the emailed token is stored.
CREATE TABLE IF NOT EXISTS email_change_tokens (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    new_email  VARCHAR(255) NOT NULL,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ  NOT NULL,
    used_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_email_change_tokens_user ON email_change_tokens (user_id);
