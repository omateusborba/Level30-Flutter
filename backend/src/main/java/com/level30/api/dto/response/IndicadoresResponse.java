package com.level30.api.dto.response;

import java.util.List;

public record IndicadoresResponse(
        long totalUsuarios,
        long totalDesafios,
        long desafiosConcluidos,
        long desafiosEmRisco,
        long xpMedioPorUsuario,
        int melhorStreak,
        List<ContagemPorChave> porCategoria,
        List<ContagemPorChave> porNivelDeRisco
) {
    public record ContagemPorChave(String chave, long quantidade) {
    }
}
