-- Current address for nearby search: the city name is chosen from GeoNames, the
-- coordinates come from the phone. users.city (V1) already holds the city name.
ALTER TABLE users ADD COLUMN IF NOT EXISTS state    VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS country  VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS latitude  NUMERIC(9,6);
ALTER TABLE users ADD COLUMN IF NOT EXISTS longitude NUMERIC(9,6);
ALTER TABLE users ADD COLUMN IF NOT EXISTS place_id VARCHAR(64);

CREATE INDEX IF NOT EXISTS idx_users_lat_lng
    ON users (latitude, longitude)
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
