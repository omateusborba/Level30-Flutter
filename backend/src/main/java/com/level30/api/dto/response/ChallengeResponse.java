package com.level30.api.dto.response;

import com.level30.api.domain.model.Challenge;
import java.time.format.DateTimeFormatter;

/**
 * <b>CONTRATO CONGELADO</b> — igual ao {@code ChallengeJson} de
 * {@code server/src/types.ts} e ao que {@code Challenge.fromJson} do Flutter espera.
 *
 * <ul>
 *   <li>chaves em camelCase</li>
 *   <li>{@code category} em minúsculas (via {@link com.level30.api.domain.model.Category})</li>
 *   <li>{@code lastActivityAt}: string ISO-8601 com {@code Z}, ou {@code null}</li>
 *   <li>{@code createdAt}: string ISO-8601 com {@code Z} — adição aditiva (C1, grade de dias)</li>
 * </ul>
 */
public record ChallengeResponse(
        String id,
        String title,
        com.level30.api.domain.model.Category category,
        String description,
        int totalDays,
        int currentDay,
        int xpReward,
        int streak,
        String lastActivityAt,
        String createdAt,
        int replanCount
) {
    public static ChallengeResponse from(Challenge c) {
        return new ChallengeResponse(
                c.getId().toString(),
                c.getTitle(),
                c.getCategory(),
                c.getDescription(),
                c.getTotalDays(),
                c.getCurrentDay(),
                c.getXpReward(),
                c.getStreak(),
                c.getLastActivityAt() == null
                        ? null
                        : DateTimeFormatter.ISO_INSTANT.format(c.getLastActivityAt()),
                c.getCreatedAt() == null
                        ? null
                        : DateTimeFormatter.ISO_INSTANT.format(c.getCreatedAt()),
                c.getReplanCount()
        );
    }
}
