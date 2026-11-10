-- One lookup list for companies AND colleges. name_key is the cleaned-up name
-- (lowercase, no "Pvt Ltd" etc.) and is unique per type, so "TCS" typed twice
-- cannot create two companies.
CREATE TABLE IF NOT EXISTS organizations (
                                             id          UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    type        VARCHAR(12)  NOT NULL,
    name        VARCHAR(200) NOT NULL,
    name_key    VARCHAR(200) NOT NULL,
    industry    VARCHAR(60),
    website     VARCHAR(255),
    status      VARCHAR(12)  NOT NULL DEFAULT 'UNVERIFIED',
    created_by  UUID         REFERENCES users(id) ON DELETE SET NULL,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_org_type_key UNIQUE (type, name_key),
    CONSTRAINT chk_org_type    CHECK (type IN ('COMPANY', 'INSTITUTION')),
    CONSTRAINT chk_org_status  CHECK (status IN ('UNVERIFIED', 'VERIFIED'))
    );

-- job_function (Engineering, Medicine, Armed Forces...) is what mentor search filters on.
CREATE TABLE IF NOT EXISTS job_titles (
                                          id            UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    title         VARCHAR(150) NOT NULL,
    title_key     VARCHAR(150) NOT NULL UNIQUE,
    job_function  VARCHAR(60),
    status        VARCHAR(12)  NOT NULL DEFAULT 'UNVERIFIED',
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_job_title_status CHECK (status IN ('UNVERIFIED', 'VERIFIED'))
    );

-- One row per job OR degree. end_date NULL means "still here".
--   WORK:      title = "Senior Engineer",   detail = what I did
--   EDUCATION: title = "B.Tech",            field_of_study = "Computer Science"
CREATE TABLE IF NOT EXISTS career_entries (
                                              id              UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID         NOT NULL REFERENCES users(id)         ON DELETE CASCADE,
    kind            VARCHAR(10)  NOT NULL,
    organization_id UUID         NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    job_title_id    UUID         REFERENCES job_titles(id)             ON DELETE SET NULL,
    title           VARCHAR(150) NOT NULL,
    field_of_study  VARCHAR(100),
    location        VARCHAR(120),
    description     VARCHAR(1000),
    start_date      DATE         NOT NULL,
    end_date        DATE,
    is_hidden       BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_career_kind  CHECK (kind IN ('WORK', 'EDUCATION')),
    CONSTRAINT chk_career_dates CHECK (end_date IS NULL OR end_date >= start_date)
    );

CREATE INDEX IF NOT EXISTS idx_career_user ON career_entries(user_id, start_date DESC);
CREATE INDEX IF NOT EXISTS idx_career_org  ON career_entries(organization_id, kind);

-- Fast "type a few letters" autocomplete (pg_trgm is already enabled by V15).
CREATE INDEX IF NOT EXISTS idx_org_name_trgm    ON organizations USING gin (name_key gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_job_titles_trgm  ON job_titles    USING gin (title_key gin_trgm_ops);