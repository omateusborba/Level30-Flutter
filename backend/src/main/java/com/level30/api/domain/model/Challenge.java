package com.level30.api.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "challenges")
@Getter
@Setter
@NoArgsConstructor
public class Challenge {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, updatable = false)
    private User user;

    @Column(nullable = false)
    private String title;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Category category;

    @Column(nullable = false, columnDefinition = "text")
    private String description;

    @Column(name = "total_days", nullable = false)
    private int totalDays;

    @Column(name = "current_day", nullable = false)
    private int currentDay;

    @Column(name = "xp_reward", nullable = false)
    private int xpReward;

    @Column(nullable = false)
    private int streak;

    @Column(name = "last_activity_at")
    private Instant lastActivityAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** B1 — risco materializado (cache do RiskEngine). Recalculado em completeDay + job diário. */
    @Column(name = "risk_score", nullable = false)
    private double riskScore;

    @Enumerated(EnumType.STRING)
    @Column(name = "risk_level", nullable = false, length = 20)
    private RiskLevel riskLevel = RiskLevel.LOW;

    @Column(name = "risk_updated_at")
    private Instant riskUpdatedAt;

    /** C2 — quantas vezes o desafio foi replanejado (máx. 2). */
    @Column(name = "replan_count", nullable = false)
    private int replanCount;

    /** C3 — modelo do programa de onde este desafio foi adotado (null = criado do zero). */
    @Column(name = "program_challenge_id")
    private UUID programChallengeId;

    public static Challenge create(User user, String title, Category category, String description,
                                   int totalDays, int xpReward) {
        Challenge c = new Challenge();
        c.id = UUID.randomUUID();
        c.user = user;
        c.title = title;
        c.category = category;
        c.description = description;
        c.totalDays = totalDays;
        c.xpReward = xpReward;
        c.currentDay = 0;
        c.streak = 0;
        c.lastActivityAt = null;
        c.createdAt = Instant.now();
        return c;
    }

    /**
     * XP acumulado até o dia atual. Divisão inteira — idêntico ao getter
     * {@code Challenge.earnedXp} do Dart e ao {@code earnedXp} de types.ts.
     */
    public int earnedXp() {
        return earnedXp(currentDay, totalDays, xpReward);
    }

    public static int earnedXp(int currentDay, int totalDays, int xpReward) {
        if (totalDays <= 0) {
            return 0;
        }
        return (int) ((long) currentDay * xpReward / totalDays);
    }

    public boolean isCompleted() {
        return currentDay >= totalDays;
    }
}
