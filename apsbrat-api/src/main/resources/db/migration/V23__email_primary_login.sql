-- Email + OTP (and Google, verified via Firebase) becomes the only login path.
-- Phone stops being a required, verified identifier — the column stays for any
-- legacy display but is no longer collected at signup or used to authenticate.

-- Backfill any row missing an email before the column becomes required —
-- keyed by id, so it is guaranteed unique even if two rows share a username.
UPDATE users
SET email = LOWER(COALESCE(username, 'user')) || '-' || id || '@placeholder.apsbrat.in'
WHERE email IS NULL;

ALTER TABLE users ALTER COLUMN email SET NOT NULL;
ALTER TABLE users ALTER COLUMN phone DROP NOT NULL;

-- A bare account now exists the moment an email is verified, before the
-- onboarding screens have collected a name or a handle.
ALTER TABLE users ALTER COLUMN username DROP NOT NULL;
ALTER TABLE users ALTER COLUMN full_name DROP NOT NULL;

-- otp_codes was phone-keyed; it is email-keyed now.
ALTER TABLE otp_codes RENAME COLUMN phone TO email;
ALTER INDEX idx_otp_phone RENAME TO idx_otp_email;
