package com.level30.api.dto.response;

/** Item de GET /me/atividade — conclusões por dia, para o heatmap. */
public record AtividadeDiaResponse(String data, long quantidade) {
}
