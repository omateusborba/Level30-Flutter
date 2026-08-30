package com.level30.api.dto.request;

import jakarta.validation.constraints.NotBlank;

public record AvatarRequest(
        @NotBlank(message = "Imagem e obrigatoria.")
        String avatar
) {
}
