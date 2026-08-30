package com.level30.api.domain.engine;

import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.RiskAssessment;
import com.level30.api.domain.model.RiskLevel;
import com.level30.api.domain.model.SuggestedAction;
import java.time.Duration;
import java.time.Instant;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * Motor de risco de abandono.
 *
 * <p><b>ESPELHO EXATO</b> de:
 * <ul>
 *   <li>{@code lib/domain/engine/risk_engine.dart} (Flutter)</li>
 *   <li>{@code server/src/risk.ts} (Cloudflare Worker)</li>
 * </ul>
 * Mesmos pesos, mesmos thresholds, mesma heurística de dias-sem-atividade.
 * Ao alterar um, alterar os outros dois — e a suíte {@code RiskEngineTest}
 * é o contrato compartilhado (portada de {@code test/risk_engine_test.dart}).
 */
@Component
public class RiskEngine {

    private static final Set<Integer> MILESTONES = Set.of(7, 14, 21, 30);

    public RiskAssessment assess(Challenge challenge) {
        double score = calculateScore(challenge);
        RiskLevel level = scoreToLevel(score);
        SuggestedAction action = determineAction(challenge, level);
        return new RiskAssessment(
                challenge.getId(),
                score,
                level,
                action,
                Instant.now()
        );
    }

    public double calculateScore(Challenge c) {
        double score = 0.0;

        // Fator 1: dias sem atividade (40%)
        int daysSince = daysSinceLastActivity(c);
        score += switch (daysSince) {
            case 0 -> 0.0;
            case 1 -> 0.1;
            case 2 -> 0.25;
            default -> 0.4;
        };

        // Fator 2: taxa de progresso vs esperada (30%)
        if (c.getTotalDays() > 0) {
            double rate = (double) c.getCurrentDay() / c.getTotalDays();
            score += (1.0 - rate) * 0.3;
        }

        // Fator 3: streak (30%)
        double streakFactor = c.getStreak() == 0
                ? 0.3
                : Math.max(0.0, 0.3 - c.getStreak() * 0.03);
        score += streakFactor;

        return clamp01(score);
    }

    public RiskLevel scoreToLevel(double score) {
        if (score < 0.25) {
            return RiskLevel.LOW;
        }
        if (score < 0.50) {
            return RiskLevel.MEDIUM;
        }
        if (score < 0.75) {
            return RiskLevel.HIGH;
        }
        return RiskLevel.CRITICAL;
    }

    public SuggestedAction determineAction(Challenge c, RiskLevel level) {
        if (MILESTONES.contains(c.getCurrentDay())) {
            return SuggestedAction.CELEBRATE_MILESTONE;
        }
        return switch (level) {
            case LOW -> SuggestedAction.NONE;
            case MEDIUM -> SuggestedAction.SEND_REMINDER;
            case HIGH -> SuggestedAction.SEND_MOTIVATION;
            case CRITICAL -> SuggestedAction.SUGGEST_REPLAN;
        };
    }

    private int daysSinceLastActivity(Challenge c) {
        if (c.getLastActivityAt() == null) {
            return c.getStreak() == 0 ? 2 : 0;
        }
        return (int) Duration.between(c.getLastActivityAt(), Instant.now()).toDays();
    }

    private double clamp01(double v) {
        return Math.min(1.0, Math.max(0.0, v));
    }
}
