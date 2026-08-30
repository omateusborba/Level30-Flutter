package com.level30.api.dto.response;

import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.RiskLevel;

public record AdminChallengeResponse(
        String id,
        String titulo,
        Category categoria,
        String usuarioNome,
        String usuarioEmail,
        int currentDay,
        int totalDays,
        int streak,
        double riskScore,
        RiskLevel riskLevel,
        boolean concluido,
        int replanCount
) {
}
