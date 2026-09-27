-- Stream chosen in Class 11-12 (Science Medical / Non-Medical / PCMB, Commerce, Arts).
-- Only meaningful for entries that reach Class 11 or 12, so it is nullable.
-- Stored as text with a check constraint (not a Postgres enum) so JPQL parameters bind cleanly.
ALTER TABLE user_school_history ADD COLUMN IF NOT EXISTS stream VARCHAR(30);

ALTER TABLE user_school_history DROP CONSTRAINT IF EXISTS chk_school_history_stream;
ALTER TABLE user_school_history ADD CONSTRAINT chk_school_history_stream CHECK (
    stream IS NULL OR stream IN (
        'SCIENCE_MEDICAL', 'SCIENCE_NON_MEDICAL', 'SCIENCE_PCMB', 'COMMERCE', 'ARTS'
    )
);
