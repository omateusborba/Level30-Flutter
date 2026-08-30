package com.level30.api.controller;

import com.level30.api.dto.request.AvatarRequest;
import com.level30.api.dto.response.AchievementResponse;
import com.level30.api.dto.response.AtividadeDiaResponse;
import com.level30.api.dto.response.UserResponse;
import com.level30.api.security.AuthPrincipal;
import com.level30.api.service.AchievementService;
import com.level30.api.service.ChallengeService;
import com.level30.api.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/me")
@Tag(name = "Perfil")
public class UserController {

    private final UserService userService;
    private final ChallengeService challengeService;
    private final AchievementService achievementService;

    public UserController(UserService userService, ChallengeService challengeService,
                          AchievementService achievementService) {
        this.userService = userService;
        this.challengeService = challengeService;
        this.achievementService = achievementService;
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

    @GetMapping("/atividade")
    @Operation(summary = "Conclusoes por dia desde a data informada (heatmap)")
    public List<AtividadeDiaResponse> atividade(
            @AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam(name = "desde")
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde) {
        return challengeService.atividade(principal.id(), desde);
    }

    @GetMapping("/conquistas")
    @Operation(summary = "Catalogo de conquistas com estado de desbloqueio (F4)")
    public List<AchievementResponse> conquistas(@AuthenticationPrincipal AuthPrincipal principal) {
        return achievementService.listar(principal.id());
    }
}
