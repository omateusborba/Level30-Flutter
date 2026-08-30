package com.level30.api.service;

import com.level30.api.domain.model.User;
import com.level30.api.repository.UserRepository;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * A1 — bookkeeping do lockout por conta, em transacao propria. Fica fora do
 * {@code AuthService.login} de proposito: o login lanca excecao no caminho de
 * falha, e uma transacao unica faria rollback do incremento.
 */
@Service
public class LoginAttemptService {

    /** Trava a conta a partir da 5a falha consecutiva. */
    private static final int LOCK_THRESHOLD = 5;

    private final UserRepository users;

    public LoginAttemptService(UserRepository users) {
        this.users = users;
    }

    /** @return segundos restantes de bloqueio, ou 0 se a conta nao esta bloqueada. */
    @Transactional(readOnly = true)
    public long lockRemainingSeconds(User user) {
        Instant until = user.getLockedUntil();
        if (until == null || !until.isAfter(Instant.now())) {
            return 0;
        }
        return Instant.now().until(until, java.time.temporal.ChronoUnit.SECONDS) + 1;
    }

    @Transactional
    public void recordFailure(UUID userId) {
        users.findById(userId).ifPresent(user -> {
            int attempts = user.getFailedAttempts() + 1;
            user.setFailedAttempts(attempts);
            if (attempts >= LOCK_THRESHOLD) {
                user.setLockedUntil(Instant.now().plusSeconds(backoffSeconds(attempts)));
            }
            users.save(user);
        });
    }

    @Transactional
    public void reset(UUID userId) {
        users.findById(userId).ifPresent(user -> {
            if (user.getFailedAttempts() != 0 || user.getLockedUntil() != null) {
                user.setFailedAttempts(0);
                user.setLockedUntil(null);
                users.save(user);
            }
        });
    }

    /** Lockout progressivo: 1, 5, 15 e 60 minutos. */
    private long backoffSeconds(int attempts) {
        return switch (attempts) {
            case 5 -> 60;
            case 6 -> 300;
            case 7 -> 900;
            default -> 3600;
        };
    }
}
