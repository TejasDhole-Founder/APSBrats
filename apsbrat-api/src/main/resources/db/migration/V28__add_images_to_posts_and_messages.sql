-- One optional photo per community post and per chat message.
-- The address points at a file uploaded through POST /api/v1/media/images
-- (re-encoded JPEG, location data stripped). A post or message may now be a
-- photo with no text, so body can be '' when image_url is set.
ALTER TABLE posts         ADD COLUMN IF NOT EXISTS image_url VARCHAR(300);
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS image_url VARCHAR(300);
