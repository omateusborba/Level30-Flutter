package com.level30.api.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
public class User {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(nullable = false)
    private String name;

    @Column(name = "total_xp", nullable = false)
    private int totalXp;

    @Column(columnDefinition = "text")
    private String avatar;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role = Role.USER;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** A1 — tentativas de login falhas consecutivas. Zera no login bem-sucedido. */
    @Column(name = "failed_attempts", nullable = false)
    private int failedAttempts;

    /** A1 — conta bloqueada ate este instante (lockout progressivo). */
    @Column(name = "locked_until")
    private Instant lockedUntil;

    public static User create(String email, String passwordHash, String name, Role role) {
        User u = new User();
        u.id = UUID.randomUUID();
        u.email = email;
        u.passwordHash = passwordHash;
        u.name = name;
        u.role = role;
        u.totalXp = 0;
        u.createdAt = Instant.now();
        return u;
    }
}
