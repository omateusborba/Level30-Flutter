package com.level30.api.demo;

import static org.assertj.core.api.Assertions.assertThat;

import com.level30.api.domain.engine.RiskEngine;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.Role;
import com.level30.api.repository.ChallengeCompletionRepository;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.RiskSnapshotRepository;
import com.level30.api.repository.UserAchievementRepository;
import com.level30.api.repository.UserRepository;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

/**
 * Executa o seed único contra o H2 de teste (Oracle desligado) e confere o que o dashboard e o app
 * vão mostrar: risco materializado = RiskEngine, XP = soma das conclusões, conquistas, snapshots, paridade.
 */
@SpringBootTest
@ActiveProfiles("test")
class DemoSeedIntegrationTest {

    @Autowired DemoSeedService seed;
    @Autowired UserRepository users;
    @Autowired ChallengeRepository challenges;
    @Autowired ChallengeCompletionRepository completions;
    @Autowired RiskSnapshotRepository snapshots;
    @Autowired UserAchievementRepository achievements;
    @Autowired RiskEngine engine;

    // @Transactional: lazy loading nas asserções e rollback no fim (não deixa a base de demo no H2 compartilhado)
    @Test
    @Transactional
    void seedPopulaBaseCoerente_eEIdempotente() {
        var r = seed.executar();
        var segunda = seed.executar();                      // idempotente: mesmo resultado, sem duplicar
        assertThat(segunda.alunos()).isEqualTo(r.alunos());

        assertThat(r.alunos()).isEqualTo(16);
        assertThat(r.divergencias()).isEmpty();
        assertThat(users.findAll().stream().filter(u -> u.getRole() == Role.USER)).hasSize(16);
        assertThat(challenges.count()).isEqualTo(r.desafios());
        assertThat(completions.count()).isEqualTo(r.conclusoes());

        // XP: saldo do usuário = soma do xp_delta das conclusões (fonte única)
        for (var u : users.findAll()) {
            if (u.getRole() != Role.USER) {
                continue;
            }
            int soma = completions.findByUserId(u.getId()).stream().mapToInt(c -> c.getXpDelta()).sum();
            assertThat(u.getTotalXp()).as(u.getName()).isEqualTo(soma).isPositive();
        }

        // risco materializado == RiskEngine (nada de default 0 / LOW em desafio parado)
        for (Challenge c : challenges.findAll()) {
            assertThat(c.getRiskUpdatedAt()).as(c.getTitle()).isNotNull();
            assertThat(c.getRiskScore()).as(c.getTitle()).isCloseTo(engine.calculateScore(c), org.assertj.core.data.Offset.offset(0.002));
        }
        var corrida = challenges.findAll().stream().filter(c -> c.getTitle().equals("Corrida matinal")
                && c.getUser().getEmail().equals("ana@level30.app")).findFirst().orElseThrow();
        assertThat(corrida.getRiskLevel().toJson()).isEqualTo("critical");

        // conquistas desbloqueadas e snapshots históricos (evolução do risco)
        assertThat(achievements.count()).isGreaterThan(16);
        assertThat(snapshots.findBySnapshotOnGreaterThanEqualOrderBySnapshotOnAsc(LocalDate.now().minusDays(90))).hasSizeGreaterThanOrEqualTo(90);
        var algumDiaComRisco = snapshots.findAll().stream().anyMatch(s -> s.getCritical() + s.getHigh() + s.getMedium() > 0);
        assertThat(algumDiaComRisco).isTrue();
    }
}
