package com.level30.api.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.level30.api.dto.response.ErroResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

/**
 * Garante que 401 e 403 saiam no mesmo contrato de erro JSON do resto da API,
 * já que o fluxo stateless não passa pelo {@code GlobalExceptionHandler}.
 */
@Component
public class RestAuthErrorHandlers {

    private final ObjectMapper mapper;

    public RestAuthErrorHandlers(ObjectMapper mapper) {
        this.mapper = mapper;
    }

    public AuthenticationEntryPoint entryPoint() {
        return this::writeUnauthorized;
    }

    public AccessDeniedHandler accessDeniedHandler() {
        return this::writeForbidden;
    }

    private void writeUnauthorized(HttpServletRequest req, HttpServletResponse res,
                                   AuthenticationException ex) throws IOException {
        write(res, HttpServletResponse.SC_UNAUTHORIZED, "Nao autenticado.");
    }

    private void writeForbidden(HttpServletRequest req, HttpServletResponse res,
                                AccessDeniedException ex) throws IOException {
        write(res, HttpServletResponse.SC_FORBIDDEN, "Acesso negado.");
    }

    private void write(HttpServletResponse res, int status, String mensagem) throws IOException {
        res.setStatus(status);
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        res.setCharacterEncoding("UTF-8");
        mapper.writeValue(res.getWriter(), ErroResponse.of(status, mensagem));
    }
}
