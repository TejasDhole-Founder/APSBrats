DO $$ BEGIN
    CREATE TYPE community_type AS ENUM ('SECTION', 'SCHOOL', 'ALL_YEARS', 'GLOBAL');
EXCEPTION WHEN duplicate_object THEN null; END $$;

CREATE TABLE IF NOT EXISTS communities (
    id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                   VARCHAR(150) NOT NULL,
    badge                  VARCHAR(50),
    type                   community_type NOT NULL,
    school_id              UUID REFERENCES schools(id) ON DELETE SET NULL,
    section                VARCHAR(5),
    batch_start            SMALLINT,
    batch_end              SMALLINT,
    subtitle               VARCHAR(200),
    auto_join_label        VARCHAR(50),
    online_count           INT NOT NULL DEFAULT 0,
    member_count_override  INT,
    created_at             TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS community_members (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id  UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_read_at  TIMESTAMP,
    joined_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_community_member UNIQUE (community_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_messages (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id  UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    sender_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body          TEXT NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comm_member_user ON community_members(user_id);
CREATE INDEX IF NOT EXISTS idx_comm_member_community ON community_members(community_id);
CREATE INDEX IF NOT EXISTS idx_comm_msg_community ON community_messages(community_id, created_at);
