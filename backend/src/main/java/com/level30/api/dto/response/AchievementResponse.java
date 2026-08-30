package com.level30.api.dto.response;

import com.level30.api.domain.model.Achievement;

/** Item de GET /me/conquistas e campo `conquistas` (aditivo) de POST .../complete. */
public record AchievementResponse(
        String id,
        String nome,
        String descricao,
        boolean desbloqueada
) {
    public static AchievementResponse of(Achievement a, boolean desbloqueada) {
        return new AchievementResponse(a.id(), a.nome(), a.descricao(), desbloqueada);
    }
}
