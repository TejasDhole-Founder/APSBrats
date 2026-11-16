-- Paged "requests waiting for me" / "requests I sent" read the newest pending rows first.
-- Without these, Postgres fetched every pending row of a person, joined and sorted them, then
-- kept 31 (about 37 ms for 6,000 waiting requests, 10 ms for 4,000 sent). With them it walks the
-- index in order and stops after one page (about 0.4 ms), including deep pages.
-- Partial on PENDING, so they only hold the small share of rows that are still waiting.
CREATE INDEX IF NOT EXISTS idx_conn_pending_incoming
    ON connections (addressee_id, requested_at DESC, id DESC) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_conn_pending_outgoing
    ON connections (requester_id, requested_at DESC, id DESC) WHERE status = 'PENDING';
