-- WP2: the hourly match_request_expire job (TECH_STACK_ADDITIONS section 21) scans ACTIVE
-- requests only, by end of availability window and age.
CREATE INDEX IF NOT EXISTS idx_match_requests_active_expiry
    ON match_requests (available_to, created_at)
    WHERE status = 'ACTIVE';
