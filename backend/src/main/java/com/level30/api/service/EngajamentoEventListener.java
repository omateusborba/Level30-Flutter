package com.level30.api.service;

import com.level30.api.domain.event.DesafioConcluidoEvent;
import com.level30.api.gateway.EngajamentoGateway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Fase 6 — reage a {@link DesafioConcluidoEvent} replicando a conclusão no Oracle, depois que a
 * transação do PostgreSQL já comitou. Assíncrono e isolado: uma falha ou lentidão do Oracle nunca
 * chega ao aluno que concluiu o dia — ele já recebeu a resposta HTTP antes disso rodar.
 */
@Component
public class EngajamentoEventListener {

    private static final Logger log = LoggerFactory.getLogger(EngajamentoEventListener.class);

    private final EngajamentoGateway engajamentoGateway;

    public EngajamentoEventListener(EngajamentoGateway engajamentoGateway) {
        this.engajamentoGateway = engajamentoGateway;
    }

    @Async("oracleExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void aoConcluirDesafio(DesafioConcluidoEvent evento) {
        try {
            int alertas = engajamentoGateway.registrarConclusao(evento);
            log.info("Conclusão replicada no Oracle: desafio={} dia={} alertas={}",
                    evento.challengeId(), evento.dayNumber(), alertas);
        } catch (RuntimeException e) {
            log.warn("Falha ao replicar conclusão {} no Oracle", evento.challengeId(), e);
        }
    }
}
