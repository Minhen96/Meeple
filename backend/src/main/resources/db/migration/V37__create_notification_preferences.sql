-- WP1: per-user, per-type delivery preferences (FEATURES_COMPLETE section 7.1). A missing row means
-- the defaults (both channels enabled). type holds the NotificationType enum name; like
-- notifications.type it has no CHECK constraint, so new enum values need no migration.

CREATE TABLE IF NOT EXISTS notification_preferences (
    user_id        UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type           VARCHAR(40) NOT NULL,
    in_app_enabled BOOLEAN     NOT NULL DEFAULT TRUE,
    push_enabled   BOOLEAN     NOT NULL DEFAULT TRUE,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, type)
);
