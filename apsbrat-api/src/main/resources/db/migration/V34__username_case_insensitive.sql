-- "Arjun" and "arjun" are the same username.
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_username_lower ON users (LOWER(username));

-- One report per person per thing: repeats were counting as extra reporters.
-- Keep the oldest of any existing duplicates first.
DELETE FROM reports r USING reports older
WHERE r.reporter_id = older.reporter_id
  AND r.target_type = older.target_type
  AND r.target_id IS NOT DISTINCT FROM older.target_id
  AND r.target_user_id IS NOT DISTINCT FROM older.target_user_id
  AND (r.created_at, r.id) > (older.created_at, older.id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_reports_once
    ON reports (reporter_id, target_type, COALESCE(target_id, target_user_id));
