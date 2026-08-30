package com.level30.api.dto.request;

import com.level30.api.domain.model.Category;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** C3 — corpo de POST /admin/programa. */
public record ProgramChallengeRequest(
        @NotBlank @Size(min = 3, message = "Titulo precisa de ao menos 3 caracteres.")
        String title,

        @NotNull(message = "Categoria e obrigatoria.")
        Category category,

        @NotBlank(message = "Descricao e obrigatoria.")
        String description,

        @Min(value = 7, message = "Minimo 7 dias.")
        @Max(value = 90, message = "Maximo 90 dias.")
        int totalDays,

        @Min(value = 100, message = "Minimo 100 XP.")
        @Max(value = 1000, message = "Maximo 1000 XP.")
        int xpReward
) {
}
