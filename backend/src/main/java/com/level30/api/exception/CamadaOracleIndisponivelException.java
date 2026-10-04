package com.level30.api.exception;

/**
 * Fase 6 — a camada Oracle (engajamento) está desligada neste ambiente, ou o banco Oracle não
 * respondeu. Vira HTTP 503: é uma falha de infraestrutura, não do pedido do cliente.
 */
public class CamadaOracleIndisponivelException extends RuntimeException {
    public CamadaOracleIndisponivelException(String mensagem) {
        super(mensagem);
    }

    public CamadaOracleIndisponivelException(String mensagem, Throwable causa) {
        super(mensagem, causa);
    }
}
