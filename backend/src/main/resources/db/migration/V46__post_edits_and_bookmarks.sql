-- WP3: post and comment editing (FEATURES_COMPLETE 5.4, 5.7) and bookmarks (5.8).
ALTER TABLE posts         ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;
ALTER TABLE post_comments ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS bookmarks (
    user_id  UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    post_id  UUID        NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);

-- Saved-posts list, newest first, keyset cursor on (saved_at, post_id)
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_saved ON bookmarks (user_id, saved_at DESC, post_id DESC);

-- "View Memories": posts linked to an event
CREATE INDEX IF NOT EXISTS idx_posts_event ON posts (event_id, created_at DESC) WHERE deleted_at IS NULL;

-- Feed keyset cursor on (created_at, id) over each author's posts
CREATE INDEX IF NOT EXISTS idx_posts_author_created_id
    ON posts (author_id, created_at DESC, id DESC) WHERE deleted_at IS NULL;
