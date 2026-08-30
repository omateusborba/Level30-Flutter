package com.level30.api.config;

import com.level30.api.repository.RefreshTokenRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** A2 — expurga refresh tokens vencidos ha mais de 2 dias. Diario, 03:15. */
@Component
public class RefreshTokenCleanup {

    private static final Logger log = LoggerFactory.getLogger(RefreshTokenCleanup.class);

    private final RefreshTokenRepository tokens;

    public RefreshTokenCleanup(RefreshTokenRepository tokens) {
        this.tokens = tokens;
    }

    @Scheduled(cron = "0 15 3 * * *")
    public void purge() {
        int removed = tokens.deleteExpiredBefore(Instant.now().minus(2, ChronoUnit.DAYS));
        if (removed > 0) {
            log.info("RefreshTokenCleanup: {} tokens vencidos removidos.", removed);
        }
    }
}
