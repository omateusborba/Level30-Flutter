package com.level30.api.dto.response;

/**
 * Congelado: o Flutter lê {@code res['token']} e {@code res['user']}.
 * {@code refreshToken} é adição da Fase 5 — o app ignora se não usar.
 */
public record AuthResponse(
        String token,
        String refreshToken,
        UserResponse user
) {
}
