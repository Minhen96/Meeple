-- WP2: 24h reminder bookkeeping (FEATURES section 4.5) and the public-listing location
-- (ENGINEERING_STANDARDS section 10: PUBLIC events show location_display until the viewer joins).
ALTER TABLE events ADD COLUMN IF NOT EXISTS reminder_sent BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE events ADD COLUMN IF NOT EXISTS location_display VARCHAR(100);

-- Events already less than 24h away (or past) when this ships never get a late reminder,
-- the same rule that applies to events created less than 24h before they start.
UPDATE events SET reminder_sent = TRUE WHERE scheduled_at < NOW() + INTERVAL '24 hours';

-- The event_reminder and event_auto_complete jobs scan only live (OPEN/FULL) events by time.
CREATE INDEX IF NOT EXISTS idx_events_live_scheduled
    ON events (scheduled_at)
    WHERE deleted_at IS NULL AND status IN ('OPEN', 'FULL');
