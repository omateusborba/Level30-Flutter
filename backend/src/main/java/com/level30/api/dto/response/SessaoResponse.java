package com.level30.api.dto.response;

import java.time.Instant;

/** A2 — uma sessao ativa (familia de refresh token) do usuario. */
public record SessaoResponse(
        String id,
        Instant iniciadaEm,
        String dispositivo,
        String ip
) {
}
