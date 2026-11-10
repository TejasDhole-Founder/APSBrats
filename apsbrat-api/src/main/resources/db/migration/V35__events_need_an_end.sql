-- Events have a start AND an end, so "upcoming" means "not over yet".
UPDATE community_events SET ends_at = starts_at + INTERVAL '3 hours' WHERE ends_at IS NULL;
ALTER TABLE community_events ALTER COLUMN ends_at SET NOT NULL;
-- Reads: what's still on (end >= now), soonest first.
CREATE INDEX IF NOT EXISTS idx_community_events_end ON community_events (community_id, ends_at);
