package com.level30.api.exception;

/**
 * A1 — conta temporariamente bloqueada por tentativas de login falhas.
 * Vira HTTP 429 com header {@code Retry-After}.
 */
public class ContaBloqueadaException extends RuntimeException {

    private final long retryAfterSeconds;

    public ContaBloqueadaException(long retryAfterSeconds) {
        super("Muitas tentativas. Tente novamente mais tarde.");
        this.retryAfterSeconds = Math.max(1, retryAfterSeconds);
    }

    public long getRetryAfterSeconds() {
        return retryAfterSeconds;
    }
}
