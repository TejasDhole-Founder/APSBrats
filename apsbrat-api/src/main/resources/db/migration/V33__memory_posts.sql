-- School memories: a photo post can be marked as a memory from a year, in a
-- fixed category. Both are set together or not at all.
ALTER TABLE posts ADD COLUMN IF NOT EXISTS memory_year SMALLINT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS memory_category VARCHAR(20);
ALTER TABLE posts DROP CONSTRAINT IF EXISTS chk_post_memory;
ALTER TABLE posts ADD CONSTRAINT chk_post_memory CHECK (
    (memory_year IS NULL) = (memory_category IS NULL)
    AND (memory_category IS NULL OR memory_category IN
         ('ANNUAL_DAY', 'SPORTS_DAY', 'CLASSROOM', 'TRIPS', 'FAREWELL', 'CAMPUS', 'OTHER'))
);
-- The Memories gallery reads one community's memory posts, newest first.
CREATE INDEX IF NOT EXISTS idx_posts_memories
    ON posts (community_id, created_at DESC) WHERE memory_category IS NOT NULL;
