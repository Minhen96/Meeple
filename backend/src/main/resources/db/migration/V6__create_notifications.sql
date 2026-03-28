-- Notifications
CREATE TABLE notifications (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type         VARCHAR(50) NOT NULL,
    title        VARCHAR(255),
    body         TEXT,
    data         JSONB,
    is_read      BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_recipient ON notifications (recipient_id, is_read, created_at DESC);
