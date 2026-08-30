CREATE TABLE users (
    id              UUID PRIMARY KEY,
    email           VARCHAR(255) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    total_xp        INTEGER NOT NULL DEFAULT 0,
    avatar          TEXT,
    role            VARCHAR(20) NOT NULL DEFAULT 'USER',
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE challenges (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title             VARCHAR(255) NOT NULL,
    category          VARCHAR(20) NOT NULL,
    description       TEXT NOT NULL,
    total_days        INTEGER NOT NULL,
    current_day       INTEGER NOT NULL DEFAULT 0,
    xp_reward         INTEGER NOT NULL,
    streak            INTEGER NOT NULL DEFAULT 0,
    last_activity_at  TIMESTAMP WITH TIME ZONE,
    created_at        TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX idx_challenges_user ON challenges (user_id);
