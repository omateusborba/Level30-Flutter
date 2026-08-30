package com.level30.api.dto.response;

/** C2 — resposta de POST /challenges/{id}/replanejar/sugestao (não muta nada). */
public record ReplanSugestaoResponse(
        int totalDaysAtual,
        int currentDay,
        int sugestaoDias,
        int minDias,
        int maxDias,
        int replanejamentosRestantes,
        String mensagem,
        boolean aiGenerated
) {
}
