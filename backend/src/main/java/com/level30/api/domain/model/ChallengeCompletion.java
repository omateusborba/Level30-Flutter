package com.level30.api.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Evento imutável: um dia de desafio concluído. Fonte de verdade para o grid de
 * 30 dias, o heatmap do perfil e as análises de padrão (F8).
 */
@Entity
@Table(name = "challenge_completions")
@Getter
@Setter
@NoArgsConstructor
public class ChallengeCompletion {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "challenge_id", nullable = false, updatable = false)
    private Challenge challenge;

    /** Desnormalizado para a consulta de atividade do usuário sem join. */
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "day_number", nullable = false)
    private int dayNumber;

    /** Data no fuso America/Sao_Paulo, calculada no service — nunca now() do banco. */
    @Column(name = "completed_on", nullable = false)
    private LocalDate completedOn;

    @Column(columnDefinition = "text")
    private String note;

    @Column(name = "xp_delta", nullable = false)
    private int xpDelta;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public static ChallengeCompletion of(Challenge challenge, int dayNumber,
                                         LocalDate completedOn, int xpDelta) {
        return of(challenge, dayNumber, completedOn, xpDelta, null);
    }

    public static ChallengeCompletion of(Challenge challenge, int dayNumber,
                                         LocalDate completedOn, int xpDelta, String note) {
        ChallengeCompletion e = new ChallengeCompletion();
        e.id = UUID.randomUUID();
        e.challenge = challenge;
        e.userId = challenge.getUser().getId();
        e.dayNumber = dayNumber;
        e.completedOn = completedOn;
        e.xpDelta = xpDelta;
        e.note = (note == null || note.isBlank()) ? null : note.trim();
        e.createdAt = Instant.now();
        return e;
    }
}
