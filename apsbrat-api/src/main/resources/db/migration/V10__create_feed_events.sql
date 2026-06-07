DO $$ BEGIN
    CREATE TYPE feed_event_type AS ENUM ('JOIN', 'CONNECTED', 'GENERAL');
EXCEPTION WHEN duplicate_object THEN null; END $$;

CREATE TABLE IF NOT EXISTS feed_events (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        feed_event_type NOT NULL,
    title       VARCHAR(200) NOT NULL,
    body        TEXT,
    meta        VARCHAR(200),
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feed_created ON feed_events(created_at);
