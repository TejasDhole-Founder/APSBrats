-- Posts can carry up to 10 photos, shown as a swipeable slider (Instagram
-- style). Replaces the single posts.image_url from V28; chat keeps one photo
-- per message. An array keeps a post's photos in order without a join.
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_urls TEXT[] NOT NULL DEFAULT '{}';
UPDATE posts SET image_urls = ARRAY[image_url] WHERE image_url IS NOT NULL;
ALTER TABLE posts DROP COLUMN IF EXISTS image_url;
