package com.level30.api.security;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Component;

/**
 * IP real do cliente. A API roda atras do Cloudflare Tunnel — sem tratar os
 * headers, todo request chega com o IP do {@code cloudflared} e o rate limit
 * por IP protege nada.
 *
 * <p>Ordem: {@code CF-Connecting-IP} (posto pela Cloudflare) &rarr; primeiro hop
 * de {@code X-Forwarded-For} &rarr; {@code getRemoteAddr()}.
 */
@Component
public class ClientIpResolver {

    public String resolve(HttpServletRequest req) {
        String cf = req.getHeader("CF-Connecting-IP");
        if (cf != null && !cf.isBlank()) {
            return cf.trim();
        }
        String xff = req.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            int comma = xff.indexOf(',');
            return (comma > 0 ? xff.substring(0, comma) : xff).trim();
        }
        String remote = req.getRemoteAddr();
        return remote != null ? remote : "unknown";
    }
}
