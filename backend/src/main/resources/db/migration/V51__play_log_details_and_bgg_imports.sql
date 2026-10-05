-- WP4: richer play logs (FEATURES_COMPLETE section 5.2 step 4, section 9.1) and an audit
-- trail of BoardGameGeek collection imports (section 3.2).

ALTER TABLE play_logs ADD COLUMN IF NOT EXISTS notes            TEXT;
ALTER TABLE play_logs ADD COLUMN IF NOT EXISTS duration_minutes INTEGER;
ALTER TABLE play_logs ADD COLUMN IF NOT EXISTS player_count     INTEGER;
-- The post that recorded the session. A hard-deleted post keeps the play (FEATURES section 0:
-- play counts are not decremented on post deletion), so the link is cleared, not cascaded.
ALTER TABLE play_logs ADD COLUMN IF NOT EXISTS post_id          UUID REFERENCES posts (id) ON DELETE SET NULL;

ALTER TABLE play_logs DROP CONSTRAINT IF EXISTS chk_play_logs_duration;
ALTER TABLE play_logs ADD CONSTRAINT chk_play_logs_duration
    CHECK (duration_minutes IS NULL OR duration_minutes BETWEEN 1 AND 1440);
ALTER TABLE play_logs DROP CONSTRAINT IF EXISTS chk_play_logs_player_count;
ALTER TABLE play_logs ADD CONSTRAINT chk_play_logs_player_count
    CHECK (player_count IS NULL OR player_count BETWEEN 1 AND 100);

-- One play per user per post: makes the session-played listener idempotent.
CREATE UNIQUE INDEX IF NOT EXISTS uq_play_logs_user_post
    ON play_logs (user_id, post_id) WHERE post_id IS NOT NULL;
-- Play history is read newest first.
CREATE INDEX IF NOT EXISTS idx_play_logs_user_played_at
    ON play_logs (user_id, played_at DESC);

CREATE TABLE IF NOT EXISTS bgg_imports (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    bgg_username VARCHAR(50) NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'RUNNING'
                 CHECK (status IN ('RUNNING', 'DONE', 'FAILED')),
    total        INTEGER     NOT NULL DEFAULT 0,
    imported     INTEGER     NOT NULL DEFAULT 0,
    skipped      INTEGER     NOT NULL DEFAULT 0,
    failed       INTEGER     NOT NULL DEFAULT 0,
    error_code   VARCHAR(40),
    started_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_bgg_imports_user_started ON bgg_imports (user_id, started_at DESC);
