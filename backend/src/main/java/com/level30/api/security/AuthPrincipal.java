package com.level30.api.security;

import com.level30.api.domain.model.Role;
import java.util.UUID;

/** Principal autenticado, extraído do JWT. Disponível via {@code @AuthenticationPrincipal}. */
public record AuthPrincipal(UUID id, String email, Role role) {
}
