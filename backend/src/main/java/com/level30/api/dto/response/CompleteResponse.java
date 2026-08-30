package com.level30.api.dto.response;

import java.util.List;

/**
 * Congelado: o Flutter lê {@code res['challenge']}, {@code res['xpDelta']}, {@code res['totalXp']}.
 * {@code conquistas} é aditivo (F4) — lista vazia quando nada foi desbloqueado.
 */
public record CompleteResponse(
        ChallengeResponse challenge,
        int xpDelta,
        int totalXp,
        List<AchievementResponse> conquistas
) {
}
