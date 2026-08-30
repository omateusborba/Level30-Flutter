package com.level30.api.controller;

import com.level30.api.dto.request.AvatarRequest;
import com.level30.api.dto.response.UserResponse;
import com.level30.api.security.AuthPrincipal;
import com.level30.api.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/me")
@Tag(name = "Perfil")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    @Operation(summary = "Perfil do usuario autenticado")
    public UserResponse me(@AuthenticationPrincipal AuthPrincipal principal) {
        return userService.me(principal.id());
    }

    @PutMapping("/avatar")
    @Operation(summary = "Atualiza a foto de perfil (data URI base64)")
    public Map<String, String> updateAvatar(@AuthenticationPrincipal AuthPrincipal principal,
                                            @Valid @RequestBody AvatarRequest req) {
        return Map.of("avatar", userService.updateAvatar(principal.id(), req.avatar()));
    }
}
