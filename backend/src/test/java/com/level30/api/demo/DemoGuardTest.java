package com.level30.api.demo;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

/** A trava do seed: bancos locais/de demo passam; o PostgreSQL do compose de produção e o Oracle da FIAP, não. */
class DemoGuardTest {

    @Test
    void permiteBancosLocaisEDeDemo() {
        assertThat(DemoGuard.permitido("jdbc:h2:file:./data/level30;AUTO_SERVER=TRUE")).isTrue();
        assertThat(DemoGuard.permitido("jdbc:h2:mem:teste")).isTrue();
        assertThat(DemoGuard.permitido("jdbc:oracle:thin:@//localhost:1521/FREEPDB1")).isTrue();
        assertThat(DemoGuard.permitido("jdbc:postgresql://127.0.0.1:5432/level30")).isTrue();
        assertThat(DemoGuard.permitido("jdbc:postgresql://db-demo.exemplo.com/level30")).isTrue();
    }

    @Test
    void recusaOQueNaoELocalNemDemo() {
        assertThat(DemoGuard.permitido("jdbc:postgresql://postgres:5432/level30")).isFalse();   // compose de produção
        assertThat(DemoGuard.permitido("jdbc:oracle:thin:@//oracle.fiap.com.br:1521/ORCL")).isFalse();
        assertThat(DemoGuard.permitido("")).isFalse();
        assertThat(DemoGuard.permitido(null)).isFalse();
        assertThatThrownBy(() -> DemoGuard.exigir("Oracle", "jdbc:oracle:thin:@//10.0.0.9:1521/ORCL"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Nada foi apagado")
                .hasMessageNotContaining("10.0.0.9");
    }
}
