-- F4 · Conquistas. O catálogo é código (enum Achievement, versionado) — aqui só
-- fica o registro de quem desbloqueou o quê. PK composta impede conceder 2x.

CREATE TABLE user_achievements (
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id VARCHAR(40) NOT NULL,
    unlocked_at    TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (user_id, achievement_id)
);
