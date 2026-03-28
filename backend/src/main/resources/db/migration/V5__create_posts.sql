-- Posts (session memories)
CREATE TABLE posts (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id  UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    game_id    UUID        REFERENCES games (id) ON DELETE SET NULL,
    caption    TEXT,
    location   VARCHAR(255),
    played_at  TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_posts_author  ON posts (author_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_posts_game    ON posts (game_id) WHERE deleted_at IS NULL;

-- Post images (ordered)
CREATE TABLE post_images (
    id            UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id       UUID    NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    url           VARCHAR(500) NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_post_images_post ON post_images (post_id, display_order);

-- Post tags (tagged users and games)
CREATE TABLE post_tags (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id        UUID NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    tagged_user_id UUID REFERENCES users (id) ON DELETE CASCADE,
    tagged_game_id UUID REFERENCES games (id) ON DELETE CASCADE,
    CHECK (tagged_user_id IS NOT NULL OR tagged_game_id IS NOT NULL)
);

CREATE INDEX idx_post_tags_post ON post_tags (post_id);
CREATE INDEX idx_post_tags_user ON post_tags (tagged_user_id) WHERE tagged_user_id IS NOT NULL;

-- Post likes
CREATE TABLE post_likes (
    post_id    UUID        NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    user_id    UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

-- Post comments
CREATE TABLE post_comments (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id    UUID        NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    author_id  UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    body       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_post_comments_post ON post_comments (post_id, created_at) WHERE deleted_at IS NULL;
