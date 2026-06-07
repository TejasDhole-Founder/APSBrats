-- Performance indexes for the new feature queries.

-- Recent-joins ordering (findTop12ByOrderByCreatedAtDesc) and the "joined today" banner.
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);

-- Trigram indexes so search's case-insensitive LIKE uses an index instead of a full scan.
-- NOTE: built on LOWER(col) to match the generated `LOWER(col) LIKE LOWER(?)` predicate.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_users_fullname_trgm ON users        USING gin (LOWER(full_name) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_city_trgm     ON users        USING gin (LOWER(city)      gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_username_trgm ON users        USING gin (LOWER(username)  gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_communities_name_trgm ON communities USING gin (LOWER(name)     gin_trgm_ops);

-- Unread-DM count: WHERE conversation_id = ? AND read_at IS NULL (partial index keeps it tiny).
CREATE INDEX IF NOT EXISTS idx_chat_unread ON chat_messages(conversation_id) WHERE read_at IS NULL;
