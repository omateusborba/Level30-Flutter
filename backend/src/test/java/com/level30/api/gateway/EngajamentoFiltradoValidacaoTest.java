package com.level30.api.gateway;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.level30.api.controller.AdminEngajamentoController;
import com.level30.api.domain.engajamento.DirecaoOrdenacao;
import com.level30.api.domain.engajamento.FiltroEngajamento;
import com.level30.api.domain.engajamento.OrdenacaoEngajamento;
import com.level30.api.exception.RegraNegocioException;
import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;

/** Fase 7 — validação em Java (defesa em profundidade) antes de qualquer chamada ao Oracle. Sem Docker. */
class EngajamentoFiltradoValidacaoTest {

    private final EngajamentoGateway gateway = Mockito.mock(EngajamentoGateway.class);
    private final AdminEngajamentoController controller = new AdminEngajamentoController(gateway);

    @Test
    void ordenacao_aceitaSoWhitelist_ignorandoCaixa() {
        assertThat(OrdenacaoEngajamento.de("streak")).isEqualTo(OrdenacaoEngajamento.STREAK);
        assertThat(OrdenacaoEngajamento.de(null)).isEqualTo(OrdenacaoEngajamento.ADESAO);
        assertThat(DirecaoOrdenacao.de(" asc ")).isEqualTo(DirecaoOrdenacao.ASC);
        assertThat(DirecaoOrdenacao.de("")).isEqualTo(DirecaoOrdenacao.DESC);
    }

    @Test
    void ordenacao_rejeitaInjecao() {
        assertThatThrownBy(() -> OrdenacaoEngajamento.de("NOME; DROP TABLE l30_users"))
                .isInstanceOf(RegraNegocioException.class);
        assertThatThrownBy(() -> DirecaoOrdenacao.de("DESC, (SELECT 1 FROM dual)"))
                .isInstanceOf(RegraNegocioException.class);
    }

    @Test
    void controller_repassaFiltroValidadoAoGateway() {
        Mockito.when(gateway.consultarEngajamento(Mockito.any())).thenReturn(List.of());

        controller.engajamentoFiltrado(null, null, 2, BigDecimal.valueOf(50), "nome", "asc");

        ArgumentCaptor<FiltroEngajamento> captor = ArgumentCaptor.forClass(FiltroEngajamento.class);
        Mockito.verify(gateway).consultarEngajamento(captor.capture());
        assertThat(captor.getValue().ordenarPor()).isEqualTo(OrdenacaoEngajamento.NOME);
        assertThat(captor.getValue().direcao()).isEqualTo(DirecaoOrdenacao.ASC);
        assertThat(captor.getValue().nivelMin()).isEqualTo(2);
    }

    @Test
    void controller_rejeitaParametrosInvalidosSemTocarNoGateway() {
        assertThatThrownBy(() -> controller.engajamentoFiltrado(null, null, null, null, "X; DROP", null))
                .isInstanceOf(RegraNegocioException.class);
        assertThatThrownBy(() -> controller.engajamentoFiltrado(null, null, 0, null, null, null))
                .isInstanceOf(RegraNegocioException.class);
        assertThatThrownBy(() -> controller.engajamentoFiltrado(null, null, null, BigDecimal.valueOf(101), null, null))
                .isInstanceOf(RegraNegocioException.class);
        assertThatThrownBy(() -> controller.auditoria(0)).isInstanceOf(RegraNegocioException.class);
        assertThatThrownBy(() -> controller.auditoria(501)).isInstanceOf(RegraNegocioException.class);
        Mockito.verifyNoInteractions(gateway);
    }
}
