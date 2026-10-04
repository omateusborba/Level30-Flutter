package com.level30.api.config;

import com.level30.api.gateway.EngajamentoGateway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Fase 6 — chama {@code pr_verificar_inatividade} diariamente. Só existe quando a camada Oracle
 * está ligada <strong>e</strong> este agendamento foi explicitamente ativado
 * ({@code level30.oracle.inatividade.agendamento-ativo=true}) — desligado por padrão para não
 * duplicar o {@code DBMS_SCHEDULER} do próprio Oracle (ver {@code db/oracle/05_job_opcional.sql}),
 * caso ele já esteja agendado lá.
 */
@Component
@ConditionalOnExpression(
        "${level30.oracle.enabled:false} and ${level30.oracle.inatividade.agendamento-ativo:false}")
public class OracleInatividadeScheduler {

    private static final Logger log = LoggerFactory.getLogger(OracleInatividadeScheduler.class);

    private final EngajamentoGateway engajamentoGateway;
    private final int diasLimite;

    public OracleInatividadeScheduler(EngajamentoGateway engajamentoGateway,
                                      @Value("${level30.oracle.inatividade.dias-limite:3}") int diasLimite) {
        this.engajamentoGateway = engajamentoGateway;
        this.diasLimite = diasLimite;
    }

    @Scheduled(cron = "${level30.oracle.inatividade.cron}", zone = "America/Sao_Paulo")
    public void verificar() {
        try {
            int alertas = engajamentoGateway.verificarInatividade(diasLimite);
            log.info("OracleInatividadeScheduler: {} alertas gerados (limite={} dias).", alertas, diasLimite);
        } catch (RuntimeException e) {
            log.warn("OracleInatividadeScheduler: falha ao verificar inatividade.", e);
        }
    }
}
