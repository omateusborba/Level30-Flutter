package com.level30.api.domain.engajamento;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Fase 7 — filtros de {@code GET /admin/engajamento}; qualquer campo nulo significa "sem filtro". */
public record FiltroEngajamento(
        LocalDate inicio,
        LocalDate fim,
        Integer nivelMin,
        BigDecimal adesaoMin,
        OrdenacaoEngajamento ordenarPor,
        DirecaoOrdenacao direcao
) {
}
