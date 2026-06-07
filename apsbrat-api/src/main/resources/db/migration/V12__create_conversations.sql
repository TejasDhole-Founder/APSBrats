CREATE TABLE IF NOT EXISTS conversations (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_a_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_message_at  TIMESTAMP,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_conversation_pair UNIQUE (user_a_id, user_b_id),
    CONSTRAINT chk_conv_not_self CHECK (user_a_id <> user_b_id)
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id  UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body             TEXT NOT NULL,
    read_at          TIMESTAMP,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conv_user_a ON conversations(user_a_id);
CREATE INDEX IF NOT EXISTS idx_conv_user_b ON conversations(user_b_id);
CREATE INDEX IF NOT EXISTS idx_chat_msg_conv ON chat_messages(conversation_id, created_at);
