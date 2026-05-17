CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE user_status AS ENUM ('STUDENT', 'ALUMNI');

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username        VARCHAR(50) UNIQUE NOT NULL,
    full_name       VARCHAR(100) NOT NULL,
    phone           VARCHAR(15) UNIQUE NOT NULL,
    email           VARCHAR(100) UNIQUE,
    dob             DATE,
    profile_pic_url TEXT,
    bio             TEXT,
    city            VARCHAR(100),
    website_url     TEXT,
    current_status  user_status DEFAULT 'STUDENT',
    profession      VARCHAR(150),
    fcm_token       TEXT,
    is_verified     BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_email ON users(email);
