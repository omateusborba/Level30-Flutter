package com.level30.api.domain.engajamento;

import java.time.Instant;

/** Fase 7 — uma linha de {@code L30_AUDIT_LOG}; os dados antigos/novos são JSON em texto. */
public record RegistroAuditoria(
        long id,
        String tabela,
        String operacao,
        String registroId,
        String dadosAntigos,
        String dadosNovos,
        String usuarioBanco,
        Instant criadoEm
) {
}
