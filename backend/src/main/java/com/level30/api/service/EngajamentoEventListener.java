package com.level30.api.service;

import com.level30.api.domain.event.DesafioConcluidoEvent;
import com.level30.api.gateway.EngajamentoGateway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Fase 6 — reage a {@link DesafioConcluidoEvent} replicando a conclusão no Oracle, depois que a
 * transação do PostgreSQL já comitou. Assíncrono e isolado: uma falha ou lentidão do Oracle nunca
 * chega ao aluno que concluiu o dia — ele já recebeu a resposta HTTP antes disso rodar.
 *
 * <p>Só existe como bean quando {@code level30.oracle.enabled=true}. Com a camada desligada (o
 * padrão hoje), este listener nem é registrado — o evento é publicado por
 * {@code ChallengeService} e simplesmente não tem ninguém ouvindo, então não há log de sucesso
 * nenhum (evitava um log de "Conclusão replicada no Oracle" quando, na prática, nada foi
 * replicado — o adapter desabilitado é um no-op silencioso).
 */
@Component
@ConditionalOnProperty(prefix = "level30.oracle", name = "enabled", havingValue = "true")
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
