-- A1 · Protecao contra forca bruta. Lockout progressivo por conta.
-- failed_attempts zera a cada login bem-sucedido; locked_until segura a conta
-- ate o horario indicado. O rate limit por IP e em memoria (nao persiste aqui).

ALTER TABLE users ADD COLUMN failed_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN locked_until    TIMESTAMP WITH TIME ZONE;
