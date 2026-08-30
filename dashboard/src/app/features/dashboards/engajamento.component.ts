import { Component, OnInit } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { forkJoin } from 'rxjs';
import { MetricasService } from '../../core/services/metricas.service';
import { Coorte, EngajamentoDia, SobrevivenciaPonto } from '../../core/models';
import { apiErrorMessage } from '../../core/http-error.util';
import { LineChartComponent } from '../../shared/charts/line-chart.component';
import { HeatmapComponent } from '../../shared/charts/heatmap.component';
import { SparklineComponent } from '../../shared/charts/sparkline.component';
import { HeatRow, LineSeries } from '../../shared/charts/chart-types';

interface Kpi {
  label: string;
  value: string;
  spark: number[];
}

@Component({
  selector: 'app-engajamento',
  standalone: true,
  imports: [NgIf, NgFor, LineChartComponent, HeatmapComponent, SparklineComponent],
  template: `
    <div class="page-head">
      <h1>Engajamento</h1>
      <div class="periodo">
        <button
          *ngFor="let p of periodos"
          type="button"
          class="btn-ghost"
          [class.active]="dias === p"
          (click)="mudarPeriodo(p)"
        >{{ p }} dias</button>
      </div>
    </div>

    <div class="state" *ngIf="loading"><span class="spinner"></span>&nbsp; Carregando…</div>
    <div class="alert alert-error" *ngIf="error && !loading">
      {{ error }}
      <button type="button" class="btn-ghost" style="margin-left: 12px;" (click)="load()">Tentar de novo</button>
    </div>

    <ng-container *ngIf="!loading && !error">
      <section class="section grid kpi-grid">
        <div class="card kpi-spark" *ngFor="let k of kpis">
          <div class="label">{{ k.label }}</div>
          <div class="value">{{ k.value }}</div>
          <app-sparkline [values]="k.spark"></app-sparkline>
        </div>
      </section>

      <section class="section card">
        <h2>Atividade diária</h2>
        <p class="hint">Conclusões e usuários ativos distintos por dia.</p>
        <app-line-chart [series]="atividadeSeries" [labels]="labels"></app-line-chart>
      </section>

      <section class="section grid two-col">
        <div class="card">
          <h2>Curva de sobrevivência</h2>
          <p class="hint">% de desafios que chegaram (ou passaram) ao dia N. Onde a curva cai é onde o programa perde gente.</p>
          <app-line-chart [series]="sobrevivenciaSeries" [labels]="sobrevivenciaLabels"></app-line-chart>
        </div>
        <div class="card">
          <h2>Retenção por coorte</h2>
          <p class="hint">Cada linha = semana de cadastro. Cada coluna = semanas depois com atividade.</p>
          <app-heatmap [rows]="coorteRows" [colLabels]="coorteCols" [max]="100" unit="%"></app-heatmap>
        </div>
      </section>
    </ng-container>
  `,
  styles: [`
    .page-head { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; }
    .periodo { display: flex; gap: 6px; }
    .periodo .btn-ghost.active { border-color: var(--accent); color: var(--accent); }
    .kpi-spark .label { color: var(--text-dim); font-size: 12px; text-transform: uppercase; letter-spacing: .6px; }
    .kpi-spark .value { font-size: 24px; font-weight: 700; margin: 4px 0 6px; }
  `],
})
export class EngajamentoComponent implements OnInit {
  readonly periodos = [7, 30, 90];
  dias = 30;
  loading = false;
  error = '';

  kpis: Kpi[] = [];
  labels: string[] = [];
  atividadeSeries: LineSeries[] = [];
  sobrevivenciaSeries: LineSeries[] = [];
  sobrevivenciaLabels: string[] = [];
  coorteRows: HeatRow[] = [];
  coorteCols: string[] = [];

  constructor(private metricas: MetricasService) {}

  ngOnInit(): void {
    this.load();
  }

  mudarPeriodo(p: number): void {
    this.dias = p;
    this.load();
  }

  load(): void {
    this.loading = true;
    this.error = '';
    forkJoin({
      eng: this.metricas.engajamento(this.dias),
      sob: this.metricas.sobrevivencia(),
      ret: this.metricas.retencao(),
    }).subscribe({
      next: ({ eng, sob, ret }) => {
        this.montarEngajamento(eng);
        this.montarSobrevivencia(sob);
        this.montarRetencao(ret);
        this.loading = false;
      },
      error: (err: unknown) => {
        this.error = apiErrorMessage(err);
        this.loading = false;
      },
    });
  }

  private montarEngajamento(dias: EngajamentoDia[]): void {
    this.labels = dias.map((d) => d.data.slice(5));
    this.atividadeSeries = [
      { name: 'Conclusões', color: 'var(--accent)', values: dias.map((d) => d.conclusoes) },
      { name: 'Usuários ativos', color: 'var(--risk-medium)', values: dias.map((d) => d.usuariosAtivos) },
    ];
    const ult7 = dias.slice(-7);
    const penult7 = dias.slice(-14, -7);
    const somaConcl = (xs: EngajamentoDia[]) => xs.reduce((s, d) => s + d.conclusoes, 0);
    const ativosHoje = dias.at(-1)?.usuariosAtivos ?? 0;
    const conclSemana = somaConcl(ult7);
    const ativosSemana = ult7.reduce((s, d) => s + d.usuariosAtivos, 0);
    const variacao = penult7.length
      ? Math.round(((conclSemana - somaConcl(penult7)) / Math.max(1, somaConcl(penult7))) * 100)
      : 0;
    this.kpis = [
      { label: 'Ativos hoje', value: String(ativosHoje), spark: dias.map((d) => d.usuariosAtivos) },
      { label: 'Conclusões na semana', value: String(conclSemana), spark: dias.map((d) => d.conclusoes) },
      {
        label: 'Média por usuário ativo',
        value: ativosSemana ? (conclSemana / ativosSemana).toFixed(1) : '—',
        spark: dias.map((d) => d.conclusoes),
      },
      {
        label: 'Variação vs. semana anterior',
        value: (variacao >= 0 ? '+' : '') + variacao + '%',
        spark: dias.map((d) => d.xpGanho),
      },
    ];
  }

  private montarSobrevivencia(pontos: SobrevivenciaPonto[]): void {
    this.sobrevivenciaLabels = pontos.map((p) => 'D' + p.dia);
    this.sobrevivenciaSeries = [
      { name: 'Ativos', color: 'var(--accent)', values: pontos.map((p) => p.pct) },
    ];
  }

  private montarRetencao(coortes: Coorte[]): void {
    const maxSemanas = Math.max(0, ...coortes.map((c) => c.retencao.length));
    this.coorteCols = Array.from({ length: maxSemanas }, (_, i) => 'S' + i);
    this.coorteRows = coortes.map((c) => ({
      label: `${c.semana.slice(5)} (${c.tamanho})`,
      cells: Array.from({ length: maxSemanas }, (_, i) =>
        i < c.retencao.length ? c.retencao[i] : null,
      ),
    }));
  }
}
