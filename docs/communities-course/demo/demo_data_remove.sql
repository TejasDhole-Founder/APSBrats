-- Removes everything demo_data.sql added. Real data is untouched:
-- demo rows have ids starting with de3a0000- and demo school memberships
-- were joined at a time ending in .424242 seconds.
BEGIN;
DELETE FROM notifications WHERE ref_type = 'POST' AND ref_id::text LIKE 'de3a0000-%';
DELETE FROM reports WHERE target_id::text LIKE 'de3a0000-%';
DELETE FROM posts WHERE id::text LIKE 'de3a0000-%';
DELETE FROM communities WHERE id::text LIKE 'de3a0000-%';
DELETE FROM community_members WHERE EXTRACT(MICROSECONDS FROM joined_at)::bigint % 1000000 = 424242;
UPDATE communities c SET member_count = (SELECT COUNT(*) FROM community_members m WHERE m.community_id = c.id);
COMMIT;
