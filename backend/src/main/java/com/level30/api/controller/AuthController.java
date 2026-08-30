package com.level30.api.controller;

import com.level30.api.dto.request.LoginRequest;
import com.level30.api.dto.request.LogoutRequest;
import com.level30.api.dto.request.RefreshRequest;
import com.level30.api.dto.request.SignupRequest;
import com.level30.api.dto.response.AuthResponse;
import com.level30.api.security.ClientIpResolver;
import com.level30.api.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/auth")
@Tag(name = "Autenticacao")
@SecurityRequirements
public class AuthController {

    private final AuthService authService;
    private final ClientIpResolver clientIp;

    public AuthController(AuthService authService, ClientIpResolver clientIp) {
        this.authService = authService;
        this.clientIp = clientIp;
    }

    @PostMapping("/signup")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Cria conta e retorna tokens")
    public AuthResponse signup(@Valid @RequestBody SignupRequest req, HttpServletRequest http) {
        return authService.signup(req, http.getHeader("User-Agent"), clientIp.resolve(http));
    }

    @PostMapping("/login")
    @Operation(summary = "Autentica e retorna tokens")
    public AuthResponse login(@Valid @RequestBody LoginRequest req, HttpServletRequest http) {
        return authService.login(req, http.getHeader("User-Agent"), clientIp.resolve(http));
    }

    @PostMapping("/refresh")
    @Operation(summary = "Rotaciona: consome o refresh token e devolve access + refresh novos")
    public AuthResponse refresh(@Valid @RequestBody RefreshRequest req, HttpServletRequest http) {
        return authService.refresh(req.refreshToken(), http.getHeader("User-Agent"), clientIp.resolve(http));
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Revoga a familia do refresh token informado")
    public void logout(@RequestBody(required = false) LogoutRequest req) {
        authService.logout(req == null ? null : req.refreshToken());
    }
}
