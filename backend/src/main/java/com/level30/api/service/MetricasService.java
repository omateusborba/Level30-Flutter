package com.level30.api.service;

import com.level30.api.domain.Leveling;
import com.level30.api.domain.model.Achievement;
import com.level30.api.domain.model.RiskLevel;
import com.level30.api.dto.response.Metricas;
import com.level30.api.repository.ChallengeCompletionRepository;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.RiskSnapshotRepository;
import com.level30.api.repository.UserAchievementRepository;
import com.level30.api.repository.UserRepository;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** B1 — agregações para os dashboards. Tudo consulta agregada; nada de findAll de entidade. */
@Service
@Transactional(readOnly = true)
public class MetricasService {

    private static final int MAX_DIA_SOBREVIVENCIA = 30;
    private static final int SEMANAS_RETENCAO = 8;

    private final ChallengeRepository challenges;
    private final ChallengeCompletionRepository completions;
    private final UserRepository users;
    private final UserAchievementRepository achievements;
    private final RiskSnapshotRepository snapshots;

    public MetricasService(ChallengeRepository challenges, ChallengeCompletionRepository completions,
                           UserRepository users, UserAchievementRepository achievements,
                           RiskSnapshotRepository snapshots) {
        this.challenges = challenges;
        this.completions = completions;
        this.users = users;
        this.achievements = achievements;
        this.snapshots = snapshots;
    }

    // ---- B2 · Engajamento ----

    public List<Metricas.Dia> engajamento(int dias) {
        LocalDate hoje = LocalDate.now(ChallengeService.ZONE);
        LocalDate desde = hoje.minusDays(Math.max(1, dias) - 1L);

        Map<LocalDate, Long> concl = mapDia(completions.conclusoesPorDia(desde));
        Map<LocalDate, Long> ativos = mapDia(completions.usuariosAtivosPorDia(desde));
        Map<LocalDate, Long> xp = mapDia(completions.xpPorDia(desde));

        Map<LocalDate, Long> novos = new HashMap<>();
        for (var instante : challenges.createdAtSince(desde.atStartOfDay(ChallengeService.ZONE).toInstant())) {
            novos.merge(LocalDate.ofInstant(instante, ChallengeService.ZONE), 1L, Long::sum);
        }

        List<Metricas.Dia> out = new ArrayList<>();
        for (LocalDate d = desde; !d.isAfter(hoje); d = d.plusDays(1)) {
            out.add(new Metricas.Dia(d,
                    concl.getOrDefault(d, 0L),
                    ativos.getOrDefault(d, 0L),
                    novos.getOrDefault(d, 0L),
                    xp.getOrDefault(d, 0L)));
        }
        return out;
    }

    public List<Metricas.Sobrevivencia> sobrevivencia() {
        Map<Integer, Long> porDiaAtual = new HashMap<>();
        long total = 0;
        for (var v : challenges.contagemPorDiaAtual()) {
            int dia = ((Number) v.getChave()).intValue();
            porDiaAtual.merge(dia, v.getQuantidade(), Long::sum);
            total += v.getQuantidade();
        }
        List<Metricas.Sobrevivencia> out = new ArrayList<>();
        for (int n = 0; n <= MAX_DIA_SOBREVIVENCIA; n++) {
            long restantes = 0;
            for (var e : porDiaAtual.entrySet()) {
                if (e.getKey() >= n) {
                    restantes += e.getValue();
                }
            }
            double pct = total == 0 ? 0.0 : round1(restantes * 100.0 / total);
            out.add(new Metricas.Sobrevivencia(n, restantes, pct));
        }
        return out;
    }

    public List<Metricas.Coorte> retencao() {
        // usuário -> semana (segunda-feira) de cadastro
        Map<UUID, LocalDate> coorteDoUsuario = new HashMap<>();
        Map<LocalDate, List<UUID>> coortes = new TreeMap<>();
        for (var c : users.cadastrosDeEstudantes()) {
            LocalDate semana = segundaFeira(LocalDate.ofInstant(c.getCriadoEm(), ChallengeService.ZONE));
            coorteDoUsuario.put(c.getId(), semana);
            coortes.computeIfAbsent(semana, k -> new ArrayList<>()).add(c.getId());
        }

        // usuário -> conjunto de semanas com atividade
        Map<UUID, java.util.Set<LocalDate>> semanasAtivas = new HashMap<>();
        for (var v : completions.todasConclusoes()) {
            semanasAtivas.computeIfAbsent(v.getUserId(), k -> new java.util.HashSet<>())
                    .add(segundaFeira(v.getData()));
        }

        List<Metricas.Coorte> out = new ArrayList<>();
        for (var entry : coortes.entrySet()) {
            LocalDate semana0 = entry.getKey();
            List<UUID> membros = entry.getValue();
            List<Double> ret = new ArrayList<>();
            for (int w = 0; w < SEMANAS_RETENCAO; w++) {
                LocalDate alvo = semana0.plusWeeks(w);
                if (alvo.isAfter(segundaFeira(LocalDate.now(ChallengeService.ZONE)))) {
                    break;
                }
                long ativos = membros.stream()
                        .filter(u -> semanasAtivas.getOrDefault(u, java.util.Set.of()).contains(alvo))
                        .count();
                ret.add(round1(membros.isEmpty() ? 0.0 : ativos * 100.0 / membros.size()));
            }
            out.add(new Metricas.Coorte(semana0, membros.size(), ret));
        }
        return out;
    }

    // ---- B3 · Risco no tempo ----

    public List<Metricas.RiscoDia> riscoNoTempo(int dias) {
        LocalDate desde = LocalDate.now(ChallengeService.ZONE).minusDays(Math.max(1, dias) - 1L);
        List<Metricas.RiscoDia> out = new ArrayList<>();
        for (var s : snapshots.findBySnapshotOnGreaterThanEqualOrderBySnapshotOnAsc(desde)) {
            out.add(new Metricas.RiscoDia(s.getSnapshotOn(), s.getLow(), s.getMedium(),
                    s.getHigh(), s.getCritical()));
        }
        if (out.isEmpty()) {
            // nenhum snapshot ainda — devolve a foto de hoje calculada na hora
            Map<RiskLevel, Long> dist = new HashMap<>();
            for (var v : challenges.contagemPorRisco()) {
                dist.merge((RiskLevel) v.getChave(), v.getQuantidade(), Long::sum);
            }
            out.add(new Metricas.RiscoDia(LocalDate.now(ChallengeService.ZONE),
                    (int) (long) dist.getOrDefault(RiskLevel.LOW, 0L),
                    (int) (long) dist.getOrDefault(RiskLevel.MEDIUM, 0L),
                    (int) (long) dist.getOrDefault(RiskLevel.HIGH, 0L),
                    (int) (long) dist.getOrDefault(RiskLevel.CRITICAL, 0L)));
        }
        return out;
    }

    // ---- B4 · Gamificação ----

    public Metricas.Gamificacao gamificacao() {
        Map<String, Long> conquistasPorId = new HashMap<>();
        for (var v : achievements.contagemPorAchievement()) {
            conquistasPorId.put(v.getChave(), v.getQuantidade());
        }
        List<Metricas.Nomeada> conquistas = new ArrayList<>();
        for (Achievement a : Achievement.values()) {
            conquistas.add(new Metricas.Nomeada(a.id(), a.nome(),
                    conquistasPorId.getOrDefault(a.id(), 0L)));
        }
        conquistas.sort((x, y) -> Long.compare(y.quantidade(), x.quantidade()));

        Map<Integer, Long> niveis = new TreeMap<>();
        for (int xp : users.xpDosEstudantes()) {
            niveis.merge(Leveling.level(xp), 1L, Long::sum);
        }
        List<Metricas.NivelContagem> niveisOut = niveis.entrySet().stream()
                .map(e -> new Metricas.NivelContagem(e.getKey(), e.getValue()))
                .toList();

        long[] faixas = new long[5]; // 1-3, 4-7, 8-14, 15-30, 30+
        for (var v : challenges.contagemPorStreak()) {
            int streak = ((Number) v.getChave()).intValue();
            long q = v.getQuantidade();
            if (streak <= 0) {
                continue;
            } else if (streak <= 3) {
                faixas[0] += q;
            } else if (streak <= 7) {
                faixas[1] += q;
            } else if (streak <= 14) {
                faixas[2] += q;
            } else if (streak <= 30) {
                faixas[3] += q;
            } else {
                faixas[4] += q;
            }
        }
        List<Metricas.Faixa> streaksOut = List.of(
                new Metricas.Faixa("1-3", faixas[0]),
                new Metricas.Faixa("4-7", faixas[1]),
                new Metricas.Faixa("8-14", faixas[2]),
                new Metricas.Faixa("15-30", faixas[3]),
                new Metricas.Faixa("30+", faixas[4]));

        return new Metricas.Gamificacao(conquistas, niveisOut, streaksOut, users.somaTotalXp());
    }

    // ---- B4/B6 · Padrões ----

    public Metricas.Padroes padroes() {
        long[] porDiaSemana = new long[7]; // 0 = segunda
        long[] porHora = new long[24];
        for (var v : completions.paraPadroes()) {
            porDiaSemana[v.getData().getDayOfWeek().getValue() - 1]++;
            int hora = v.getInstante().atZone(ChallengeService.ZONE).getHour();
            porHora[hora]++;
        }
        return new Metricas.Padroes(porDiaSemana, porHora);
    }

    // ---- helpers ----

    private Map<LocalDate, Long> mapDia(List<ChallengeCompletionRepository.AtividadeDiaView> rows) {
        Map<LocalDate, Long> m = new HashMap<>();
        for (var r : rows) {
            m.put(r.getData(), r.getQuantidade());
        }
        return m;
    }

    private LocalDate segundaFeira(LocalDate d) {
        return d.minusDays((long) d.getDayOfWeek().getValue() - 1);
    }

    private double round1(double v) {
        return Math.round(v * 10.0) / 10.0;
    }
}
