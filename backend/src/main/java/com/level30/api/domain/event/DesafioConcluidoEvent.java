package com.level30.api.domain.event;

import java.time.LocalDate;
import java.util.UUID;

/**
 * Fase 6 — publicado por {@code ChallengeService.completeDay} depois do commit da transação.
 * Carrega tudo que {@code pr_registrar_conclusao} (Oracle) precisa para replicar o evento; nenhum
 * campo exige consulta extra — todos já existem no escopo do método que conclui o dia (ver
 * {@code docs/MELHORIAS_FASE6.md}, Parte 2).
 */
public record DesafioConcluidoEvent(
        UUID userId,
        String userName,
        int totalXp,
        UUID challengeId,
        String title,
        LocalDate startDate,
        int dayNumber,
        int streak,
        LocalDate completedOn,
        int xpDelta
) {
}
