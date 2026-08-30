package com.level30.api.exception;

import com.level30.api.dto.response.ErroResponse;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(RecursoNaoEncontradoException.class)
    public ResponseEntity<ErroResponse> handleNotFound(RecursoNaoEncontradoException ex) {
        return build(HttpStatus.NOT_FOUND, ex.getMessage(), List.of());
    }

    @ExceptionHandler(RegraNegocioException.class)
    public ResponseEntity<ErroResponse> handleRegra(RegraNegocioException ex) {
        return build(ex.getStatus(), ex.getMessage(), List.of());
    }

    @ExceptionHandler(AiIndisponivelException.class)
    public ResponseEntity<ErroResponse> handleAi(AiIndisponivelException ex) {
        return build(HttpStatus.BAD_GATEWAY, ex.getMessage(), List.of());
    }

    @ExceptionHandler(ContaBloqueadaException.class)
    public ResponseEntity<ErroResponse> handleBloqueio(ContaBloqueadaException ex) {
        return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                .header("Retry-After", String.valueOf(ex.getRetryAfterSeconds()))
                .body(ErroResponse.of(HttpStatus.TOO_MANY_REQUESTS.value(), ex.getMessage(), List.of()));
    }

    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ErroResponse> handleAuth(AuthenticationException ex) {
        return build(HttpStatus.UNAUTHORIZED, ex.getMessage(), List.of());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErroResponse> handleValidation(MethodArgumentNotValidException ex) {
        List<String> detalhes = ex.getBindingResult().getFieldErrors().stream()
                .map(f -> f.getField() + ": " + f.getDefaultMessage())
                .toList();
        return build(HttpStatus.BAD_REQUEST, "Dados invalidos.", detalhes);
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, IllegalArgumentException.class})
    public ResponseEntity<ErroResponse> handleBadRequest(Exception ex) {
        return build(HttpStatus.BAD_REQUEST, mensagemLegivel(ex), List.of());
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErroResponse> handleUnexpected(Exception ex, HttpServletRequest req) {
        log.error("Erro nao tratado em {} {}", req.getMethod(), req.getRequestURI(), ex);
        return build(HttpStatus.INTERNAL_SERVER_ERROR, "Erro interno inesperado.", List.of());
    }

    private String mensagemLegivel(Exception ex) {
        if (ex instanceof IllegalArgumentException) {
            return ex.getMessage();
        }
        return "Requisicao malformada.";
    }

    private ResponseEntity<ErroResponse> build(HttpStatus status, String mensagem, List<String> detalhes) {
        return ResponseEntity.status(status)
                .body(ErroResponse.of(status.value(), mensagem, detalhes));
    }
}
