-- A device session is a refresh-token family: the token issued at login and every token rotated
-- from it share family_id. GET /auth/sessions exposes the family id, so the id of a session stays
-- stable across refreshes, and DELETE /auth/sessions/{id} removes the whole family.
ALTER TABLE refresh_tokens ADD COLUMN IF NOT EXISTS family_id UUID;

-- Backfill: follow the rotation chain (replaced_by) from each root, i.e. a token no other token
-- was replaced by; the root's id becomes the family id of the chain.
WITH RECURSIVE chain (id, family) AS (
    SELECT r.id, r.id
    FROM refresh_tokens r
    WHERE NOT EXISTS (SELECT 1 FROM refresh_tokens p WHERE p.replaced_by = r.id)
    UNION ALL
    SELECT successor.id, chain.family
    FROM chain
    JOIN refresh_tokens predecessor ON predecessor.id = chain.id
    JOIN refresh_tokens successor ON successor.id = predecessor.replaced_by
)
UPDATE refresh_tokens r SET family_id = chain.family FROM chain WHERE r.id = chain.id;

UPDATE refresh_tokens SET family_id = id WHERE family_id IS NULL;

ALTER TABLE refresh_tokens ALTER COLUMN family_id SET DEFAULT gen_random_uuid();
ALTER TABLE refresh_tokens ALTER COLUMN family_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_family ON refresh_tokens (user_id, family_id);

-- Push registrations remember the session (family) they were registered from, so revoking a
-- session also stops pushes to that device. NULL = registered without a refresh cookie.
ALTER TABLE user_fcm_tokens ADD COLUMN IF NOT EXISTS family_id UUID;

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_family ON user_fcm_tokens (user_id, family_id);
