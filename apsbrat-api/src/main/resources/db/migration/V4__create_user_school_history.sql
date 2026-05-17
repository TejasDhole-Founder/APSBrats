CREATE TABLE IF NOT EXISTS user_school_history (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    school_id       UUID        NOT NULL REFERENCES schools(id) ON DELETE RESTRICT,
    class_from      SMALLINT    NOT NULL,
    class_to        SMALLINT    NOT NULL,
    section         VARCHAR(5)  NOT NULL,
    batch_start     SMALLINT    NOT NULL,
    batch_end       SMALLINT    NOT NULL,
    is_primary      BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_class_range CHECK (
        class_from >= 1
        AND class_to <= 12
        AND class_to >= class_from
    ),
    CONSTRAINT chk_batch_range CHECK (
        batch_end >= batch_start
    ),
    CONSTRAINT chk_section_uppercase CHECK (
        section = UPPER(section)
    )
);

CREATE INDEX IF NOT EXISTS idx_school_history_lookup
ON user_school_history(school_id, section, batch_start, batch_end);

CREATE INDEX IF NOT EXISTS idx_school_history_user
ON user_school_history(user_id);
