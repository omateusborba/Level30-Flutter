package com.level30.api.service;

import com.level30.api.domain.model.User;
import com.level30.api.dto.response.UserResponse;
import com.level30.api.exception.RecursoNaoEncontradoException;
import com.level30.api.exception.RegraNegocioException;
import com.level30.api.repository.UserRepository;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    /** ~300 KB de imagem decodificada ≈ 400 KB em base64 (data URI). Margem de segurança. */
    private static final int MAX_AVATAR_LENGTH = 400_000;

    private final UserRepository users;

    public UserService(UserRepository users) {
        this.users = users;
    }

    @Transactional(readOnly = true)
    public UserResponse me(UUID userId) {
        return UserResponse.from(load(userId));
    }

    @Transactional
    public String updateAvatar(UUID userId, String avatar) {
        if (avatar == null || !avatar.startsWith("data:image/")) {
            throw new RegraNegocioException("Imagem invalida.");
        }
        if (avatar.length() > MAX_AVATAR_LENGTH) {
            throw new RegraNegocioException("Imagem muito grande.");
        }
        User user = load(userId);
        user.setAvatar(avatar);
        users.save(user);
        return avatar;
    }

    @Transactional(readOnly = true)
    public User load(UUID userId) {
        return users.findById(userId)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Usuario nao encontrado."));
    }
}
