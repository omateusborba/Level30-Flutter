package com.level30.api.exception;

/** 502 — o gateway de IA (Cloudflare Worker) falhou e não há fallback textual. */
public class AiIndisponivelException extends RuntimeException {
    public AiIndisponivelException(String mensagem) {
        super(mensagem);
    }
}
