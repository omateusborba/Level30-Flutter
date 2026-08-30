package com.level30.api.dto.request;

import jakarta.validation.constraints.Size;

/** C4 — corpo opcional de POST /challenges/{id}/complete. Nota do dia (diário). */
public record CompleteRequest(
        @Size(max = 280, message = "A nota deve ter no maximo 280 caracteres.")
        String note
) {
}
