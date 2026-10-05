-- WP1: quiet hours ("Do Not Disturb", SCREENS_AND_STATES section 11.3). Kept out of users so the
-- notifications package owns it. Times are wall-clock times in timezone, falling back to
-- users.timezone and then UTC when timezone is NULL.

CREATE TABLE IF NOT EXISTS notification_settings (
    user_id             UUID        PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    quiet_hours_enabled BOOLEAN     NOT NULL DEFAULT FALSE,
    quiet_hours_start   TIME,
    quiet_hours_end     TIME,
    timezone            VARCHAR(50),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_notification_settings_quiet_hours
        CHECK (NOT quiet_hours_enabled OR (quiet_hours_start IS NOT NULL AND quiet_hours_end IS NOT NULL))
);
