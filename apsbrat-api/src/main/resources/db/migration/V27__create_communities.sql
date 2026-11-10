-- Communities: one per APS school (automatic) + interest groups users create.
-- Text posts, likes and comments. See docs/communities-course.

CREATE TABLE IF NOT EXISTS communities (
                                           id            UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    type          VARCHAR(10)  NOT NULL,
    school_id     UUID         UNIQUE REFERENCES schools(id) ON DELETE CASCADE,
    name          VARCHAR(150) NOT NULL,
    name_key      VARCHAR(150) NOT NULL,
    description   VARCHAR(500),
    visibility    VARCHAR(10)  NOT NULL DEFAULT 'OPEN',
    created_by    UUID         REFERENCES users(id) ON DELETE SET NULL,
    member_count  INT          NOT NULL DEFAULT 0,
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    version       BIGINT       NOT NULL DEFAULT 0,
    CONSTRAINT chk_community_type       CHECK (type IN ('SCHOOL', 'INTEREST')),
    CONSTRAINT chk_community_visibility CHECK (visibility IN ('OPEN', 'PRIVATE')),
    -- A school community always has a school; an interest one never does.
    CONSTRAINT chk_community_school     CHECK ((type = 'SCHOOL') = (school_id IS NOT NULL))
    );
-- Interest names must be unique ("Software Devs" = "software devs").
-- School names are not checked: two schools may share a name.
CREATE UNIQUE INDEX IF NOT EXISTS uq_interest_community_name
    ON communities (name_key) WHERE type = 'INTEREST';

CREATE TABLE IF NOT EXISTS community_members (
                                                 community_id  UUID        NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    user_id       UUID        NOT NULL REFERENCES users(id)       ON DELETE CASCADE,
    role          VARCHAR(10) NOT NULL DEFAULT 'MEMBER',
    joined_at     TIMESTAMP   NOT NULL DEFAULT NOW(),
    PRIMARY KEY (community_id, user_id),
    CONSTRAINT chk_member_role CHECK (role IN ('OWNER', 'MEMBER'))
    );
-- "Which communities am I in?" reads by user, so it needs its own index.
CREATE INDEX IF NOT EXISTS idx_community_members_user ON community_members (user_id);

CREATE TABLE IF NOT EXISTS community_join_requests (
                                                       community_id  UUID       NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    user_id       UUID       NOT NULL REFERENCES users(id)       ON DELETE CASCADE,
    created_at    TIMESTAMP  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (community_id, user_id)
    );

CREATE TABLE IF NOT EXISTS posts (
                                     id             UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id   UUID          NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    author_id      UUID          NOT NULL REFERENCES users(id)       ON DELETE CASCADE,
    body           VARCHAR(2000) NOT NULL,
    status         VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',
    like_count     INT           NOT NULL DEFAULT 0,
    comment_count  INT           NOT NULL DEFAULT 0,
    created_at     TIMESTAMP     NOT NULL DEFAULT NOW(),
    version        BIGINT        NOT NULL DEFAULT 0,
    CONSTRAINT chk_post_status CHECK (status IN ('ACTIVE', 'HIDDEN', 'REMOVED'))
    );
-- Newest-first pages of one community (and the Home feed across several).
CREATE INDEX IF NOT EXISTS idx_posts_community_newest
    ON posts (community_id, created_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS post_likes (
                                          post_id     UUID       NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id     UUID       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMP  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
    );

CREATE TABLE IF NOT EXISTS comments (
                                        id          UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id     UUID          NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    author_id   UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body        VARCHAR(1000) NOT NULL,
    status      VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',
    created_at  TIMESTAMP     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_comment_status CHECK (status IN ('ACTIVE', 'HIDDEN', 'REMOVED'))
    );
CREATE INDEX IF NOT EXISTS idx_comments_post ON comments (post_id, created_at);

-- One community per school, created now for all of them. Nobody is added:
-- people see their schools' communities as suggestions and join if they want.
INSERT INTO communities (type, school_id, name, name_key, visibility)
SELECT 'SCHOOL', s.id, s.name, LOWER(s.name), 'OPEN'
FROM schools s
    ON CONFLICT (school_id) DO NOTHING;