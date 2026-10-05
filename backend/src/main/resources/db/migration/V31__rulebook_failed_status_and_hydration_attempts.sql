-- Allow 'failed' status on game_rulebooks (set when download / extraction / embedding fails).
-- game_rulebooks.status values stay lowercase (V30 did not touch this table).
ALTER TABLE game_rulebooks DROP CONSTRAINT IF EXISTS game_rulebooks_status_check;
ALTER TABLE game_rulebooks ADD CONSTRAINT game_rulebooks_status_check
    CHECK (status IN ('ingesting', 'approved', 'pending_review', 'rejected', 'failed'));

-- Track BGG hydration attempts so the bulk hydration loop never re-requests the same
-- games forever when BGG returns no data for them.
ALTER TABLE games ADD COLUMN hydration_attempted_at TIMESTAMPTZ;

CREATE INDEX idx_games_hydration_pending ON games (hydration_attempted_at)
    WHERE min_players IS NULL;
