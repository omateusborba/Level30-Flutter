package com.level30.api.domain.engajamento;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Fase 6 — resumo de um aluno formatado pelo Oracle ({@code fn_resumo_usuario}) junto com a taxa
 * de adesão de 30 dias ({@code fn_taxa_adesao}), as duas functions demonstradas em consulta única.
 */
public record ResumoEngajamentoUsuario(
        UUID userId,
        String resumo,
        BigDecimal taxaAdesao30d
) {
}
