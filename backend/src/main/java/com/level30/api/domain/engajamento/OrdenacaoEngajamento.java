package com.level30.api.domain.engajamento;

import com.level30.api.exception.RegraNegocioException;
import org.springframework.http.HttpStatus;

/**
 * Fase 7 — colunas aceitas em {@code PKG_L30_CONSULTAS.FN_ENGAJAMENTO_FILTRADO(p_ordenar_por)}.
 * Defesa em profundidade: o PL/SQL também faz whitelist, mas o texto vindo do cliente nunca chega
 * ao banco — só o {@link #name()} de um valor deste enum.
 */
public enum OrdenacaoEngajamento {
    ADESAO, STREAK, NOME, NIVEL;

    public static OrdenacaoEngajamento de(String valor) {
        if (valor == null || valor.isBlank()) {
            return ADESAO;
        }
        for (OrdenacaoEngajamento o : values()) {
            if (o.name().equalsIgnoreCase(valor.strip())) {
                return o;
            }
        }
        throw new RegraNegocioException("ordenarPor invalido. Use ADESAO, STREAK, NOME ou NIVEL.", HttpStatus.BAD_REQUEST);
    }
}
