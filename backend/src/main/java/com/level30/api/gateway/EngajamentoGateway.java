package com.level30.api.gateway;

import com.level30.api.domain.engajamento.AlertaEngajamento;
import com.level30.api.domain.engajamento.RelatorioEngajamento;
import com.level30.api.domain.engajamento.ResumoEngajamentoUsuario;
import com.level30.api.domain.event.DesafioConcluidoEvent;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Fase 6 — porta (Ports &amp; Adapters) para a camada de engajamento Oracle PL/SQL. O domínio só
 * conhece esta interface; quem decide se a implementação fala com o Oracle de verdade ou recusa
 * educadamente é a configuração ({@code level30.oracle.enabled}), via
 * {@link com.level30.api.gateway.OracleEngajamentoGateway} ou
 * {@link com.level30.api.gateway.EngajamentoDesabilitadoGateway}.
 */
public interface EngajamentoGateway {

    /** @return quantos alertas novos a conclusão gerou. */
    int registrarConclusao(DesafioConcluidoEvent evento);

    /** @return quantos alertas de inatividade novos foram criados. */
    int verificarInatividade(int diasLimite);

    RelatorioEngajamento gerarRelatorio(LocalDate inicio, LocalDate fim);

    RelatorioEngajamento buscarRelatorio(long execucaoId);

    List<AlertaEngajamento> listarAlertas(boolean somenteAbertos);

    ResumoEngajamentoUsuario resumoUsuario(UUID userId);
}
