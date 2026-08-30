package com.level30.api.security;

import com.level30.api.domain.model.Role;
import com.level30.api.domain.model.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import io.jsonwebtoken.security.MacAlgorithm;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Emissão e verificação de JWT (HS256). Access token curto (1h), refresh longo (30d).
 * O segredo vem de {@code app.jwt.secret} (variável de ambiente {@code JWT_SECRET}).
 */
@Service
public class JwtService {

    public static final String TYPE_ACCESS = "access";
    public static final String TYPE_REFRESH = "refresh";

    /** Contrato: HS256, mesmo com segredos mais longos (jjwt escalaria para HS384/512). */
    private static final MacAlgorithm ALG = Jwts.SIG.HS256;

    private final SecretKey key;
    private final long accessTtlSeconds;
    private final long refreshTtlSeconds;

    public JwtService(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.access-ttl-seconds:3600}") long accessTtlSeconds,
            @Value("${app.jwt.refresh-ttl-seconds:2592000}") long refreshTtlSeconds) {
        byte[] bytes = secret.getBytes(StandardCharsets.UTF_8);
        if (bytes.length < 32) {
            throw new IllegalStateException(
                    "app.jwt.secret precisa ter pelo menos 32 bytes (256 bits) para HS256.");
        }
        this.key = Keys.hmacShaKeyFor(bytes);
        this.accessTtlSeconds = accessTtlSeconds;
        this.refreshTtlSeconds = refreshTtlSeconds;
    }

    public String generateAccessToken(User user) {
        return build(user, TYPE_ACCESS, accessTtlSeconds);
    }

    public String generateRefreshToken(User user) {
        return build(user, TYPE_REFRESH, refreshTtlSeconds);
    }

    private String build(User user, String type, long ttlSeconds) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(user.getId().toString())
                .claim("email", user.getEmail())
                .claim("role", user.getRole().name())
                .claim("type", type)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(ttlSeconds)))
                .signWith(key, ALG)
                .compact();
    }

    /** @return o principal, ou {@code null} se o token for inválido, expirado ou do tipo errado. */
    public AuthPrincipal parse(String token, String expectedType) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(key)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();

            if (!expectedType.equals(claims.get("type", String.class))) {
                return null;
            }
            return new AuthPrincipal(
                    UUID.fromString(claims.getSubject()),
                    claims.get("email", String.class),
                    Role.valueOf(claims.get("role", String.class))
            );
        } catch (JwtException | IllegalArgumentException ex) {
            return null;
        }
    }
}
