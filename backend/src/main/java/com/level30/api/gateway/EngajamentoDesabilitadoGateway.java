package com.level30.api.gateway;

import com.level30.api.domain.engajamento.AlertaEngajamento;
import com.level30.api.domain.engajamento.RelatorioEngajamento;
import com.level30.api.domain.engajamento.ResumoEngajamentoUsuario;
import com.level30.api.domain.event.DesafioConcluidoEvent;
import com.level30.api.exception.CamadaOracleIndisponivelException;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Fase 6 — adapter ativo quando {@code level30.oracle.enabled} é {@code false} (o padrão, e o que
 * roda hoje em produção). Escrita é um no-op silencioso (a conclusão do dia nunca falha por causa
 * do Oracle); leitura recusa com {@link CamadaOracleIndisponivelException} → 503.
 */
@Component
@ConditionalOnProperty(prefix = "level30.oracle", name = "enabled", havingValue = "false", matchIfMissing = true)
public class EngajamentoDesabilitadoGateway implements EngajamentoGateway {

    private static final String MSG = "Camada Oracle desabilitada neste ambiente.";

    @Override
    public int registrarConclusao(DesafioConcluidoEvent evento) {
        return 0;
    }

    @Override
    public int verificarInatividade(int diasLimite) {
        throw new CamadaOracleIndisponivelException(MSG);
    }

    @Override
    public RelatorioEngajamento gerarRelatorio(LocalDate inicio, LocalDate fim) {
        throw new CamadaOracleIndisponivelException(MSG);
    }

    @Override
    public RelatorioEngajamento buscarRelatorio(long execucaoId) {
        throw new CamadaOracleIndisponivelException(MSG);
    }

    @Override
    public List<AlertaEngajamento> listarAlertas(boolean somenteAbertos) {
        throw new CamadaOracleIndisponivelException(MSG);
    }

    @Override
    public ResumoEngajamentoUsuario resumoUsuario(UUID userId) {
        throw new CamadaOracleIndisponivelException(MSG);
    }
}
