package com.level30.api.controller;

import com.level30.api.domain.engajamento.AlertaEngajamento;
import com.level30.api.domain.engajamento.DirecaoOrdenacao;
import com.level30.api.domain.engajamento.EngajamentoFiltrado;
import com.level30.api.domain.engajamento.FiltroEngajamento;
import com.level30.api.domain.engajamento.OrdenacaoEngajamento;
import com.level30.api.domain.engajamento.RegistroAuditoria;
import com.level30.api.domain.engajamento.RelatorioEngajamento;
import com.level30.api.domain.engajamento.ResumoEngajamentoUsuario;
import com.level30.api.dto.request.RelatorioEngajamentoRequest;
import com.level30.api.dto.response.InatividadeVerificacaoResponse;
import com.level30.api.exception.RegraNegocioException;
import com.level30.api.gateway.EngajamentoGateway;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
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
@RequestMapping("/admin")
@Tag(name = "Engajamento (Oracle)")
@PreAuthorize("hasRole('ADMIN')")
public class AdminEngajamentoController {

    private final EngajamentoGateway engajamentoGateway;

    public AdminEngajamentoController(EngajamentoGateway engajamentoGateway) {
        this.engajamentoGateway = engajamentoGateway;
    }

    @PostMapping("/engajamento/relatorios")
    @Operation(summary = "Gera um relatorio de engajamento para o periodo (maximo 366 dias)")
    public RelatorioEngajamento gerarRelatorio(@Valid @RequestBody RelatorioEngajamentoRequest req) {
        if (req.inicio().isAfter(req.fim())) {
            throw new RegraNegocioException("Periodo invalido: inicio posterior ao fim.");
        }
        return engajamentoGateway.gerarRelatorio(req.inicio(), req.fim());
    }

    @GetMapping("/engajamento/relatorios/{execucaoId}")
    @Operation(summary = "Recupera um relatorio de engajamento ja gerado")
    public RelatorioEngajamento buscarRelatorio(@PathVariable long execucaoId) {
        return engajamentoGateway.buscarRelatorio(execucaoId);
    }

    @GetMapping("/engajamento/alertas")
    @Operation(summary = "Lista alertas de engajamento (inatividade, adesao baixa, streak reiniciado)")
    public List<AlertaEngajamento> listarAlertas(
            @RequestParam(name = "abertos", defaultValue = "true") boolean abertos) {
        return engajamentoGateway.listarAlertas(abertos);
    }

    @PostMapping("/engajamento/inatividade/verificar")
    @Operation(summary = "Roda a verificacao de inatividade agora (fora do agendamento)")
    public InatividadeVerificacaoResponse verificarInatividade(
            @RequestParam(name = "diasLimite", defaultValue = "3") int diasLimite) {
        return new InatividadeVerificacaoResponse(engajamentoGateway.verificarInatividade(diasLimite));
    }

    @GetMapping("/engajamento/usuarios/{id}/resumo")
    @Operation(summary = "Resumo formatado do aluno + taxa de adesao de 30 dias (functions Oracle)")
    public ResumoEngajamentoUsuario resumoUsuario(@PathVariable UUID id) {
        return engajamentoGateway.resumoUsuario(id);
    }

    @GetMapping("/engajamento")
    @Operation(summary = "Engajamento por aluno com filtros e ordenacao (Dynamic SQL seguro no Oracle)")
    public List<EngajamentoFiltrado> engajamentoFiltrado(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate inicio,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fim,
            @RequestParam(required = false) Integer nivelMin,
            @RequestParam(required = false) BigDecimal adesaoMin,
            @RequestParam(required = false) String ordenarPor,
            @RequestParam(required = false) String direcao) {
        if (inicio != null && fim != null && inicio.isAfter(fim)) {
            throw new RegraNegocioException("Periodo invalido: inicio posterior ao fim.");
        }
        if (nivelMin != null && nivelMin < 1) {
            throw new RegraNegocioException("nivelMin deve ser maior ou igual a 1.", HttpStatus.BAD_REQUEST);
        }
        if (adesaoMin != null && (adesaoMin.signum() < 0 || adesaoMin.compareTo(BigDecimal.valueOf(100)) > 0)) {
            throw new RegraNegocioException("adesaoMin deve estar entre 0 e 100.", HttpStatus.BAD_REQUEST);
        }
        return engajamentoGateway.consultarEngajamento(new FiltroEngajamento(
                inicio, fim, nivelMin, adesaoMin,
                OrdenacaoEngajamento.de(ordenarPor), DirecaoOrdenacao.de(direcao)));
    }

    @GetMapping("/auditoria")
    @Operation(summary = "Ultimas linhas da auditoria de conclusoes (L30_AUDIT_LOG)")
    public List<RegistroAuditoria> auditoria(@RequestParam(name = "limite", defaultValue = "50") int limite) {
        if (limite < 1 || limite > 500) {
            throw new RegraNegocioException("limite deve estar entre 1 e 500.", HttpStatus.BAD_REQUEST);
        }
        return engajamentoGateway.listarAuditoria(limite);
    }
}
