-- Optimistic locking (@Version) support for contended, mutable rows.
ALTER TABLE users ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE connections ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE community_members ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 0;
