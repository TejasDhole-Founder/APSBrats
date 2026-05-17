CREATE TYPE social_platform AS ENUM (
  'INSTAGRAM',
  'LINKEDIN',
  'WHATSAPP',
  'TWITTER',
  'CUSTOM'
);

CREATE TABLE user_social_links (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform      social_platform NOT NULL,
  handle        VARCHAR(200) NOT NULL,
  label         VARCHAR(50),
  is_visible    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMP NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_user_platform UNIQUE (user_id, platform)
);

CREATE INDEX idx_social_links_user ON user_social_links(user_id);
