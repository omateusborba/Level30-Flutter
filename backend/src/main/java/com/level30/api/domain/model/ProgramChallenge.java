package com.level30.api.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** C3 — modelo de desafio publicado pela coordenação. O aluno adota → vira um {@link Challenge}. */
@Entity
@Table(name = "program_challenges")
@Getter
@Setter
@NoArgsConstructor
public class ProgramChallenge {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id;

    @Column(nullable = false)
    private String title;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Category category;

    @Column(nullable = false, columnDefinition = "text")
    private String description;

    @Column(name = "total_days", nullable = false)
    private int totalDays;

    @Column(name = "xp_reward", nullable = false)
    private int xpReward;

    @Column(nullable = false)
    private boolean active = true;

    @Column(name = "created_by")
    private UUID createdBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public static ProgramChallenge create(String title, Category category, String description,
                                          int totalDays, int xpReward, UUID createdBy) {
        ProgramChallenge p = new ProgramChallenge();
        p.id = UUID.randomUUID();
        p.title = title;
        p.category = category;
        p.description = description;
        p.totalDays = totalDays;
        p.xpReward = xpReward;
        p.active = true;
        p.createdBy = createdBy;
        p.createdAt = Instant.now();
        return p;
    }
}
