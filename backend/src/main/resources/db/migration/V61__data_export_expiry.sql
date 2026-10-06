-- Data exports expire with their 7-day download link: DataExportCleanupJob deletes the zip from
-- the private bucket and marks the request EXPIRED.
ALTER TABLE data_export_requests DROP CONSTRAINT IF EXISTS data_export_requests_status_check;
ALTER TABLE data_export_requests ADD CONSTRAINT data_export_requests_status_check
    CHECK (status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED', 'EXPIRED'));

CREATE INDEX IF NOT EXISTS idx_data_export_requests_completed
    ON data_export_requests (completed_at) WHERE status = 'COMPLETED';
