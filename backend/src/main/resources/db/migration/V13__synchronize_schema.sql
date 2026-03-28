-- Force schema synchronization for elements out of sync with entity classes
-- Fix notifications table to match Notification.java
ALTER TABLE notifications DROP COLUMN IF EXISTS title;
ALTER TABLE notifications DROP COLUMN IF EXISTS body;
ALTER TABLE notifications DROP COLUMN IF EXISTS data;
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notifications' AND column_name='is_read') THEN
        ALTER TABLE notifications RENAME COLUMN is_read TO read;
    END IF;
END $$;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actor_id UUID;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS reference_id UUID;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS reference_type VARCHAR(30);
ALTER TABLE notifications ALTER COLUMN type TYPE VARCHAR(40);

-- Fix events table to match Event.java
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='events' AND column_name='start_time') THEN
        ALTER TABLE events RENAME COLUMN start_time TO scheduled_at;
    END IF;
END $$;
ALTER TABLE events DROP COLUMN IF EXISTS end_time;
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='events' AND column_name='max_players') THEN
        ALTER TABLE events RENAME COLUMN max_players TO max_participants;
    END IF;
END $$;
ALTER TABLE events ALTER COLUMN max_participants SET DEFAULT 8;
ALTER TABLE events ADD COLUMN IF NOT EXISTS location_lat DECIMAL(9, 6);
ALTER TABLE events ADD COLUMN IF NOT EXISTS location_lng DECIMAL(9, 6);

-- Convert is_private to visibility enum
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='events' AND column_name='is_private') THEN
        ALTER TABLE events ADD COLUMN IF NOT EXISTS visibility VARCHAR(20) NOT NULL DEFAULT 'INVITE_ONLY';
        UPDATE events SET visibility = 'PUBLIC' WHERE is_private = FALSE;
        ALTER TABLE events DROP COLUMN is_private;
    END IF;
END $$;

-- Add status enum
ALTER TABLE events ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'OPEN';
