-- Privacy becomes one switch: Public (everything visible) or Private
-- (everything visible EXCEPT phone number and social links).
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE user_settings DROP COLUMN IF EXISTS show_phone;
ALTER TABLE user_settings DROP COLUMN IF EXISTS batchmates_only;
