package com.level30.api.service;

import com.level30.api.domain.model.Role;
import com.level30.api.domain.model.User;
import com.level30.api.dto.request.LoginRequest;
import com.level30.api.dto.request.RefreshRequest;
import com.level30.api.dto.request.SignupRequest;
import com.level30.api.dto.response.AuthResponse;
import com.level30.api.dto.response.UserResponse;
import com.level30.api.exception.RegraNegocioException;
import com.level30.api.repository.UserRepository;
import com.level30.api.security.AuthPrincipal;
import com.level30.api.security.JwtService;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(UserRepository users, PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    @Transactional
    public AuthResponse signup(SignupRequest req) {
        String email = normalizeEmail(req.email());
        if (users.existsByEmail(email)) {
            throw new RegraNegocioException("Este e-mail ja esta cadastrado.", HttpStatus.CONFLICT);
        }
        User user = User.create(
                email,
                passwordEncoder.encode(req.password()),
                req.name().trim(),
                Role.USER
        );
        users.save(user);
        return tokensFor(user);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest req) {
        String email = normalizeEmail(req.email());
        User user = users.findByEmail(email)
                .filter(u -> passwordEncoder.matches(req.password(), u.getPasswordHash()))
                .orElseThrow(() -> new BadCredentialsException("E-mail ou senha incorretos."));
        return tokensFor(user);
    }

    @Transactional(readOnly = true)
    public AuthResponse refresh(RefreshRequest req) {
        AuthPrincipal principal = jwtService.parse(req.refreshToken(), JwtService.TYPE_REFRESH);
        if (principal == null) {
            throw new BadCredentialsException("Refresh token invalido ou expirado.");
        }
        User user = users.findById(principal.id())
                .orElseThrow(() -> new BadCredentialsException("Usuario nao encontrado."));
        // Só o access token é rotacionado; o refresh continua válido até expirar.
        return new AuthResponse(jwtService.generateAccessToken(user), null, UserResponse.from(user));
    }

    private AuthResponse tokensFor(User user) {
        return new AuthResponse(
                jwtService.generateAccessToken(user),
                jwtService.generateRefreshToken(user),
                UserResponse.from(user)
        );
    }

    private String normalizeEmail(String email) {
        return email == null ? null : email.trim().toLowerCase();
    }
}
