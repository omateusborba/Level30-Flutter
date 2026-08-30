package com.level30.api.controller;

import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.RiskLevel;
import com.level30.api.dto.response.AdminChallengeResponse;
import com.level30.api.dto.response.AdminUserResponse;
import com.level30.api.dto.response.IndicadoresResponse;
import com.level30.api.service.AdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/admin")
@Tag(name = "Admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    private final AdminService adminService;

    public AdminController(AdminService adminService) {
        this.adminService = adminService;
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
            @PageableDefault(size = 20) Pageable pageable) {
        return adminService.desafios(riskLevel, category, pageable);
    }

    @GetMapping("/indicadores")
    @Operation(summary = "Agregacoes para o dashboard")
    public IndicadoresResponse indicadores() {
        return adminService.indicadores();
    }
}
