package com.level30.api.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

/** C2 — corpo de POST /challenges/{id}/replanejar. Nova duração total. */
public record ReplanRequest(
        @Min(value = 7, message = "A duracao minima e 7 dias.")
        @Max(value = 90, message = "A duracao maxima e 90 dias.")
        int totalDays
) {
}
