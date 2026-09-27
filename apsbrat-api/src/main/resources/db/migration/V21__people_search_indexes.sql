-- People search: name/username text matching backed by trigram indexes, and
-- a history index that covers every filter combination in one lookup.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_users_full_name_trgm
    ON users USING gin (LOWER(full_name) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_users_username_trgm
    ON users USING gin (LOWER(username) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_users_city_lower
    ON users (LOWER(city));

CREATE INDEX IF NOT EXISTS idx_school_history_filters
    ON user_school_history (school_id, batch_end, class_to, section, stream);
