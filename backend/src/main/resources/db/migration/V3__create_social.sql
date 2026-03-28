-- Friend requests (Facebook model — must accept before becoming friends)
CREATE TABLE friend_requests (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id   UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    receiver_id UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    status      VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (sender_id, receiver_id),
    CHECK (sender_id <> receiver_id)
);

CREATE INDEX idx_friend_requests_sender   ON friend_requests (sender_id);
CREATE INDEX idx_friend_requests_receiver ON friend_requests (receiver_id);
CREATE INDEX idx_friend_requests_status   ON friend_requests (receiver_id, status);
