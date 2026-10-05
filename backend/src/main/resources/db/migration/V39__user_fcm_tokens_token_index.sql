-- WP1: stale-token cleanup deletes by token, and registration moves a token between accounts
-- (a shared device); both look the row up by the token alone.

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_token ON user_fcm_tokens (fcm_token);
