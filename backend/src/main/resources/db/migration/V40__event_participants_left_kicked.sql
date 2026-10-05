-- WP2: participants who leave keep their row with status LEFT (FEATURES section 4.2) and
-- participants removed by the host get KICKED (section 4.4), instead of the row being deleted.
-- Uppercase values, matching @Enumerated(EnumType.STRING) and V30.
ALTER TABLE event_participants DROP CONSTRAINT IF EXISTS event_participants_status_check;
UPDATE event_participants SET status = UPPER(status);
ALTER TABLE event_participants
    ADD CONSTRAINT event_participants_status_check
    CHECK (status IN ('INVITED', 'ACCEPTED', 'DECLINED', 'LEFT', 'KICKED'));

-- Accepted counts per event (capacity checks, list badges) without scanning other statuses.
CREATE INDEX IF NOT EXISTS idx_event_participants_event_status
    ON event_participants (event_id, status);
