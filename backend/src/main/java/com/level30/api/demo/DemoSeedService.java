package com.level30.api.demo;

import com.level30.api.demo.DemoPlan.AlunoPlan;
import com.level30.api.demo.DemoPlan.Conclusao;
import com.level30.api.demo.DemoPlan.DesafioPlan;
import com.level30.api.domain.engine.RiskEngine;
import com.level30.api.domain.event.DesafioConcluidoEvent;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.ChallengeCompletion;
import com.level30.api.domain.model.RiskLevel;
import com.level30.api.domain.model.RiskSnapshot;
import com.level30.api.domain.model.Role;
import com.level30.api.domain.model.User;
import com.level30.api.gateway.EngajamentoGateway;
import com.level30.api.repository.ChallengeCompletionRepository;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.RiskSnapshotRepository;
import com.level30.api.repository.UserRepository;
import com.level30.api.service.AchievementService;
import com.level30.api.service.RiskMaterializationService;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import jakarta.persistence.EntityManager;
import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Seed ÚNICO da demo. Grava o {@link DemoPlan} nos dois bancos com as mesmas pessoas e os mesmos IDs:
 *
 * <ol>
 *   <li>PostgreSQL/H2: usuários (XP = soma das conclusões), desafios, conclusões com data e hora, conquistas
 *       (pelo {@link AchievementService}), risco materializado (pelo {@code RiskEngine}) e ~90 snapshots
 *       diários de risco;</li>
 *   <li>Oracle (se ligado): zera a réplica e reexecuta cada conclusão, em ordem cronológica, por
 *       {@code PR_REGISTRAR_CONCLUSAO} (o mesmo caminho do app), com {@code totalXp} vindo do PostgreSQL;</li>
 *   <li>checagem de paridade entre os bancos (alunos, desafios, conclusões dos últimos 30 dias, XP).</li>
 * </ol>
 *
 * Recusa-se a rodar fora de ambiente local/demo ({@link DemoGuard}).
 */
@Service
public class DemoSeedService {

    private static final Logger log = LoggerFactory.getLogger(DemoSeedService.class);
    private static final int DIAS_DE_SNAPSHOT = 90;

    private final UserRepository users;
    private final ChallengeRepository challenges;
    private final ChallengeCompletionRepository completions;
    private final RiskSnapshotRepository snapshots;
    private final RiskMaterializationService risk;
    private final RiskEngine engine;
    private final AchievementService achievements;
    private final PasswordEncoder encoder;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    private final EngajamentoGateway gateway;
    private final Optional<OracleDemoSupport> oracle;
    private final EntityManager em;
    private final String pgUrl;

    public DemoSeedService(UserRepository users, ChallengeRepository challenges,
                           ChallengeCompletionRepository completions, RiskSnapshotRepository snapshots,
                           RiskMaterializationService risk, RiskEngine engine, AchievementService achievements,
                           PasswordEncoder encoder, @Qualifier("dataSource") DataSource primaryDataSource,
                           TransactionTemplate tx,
                           EngajamentoGateway gateway, Optional<OracleDemoSupport> oracle,
                           EntityManager em,
                           @Value("${spring.datasource.url:}") String pgUrl) {
        this.users = users;
        this.challenges = challenges;
        this.completions = completions;
        this.snapshots = snapshots;
        this.risk = risk;
        this.engine = engine;
        this.achievements = achievements;
        this.encoder = encoder;
        // não injetar JdbcTemplate: com o Oracle ligado o único bean é o do Oracle (a autoconfiguração recua)
        this.jdbc = new JdbcTemplate(primaryDataSource);
        this.tx = tx;
        this.gateway = gateway;
        this.oracle = oracle;
        this.em = em;
        this.pgUrl = pgUrl;
    }

    public record Resultado(int alunos, int desafios, int conclusoes, int snapshots, boolean oracle,
                            List<String> divergencias) { }

    /** Só semeia se ainda não há alunos (uso no boot, idempotente). */
    public Optional<Resultado> executarSeVazio() {
        boolean temAlunos = users.findAll().stream().anyMatch(u -> u.getRole() == Role.USER);
        return temAlunos ? Optional.empty() : Optional.of(executar());
    }

    /** Reseta e semeia os dois bancos. */
    public Resultado executar() {
        DemoGuard.exigir("PostgreSQL/H2", pgUrl);
        oracle.ifPresent(o -> DemoGuard.exigir("Oracle", o.url()));

        Instant agora = Instant.now();
        LocalDate hoje = LocalDate.now(DemoPlan.ZONE);
        List<AlunoPlan> plano = DemoPlan.gerar(hoje, agora);

        log.info("Seed da demo: resetando e populando {} alunos...", plano.size());
        tx.executeWithoutResult(s -> gravarPostgres(plano, hoje, agora));
        oracle.ifPresent(o -> replicarNoOracle(o, plano));

        List<String> divergencias = verificarParidade(plano, hoje);
        int conclusoes = plano.stream().flatMap(a -> a.desafios().stream()).mapToInt(d -> d.conclusoes().size()).sum();
        int desafios = plano.stream().mapToInt(a -> a.desafios().size()).sum();
        Resultado r = new Resultado(plano.size(), desafios, conclusoes, DIAS_DE_SNAPSHOT, oracle.isPresent(), divergencias);
        if (!divergencias.isEmpty()) {
            throw new IllegalStateException("Paridade entre os bancos falhou: " + divergencias);
        }
        log.info("Seed da demo concluído: {}", r);
        return r;
    }

    // ------------------------------------------------------------------ PostgreSQL / H2

    private void gravarPostgres(List<AlunoPlan> plano, LocalDate hoje, Instant agora) {
        jdbc.update("DELETE FROM risk_snapshots");
        jdbc.update("DELETE FROM users WHERE role = 'USER'");   // FKs em cascata levam o resto
        jdbc.update("UPDATE users SET name = 'Coordenação' WHERE role = 'ADMIN' AND name = 'Coordenacao'");
        em.clear();                         // o SQL direto apagou linhas que o contexto do Hibernate ainda pode ter em cache

        String hash = encoder.encode(DemoPlan.SENHA_DEMO);
        List<Challenge> todosDesafios = new ArrayList<>();
        for (AlunoPlan a : plano) {
            User u = User.create(a.email(), hash, a.nome(), Role.USER);
            u.setId(a.id());
            u.setCreatedAt(a.criadoEm());
            u.setTotalXp(a.xpTotal());
            users.save(u);

            for (DesafioPlan dp : a.desafios()) {
                Challenge c = Challenge.create(u, dp.titulo(), dp.categoria(), dp.descricao(), DemoPlan.DIAS_DESAFIO, dp.xpReward());
                c.setId(dp.id());
                c.setCreatedAt(dp.inicio().atTime(8, 0).atZone(DemoPlan.ZONE).toInstant());
                c.setCurrentDay(dp.diaAtual());
                c.setStreak(dp.streakFinal());
                c.setLastActivityAt(dp.conclusoes().isEmpty() ? null
                        : dp.conclusoes().get(dp.conclusoes().size() - 1).instante());
                risk.refresh(c);            // risco calculado pelo RiskEngine, não o default da coluna
                challenges.save(c);
                for (Conclusao cl : dp.conclusoes()) {
                    completions.save(ChallengeCompletion.of(c, cl.dia(), cl.data(), dp.xpDoDia(cl.dia()), null, cl.instante()));
                }
                todosDesafios.add(c);
            }
        }
        completions.flush();
        for (AlunoPlan a : plano) {
            achievements.avaliar(users.findById(a.id()).orElseThrow());
        }
        gravarSnapshotsHistoricos(plano, hoje);
        risk.recomputeAll();                // snapshot de hoje + risco de todos com o "agora" real
    }

    /** Reconstrói a distribuição de risco de cada um dos últimos 90 dias, com o estado de cada desafio naquela data. */
    private void gravarSnapshotsHistoricos(List<AlunoPlan> plano, LocalDate hoje) {
        for (int atras = DIAS_DE_SNAPSHOT; atras >= 1; atras--) {
            LocalDate dia = hoje.minusDays(atras);
            Instant fimDoDia = dia.atTime(23, 59).atZone(DemoPlan.ZONE).toInstant();
            Map<RiskLevel, Integer> dist = new EnumMap<>(RiskLevel.class);
            for (AlunoPlan a : plano) {
                for (DesafioPlan dp : a.desafios()) {
                    if (dp.inicio().isAfter(dia)) {
                        continue;
                    }
                    int feitas = (int) dp.conclusoes().stream().filter(c -> !c.data().isAfter(dia)).count();
                    if (feitas >= DemoPlan.DIAS_DESAFIO) {
                        continue;           // concluído: não entra na distribuição, como em recomputeAll
                    }
                    Challenge estado = new Challenge();
                    estado.setTotalDays(DemoPlan.DIAS_DESAFIO);
                    estado.setCurrentDay(feitas);
                    estado.setStreak(dp.streakAte(feitas));
                    estado.setLastActivityAt(feitas == 0 ? null : dp.conclusoes().get(feitas - 1).instante());
                    RiskLevel nivel = engine.scoreToLevel(engine.calculateScore(estado, fimDoDia));
                    dist.merge(nivel, 1, Integer::sum);
                }
            }
            snapshots.save(RiskSnapshot.of(dia, dist));
        }
    }

    // ------------------------------------------------------------------ Oracle

    private void replicarNoOracle(OracleDemoSupport o, List<AlunoPlan> plano) {
        o.resetar();

        record Evento(LocalDate data, Instant instante, DesafioConcluidoEvent evento) { }
        List<Evento> eventos = new ArrayList<>();
        for (AlunoPlan a : plano) {
            int xpAcumulado = 0;
            // XP acumulado em ordem cronológica por aluno (é o total_xp que o PostgreSQL tinha naquele momento)
            List<Evento> doAluno = new ArrayList<>();
            List<Object[]> flat = new ArrayList<>();
            for (DesafioPlan dp : a.desafios()) {
                for (Conclusao cl : dp.conclusoes()) {
                    flat.add(new Object[] {dp, cl});
                }
            }
            flat.sort(Comparator.comparing(x -> ((Conclusao) x[1]).instante()));
            for (Object[] x : flat) {
                DesafioPlan dp = (DesafioPlan) x[0];
                Conclusao cl = (Conclusao) x[1];
                int idx = dp.conclusoes().indexOf(cl);
                int xp = dp.xpDoDia(cl.dia());
                xpAcumulado += xp;
                doAluno.add(new Evento(cl.data(), cl.instante(), new DesafioConcluidoEvent(
                        a.id(), a.nome(), xpAcumulado, dp.id(), dp.titulo(), dp.inicio(), cl.dia(),
                        dp.streakAte(idx + 1), cl.data(), xp)));
            }
            eventos.addAll(doAluno);
        }
        eventos.sort(Comparator.comparing(Evento::instante));
        for (Evento e : eventos) {
            gateway.registrarConclusao(e.evento());
        }
        o.finalizar();
        gateway.verificarInatividade(3);
        o.limparRastroDoSeed();
    }

    // ------------------------------------------------------------------ paridade

    /** Compara PostgreSQL x Oracle: alunos, desafios, conclusões dos últimos 30 dias e XP total. */
    public List<String> verificarParidade(List<AlunoPlan> plano, LocalDate hoje) {
        List<String> divergencias = new ArrayList<>();
        LocalDate desde = hoje.minusDays(30);

        long pgAlunos = users.findAll().stream().filter(u -> u.getRole() == Role.USER).count();
        long pgDesafios = challenges.count();
        long pgConclusoes = completions.findAll().stream().filter(c -> !c.getCompletedOn().isBefore(desde)).count();
        long pgXp = users.findAll().stream().filter(u -> u.getRole() == Role.USER).mapToLong(User::getTotalXp).sum();
        long planoConclusoes = plano.stream().flatMap(a -> a.desafios().stream()).flatMap(d -> d.conclusoes().stream())
                .filter(c -> !c.data().isBefore(desde)).count();

        comparar(divergencias, "alunos (plano x PostgreSQL)", plano.size(), pgAlunos);
        comparar(divergencias, "conclusões 30d (plano x PostgreSQL)", planoConclusoes, pgConclusoes);
        comparar(divergencias, "XP total (plano x PostgreSQL)", plano.stream().mapToLong(AlunoPlan::xpTotal).sum(), pgXp);

        oracle.ifPresent(o -> {
            comparar(divergencias, "alunos (PostgreSQL x Oracle)", pgAlunos, o.usuarios());
            comparar(divergencias, "desafios (PostgreSQL x Oracle)", pgDesafios, o.desafios());
            comparar(divergencias, "conclusões 30d (PostgreSQL x Oracle)", pgConclusoes, o.conclusoesDesde(desde));
            comparar(divergencias, "XP total (PostgreSQL x Oracle)", pgXp, o.xpTotal());
        });
        return divergencias;
    }

    private static void comparar(List<String> divergencias, String o, long esperado, long obtido) {
        if (esperado != obtido) {
            divergencias.add(o + ": " + esperado + " != " + obtido);
        }
    }
}
