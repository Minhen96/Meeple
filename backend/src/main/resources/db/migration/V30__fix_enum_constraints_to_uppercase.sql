-- Fix all CHECK constraints to match Java @Enumerated(EnumType.STRING) uppercase values

-- ── friend_requests ──────────────────────────────────────────────────────────
ALTER TABLE friend_requests DROP CONSTRAINT IF EXISTS friend_requests_status_check;
UPDATE friend_requests SET status = UPPER(status);
ALTER TABLE friend_requests
    ADD CONSTRAINT friend_requests_status_check
    CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED'));
ALTER TABLE friend_requests ALTER COLUMN status SET DEFAULT 'PENDING';

-- ── events.status ─────────────────────────────────────────────────────────────
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
UPDATE events SET status = UPPER(status);
ALTER TABLE events
    ADD CONSTRAINT events_status_check
    CHECK (status IN ('OPEN', 'FULL', 'COMPLETED', 'CANCELLED'));
ALTER TABLE events ALTER COLUMN status SET DEFAULT 'OPEN';

-- ── events.visibility ─────────────────────────────────────────────────────────
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_visibility_check;
UPDATE events SET visibility = UPPER(visibility);
ALTER TABLE events
    ADD CONSTRAINT events_visibility_check
    CHECK (visibility IN ('INVITE_ONLY', 'FRIENDS', 'PUBLIC'));
ALTER TABLE events ALTER COLUMN visibility SET DEFAULT 'INVITE_ONLY';

-- ── event_participants.status ─────────────────────────────────────────────────
ALTER TABLE event_participants DROP CONSTRAINT IF EXISTS event_participants_status_check;
UPDATE event_participants SET status = UPPER(status);
ALTER TABLE event_participants
    ADD CONSTRAINT event_participants_status_check
    CHECK (status IN ('INVITED', 'ACCEPTED', 'DECLINED'));
ALTER TABLE event_participants ALTER COLUMN status SET DEFAULT 'INVITED';
