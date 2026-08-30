package com.level30.api.dto.response;

/** Congelado: o Flutter lê {@code res['challenge']}, {@code res['xpDelta']}, {@code res['totalXp']}. */
public record CompleteResponse(
        ChallengeResponse challenge,
        int xpDelta,
        int totalXp
) {
}
