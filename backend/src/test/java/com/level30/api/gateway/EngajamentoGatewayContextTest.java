package com.level30.api.gateway;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.level30.api.service.EngajamentoEventListener;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.NoSuchBeanDefinitionException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.ActiveProfiles;

/**
 * Fase 6 — com {@code level30.oracle.enabled=false} (o padrão — não sobrescrito em
 * {@code application-test.yml}, de propósito, para provar isto), a aplicação sobe normalmente, o
 * gateway ativo é o desabilitado, e o {@link EngajamentoEventListener} nem é registrado como bean
 * — nada fica ouvindo {@code DesafioConcluidoEvent}, então não há log de "Conclusão replicada no
 * Oracle" quando nada foi replicado de fato.
 */
@SpringBootTest
@ActiveProfiles("test")
class EngajamentoGatewayContextTest {

    @Autowired
    private EngajamentoGateway engajamentoGateway;

    @Autowired
    private ApplicationContext context;

    @Test
    void comOracleDesligado_oGatewayAtivoEODesabilitado() {
        assertThat(engajamentoGateway).isInstanceOf(EngajamentoDesabilitadoGateway.class);
    }

    @Test
    void comOracleDesligado_oListenerDeEventoNaoEhRegistrado() {
        assertThatThrownBy(() -> context.getBean(EngajamentoEventListener.class))
                .isInstanceOf(NoSuchBeanDefinitionException.class);
    }
}
