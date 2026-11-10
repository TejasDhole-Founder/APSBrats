-- Pinned posts lead a community's feed. Owners pin in their interest
-- communities; staff pin anywhere (school communities have no owner).
ALTER TABLE posts ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMP;
