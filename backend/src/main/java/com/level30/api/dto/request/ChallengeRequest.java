package com.level30.api.dto.request;

import com.level30.api.domain.model.Category;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ChallengeRequest(
        @NotBlank(message = "Titulo e obrigatorio.")
        @Size(min = 3, message = "Titulo precisa ter pelo menos 3 caracteres.")
        String title,

        @NotNull(message = "Categoria e obrigatoria.")
        Category category,

        @NotBlank(message = "Descricao e obrigatoria.")
        String description,

        @NotNull(message = "Duracao e obrigatoria.")
        @Min(value = 7, message = "Duracao precisa estar entre 7 e 90 dias.")
        @Max(value = 90, message = "Duracao precisa estar entre 7 e 90 dias.")
        Integer totalDays,

        @NotNull(message = "Recompensa e obrigatoria.")
        @Min(value = 100, message = "Recompensa precisa estar entre 100 e 1000 XP.")
        @Max(value = 1000, message = "Recompensa precisa estar entre 100 e 1000 XP.")
        Integer xpReward
) {
}
