CREATE TABLE schools (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name         VARCHAR(150) NOT NULL,
    city         VARCHAR(100),
    state        VARCHAR(100),
    cantonment   VARCHAR(100),
    school_code  VARCHAR(20) UNIQUE,
    created_at   TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_schools_name ON schools(LOWER(name));
