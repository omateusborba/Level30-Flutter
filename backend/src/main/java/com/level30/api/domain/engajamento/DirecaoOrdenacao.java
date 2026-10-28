package com.level30.api.domain.engajamento;

import com.level30.api.exception.RegraNegocioException;
import org.springframework.http.HttpStatus;

/** Fase 7 — direção do ORDER BY de {@code FN_ENGAJAMENTO_FILTRADO}; ver {@link OrdenacaoEngajamento}. */
public enum DirecaoOrdenacao {
    ASC, DESC;

    public static DirecaoOrdenacao de(String valor) {
        if (valor == null || valor.isBlank()) {
            return DESC;
        }
        for (DirecaoOrdenacao d : values()) {
            if (d.name().equalsIgnoreCase(valor.strip())) {
                return d;
            }
        }
        throw new RegraNegocioException("direcao invalida. Use ASC ou DESC.", HttpStatus.BAD_REQUEST);
    }
}
