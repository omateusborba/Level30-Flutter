package com.level30.api.demo;

import static org.assertj.core.api.Assertions.assertThat;

import com.level30.api.demo.DemoPlan.AlunoPlan;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

/** O plano da demo (puro): determinístico, coerente consigo mesmo e com o roteiro de gravação. */
class DemoPlanTest {

    private static final LocalDate HOJE = LocalDate.of(2026, 10, 28);
    private static final Instant AGORA = HOJE.atTime(15, 0).atZone(DemoPlan.ZONE).toInstant();

    private final List<AlunoPlan> plano = DemoPlan.gerar(HOJE, AGORA);

    @Test
    void mesmaEntradaGeraMesmoPlanoEMesmosIds() {
        List<AlunoPlan> outra = DemoPlan.gerar(HOJE, AGORA);
        assertThat(outra).isEqualTo(plano);
        assertThat(plano.stream().map(AlunoPlan::id).distinct()).hasSameSizeAs(plano);
    }

    @Test
    void temDezesseisAlunosComOsTresDoApp_eNomesAcentuados() {
        assertThat(plano).hasSize(16);
        assertThat(plano).extracting(AlunoPlan::nome).contains("Ana Souza", "Bruno Lima", "Carla Dias", "João Pedro Melo", "Natália Ribeiro");
        assertThat(plano.stream().flatMap(a -> a.desafios().stream()).map(d -> d.titulo()))
                .contains("Meditação", "Leitura diária", "Revisão de cálculo");
    }

    @Test
    void historicoDeNoventaDias_comConclusoesDeHojeEDestaSemana() {
        var todas = plano.stream().flatMap(a -> a.desafios().stream()).flatMap(d -> d.conclusoes().stream()).toList();
        assertThat(todas.stream().map(c -> c.data()).min(LocalDate::compareTo).orElseThrow()).isBefore(HOJE.minusDays(60));
        assertThat(todas.stream().filter(c -> c.data().equals(HOJE))).isNotEmpty();
        assertThat(todas.stream().filter(c -> !c.data().isBefore(HOJE.minusDays(6)))).hasSizeGreaterThan(20);
        assertThat(todas.stream().allMatch(c -> !c.data().isAfter(HOJE) && !c.instante().isAfter(AGORA))).isTrue();
    }

    @Test
    void todoDesafioTemAoMenosUmaConclusao_eDiasSaoSequenciais() {
        for (AlunoPlan a : plano) {
            for (var d : a.desafios()) {
                assertThat(d.conclusoes()).as(a.nome() + " / " + d.titulo()).isNotEmpty();
                for (int i = 0; i < d.conclusoes().size(); i++) {
                    assertThat(d.conclusoes().get(i).dia()).isEqualTo(i + 1);
                }
                assertThat(d.conclusoes().size()).isLessThanOrEqualTo(DemoPlan.DIAS_DESAFIO);
            }
        }
    }

    @Test
    void xpDoAlunoEASomaDasConclusoes_eTemVariedade() {
        for (AlunoPlan a : plano) {
            int soma = a.desafios().stream().mapToInt(d -> d.conclusoes().stream().mapToInt(c -> d.xpDoDia(c.dia())).sum()).sum();
            assertThat(a.xpTotal()).isEqualTo(soma);
        }
        assertThat(plano.stream().mapToInt(AlunoPlan::xpTotal).max().orElse(0)).isGreaterThan(1000);
        assertThat(plano.stream().filter(a -> a.xpTotal() > 0)).hasSize(16);
    }

    @Test
    void alunoDoRoteiro_comecaAbaixoDe50PorCento_e1ConclusaoHojePassaDaMeta() {
        AlunoPlan larissa = plano.stream().filter(a -> a.email().equals(DemoPlan.EMAIL_ALUNO_DO_ROTEIRO)).findFirst().orElseThrow();
        var d = larissa.desafios().get(0);
        assertThat(larissa.desafios()).hasSize(1);
        assertThat(d.inicio()).isEqualTo(HOJE.minusDays(29));
        assertThat(d.conclusoes()).hasSize(14);                      // 14/30 = 46,7 % < 50
        assertThat(d.conclusoes().stream().noneMatch(c -> c.data().equals(HOJE))).isTrue();
        assertThat((d.conclusoes().size() + 1) * 100.0 / 30).isGreaterThanOrEqualTo(50.0);   // 15/30 = 50 %
        assertThat(d.conclusoes().size() * 100.0 / 30).isLessThan(50.0);
    }
}
