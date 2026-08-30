package com.level30.api.service;

import com.level30.api.domain.model.Role;
import com.level30.api.domain.model.User;
import com.level30.api.dto.request.LoginRequest;
import com.level30.api.dto.request.SignupRequest;
import com.level30.api.dto.response.AuthResponse;
import com.level30.api.dto.response.UserResponse;
import com.level30.api.exception.ContaBloqueadaException;
import com.level30.api.exception.RegraNegocioException;
import com.level30.api.repository.UserRepository;
import com.level30.api.security.JwtService;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    /** Hash BCrypt fixo usado so para equalizar o tempo de resposta quando o e-mail nao existe. */
    private static final String DUMMY_HASH =
            "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy";

    private final UserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final LoginAttemptService loginAttempts;
    private final RefreshTokenService refreshTokens;

    public AuthService(UserRepository users, PasswordEncoder passwordEncoder, JwtService jwtService,
                       LoginAttemptService loginAttempts, RefreshTokenService refreshTokens) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.loginAttempts = loginAttempts;
        this.refreshTokens = refreshTokens;
    }

    @Transactional
    public AuthResponse signup(SignupRequest req, String userAgent, String ip) {
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
        return tokensFor(user, userAgent, ip);
    }

    public AuthResponse login(LoginRequest req, String userAgent, String ip) {
        String email = normalizeEmail(req.email());
        User user = users.findByEmail(email).orElse(null);

        if (user != null) {
            long locked = loginAttempts.lockRemainingSeconds(user);
            if (locked > 0) {
                throw new ContaBloqueadaException(locked);
            }
        }

        boolean ok = user != null && passwordEncoder.matches(req.password(), user.getPasswordHash());
        if (!ok) {
            if (user == null) {
                // gasta um BCrypt mesmo sem usuario — resposta com tempo uniforme (anti-enumeracao)
                passwordEncoder.matches(req.password(), DUMMY_HASH);
            } else {
                loginAttempts.recordFailure(user.getId());
            }
            throw new BadCredentialsException("E-mail ou senha incorretos.");
        }

        loginAttempts.reset(user.getId());
        return tokensFor(user, userAgent, ip);
    }

    /**
     * A2 — rotaciona: consome o refresh apresentado e devolve access + refresh novos.
     * Reuso de um token ja consumido derruba a familia (ver {@link RefreshTokenService}).
     */
    public AuthResponse refresh(String presentedRefreshToken, String userAgent, String ip) {
        UUID userId = userIdFrom(presentedRefreshToken);
        User user = users.findById(userId)
                .orElseThrow(() -> new BadCredentialsException("Usuario nao encontrado."));
        RefreshTokenService.Rotated rotated =
                refreshTokens.rotate(presentedRefreshToken, user, userAgent, ip);
        return new AuthResponse(
                jwtService.generateAccessToken(user),
                rotated.refreshToken(),
                UserResponse.from(user));
    }

    public void logout(String refreshToken) {
        if (refreshToken != null && !refreshToken.isBlank()) {
            refreshTokens.revokeByToken(refreshToken);
        }
    }

    private UUID userIdFrom(String refreshToken) {
        var principal = jwtService.parse(refreshToken, JwtService.TYPE_REFRESH);
        if (principal == null) {
            throw new BadCredentialsException("Refresh token invalido ou expirado.");
        }
        return principal.id();
    }

    private AuthResponse tokensFor(User user, String userAgent, String ip) {
        return new AuthResponse(
                jwtService.generateAccessToken(user),
                refreshTokens.issue(user, userAgent, ip),
                UserResponse.from(user)
        );
    }

    private String normalizeEmail(String email) {
        return email == null ? null : email.trim().toLowerCase();
    }
}
