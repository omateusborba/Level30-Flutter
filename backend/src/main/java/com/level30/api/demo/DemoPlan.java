package com.level30.api.demo;

import com.level30.api.domain.model.Category;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;
import java.util.UUID;

/**
 * Plano determinístico da base de demo: quem são os alunos, que desafios têm e em que dias concluíram
 * cada dia. É um objeto puro (sem banco): o {@link DemoSeedService} grava o MESMO plano no PostgreSQL e
 * no Oracle, então pessoas, IDs, XP e históricos são idênticos nos dois lados.
 *
 * <p>Os IDs são derivados do e-mail/posição ({@code UUID.nameUUIDFromBytes}); a mesma data de
 * referência gera sempre o mesmo plano. Todos os desafios têm 30 dias, que é o que a réplica Oracle
 * suporta (dia 1..30).
 */
public final class DemoPlan {

    public static final ZoneId ZONE = ZoneId.of("America/Sao_Paulo");
    public static final int DIAS_DESAFIO = 30;
    public static final String SENHA_DEMO = "estudante1";
    /** Aluno do roteiro: começa abaixo da meta de adesão; 1 conclusão hoje passa de 46,7 % para 50 %. */
    public static final String EMAIL_ALUNO_DO_ROTEIRO = "larissa@level30.app";

    public enum Perfil { ALTA, MODERADA, BAIXA, ABANDONO, RETOMADA, ROTEIRO }

    public record Conclusao(int dia, LocalDate data, Instant instante) { }

    public record DesafioPlan(UUID id, String titulo, Category categoria, String descricao, int xpReward,
                              LocalDate inicio, List<Conclusao> conclusoes) {
        public int diaAtual() { return conclusoes.size(); }

        public boolean concluido() { return conclusoes.size() >= DIAS_DESAFIO; }

        public int streakFinal() { return streakAte(conclusoes.size()); }

        /** Mesma regra de {@code ChallengeService.nextStreak}: ontem + 1, senão reinicia em 1. */
        public int streakAte(int quantas) {
            int streak = 0;
            LocalDate anterior = null;
            for (int i = 0; i < quantas; i++) {
                LocalDate d = conclusoes.get(i).data();
                streak = (anterior != null && anterior.plusDays(1).equals(d)) ? streak + 1 : 1;
                anterior = d;
            }
            return streak;
        }

        /** XP do dia N = earnedXp(N) - earnedXp(N-1), idêntico a {@code Challenge.earnedXp}. */
        public int xpDoDia(int dia) {
            return (int) ((long) dia * xpReward / DIAS_DESAFIO) - (int) ((long) (dia - 1) * xpReward / DIAS_DESAFIO);
        }
    }

    public record AlunoPlan(UUID id, String nome, String email, Perfil perfil, List<DesafioPlan> desafios) {
        public int xpTotal() {
            int xp = 0;
            for (DesafioPlan d : desafios) {
                for (Conclusao c : d.conclusoes()) {
                    xp += d.xpDoDia(c.dia());
                }
            }
            return xp;
        }

        public Instant criadoEm() {
            LocalDate primeiro = desafios.stream().map(DesafioPlan::inicio).min(LocalDate::compareTo).orElseThrow();
            return primeiro.minusDays(1).atTime(9, 0).atZone(ZONE).toInstant();
        }
    }

    private record Roteiro(String nome, String email, Perfil perfil) { }

    private static final List<Roteiro> ELENCO = List.of(
            new Roteiro("Ana Souza", "ana@level30.app", Perfil.ALTA),
            new Roteiro("Bruno Lima", "bruno@level30.app", Perfil.ALTA),
            new Roteiro("Carla Dias", "carla@level30.app", Perfil.MODERADA),
            new Roteiro("Diego Rocha", "diego@level30.app", Perfil.MODERADA),
            new Roteiro("Elisa Castro", "elisa@level30.app", Perfil.ALTA),
            new Roteiro("Felipe Nunes", "felipe@level30.app", Perfil.MODERADA),
            new Roteiro("Gabriela Alves", "gabriela@level30.app", Perfil.ALTA),
            new Roteiro("Henrique Dias", "henrique@level30.app", Perfil.MODERADA),
            new Roteiro("Isabela Prado", "isabela@level30.app", Perfil.BAIXA),
            new Roteiro("João Pedro Melo", "joao@level30.app", Perfil.ALTA),
            new Roteiro("Larissa Freitas", EMAIL_ALUNO_DO_ROTEIRO, Perfil.ROTEIRO),
            new Roteiro("Marcos Vieira", "marcos@level30.app", Perfil.ABANDONO),
            new Roteiro("Natália Ribeiro", "natalia@level30.app", Perfil.BAIXA),
            new Roteiro("Otávio Campos", "otavio@level30.app", Perfil.ABANDONO),
            new Roteiro("Paula Teixeira", "paula@level30.app", Perfil.RETOMADA),
            new Roteiro("Rafael Gomes", "rafael@level30.app", Perfil.ABANDONO));

    private record Modelo(String titulo, Category categoria, String descricao, int xp) { }

    private static final List<Modelo> MODELOS = List.of(
            new Modelo("Leitura diária", Category.STUDY, "Ler 20 páginas por dia", 600),
            new Modelo("Revisão de cálculo", Category.STUDY, "1h de exercícios", 800),
            new Modelo("Estudar Java por 1 hora", Category.STUDY, "Prática de programação", 700),
            new Modelo("Resolver 2 exercícios de SQL", Category.STUDY, "Treino de consultas", 500),
            new Modelo("Corrida matinal", Category.FITNESS, "5 km toda manhã", 600),
            new Modelo("Caminhar 30 minutos", Category.FITNESS, "Caminhada diária", 400),
            new Modelo("Treino de força", Category.FITNESS, "Musculação 3x por semana", 700),
            new Modelo("Meditação", Category.MINDFULNESS, "10 min de respiração", 500),
            new Modelo("Diário de gratidão", Category.MINDFULNESS, "3 itens por dia", 300),
            new Modelo("Beber 2 litros de água", Category.HEALTH, "Hidratação diária", 300),
            new Modelo("Sono regular", Category.HEALTH, "Dormir antes das 23h", 500),
            new Modelo("Pomodoro de foco", Category.PRODUCTIVITY, "4 blocos por dia", 600),
            new Modelo("Planejar o dia", Category.PRODUCTIVITY, "Lista de prioridades pela manhã", 400));

    private DemoPlan() { }

    public static List<AlunoPlan> gerar(LocalDate hoje, Instant agora) {
        List<AlunoPlan> alunos = new ArrayList<>();
        for (Roteiro r : ELENCO) {
            Random rng = new Random(("demo-l30-" + r.email()).hashCode());
            alunos.add(new AlunoPlan(uuid("user", r.email()), r.nome(), r.email(), r.perfil(),
                    desafiosDe(r, rng, hoje, agora)));
        }
        return alunos;
    }

    // ------------------------------------------------------------------ desafios por aluno

    private static List<DesafioPlan> desafiosDe(Roteiro r, Random rng, LocalDate hoje, Instant agora) {
        List<DesafioPlan> out = new ArrayList<>();
        Set<String> usados = new HashSet<>();

        if (r.perfil() == Perfil.ROTEIRO) {
            Modelo m = modelo("Resolver 2 exercícios de SQL");
            // 14 conclusões em dias alternados nos últimos 29 dias, nenhuma hoje
            List<LocalDate> datas = new ArrayList<>();
            for (int off = 29; off >= 3; off -= 2) {
                datas.add(hoje.minusDays(off));
            }
            out.add(desafio(r, 0, m, hoje.minusDays(29), datas, rng, hoje, agora));
            return out;
        }
        if (r.email().equals("ana@level30.app")) {
            out.add(desafio(r, 0, modelo("Meditação"), hoje.minusDays(48), sequencia(hoje.minusDays(48), 30), rng, hoje, agora));
            out.add(desafio(r, 1, modelo("Leitura diária"), hoje.minusDays(16), probabilistico(hoje.minusDays(16), hoje, 0.95, -1, rng), rng, hoje, agora));
            out.add(desafio(r, 2, modelo("Corrida matinal"), hoje.minusDays(8), sequencia(hoje.minusDays(8), 4), rng, hoje, agora));
            return out;
        }

        int[] inicios = switch (r.perfil()) {
            case ALTA -> new int[] {78, 44, 15};
            case MODERADA -> new int[] {60, 24};
            case BAIXA -> new int[] {50, 22};
            case ABANDONO -> new int[] {40, 12};
            case RETOMADA -> new int[] {55, 20};
            case ROTEIRO -> new int[0];
        };
        for (int i = 0; i < inicios.length; i++) {
            Modelo m = escolher(rng, usados);
            LocalDate inicio = hoje.minusDays(inicios[i]);
            boolean ultimo = i == inicios.length - 1;
            List<LocalDate> datas = switch (r.perfil()) {
                case ALTA -> probabilistico(inicio, hoje, 0.93, -1, rng);
                case MODERADA -> probabilistico(inicio, hoje, 0.68, -1, rng);
                case BAIXA -> probabilistico(inicio, hoje, 0.30, -1, rng);
                case ABANDONO -> probabilistico(inicio, hoje, ultimo ? 0.85 : 0.80, ultimo ? 4 + rng.nextInt(6) : 12 + rng.nextInt(8), rng);
                case RETOMADA -> ultimo ? probabilistico(inicio, hoje, 0.85, -1, rng) : probabilistico(inicio, hoje, 0.22, -1, rng);
                case ROTEIRO -> List.of();
            };
            out.add(desafio(r, i, m, inicio, datas, rng, hoje, agora));
        }
        return out;
    }

    private static DesafioPlan desafio(Roteiro r, int idx, Modelo m, LocalDate inicio, List<LocalDate> datas,
                                       Random rng, LocalDate hoje, Instant agora) {
        List<Conclusao> cs = new ArrayList<>();
        int dia = 1;
        for (LocalDate d : datas) {
            if (dia > DIAS_DESAFIO || d.isAfter(hoje)) {
                break;
            }
            int hora = 6 + rng.nextInt(16);
            int minuto = rng.nextInt(60);
            ZonedDateTime z = d.atTime(hora, minuto).atZone(ZONE);
            if (z.toInstant().isAfter(agora)) {
                z = agora.atZone(ZONE).minusMinutes(1 + rng.nextInt(30));
            }
            cs.add(new Conclusao(dia++, d, z.toInstant()));
        }
        return new DesafioPlan(uuid("challenge", r.email() + "-" + idx), m.titulo(), m.categoria(), m.descricao(),
                m.xp(), inicio, cs);
    }

    /** Conclui todos os dias a partir de {@code inicio}, {@code n} dias seguidos. */
    private static List<LocalDate> sequencia(LocalDate inicio, int n) {
        List<LocalDate> out = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            out.add(inicio.plusDays(i));
        }
        return out;
    }

    /**
     * Um sorteio por dia do calendário, com probabilidade {@code p}; o 1º dia é sempre concluído (todo
     * desafio tem ao menos 1 conclusão, para existir na réplica Oracle). Depois de {@code corteDia} (se
     * &gt;= 0) o aluno para de vez.
     */
    private static List<LocalDate> probabilistico(LocalDate inicio, LocalDate hoje, double p, int corteDia, Random rng) {
        List<LocalDate> out = new ArrayList<>();
        for (LocalDate d = inicio; !d.isAfter(hoje) && out.size() < DIAS_DESAFIO; d = d.plusDays(1)) {
            int idx = (int) java.time.temporal.ChronoUnit.DAYS.between(inicio, d);
            boolean ativo = corteDia < 0 || idx < corteDia;
            if (idx == 0 || (ativo && rng.nextDouble() < p)) {
                out.add(d);
            }
        }
        return out;
    }

    private static Modelo escolher(Random rng, Set<String> usados) {
        for (int tentativa = 0; tentativa < 50; tentativa++) {
            Modelo m = MODELOS.get(rng.nextInt(MODELOS.size()));
            if (usados.add(m.titulo())) {
                return m;
            }
        }
        return MODELOS.get(0);
    }

    private static Modelo modelo(String titulo) {
        return MODELOS.stream().filter(m -> m.titulo().equals(titulo)).findFirst().orElseThrow();
    }

    private static UUID uuid(String tipo, String chave) {
        return UUID.nameUUIDFromBytes(("l30-demo-" + tipo + "-" + chave).getBytes(StandardCharsets.UTF_8));
    }
}
