package com.level30.api.dto.response;

import com.level30.api.domain.model.User;

/**
 * Shape público do usuário. Congelado: bate com {@code UserProfile.fromJson}
 * do Flutter ({@code name}, {@code totalXp}, {@code avatar}).
 * {@code role} é adição aditiva (A5) — o app ignora; o dashboard usa para o guard de papel.
 */
public record UserResponse(
        String id,
        String name,
        String email,
        int totalXp,
        String avatar,
        String role
) {
    public static UserResponse from(User u) {
        return new UserResponse(
                u.getId().toString(),
                u.getName(),
                u.getEmail(),
                u.getTotalXp(),
                u.getAvatar(),
                u.getRole().name()
        );
    }
}
