package com.level30.api.dto.response;

import com.level30.api.domain.model.User;

/**
 * Shape público do usuário. Congelado: bate com {@code UserProfile.fromJson}
 * do Flutter ({@code name}, {@code totalXp}, {@code avatar}).
 */
public record UserResponse(
        String id,
        String name,
        String email,
        int totalXp,
        String avatar
) {
    public static UserResponse from(User u) {
        return new UserResponse(
                u.getId().toString(),
                u.getName(),
                u.getEmail(),
                u.getTotalXp(),
                u.getAvatar()
        );
    }
}
