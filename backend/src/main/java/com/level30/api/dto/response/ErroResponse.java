package com.level30.api.dto.response;

import java.time.Instant;
import java.util.List;

/**
 * Contrato de erro único da API. Todo erro — validação, regra de negócio,
 * autenticação, 404, 500 — sai neste formato. Nunca expõe stack trace.
 *
 * <p>O app consome {@code error} do Worker atual; mantemos {@code mensagem}
 * e adicionamos um alias {@code error} para compatibilidade com o
 * {@code ApiClient._handle} do Flutter, que lê {@code body['error']}.
 */
public record ErroResponse(
        int status,
        String error,
        String mensagem,
        List<String> detalhes,
        Instant timestamp
) {
    public static ErroResponse of(int status, String mensagem, List<String> detalhes) {
        return new ErroResponse(status, mensagem, mensagem,
                detalhes == null ? List.of() : detalhes, Instant.now());
    }

    public static ErroResponse of(int status, String mensagem) {
        return of(status, mensagem, List.of());
    }
}
