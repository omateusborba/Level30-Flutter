package com.level30.api.security;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * A1 — rate limit por IP nas rotas {@code /auth/**}. Janela fixa em memoria
 * (sem Redis — a escala nao justifica). Reinicia a cada boot, o que e aceitavel.
 */
@Component
public class AuthRateLimiter {

    public record Result(boolean allowed, long retryAfterSeconds) {}

    private static final class Window {
        long startMillis;
        int count;
    }

    private final Map<String, Window> windows = new ConcurrentHashMap<>();
    private final int maxRequests;
    private final long windowMillis;

    public AuthRateLimiter(
            @Value("${app.security.auth-rate-limit.max-requests:10}") int maxRequests,
            @Value("${app.security.auth-rate-limit.window-seconds:60}") long windowSeconds) {
        this.maxRequests = maxRequests;
        this.windowMillis = windowSeconds * 1000L;
    }

    public Result check(String key) {
        long now = System.currentTimeMillis();
        if (windows.size() > 10_000) {
            windows.entrySet().removeIf(e -> now - e.getValue().startMillis >= windowMillis);
        }
        Window w = windows.compute(key, (k, cur) -> {
            if (cur == null || now - cur.startMillis >= windowMillis) {
                Window fresh = new Window();
                fresh.startMillis = now;
                fresh.count = 1;
                return fresh;
            }
            cur.count++;
            return cur;
        });
        if (w.count <= maxRequests) {
            return new Result(true, 0);
        }
        long retry = (windowMillis - (now - w.startMillis)) / 1000 + 1;
        return new Result(false, Math.max(1, retry));
    }

    /** Teste/manutencao. */
    public void reset() {
        windows.clear();
    }
}
