package com.level30.api.dto.response;

public record AdminUserResponse(
        String id,
        String nome,
        String email,
        int totalXp,
        int nivel,
        String rank,
        long quantidadeDesafios
) {
}
