package com.level30.api.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

public record ChatRequest(
        @NotBlank(message = "Mensagem vazia.")
        @Size(max = 1000, message = "Mensagem muito longa.")
        String message,

        List<Turn> history
) {
    public record Turn(String role, String content) {
    }
}
