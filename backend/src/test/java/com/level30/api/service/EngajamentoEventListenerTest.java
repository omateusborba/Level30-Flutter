package com.level30.api.service;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.level30.api.domain.event.DesafioConcluidoEvent;
import com.level30.api.gateway.EngajamentoGateway;
import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * Fase 6 — {@link EngajamentoEventListener} isolado (sem Spring context): chama o gateway, e uma
 * falha do gateway nunca deve propagar (regra: Oracle nunca derruba a conclusão do aluno, que já
 * aconteceu antes deste listener rodar).
 */
@ExtendWith(MockitoExtension.class)
class EngajamentoEventListenerTest {

    @Mock
    private EngajamentoGateway engajamentoGateway;

    private final DesafioConcluidoEvent evento = new DesafioConcluidoEvent(
            UUID.randomUUID(), "Ana Souza", 1250,
            UUID.randomUUID(), "Ler 20 páginas por dia",
            LocalDate.of(2026, 9, 1), 12, 4,
            LocalDate.of(2026, 9, 12), 42);

    @Test
    void chamaOGatewayComOEvento() {
        EngajamentoEventListener listener = new EngajamentoEventListener(engajamentoGateway);

        listener.aoConcluirDesafio(evento);

        verify(engajamentoGateway).registrarConclusao(evento);
    }

    @Test
    void excecaoNoGateway_naoPropaga() {
        when(engajamentoGateway.registrarConclusao(evento))
                .thenThrow(new RuntimeException("Oracle fora do ar"));
        EngajamentoEventListener listener = new EngajamentoEventListener(engajamentoGateway);

        assertThatCode(() -> listener.aoConcluirDesafio(evento)).doesNotThrowAnyException();
    }
}
