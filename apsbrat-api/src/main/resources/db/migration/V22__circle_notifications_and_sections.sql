-- ── Connections: keep history instead of deleting, remember when accepted ─────
ALTER TYPE connection_status ADD VALUE IF NOT EXISTS 'DECLINED';
ALTER TYPE connection_status ADD VALUE IF NOT EXISTS 'WITHDRAWN';
ALTER TYPE connection_status ADD VALUE IF NOT EXISTS 'REMOVED';

ALTER TABLE connections ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMP;
ALTER TABLE connections ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT NOW();

UPDATE connections SET accepted_at = created_at WHERE status = 'ACCEPTED' AND accepted_at IS NULL;

-- ── Notifications: who it is about and what it points to ─────────────────────
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actor_id  UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS ref_type  VARCHAR(30);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS ref_id    UUID;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS group_key VARCHAR(120);

CREATE INDEX IF NOT EXISTS idx_notif_user_created_desc ON notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_group ON notifications (user_id, group_key) WHERE group_key IS NOT NULL;

-- ── School history: section is the letter only, and may be unknown ───────────
-- Old rows stored "12D"; strip the leading class digits so "D" = "D" everywhere.
UPDATE user_school_history
SET section = UPPER(REGEXP_REPLACE(section, '^[0-9]+', ''))
WHERE section IS NOT NULL;

UPDATE user_school_history SET section = NULL WHERE section = '';

ALTER TABLE user_school_history ALTER COLUMN section DROP NOT NULL;
ALTER TABLE user_school_history DROP CONSTRAINT IF EXISTS chk_section_uppercase;
ALTER TABLE user_school_history DROP CONSTRAINT IF EXISTS chk_section_letter;
ALTER TABLE user_school_history ADD CONSTRAINT chk_section_letter CHECK (
    section IS NULL OR section ~ '^[A-Z]{1,2}$'
);

-- Classmate lookup: same school + section, overlapping years.
CREATE INDEX IF NOT EXISTS idx_school_history_classmates
    ON user_school_history (school_id, section, batch_start, batch_end);
