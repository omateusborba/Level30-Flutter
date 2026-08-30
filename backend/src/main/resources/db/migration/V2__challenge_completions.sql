-- F1 · Histórico de conclusões. Cada dia concluído vira um evento imutável.
-- A constraint uq_completion_por_dia é a defesa de BANCO contra dia duplicado,
-- complementando a validação de service (409) que já existe.
-- Registros anteriores a esta versão são reconstruídos aproximadamente por
-- CompletionBackfill (Java) no primeiro boot após o deploy.

CREATE TABLE challenge_completions (
    id            UUID PRIMARY KEY,
    challenge_id  UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day_number    INTEGER NOT NULL,
    completed_on  DATE NOT NULL,
    note          TEXT,
    xp_delta      INTEGER NOT NULL,
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_completion_por_dia UNIQUE (challenge_id, completed_on)
);

CREATE INDEX idx_completions_challenge ON challenge_completions (challenge_id);
CREATE INDEX idx_completions_user_data ON challenge_completions (user_id, completed_on);
