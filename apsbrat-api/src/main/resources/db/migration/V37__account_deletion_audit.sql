-- Durable record that an account deletion was requested and carried out (DPDP accountability).
-- Ids and times only, no personal data. No FK: the record must outlive anything done to the user row.
CREATE TABLE IF NOT EXISTS account_deletions (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID        NOT NULL,
    deleted_at  TIMESTAMP   NOT NULL DEFAULT now(),
    request_id  VARCHAR(64)
);
CREATE INDEX IF NOT EXISTS idx_account_deletions_user ON account_deletions (user_id);
