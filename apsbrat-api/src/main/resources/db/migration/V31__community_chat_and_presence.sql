-- One group chat per community; members read and write it.
CREATE TABLE IF NOT EXISTS community_messages (
    id            UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id  UUID          NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    sender_id     UUID          NOT NULL REFERENCES users(id)       ON DELETE CASCADE,
    body          VARCHAR(2000) NOT NULL DEFAULT '',
    image_url     VARCHAR(300),
    status        VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',
    created_at    TIMESTAMP     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_community_message_status CHECK (status IN ('ACTIVE', 'HIDDEN', 'REMOVED'))
);
-- Newest-first pages, the latest message, and unread counts all read by community + time.
CREATE INDEX IF NOT EXISTS idx_community_messages_newest
    ON community_messages (community_id, created_at DESC);

-- How far each member has read the chat (null = since they joined).
ALTER TABLE community_members ADD COLUMN IF NOT EXISTS chat_read_at TIMESTAMP;

-- Presence: when the person last used the app, and whether they share it.
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP;
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS show_activity BOOLEAN NOT NULL DEFAULT TRUE;
