package com.level30.api.controller;

import com.level30.api.dto.response.ChallengeResponse;
import com.level30.api.dto.response.ProgramChallengeResponse;
import com.level30.api.security.AuthPrincipal;
import com.level30.api.service.ProgramChallengeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** C3 — visão do aluno: modelos de desafio publicados pela coordenação. */
@RestController
@RequestMapping("/programa")
@Tag(name = "Desafios do programa")
public class ProgramaController {

    private final ProgramChallengeService service;

    public ProgramaController(ProgramChallengeService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Modelos ativos, com marca de 'ja adotei'")
    public List<ProgramChallengeResponse> ativos(@AuthenticationPrincipal AuthPrincipal principal) {
        return service.ativos(principal.id());
    }

    @PostMapping("/{id}/adotar")
    @Operation(summary = "Adota um modelo — cria um desafio pessoal a partir dele")
    public ChallengeResponse adotar(@AuthenticationPrincipal AuthPrincipal principal,
                                    @PathVariable UUID id) {
        return service.adotar(principal.id(), id);
    }
}
