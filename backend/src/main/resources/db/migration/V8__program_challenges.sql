-- C3 · Desafios do programa (F3). A coordenacao publica modelos de desafio;
-- o estudante adota um modelo e ganha um desafio pessoal (linha em challenges).
-- Resolve a ambiguidade do form de /admin (achado D6).

CREATE TABLE program_challenges (
    id           UUID PRIMARY KEY,
    title        VARCHAR(255) NOT NULL,
    category     VARCHAR(20) NOT NULL,
    description  TEXT NOT NULL,
    total_days   INTEGER NOT NULL,
    xp_reward    INTEGER NOT NULL,
    active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_by   UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL
);

-- de qual modelo o desafio pessoal veio (null = criado do zero pelo aluno)
ALTER TABLE challenges ADD COLUMN program_challenge_id UUID
    REFERENCES program_challenges(id) ON DELETE SET NULL;

CREATE INDEX idx_challenges_program ON challenges (program_challenge_id);
