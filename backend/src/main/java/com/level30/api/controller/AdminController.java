package com.level30.api.controller;

import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.RiskLevel;
import com.level30.api.dto.request.ProgramChallengeRequest;
import com.level30.api.dto.response.AdminChallengeResponse;
import com.level30.api.dto.response.AdminUserResponse;
import com.level30.api.dto.response.IndicadoresResponse;
import com.level30.api.dto.response.ProgramChallengeResponse;
import com.level30.api.security.AuthPrincipal;
import com.level30.api.service.AdminService;
import com.level30.api.service.ProgramChallengeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/admin")
@Tag(name = "Admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    private final AdminService adminService;
    private final ProgramChallengeService programService;

    public AdminController(AdminService adminService, ProgramChallengeService programService) {
        this.adminService = adminService;
        this.programService = programService;
    }

    @GetMapping("/usuarios")
    @Operation(summary = "Lista paginada de usuarios com nivel e nº de desafios")
    public Page<AdminUserResponse> usuarios(@PageableDefault(size = 20) Pageable pageable) {
        return adminService.usuarios(pageable);
    }

    @GetMapping("/desafios")
    @Operation(summary = "Lista paginada de desafios, com risco calculado; filtros opcionais")
    public Page<AdminChallengeResponse> desafios(
            @RequestParam(required = false) RiskLevel riskLevel,
            @RequestParam(required = false) Category category,
            @RequestParam(required = false) String busca,
            @PageableDefault(size = 20) Pageable pageable) {
        return adminService.desafios(riskLevel, category, busca, pageable);
    }

    @GetMapping("/indicadores")
    @Operation(summary = "Agregacoes para o dashboard")
    public IndicadoresResponse indicadores() {
        return adminService.indicadores();
    }

    // ---- C3 · desafios do programa ----

    @GetMapping("/programa")
    @Operation(summary = "Modelos de desafio do programa (todos, com nº de adotantes)")
    public List<ProgramChallengeResponse> programa() {
        return programService.listarTodos();
    }

    @PostMapping("/programa")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Publica um modelo de desafio do programa")
    public ProgramChallengeResponse criarPrograma(@AuthenticationPrincipal AuthPrincipal principal,
                                                  @Valid @RequestBody ProgramChallengeRequest req) {
        return programService.criar(req, principal.id());
    }

    @PatchMapping("/programa/{id}")
    @Operation(summary = "Ativa/arquiva um modelo — body { \"active\": true|false }")
    public ProgramChallengeResponse alternarPrograma(@PathVariable UUID id,
                                                     @RequestBody Map<String, Boolean> body) {
        return programService.definirAtivo(id, Boolean.TRUE.equals(body.get("active")));
    }

    @DeleteMapping("/programa/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Remove um modelo do programa (desafios ja adotados nao mudam)")
    public void removerPrograma(@PathVariable UUID id) {
        programService.remover(id);
    }
}
