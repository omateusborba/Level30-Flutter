package com.level30.api.domain.engine;

import static org.assertj.core.api.Assertions.assertThat;

import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.RiskLevel;
import com.level30.api.domain.model.SuggestedAction;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Porte direto de {@code test/risk_engine_test.dart}. Mesma fórmula, mesmos casos —
 * é o contrato compartilhado entre Dart, TypeScript e Java.
 */
class RiskEngineTest {

    private final RiskEngine engine = new RiskEngine();

    private Challenge challenge(int currentDay, int streak, int totalDays, Instant lastActivityAt) {
        Challenge c = new Challenge();
        c.setId(UUID.randomUUID());
        c.setTitle("Test");
        c.setCategory(Category.STUDY);
        c.setDescription("");
        c.setTotalDays(totalDays);
        c.setCurrentDay(currentDay);
        c.setXpReward(100);
        c.setStreak(streak);
        c.setLastActivityAt(lastActivityAt);
        c.setCreatedAt(Instant.now());
        return c;
    }

    @Test
    @DisplayName("streak zero deve resultar em risco medio ou maior")
    void streakZero() {
        Challenge c = challenge(5, 0, 30, null);
        assertThat(engine.assess(c).riskScore()).isGreaterThan(0.25);
    }

    @Test
    @DisplayName("streak ativo com bom progresso deve resultar em risco baixo")
    void streakAtivoBomProgresso() {
        Challenge c = challenge(25, 10, 30, Instant.now());
        assertThat(engine.assess(c).riskLevel()).isEqualTo(RiskLevel.LOW);
    }

    @Test
    @DisplayName("dia 7 deve retornar celebracao de marco")
    void dia7Marco() {
        Challenge c = challenge(7, 7, 30, Instant.now());
        assertThat(engine.assess(c).suggestedAction()).isEqualTo(SuggestedAction.CELEBRATE_MILESTONE);
    }

    @Test
    @DisplayName("dia 14 deve retornar celebracao de marco")
    void dia14Marco() {
        Challenge c = challenge(14, 14, 30, Instant.now());
        assertThat(engine.assess(c).suggestedAction()).isEqualTo(SuggestedAction.CELEBRATE_MILESTONE);
    }

    @Test
    @DisplayName("score deve estar entre 0 e 1 para qualquer dia/streak")
    void scoreNormalizado() {
        for (int day = 0; day <= 30; day++) {
            Instant last = day > 0 ? Instant.now() : null;
            double score = engine.assess(challenge(day, day, 30, last)).riskScore();
            assertThat(score).isBetween(0.0, 1.0);
        }
    }

    @Test
    @DisplayName("progresso completo deve resultar em risco baixo")
    void progressoCompleto() {
        Challenge c = challenge(30, 10, 30, Instant.now());
        assertThat(engine.assess(c).riskLevel()).isEqualTo(RiskLevel.LOW);
    }

    @Test
    @DisplayName("score critico para desafio abandonado")
    void abandonado() {
        Challenge c = challenge(1, 0, 30, Instant.now().minus(10, ChronoUnit.DAYS));
        assertThat(engine.assess(c).riskScore()).isGreaterThan(0.5);
    }

    @Test
    @DisplayName("thresholds de nivel: fronteiras 0.25 / 0.50 / 0.75")
    void thresholds() {
        assertThat(engine.scoreToLevel(0.24)).isEqualTo(RiskLevel.LOW);
        assertThat(engine.scoreToLevel(0.25)).isEqualTo(RiskLevel.MEDIUM);
        assertThat(engine.scoreToLevel(0.49)).isEqualTo(RiskLevel.MEDIUM);
        assertThat(engine.scoreToLevel(0.50)).isEqualTo(RiskLevel.HIGH);
        assertThat(engine.scoreToLevel(0.74)).isEqualTo(RiskLevel.HIGH);
        assertThat(engine.scoreToLevel(0.75)).isEqualTo(RiskLevel.CRITICAL);
    }
}
