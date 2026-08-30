-- A2 · Ciclo de vida do refresh token: rotacao com deteccao de reuso.
-- Cada POST /auth/refresh invalida o token usado e emite outro na mesma family_id.
-- Reusar um token ja marcado (used_at) => comprometimento => revoga a familia inteira.

CREATE TABLE refresh_tokens (
    jti         UUID PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    family_id   UUID NOT NULL,
    issued_at   TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at     TIMESTAMP WITH TIME ZONE,
    revoked_at  TIMESTAMP WITH TIME ZONE,
    user_agent  VARCHAR(255),
    ip          VARCHAR(64)
);

CREATE INDEX idx_refresh_family ON refresh_tokens (family_id);
CREATE INDEX idx_refresh_user ON refresh_tokens (user_id);
