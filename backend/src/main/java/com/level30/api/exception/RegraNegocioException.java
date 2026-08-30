package com.level30.api.exception;

import org.springframework.http.HttpStatus;

/** Violação de regra de negócio. Carrega o status HTTP adequado (400 ou 409). */
public class RegraNegocioException extends RuntimeException {

    private final HttpStatus status;

    public RegraNegocioException(String mensagem) {
        this(mensagem, HttpStatus.BAD_REQUEST);
    }

    public RegraNegocioException(String mensagem, HttpStatus status) {
        super(mensagem);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }
}
