package com.level30.api.controller;

import com.level30.api.dto.response.Metricas;
import com.level30.api.service.MetricasService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** B1 — métricas agregadas para os dashboards. */
@RestController
@RequestMapping("/admin/metricas")
@Tag(name = "Admin · Métricas")
@PreAuthorize("hasRole('ADMIN')")
public class MetricasController {

    private final MetricasService metricas;

    public MetricasController(MetricasService metricas) {
        this.metricas = metricas;
    }

    @GetMapping("/engajamento")
    @Operation(summary = "Série diária: conclusões, usuários ativos, novos desafios, XP ganho")
    public List<Metricas.Dia> engajamento(@RequestParam(name = "dias", defaultValue = "30") int dias) {
        return metricas.engajamento(dias);
    }

    @GetMapping("/sobrevivencia")
    @Operation(summary = "Curva de sobrevivência: % de desafios que chegam ao dia N")
    public List<Metricas.Sobrevivencia> sobrevivencia() {
        return metricas.sobrevivencia();
    }

    @GetMapping("/retencao")
    @Operation(summary = "Retenção por coorte (semana de cadastro × semanas ativas)")
    public List<Metricas.Coorte> retencao() {
        return metricas.retencao();
    }

    @GetMapping("/risco")
    @Operation(summary = "Evolução da distribuição de risco no tempo (snapshots diários)")
    public List<Metricas.RiscoDia> risco(@RequestParam(name = "dias", defaultValue = "30") int dias) {
        return metricas.riscoNoTempo(dias);
    }

    @GetMapping("/gamificacao")
    @Operation(summary = "Conquistas, distribuição de nível, faixas de streak, XP do programa")
    public Metricas.Gamificacao gamificacao() {
        return metricas.gamificacao();
    }

    @GetMapping("/padroes")
    @Operation(summary = "Conclusões por dia da semana e por faixa horária")
    public Metricas.Padroes padroes() {
        return metricas.padroes();
    }
}
