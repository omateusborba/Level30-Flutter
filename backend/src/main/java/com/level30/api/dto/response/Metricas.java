package com.level30.api.dto.response;

import java.time.LocalDate;
import java.util.List;

/** B1/B2/B3/B4 — respostas dos endpoints {@code /admin/metricas/*}. */
public final class Metricas {

    private Metricas() {
    }

    /** Série diária de engajamento (B2). */
    public record Dia(
            LocalDate data,
            long conclusoes,
            long usuariosAtivos,
            long novosDesafios,
            long xpGanho
    ) {
    }

    /** Curva de sobrevivência: % de desafios que chegaram (ou passaram) ao dia N (B2). */
    public record Sobrevivencia(int dia, long restantes, double pct) {
    }

    /** Uma coorte de retenção: usuários cadastrados na mesma semana (B2). */
    public record Coorte(LocalDate semana, int tamanho, List<Double> retencao) {
    }

    /** Distribuição de risco num dia (B3). */
    public record RiscoDia(LocalDate data, int low, int medium, int high, int critical) {
    }

    public record Nomeada(String id, String nome, long quantidade) {
    }

    public record Faixa(String faixa, long quantidade) {
    }

    public record NivelContagem(int nivel, long quantidade) {
    }

    /** Painel de gamificação (B4). */
    public record Gamificacao(
            List<Nomeada> conquistas,
            List<NivelContagem> niveis,
            List<Faixa> streaks,
            long xpTotalPrograma
    ) {
    }

    /** Padrões de conclusão do programa (B4/B6). */
    public record Padroes(long[] porDiaSemana, long[] porHora) {
    }
}
