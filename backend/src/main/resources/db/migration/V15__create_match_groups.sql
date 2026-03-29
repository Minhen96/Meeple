-- Replace is_active boolean with status enum on match_requests
ALTER TABLE match_requests ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE';
UPDATE match_requests SET status = CASE WHEN is_active THEN 'ACTIVE' ELSE 'CANCELLED' END;
ALTER TABLE match_requests DROP COLUMN IF EXISTS is_active;
CREATE INDEX IF NOT EXISTS idx_match_requests_status ON match_requests (game_id, status);

-- Match groups (a set of users matched to play the same game)
CREATE TABLE match_groups (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id       UUID        NOT NULL REFERENCES games (id) ON DELETE CASCADE,
    overlap_start TIMESTAMPTZ,
    overlap_end   TIMESTAMPTZ,
    status        VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_match_groups_status ON match_groups (status);

-- Members of each match group
CREATE TABLE match_group_members (
    group_id  UUID        NOT NULL REFERENCES match_groups (id) ON DELETE CASCADE,
    user_id   UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    status    VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, user_id)
);

CREATE INDEX idx_match_group_members_user ON match_group_members (user_id);
