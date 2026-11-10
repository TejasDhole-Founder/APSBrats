-- Reunions and meetups inside a community. Owners (interest communities) and
-- staff create them; members RSVP Going / Interested.
-- Times are wall-clock local time (the app is India-only).
CREATE TABLE IF NOT EXISTS community_events (
    id            UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id  UUID          NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    organizer_id  UUID          NOT NULL REFERENCES users(id)       ON DELETE CASCADE,
    title         VARCHAR(120)  NOT NULL,
    description   VARCHAR(2000),
    venue         VARCHAR(200)  NOT NULL,
    starts_at     TIMESTAMP     NOT NULL,
    ends_at       TIMESTAMP,
    cover_url     VARCHAR(300),
    cancelled     BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMP     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_event_times CHECK (ends_at IS NULL OR ends_at >= starts_at)
);
CREATE INDEX IF NOT EXISTS idx_community_events_when ON community_events (community_id, starts_at);

CREATE TABLE IF NOT EXISTS event_rsvps (
    event_id    UUID         NOT NULL REFERENCES community_events(id) ON DELETE CASCADE,
    user_id     UUID         NOT NULL REFERENCES users(id)            ON DELETE CASCADE,
    status      VARCHAR(12)  NOT NULL,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, user_id),
    CONSTRAINT chk_rsvp_status CHECK (status IN ('GOING', 'INTERESTED'))
);

-- Event photos are ordinary posts tagged with the event.
ALTER TABLE posts ADD COLUMN IF NOT EXISTS event_id UUID REFERENCES community_events(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_posts_event ON posts (event_id, created_at DESC) WHERE event_id IS NOT NULL;
