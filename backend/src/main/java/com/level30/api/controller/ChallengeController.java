package com.level30.api.controller;

import com.level30.api.dto.request.ChallengeRequest;
import com.level30.api.dto.response.ChallengeResponse;
import com.level30.api.dto.response.CompleteResponse;
import com.level30.api.dto.response.CompletionResponse;
import com.level30.api.dto.response.RecommendationResponse;
import com.level30.api.security.AuthPrincipal;
import com.level30.api.service.ChallengeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/challenges")
@Tag(name = "Desafios")
public class ChallengeController {

    private final ChallengeService challengeService;

    public ChallengeController(ChallengeService challengeService) {
        this.challengeService = challengeService;
    }

    @GetMapping
    @Operation(summary = "Lista os desafios do usuario (mais recentes primeiro)")
    public List<ChallengeResponse> list(@AuthenticationPrincipal AuthPrincipal principal) {
        return challengeService.listForUser(principal.id());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Cria um desafio")
    public ChallengeResponse create(@AuthenticationPrincipal AuthPrincipal principal,
                                    @Valid @RequestBody ChallengeRequest req) {
        return challengeService.create(principal.id(), req);
    }

    @PostMapping("/{id}/complete")
    @Operation(summary = "Marca o dia de hoje como concluido")
    public CompleteResponse complete(@AuthenticationPrincipal AuthPrincipal principal,
                                     @PathVariable UUID id) {
        return challengeService.completeDay(principal.id(), id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Exclui um desafio")
    public void delete(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable UUID id) {
        challengeService.delete(principal.id(), id);
    }

    @GetMapping("/{id}/recommendation")
    @Operation(summary = "Recomendacao do dia (IA com fallback deterministico)")
    public ResponseEntity<RecommendationResponse> recommendation(
            @AuthenticationPrincipal AuthPrincipal principal, @PathVariable UUID id) {
        return ResponseEntity.ok(challengeService.recommendation(principal.id(), id));
    }

    @GetMapping("/{id}/historico")
    @Operation(summary = "Historico de conclusoes do desafio (F1)")
    public List<CompletionResponse> historico(
            @AuthenticationPrincipal AuthPrincipal principal, @PathVariable UUID id) {
        return challengeService.historico(principal.id(), id);
    }
}
