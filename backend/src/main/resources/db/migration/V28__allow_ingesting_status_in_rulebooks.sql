-- Fix check constraint to allow 'ingesting' status
ALTER TABLE game_rulebooks DROP CONSTRAINT IF EXISTS game_rulebooks_status_check;
ALTER TABLE game_rulebooks ADD CONSTRAINT game_rulebooks_status_check 
    CHECK (status IN ('ingesting', 'approved', 'pending_review', 'rejected'));
