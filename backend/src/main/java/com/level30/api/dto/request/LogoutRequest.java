package com.level30.api.dto.request;

/** A2 — corpo de POST /auth/logout. Revoga a familia do refresh token informado. */
public record LogoutRequest(String refreshToken) {
}
