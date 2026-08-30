package com.level30.api.exception;

/** 404 — recurso inexistente ou fora do escopo de posse do usuário. */
public class RecursoNaoEncontradoException extends RuntimeException {
    public RecursoNaoEncontradoException(String mensagem) {
        super(mensagem);
    }
}
