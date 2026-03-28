-- Games (cached from BGG API)
CREATE TABLE games (
    id           UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    bgg_id       INTEGER        UNIQUE NOT NULL,
    name         VARCHAR(255)   NOT NULL,
    description  TEXT,
    image_url    VARCHAR(500),
    min_players  INTEGER,
    max_players  INTEGER,
    min_duration INTEGER,
    max_duration INTEGER,
    complexity   DECIMAL(3, 2),                         -- 1.0–5.0 BGG weight
    categories   TEXT[]         DEFAULT '{}',
    mechanics    TEXT[]         DEFAULT '{}',
    designer     VARCHAR(255),
    publisher    VARCHAR(255),
    bgg_rating   DECIMAL(4, 2),
    year_published INTEGER,
    created_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_games_bgg_id ON games (bgg_id);
CREATE INDEX idx_games_name   ON games (LOWER(name));

-- User game collection (owned / wishlisted / favorited — multi-boolean)
CREATE TABLE user_games (
    id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    game_id         UUID          NOT NULL REFERENCES games (id) ON DELETE CASCADE,
    is_owned        BOOLEAN       NOT NULL DEFAULT FALSE,
    is_wishlisted   BOOLEAN       NOT NULL DEFAULT FALSE,
    is_favorited    BOOLEAN       NOT NULL DEFAULT FALSE,
    play_count      INTEGER       NOT NULL DEFAULT 0,
    personal_rating DECIMAL(3, 1) CHECK (personal_rating BETWEEN 1.0 AND 10.0),
    notes           TEXT,
    added_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, game_id)
);

CREATE INDEX idx_user_games_user ON user_games (user_id);
CREATE INDEX idx_user_games_game ON user_games (game_id);
