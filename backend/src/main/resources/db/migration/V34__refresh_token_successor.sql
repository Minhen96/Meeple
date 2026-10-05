-- Refresh-token rotation records the token that replaced a rotated one. When a rotated token
-- is presented again and its successor was never used, the client most likely never received
-- the rotation response (aborted request, navigation, dropped mobile connection): the successor
-- is discarded and a fresh pair issued instead of revoking every session of the user.
ALTER TABLE refresh_tokens
    ADD COLUMN IF NOT EXISTS replaced_by UUID REFERENCES refresh_tokens (id) ON DELETE SET NULL;

-- Supports ON DELETE SET NULL lookups when successors are deleted
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_replaced_by ON refresh_tokens (replaced_by);
