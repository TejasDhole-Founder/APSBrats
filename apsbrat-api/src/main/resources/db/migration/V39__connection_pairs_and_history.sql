-- One row per pair of users, and a history of every relationship change.
--
--  * user_low_id / user_high_id: the two user ids in a fixed order (smaller first), so
--    Arjun -> Rahul and Rahul -> Arjun are the same pair. requester_id / addressee_id
--    still say who sent the current (latest) request.
--  * requested_at: when the latest request was sent. created_at is now the first time
--    the pair ever connected and is no longer reset on a re-request.
--  * connection_events: what happened, who did it, and when. connections stays the
--    source of truth for the current state.

ALTER TABLE connections ADD COLUMN IF NOT EXISTS user_low_id  UUID;
ALTER TABLE connections ADD COLUMN IF NOT EXISTS user_high_id UUID;
ALTER TABLE connections ADD COLUMN IF NOT EXISTS requested_at TIMESTAMP;

CREATE TABLE IF NOT EXISTS connection_events (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    connection_id UUID NOT NULL REFERENCES connections(id) ON DELETE CASCADE,
    actor_id      UUID REFERENCES users(id) ON DELETE SET NULL,
    event_type    VARCHAR(20) NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata      JSONB,
    CONSTRAINT chk_connection_event_type
        CHECK (event_type IN ('REQUESTED', 'ACCEPTED', 'DECLINED', 'WITHDRAWN', 'REMOVED'))
);

-- 1. Backfill the pair columns and the request time from the existing rows.
UPDATE connections
SET user_low_id  = LEAST(requester_id, addressee_id),
    user_high_id = GREATEST(requester_id, addressee_id)
WHERE user_low_id IS NULL OR user_high_id IS NULL;

-- created_at was reset on every re-request, so it is the time of the latest request.
UPDATE connections SET requested_at = created_at WHERE requested_at IS NULL;

-- 2. Rebuild a history from what the old rows remember (their latest state only).
--    Rebuilt events are marked {"source":"backfill"}.
INSERT INTO connection_events (connection_id, actor_id, event_type, created_at, metadata)
SELECT c.id, c.requester_id, 'REQUESTED', c.created_at, '{"source":"backfill"}'::jsonb
FROM connections c
WHERE NOT EXISTS (SELECT 1 FROM connection_events e WHERE e.connection_id = c.id);

-- Rebuilt events are spaced a microsecond apart (REQUESTED, then ACCEPTED, then the ending),
-- because old rows often have the same timestamp for all of them and the order must still read right.
INSERT INTO connection_events (connection_id, actor_id, event_type, created_at, metadata)
SELECT c.id, c.addressee_id, 'ACCEPTED',
       GREATEST(c.accepted_at, c.created_at) + INTERVAL '1 microsecond',
       '{"source":"backfill"}'::jsonb
FROM connections c
WHERE c.accepted_at IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM connection_events e
                  WHERE e.connection_id = c.id AND e.event_type = 'ACCEPTED');

-- How a closed relationship ended: the old rows only know the final status.
INSERT INTO connection_events (connection_id, actor_id, event_type, created_at, metadata)
SELECT c.id,
       CASE c.status::text
           WHEN 'DECLINED'  THEN c.addressee_id
           WHEN 'WITHDRAWN' THEN c.requester_id
           ELSE NULL
       END,
       c.status::text,
       GREATEST(c.updated_at, c.created_at, COALESCE(c.accepted_at, c.created_at))
           + INTERVAL '2 microseconds',
       '{"source":"backfill"}'::jsonb
FROM connections c
WHERE c.status::text IN ('DECLINED', 'WITHDRAWN', 'REMOVED')
  AND NOT EXISTS (SELECT 1 FROM connection_events e
                  WHERE e.connection_id = c.id AND e.event_type = c.status::text);

-- 3. A pair can only have one row. If an old race left two (one per direction), keep
--    the most meaningful one (accepted, then pending, then the latest activity), move
--    the others' history and notification links onto it, and keep the earliest created_at.
DO $$
DECLARE
    pair   RECORD;
    keeper UUID;
BEGIN
    FOR pair IN
        SELECT user_low_id AS low_id, user_high_id AS high_id
        FROM connections
        GROUP BY user_low_id, user_high_id
        HAVING COUNT(*) > 1
    LOOP
        SELECT id INTO keeper
        FROM connections
        WHERE user_low_id = pair.low_id AND user_high_id = pair.high_id
        ORDER BY CASE status::text WHEN 'ACCEPTED' THEN 0 WHEN 'PENDING' THEN 1 ELSE 2 END,
                 GREATEST(updated_at, created_at) DESC,
                 id
        LIMIT 1;

        UPDATE connection_events
        SET connection_id = keeper,
            metadata = COALESCE(metadata, '{}'::jsonb)
                       || jsonb_build_object('mergedFrom', connection_id::text)
        WHERE connection_id IN (SELECT id FROM connections
                                WHERE user_low_id = pair.low_id AND user_high_id = pair.high_id
                                  AND id <> keeper);

        UPDATE notifications
        SET ref_id = keeper
        WHERE ref_type = 'CONNECTION'
          AND ref_id IN (SELECT id FROM connections
                         WHERE user_low_id = pair.low_id AND user_high_id = pair.high_id
                           AND id <> keeper);

        UPDATE connections
        SET created_at = (SELECT MIN(created_at) FROM connections
                          WHERE user_low_id = pair.low_id AND user_high_id = pair.high_id)
        WHERE id = keeper;

        DELETE FROM connections
        WHERE user_low_id = pair.low_id AND user_high_id = pair.high_id AND id <> keeper;
    END LOOP;
END $$;

-- 4. Lock the rules into the database.
ALTER TABLE connections ALTER COLUMN user_low_id  SET NOT NULL;
ALTER TABLE connections ALTER COLUMN user_high_id SET NOT NULL;
ALTER TABLE connections ALTER COLUMN requested_at SET NOT NULL;
ALTER TABLE connections ALTER COLUMN requested_at SET DEFAULT NOW();

DO $$ BEGIN
    ALTER TABLE connections
        ADD CONSTRAINT chk_connection_pair_order CHECK (user_low_id < user_high_id);
EXCEPTION WHEN duplicate_object OR duplicate_table THEN NULL; END $$;

DO $$ BEGIN
    ALTER TABLE connections
        ADD CONSTRAINT chk_connection_pair_matches CHECK (
            (requester_id = user_low_id  AND addressee_id = user_high_id) OR
            (requester_id = user_high_id AND addressee_id = user_low_id));
EXCEPTION WHEN duplicate_object OR duplicate_table THEN NULL; END $$;

DO $$ BEGIN
    ALTER TABLE connections
        ADD CONSTRAINT uq_connection_pair UNIQUE (user_low_id, user_high_id);
EXCEPTION WHEN duplicate_object OR duplicate_table THEN NULL; END $$;

-- 5. Indexes. The pair constraint above replaces the old per-direction unique key.
--    The status composites replace the single-column ones (same leading column), and
--    the partial "accepted" indexes from V36 stay for the friends list.
ALTER TABLE connections DROP CONSTRAINT IF EXISTS uq_connection;
DROP INDEX IF EXISTS idx_conn_requester;
DROP INDEX IF EXISTS idx_conn_addressee;
CREATE INDEX IF NOT EXISTS idx_conn_requester_status ON connections (requester_id, status);
CREATE INDEX IF NOT EXISTS idx_conn_addressee_status ON connections (addressee_id, status);
CREATE INDEX IF NOT EXISTS idx_conn_events_connection_created
    ON connection_events (connection_id, created_at);
