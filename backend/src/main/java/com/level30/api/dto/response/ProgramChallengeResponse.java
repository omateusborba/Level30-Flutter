package com.level30.api.dto.response;

import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.ProgramChallenge;

/** C3 — modelo de desafio do programa. {@code adotado} só é preenchido na visão do aluno. */
public record ProgramChallengeResponse(
        String id,
        String title,
        Category category,
        String description,
        int totalDays,
        int xpReward,
        boolean active,
        long adotantes,
        boolean adotado
) {
    public static ProgramChallengeResponse of(ProgramChallenge p, long adotantes, boolean adotado) {
        return new ProgramChallengeResponse(
                p.getId().toString(), p.getTitle(), p.getCategory(), p.getDescription(),
                p.getTotalDays(), p.getXpReward(), p.isActive(), adotantes, adotado);
    }
}
