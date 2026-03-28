-- Fix type mismatch between Hibernate Long and Postgres INTEGER
ALTER TABLE games ALTER COLUMN bgg_id TYPE BIGINT;
