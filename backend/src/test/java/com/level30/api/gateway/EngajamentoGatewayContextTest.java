package com.level30.api.gateway;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * Fase 6 — com {@code level30.oracle.enabled=false} (o padrão — não sobrescrito em
 * {@code application-test.yml}, de propósito, para provar isto), a aplicação sobe normalmente e o
 * gateway ativo é o desabilitado. É o comportamento de produção hoje.
 */
@SpringBootTest
@ActiveProfiles("test")
class EngajamentoGatewayContextTest {

    @Autowired
    private EngajamentoGateway engajamentoGateway;

    @Test
    void comOracleDesligado_oGatewayAtivoEODesabilitado() {
        assertThat(engajamentoGateway).isInstanceOf(EngajamentoDesabilitadoGateway.class);
    }
}
