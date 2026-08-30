package com.level30.api.service;

import com.level30.api.domain.model.RefreshToken;
import com.level30.api.domain.model.User;
import com.level30.api.dto.response.SessaoResponse;
import com.level30.api.repository.RefreshTokenRepository;
import com.level30.api.security.JwtService;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;

/**
 * A2 — emissao, rotacao e revogacao de refresh tokens.
 *
 * <p>Rotacao com deteccao de reuso (OAuth 2.1): cada uso emite um token novo e
 * consome o anterior por um UPDATE condicional atomico; reapresentar um token
 * ja consumido revoga a familia toda. Cada escrita commita na hora (metodos do
 * repositorio), entao a excecao de reuso nao faz rollback da revogacao.
 */
@Service
public class RefreshTokenService {

    private static final Logger log = LoggerFactory.getLogger(RefreshTokenService.class);

    private final RefreshTokenRepository tokens;
    private final JwtService jwt;

    public RefreshTokenService(RefreshTokenRepository tokens, JwtService jwt) {
        this.tokens = tokens;
        this.jwt = jwt;
    }

    /** Nova familia de sessao (login / signup). */
    public String issue(User user, String userAgent, String ip) {
        return persistAndSign(user, UUID.randomUUID(), UUID.randomUUID(), userAgent, ip);
    }

    /** Consome o token apresentado e emite o proximo da mesma familia. */
    public Rotated rotate(String presentedToken, User user, String userAgent, String ip) {
        UUID jti = jwt.refreshJti(presentedToken);
        if (jti == null) {
            throw new BadCredentialsException("Refresh token invalido ou expirado.");
        }
        RefreshToken row = tokens.findById(jti).orElse(null);
        if (row == null) {
            throw new BadCredentialsException("Refresh token invalido ou expirado.");
        }
        Instant now = Instant.now();

        if (tokens.consume(jti, now) == 0) {
            // nao estava ativo: reuso de token ja consumido, ou familia/token revogado/expirado
            if (row.getUsedAt() != null && row.getRevokedAt() == null) {
                tokens.revokeFamily(row.getFamilyId(), now);
                log.warn("Reuso de refresh token detectado (user {}). Familia {} revogada.",
                        row.getUserId(), row.getFamilyId());
            }
            throw new BadCredentialsException("Sessao invalidada. Entre novamente.");
        }

        String token = persistAndSign(user, UUID.randomUUID(), row.getFamilyId(), userAgent, ip);
        return new Rotated(token);
    }

    public void revokeByToken(String presentedToken) {
        UUID jti = jwt.refreshJti(presentedToken);
        if (jti == null) {
            return;
        }
        tokens.findById(jti).ifPresent(row -> tokens.revokeFamily(row.getFamilyId(), Instant.now()));
    }

    public void revokeAllFor(UUID userId) {
        Instant now = Instant.now();
        tokens.findByUserIdOrderByIssuedAtDesc(userId).stream()
                .filter(t -> t.getRevokedAt() == null)
                .map(RefreshToken::getFamilyId)
                .distinct()
                .forEach(fam -> tokens.revokeFamily(fam, now));
    }

    public List<SessaoResponse> sessions(UUID userId) {
        Instant now = Instant.now();
        return tokens.findByUserIdOrderByIssuedAtDesc(userId).stream()
                .filter(t -> t.isActive(now))
                .map(t -> new SessaoResponse(
                        t.getJti().toString(),
                        t.getIssuedAt(),
                        t.getUserAgent(),
                        t.getIp()))
                .toList();
    }

    /** Revoga a familia dona do jti, se pertencer ao usuario. */
    public void revokeSession(UUID userId, UUID jti) {
        RefreshToken row = tokens.findById(jti).orElse(null);
        if (row != null && row.getUserId().equals(userId)) {
            tokens.revokeFamily(row.getFamilyId(), Instant.now());
        }
    }

    private String persistAndSign(User user, UUID jti, UUID familyId, String userAgent, String ip) {
        Instant now = Instant.now();
        tokens.save(RefreshToken.create(jti, user.getId(), familyId, now,
                now.plusSeconds(jwt.getRefreshTtlSeconds()), userAgent, ip));
        return jwt.generateRefreshToken(user, jti);
    }

    public record Rotated(String refreshToken) {}
}
