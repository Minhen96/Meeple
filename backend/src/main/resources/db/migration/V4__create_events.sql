-- Events
CREATE TABLE events (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    host_id          UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    game_id          UUID        REFERENCES games (id) ON DELETE SET NULL,
    title            VARCHAR(255) NOT NULL,
    description      TEXT,
    location         VARCHAR(255),
    location_lat     DECIMAL(9, 6),
    location_lng     DECIMAL(9, 6),
    scheduled_at     TIMESTAMPTZ NOT NULL,
    max_participants INTEGER     NOT NULL DEFAULT 8,
    visibility       VARCHAR(20) NOT NULL DEFAULT 'invite_only' CHECK (visibility IN ('invite_only', 'friends', 'public')),
    status           VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'full', 'completed', 'cancelled')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at       TIMESTAMPTZ
);

CREATE INDEX idx_events_host        ON events (host_id);
CREATE INDEX idx_events_scheduled   ON events (scheduled_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_events_visibility  ON events (visibility, scheduled_at) WHERE deleted_at IS NULL;

-- Event participants
CREATE TABLE event_participants (
    event_id  UUID        NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    user_id   UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    status    VARCHAR(20) NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'accepted', 'declined')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, user_id)
);

CREATE INDEX idx_event_participants_user ON event_participants (user_id);
