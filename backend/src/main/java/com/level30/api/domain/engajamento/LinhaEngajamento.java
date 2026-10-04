package com.level30.api.domain.engajamento;

import java.math.BigDecimal;

/** Fase 6 — uma linha do relatório de engajamento (um aluno, num período). */
public record LinhaEngajamento(
        String userId,
        String nome,
        int desafiosAtivos,
        int conclusoes,
        BigDecimal adesaoPercentual,
        int streakAtual,
        String faixa
) {
}
