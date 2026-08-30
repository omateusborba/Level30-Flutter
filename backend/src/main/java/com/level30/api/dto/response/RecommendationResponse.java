package com.level30.api.dto.response;

import com.level30.api.domain.model.RiskLevel;

/** Congelado: bate com o {@code RecommendationResult} de {@code server/src/ai.ts}. */
public record RecommendationResponse(
        String message,
        double riskScore,
        RiskLevel riskLevel,
        boolean aiGenerated
) {
}
