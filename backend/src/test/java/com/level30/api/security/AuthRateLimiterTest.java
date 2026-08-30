package com.level30.api.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/** A1 — janela fixa do rate limit por IP (unitario, sem Spring). */
class AuthRateLimiterTest {

    @Test
    void bloqueiaAcimaDoLimiteNaMesmaJanela() {
        AuthRateLimiter limiter = new AuthRateLimiter(3, 60);

        assertThat(limiter.check("ip:a").allowed()).isTrue();
        assertThat(limiter.check("ip:a").allowed()).isTrue();
        assertThat(limiter.check("ip:a").allowed()).isTrue();

        AuthRateLimiter.Result quarta = limiter.check("ip:a");
        assertThat(quarta.allowed()).isFalse();
        assertThat(quarta.retryAfterSeconds()).isBetween(1L, 60L);
    }

    @Test
    void chavesDiferentesNaoInterferem() {
        AuthRateLimiter limiter = new AuthRateLimiter(1, 60);
        assertThat(limiter.check("ip:a").allowed()).isTrue();
        assertThat(limiter.check("ip:b").allowed()).isTrue();
        assertThat(limiter.check("ip:a").allowed()).isFalse();
    }

    @Test
    void resetLiberaNovamente() {
        AuthRateLimiter limiter = new AuthRateLimiter(1, 60);
        assertThat(limiter.check("ip:a").allowed()).isTrue();
        assertThat(limiter.check("ip:a").allowed()).isFalse();
        limiter.reset();
        assertThat(limiter.check("ip:a").allowed()).isTrue();
    }
}
