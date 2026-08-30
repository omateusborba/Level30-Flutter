package com.level30.api.dto.response;

/** Item de GET /me/atividade — conclusões e XP por dia (heatmap + "Meu Progresso"). */
public record AtividadeDiaResponse(String data, long quantidade, long xp) {
}
