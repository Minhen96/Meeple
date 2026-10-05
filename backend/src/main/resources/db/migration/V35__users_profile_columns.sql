-- Step 0 (docs/GAP_ANALYSIS.md section 5): profile columns used by the account, library and
-- notifications work packages. notifications.type has no CHECK constraint (VARCHAR(40) since V13),
-- so the new NotificationType values need no schema change.

ALTER TABLE users ADD COLUMN IF NOT EXISTS bgg_username        VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified         BOOLEAN     NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS username_changed_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS preferred_language  VARCHAR(10) NOT NULL DEFAULT 'en';
ALTER TABLE users ADD COLUMN IF NOT EXISTS timezone            VARCHAR(50);
