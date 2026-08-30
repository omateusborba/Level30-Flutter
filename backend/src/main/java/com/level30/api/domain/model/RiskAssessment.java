package com.level30.api.domain.model;

import java.time.Instant;
import java.util.UUID;

/**
 * Saída do {@link com.level30.api.domain.engine.RiskEngine}. Espelha RiskAssessment
 * do Dart (lib/data/model/risk_assessment.dart).
 */
public record RiskAssessment(
        UUID challengeId,
        double riskScore,
        RiskLevel riskLevel,
        SuggestedAction suggestedAction,
        Instant calculatedAt
) {
}
