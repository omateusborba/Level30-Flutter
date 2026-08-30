package com.level30.api.dto.response;

import com.level30.api.domain.model.ChallengeCompletion;
import java.time.format.DateTimeFormatter;

/** Item de GET /challenges/{id}/historico. */
public record CompletionResponse(
        int dayNumber,
        String completedOn,
        String note,
        int xpDelta
) {
    public static CompletionResponse from(ChallengeCompletion c) {
        return new CompletionResponse(
                c.getDayNumber(),
                DateTimeFormatter.ISO_LOCAL_DATE.format(c.getCompletedOn()),
                c.getNote(),
                c.getXpDelta()
        );
    }
}
