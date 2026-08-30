package com.level30.api.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.level30.api.dto.response.ErroResponse;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * A1 — barra excesso de requisicoes por IP nas rotas de autenticacao antes de
 * qualquer processamento. Instanciado direto no {@code SecurityConfig} (nao e
 * bean) para nao ser auto-registrado e contar em dobro.
 */
public class AuthRateLimitFilter extends OncePerRequestFilter {

    private final AuthRateLimiter limiter;
    private final ClientIpResolver ip;
    private final ObjectMapper mapper;

    public AuthRateLimitFilter(AuthRateLimiter limiter, ClientIpResolver ip, ObjectMapper mapper) {
        this.limiter = limiter;
        this.ip = ip;
        this.mapper = mapper;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        if (!"POST".equalsIgnoreCase(request.getMethod())) {
            return true;
        }
        String path = request.getRequestURI();
        return !(path.equals("/auth/login")
                || path.equals("/auth/signup")
                || path.equals("/auth/refresh"));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        AuthRateLimiter.Result r = limiter.check("ip:" + ip.resolve(request));
        if (r.allowed()) {
            filterChain.doFilter(request, response);
            return;
        }
        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setHeader("Retry-After", String.valueOf(r.retryAfterSeconds()));
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        mapper.writeValue(response.getWriter(), ErroResponse.of(
                HttpStatus.TOO_MANY_REQUESTS.value(),
                "Muitas tentativas. Aguarde um momento e tente de novo."));
    }
}
