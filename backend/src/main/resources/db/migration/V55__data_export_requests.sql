-- WP5: GDPR data export requests (GET /api/v1/users/me/export). The export is built
-- asynchronously, stored in R2 under file_key and emailed to the user as a presigned link.
CREATE TABLE IF NOT EXISTS data_export_requests (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    status       VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                 CHECK (status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED')),
    file_key     VARCHAR(500),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_data_export_requests_user
    ON data_export_requests (user_id, created_at DESC);
