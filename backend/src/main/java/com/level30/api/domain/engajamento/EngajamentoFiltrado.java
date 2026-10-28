package com.level30.api.domain.engajamento;

import java.math.BigDecimal;

/** Fase 7 — uma linha de {@code PKG_L30_CONSULTAS.FN_ENGAJAMENTO_FILTRADO}. */
public record EngajamentoFiltrado(
        String userId,
        String nome,
        int totalXp,
        int nivel,
        int streak,
        int conclusoes,
        BigDecimal adesaoPercentual,
        String faixa
) {
}
