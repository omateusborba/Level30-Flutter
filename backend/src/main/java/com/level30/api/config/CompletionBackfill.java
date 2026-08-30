package com.level30.api.config;

import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.ChallengeCompletion;
import com.level30.api.repository.ChallengeCompletionRepository;
import com.level30.api.repository.ChallengeRepository;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * F1 · Reconstrói (aproximadamente) o histórico de conclusões para desafios que
 * já tinham progresso antes da migração V2. Roda uma única vez: no-op assim que
 * a tabela {@code challenge_completions} tem qualquer linha.
 *
 * <p>Aproximação: assume conclusões consecutivas terminando em
 * {@code last_activity_at}. É melhor que histórico vazio na demonstração; a
 * partir da V2 os eventos são registrados com precisão.
 */
@Component
@Order(20) // depois do DataSeeder
public class CompletionBackfill implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(CompletionBackfill.class);
    private static final ZoneId ZONE = ZoneId.of("America/Sao_Paulo");

    private final ChallengeRepository challenges;
    private final ChallengeCompletionRepository completions;

    public CompletionBackfill(ChallengeRepository challenges,
                              ChallengeCompletionRepository completions) {
        this.challenges = challenges;
        this.completions = completions;
    }

    @Override
    @Transactional
    public void run(String... args) {
        if (completions.count() > 0) {
            return;
        }
        List<Challenge> pendentes = challenges.findAll().stream()
                .filter(c -> c.getCurrentDay() > 0)
                .toList();
        if (pendentes.isEmpty()) {
            return;
        }

        int total = 0;
        for (Challenge c : pendentes) {
            LocalDate fim = LocalDate.ofInstant(
                    c.getLastActivityAt() != null ? c.getLastActivityAt() : c.getCreatedAt(), ZONE);
            for (int dia = c.getCurrentDay(); dia >= 1; dia--) {
                LocalDate on = fim.minusDays((long) c.getCurrentDay() - dia);
                int xp = Challenge.earnedXp(dia, c.getTotalDays(), c.getXpReward())
                        - Challenge.earnedXp(dia - 1, c.getTotalDays(), c.getXpReward());
                completions.save(ChallengeCompletion.of(c, dia, on, xp));
                total++;
            }
        }
        log.info("Backfill de historico: {} conclusoes reconstruidas para {} desafios.",
                total, pendentes.size());
    }
}
