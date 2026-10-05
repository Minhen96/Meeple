-- V12 created UNIQUE (user_id, game_id) on match_requests, which blocks a user from ever
-- creating a new request for a game once an older one is MATCHED/CANCELLED/EXPIRED.
-- Uniqueness must only hold for ACTIVE requests (status values are uppercase, see V15).

-- Drop the table-level unique constraint on exactly (user_id, game_id), whatever its name
-- (PostgreSQL's default name is match_requests_user_id_game_id_key).
DO $$
DECLARE
    con_name TEXT;
BEGIN
    FOR con_name IN
        SELECT c.conname
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        WHERE t.relname = 'match_requests'
          AND c.contype = 'u'
          AND (
              SELECT array_agg(a.attname::TEXT ORDER BY a.attname)
              FROM unnest(c.conkey) AS k(attnum)
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
          ) = ARRAY['game_id', 'user_id']
    LOOP
        EXECUTE format('ALTER TABLE match_requests DROP CONSTRAINT %I', con_name);
    END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_match_requests_user_game_active
    ON match_requests (user_id, game_id)
    WHERE status = 'ACTIVE';
