-- Roles + account moderation state for Trust & Safety / admin console.
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'USER';
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_until TIMESTAMP;
ALTER TABLE users ADD COLUMN IF NOT EXISTS banned_at TIMESTAMP;

-- Moderation audit trail: who did what, to whom, and why.
CREATE TABLE IF NOT EXISTS moderation_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID NOT NULL REFERENCES users (id),
    target_user_id UUID REFERENCES users (id),
    action VARCHAR(40) NOT NULL,
    reason VARCHAR(500),
    report_id UUID REFERENCES reports (id),
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_moderation_actions_target ON moderation_actions (target_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports (status);
