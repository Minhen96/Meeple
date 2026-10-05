-- Hard delete anonymises instead of cascading (FEATURES_COMPLETE section 1.6): when an account is
-- permanently removed, the events it hosted and the comments it wrote are kept and shown as
-- "Deleted User". events.host_id and post_comments.author_id become nullable and their foreign
-- keys to users switch from ON DELETE CASCADE to ON DELETE SET NULL.
--
-- The original constraints were created inline (V4, V5), so their names are PostgreSQL defaults;
-- find them through the catalog rather than assuming a name.
DO $$
DECLARE
    target RECORD;
    con_name TEXT;
BEGIN
    FOR target IN
        SELECT * FROM (VALUES ('events', 'host_id', 'fk_events_host'),
                              ('post_comments', 'author_id', 'fk_post_comments_author')) AS t(tbl, col, new_name)
    LOOP
        FOR con_name IN
            SELECT c.conname
            FROM pg_constraint c
            JOIN pg_class t ON t.oid = c.conrelid
            JOIN pg_class r ON r.oid = c.confrelid
            WHERE t.relname = target.tbl
              AND r.relname = 'users'
              AND c.contype = 'f'
              AND c.conname <> target.new_name
              AND (
                  SELECT array_agg(a.attname::TEXT)
                  FROM unnest(c.conkey) AS k(attnum)
                  JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
              ) = ARRAY[target.col]
        LOOP
            EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', target.tbl, con_name);
        END LOOP;

        EXECUTE format('ALTER TABLE %I ALTER COLUMN %I DROP NOT NULL', target.tbl, target.col);

        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = target.new_name) THEN
            EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES users (id) ON DELETE SET NULL',
                           target.tbl, target.new_name, target.col);
        END IF;
    END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_post_comments_author ON post_comments (author_id);
