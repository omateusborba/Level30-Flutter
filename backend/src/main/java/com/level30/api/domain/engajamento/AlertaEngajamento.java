package com.level30.api.domain.engajamento;

import java.math.BigDecimal;
import java.time.Instant;

/** Fase 6 — uma linha de {@code l30_alerts} (Oracle), com o nome do aluno já resolvido. */
public record AlertaEngajamento(
        long id,
        String userId,
        String nomeUsuario,
        String challengeId,
        String tipo,
        String severidade,
        String mensagem,
        BigDecimal valorMedido,
        boolean resolvido,
        Instant criadoEm
) {
}
