package com.level30.api.domain.engajamento;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * Fase 6 — resultado de uma execução de {@code pr_gerar_relatorio_engajamento} (Oracle): uma
 * linha por aluno, mais a contagem por faixa (ALTO/MODERADO/EM_RISCO/CRITICO/SEM_DESAFIO) pronta
 * para os cards do dashboard.
 */
public record RelatorioEngajamento(
        long execucaoId,
        LocalDate periodoInicio,
        LocalDate periodoFim,
        Map<String, Long> contagemPorFaixa,
        List<LinhaEngajamento> linhas
) {
}
