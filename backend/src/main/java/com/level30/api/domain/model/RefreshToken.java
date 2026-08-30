package com.level30.api.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** A2 — um refresh token emitido. Linhagem = {@code familyId}. */
@Entity
@Table(name = "refresh_tokens")
@Getter
@Setter
@NoArgsConstructor
public class RefreshToken {

    @Id
    private UUID jti;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "family_id", nullable = false)
    private UUID familyId;

    @Column(name = "issued_at", nullable = false)
    private Instant issuedAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "used_at")
    private Instant usedAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    @Column(name = "user_agent", length = 255)
    private String userAgent;

    @Column(length = 64)
    private String ip;

    public static RefreshToken create(UUID jti, UUID userId, UUID familyId,
                                      Instant now, Instant expiresAt, String userAgent, String ip) {
        RefreshToken t = new RefreshToken();
        t.jti = jti;
        t.userId = userId;
        t.familyId = familyId;
        t.issuedAt = now;
        t.expiresAt = expiresAt;
        t.userAgent = userAgent == null ? null : userAgent.substring(0, Math.min(userAgent.length(), 255));
        t.ip = ip == null ? null : ip.substring(0, Math.min(ip.length(), 64));
        return t;
    }

    public boolean isActive(Instant now) {
        return revokedAt == null && usedAt == null && expiresAt.isAfter(now);
    }
}
