DO $$ BEGIN
    CREATE TYPE connection_status AS ENUM ('PENDING', 'ACCEPTED');
EXCEPTION WHEN duplicate_object THEN null; END $$;

CREATE TABLE IF NOT EXISTS connections (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    addressee_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status        connection_status NOT NULL DEFAULT 'PENDING',
    created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_connection UNIQUE (requester_id, addressee_id),
    CONSTRAINT chk_not_self CHECK (requester_id <> addressee_id)
);

CREATE INDEX IF NOT EXISTS idx_conn_requester ON connections(requester_id);
CREATE INDEX IF NOT EXISTS idx_conn_addressee ON connections(addressee_id);
