package com.level30.api.dto.request;

import jakarta.validation.constraints.NotBlank;

public record RefreshRequest(
        @NotBlank(message = "refreshToken e obrigatorio.")
        String refreshToken
) {
}
