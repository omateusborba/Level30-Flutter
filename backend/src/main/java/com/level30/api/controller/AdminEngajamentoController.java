package com.level30.api.controller;

import com.level30.api.domain.engajamento.AlertaEngajamento;
import com.level30.api.domain.engajamento.RelatorioEngajamento;
import com.level30.api.domain.engajamento.ResumoEngajamentoUsuario;
import com.level30.api.dto.request.RelatorioEngajamentoRequest;
import com.level30.api.dto.response.InatividadeVerificacaoResponse;
import com.level30.api.exception.RegraNegocioException;
import com.level30.api.gateway.EngajamentoGateway;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Fase 6 — painel de engajamento, alimentado pela camada Oracle PL/SQL ({@code db/oracle/}).
 * Some com 503 ({@link com.level30.api.exception.CamadaOracleIndisponivelException}) quando a
 * camada está desligada neste ambiente ({@code level30.oracle.enabled=false}, o padrão hoje).
 */
@RestController
@RequestMapping("/admin/engajamento")
@Tag(name = "Engajamento (Oracle)")
@PreAuthorize("hasRole('ADMIN')")
public class AdminEngajamentoController {

    private final EngajamentoGateway engajamentoGateway;

    public AdminEngajamentoController(EngajamentoGateway engajamentoGateway) {
        this.engajamentoGateway = engajamentoGateway;
    }

    @PostMapping("/relatorios")
    @Operation(summary = "Gera um relatorio de engajamento para o periodo (maximo 366 dias)")
    public RelatorioEngajamento gerarRelatorio(@Valid @RequestBody RelatorioEngajamentoRequest req) {
        if (req.inicio().isAfter(req.fim())) {
            throw new RegraNegocioException("Periodo invalido: inicio posterior ao fim.");
        }
        return engajamentoGateway.gerarRelatorio(req.inicio(), req.fim());
    }

    @GetMapping("/relatorios/{execucaoId}")
    @Operation(summary = "Recupera um relatorio de engajamento ja gerado")
    public RelatorioEngajamento buscarRelatorio(@PathVariable long execucaoId) {
        return engajamentoGateway.buscarRelatorio(execucaoId);
    }

    @GetMapping("/alertas")
    @Operation(summary = "Lista alertas de engajamento (inatividade, adesao baixa, streak reiniciado)")
    public List<AlertaEngajamento> listarAlertas(
            @RequestParam(name = "abertos", defaultValue = "true") boolean abertos) {
        return engajamentoGateway.listarAlertas(abertos);
    }

    @PostMapping("/inatividade/verificar")
    @Operation(summary = "Roda a verificacao de inatividade agora (fora do agendamento)")
    public InatividadeVerificacaoResponse verificarInatividade(
            @RequestParam(name = "diasLimite", defaultValue = "3") int diasLimite) {
        return new InatividadeVerificacaoResponse(engajamentoGateway.verificarInatividade(diasLimite));
    }

    @GetMapping("/usuarios/{id}/resumo")
    @Operation(summary = "Resumo formatado do aluno + taxa de adesao de 30 dias (functions Oracle)")
    public ResumoEngajamentoUsuario resumoUsuario(@PathVariable UUID id) {
        return engajamentoGateway.resumoUsuario(id);
    }
}
