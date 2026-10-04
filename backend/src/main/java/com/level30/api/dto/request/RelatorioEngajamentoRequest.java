package com.level30.api.dto.request;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

/** Fase 6 — período para {@code pr_gerar_relatorio_engajamento}. O limite de 366 dias é da procedure. */
public record RelatorioEngajamentoRequest(
        @NotNull(message = "Inicio e obrigatorio.")
        LocalDate inicio,

        @NotNull(message = "Fim e obrigatorio.")
        LocalDate fim
) {
}
