import { Component, OnInit } from '@angular/core';
import { NgClass, NgFor, NgIf } from '@angular/common';
import { RouterLink } from '@angular/router';
import { forkJoin } from 'rxjs';
import { MetricasService } from '../../core/services/metricas.service';
import { AdminService } from '../../core/services/admin.service';
import { AdminChallenge, Indicadores, RiscoDia } from '../../core/models';
import { apiErrorMessage } from '../../core/http-error.util';
import { CategoriaLabelPipe, RiscoLabelPipe } from '../../shared/pipes/rotulos.pipe';
import { DonutChartComponent } from '../../shared/charts/donut-chart.component';
import { LineChartComponent } from '../../shared/charts/line-chart.component';
import { BarChartComponent } from '../../shared/charts/bar-chart.component';
import { BarDatum, LineSeries, SliceDatum } from '../../shared/charts/chart-types';

const CORES: Record<string, string> = {
  low: 'var(--risk-low)',
  medium: 'var(--risk-medium)',
  high: 'var(--risk-high)',
  critical: 'var(--risk-critical)',
};

@Component({
  selector: 'app-risco',
  standalone: true,
  imports: [
    NgIf, NgFor, NgClass, RouterLink, CategoriaLabelPipe, RiscoLabelPipe,
    DonutChartComponent, LineChartComponent, BarChartComponent,
  ],
  template: `
    <h1>Risco de abandono</h1>

    <div class="state" *ngIf="loading"><span class="spinner"></span>&nbsp; Carregando…</div>
    <div class="alert alert-error" *ngIf="error && !loading">
      {{ error }}
      <button type="button" class="btn-ghost" style="margin-left: 12px;" (click)="load()">Tentar de novo</button>
    </div>

    <ng-container *ngIf="!loading && !error">
      <section class="section grid two-col">
        <div class="card">
          <h2>Distribuição atual</h2>
          <app-donut-chart [data]="distribuicao"></app-donut-chart>
        </div>
        <div class="card">
          <h2>Evolução do risco</h2>
          <p class="hint">Distribuição de risco por dia (snapshots).</p>
          <app-line-chart [series]="evolucaoSeries" [labels]="evolucaoLabels" [stacked]="true"></app-line-chart>
        </div>
      </section>

      <section class="section card">
        <div class="fila-head">
          <h2>Fila de intervenção</h2>
          <span class="hint">{{ fila.length }} desafio(s) em risco alto ou crítico</span>
        </div>
        <div class="state" *ngIf="fila.length === 0">Ninguém precisa de atenção agora. 🎉</div>
        <div class="table-wrap" *ngIf="fila.length > 0">
          <table>
            <thead>
              <tr><th>Título</th><th>Aluno</th><th>Categoria</th><th>Progresso</th><th>Parado há</th><th>Risco</th><th></th></tr>
            </thead>
            <tbody>
              <tr *ngFor="let d of fila">
                <td>{{ d.titulo }}</td>
                <td>{{ d.usuarioNome }}<div class="sub">{{ d.usuarioEmail }}</div></td>
                <td>{{ d.categoria | categoriaLabel }}</td>
                <td>{{ d.currentDay }}/{{ d.totalDays }}</td>
                <td>{{ diasParado(d) }}</td>
                <td>
                  <span class="badge" [ngClass]="'risk-' + d.riskLevel" [style.background]="cor(d.riskLevel)">
                    {{ d.riskLevel | riscoLabel }} · {{ (d.riskScore * 100).toFixed(0) }}%
                  </span>
                </td>
                <td><a class="btn-ghost" [routerLink]="['/admin']">Ver</a></td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="section card">
        <h2>Desafios em risco por categoria</h2>
        <app-bar-chart [data]="porCategoria"></app-bar-chart>
      </section>
    </ng-container>
  `,
  styles: [`
    .fila-head { display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px; }
    .sub { color: var(--text-dim); font-size: 12px; }
  `],
})
export class RiscoComponent implements OnInit {
  loading = false;
  error = '';

  distribuicao: SliceDatum[] = [];
  evolucaoSeries: LineSeries[] = [];
  evolucaoLabels: string[] = [];
  fila: AdminChallenge[] = [];
  porCategoria: BarDatum[] = [];

  constructor(private metricas: MetricasService, private admin: AdminService) {}

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.loading = true;
    this.error = '';
    forkJoin({
      ind: this.admin.getIndicadores(),
      risco: this.metricas.risco(30),
      criticos: this.admin.getDesafios({ riskLevel: 'critical', page: 0, size: 50 }),
      altos: this.admin.getDesafios({ riskLevel: 'high', page: 0, size: 50 }),
    }).subscribe({
      next: ({ ind, risco, criticos, altos }) => {
        this.montarDistribuicao(ind);
        this.montarEvolucao(risco);
        this.fila = [...criticos.content, ...altos.content].sort((a, b) => b.riskScore - a.riskScore);
        this.montarPorCategoria();
        this.loading = false;
      },
      error: (err: unknown) => {
        this.error = apiErrorMessage(err);
        this.loading = false;
      },
    });
  }

  private montarDistribuicao(ind: Indicadores): void {
    this.distribuicao = ind.porNivelDeRisco.map((r) => ({
      label: this.rotulo(r.chave),
      value: r.quantidade,
      color: CORES[r.chave] ?? 'var(--accent)',
    }));
  }

  private montarEvolucao(dias: RiscoDia[]): void {
    this.evolucaoLabels = dias.map((d) => d.data.slice(5));
    this.evolucaoSeries = [
      { name: 'Baixo', color: 'var(--risk-low)', values: dias.map((d) => d.low) },
      { name: 'Médio', color: 'var(--risk-medium)', values: dias.map((d) => d.medium) },
      { name: 'Alto', color: 'var(--risk-high)', values: dias.map((d) => d.high) },
      { name: 'Crítico', color: 'var(--risk-critical)', values: dias.map((d) => d.critical) },
    ];
  }

  private montarPorCategoria(): void {
    const m = new Map<string, number>();
    for (const d of this.fila) {
      m.set(d.categoria, (m.get(d.categoria) ?? 0) + 1);
    }
    this.porCategoria = [...m.entries()]
      .map(([cat, n]) => ({ label: this.categoriaLabel(cat), value: n, color: 'var(--risk-high)' }))
      .sort((a, b) => b.value - a.value);
  }

  cor(nivel: string): string {
    return CORES[nivel] ?? 'var(--accent)';
  }

  diasParado(d: AdminChallenge): string {
    // sem lastActivity no AdminChallenge — aproxima pelo risco de inatividade
    return d.riskLevel === 'critical' ? '3+ dias' : d.riskLevel === 'high' ? '~2 dias' : '—';
  }

  private rotulo(chave: string): string {
    return { low: 'Baixo', medium: 'Médio', high: 'Alto', critical: 'Crítico' }[chave] ?? chave;
  }

  private categoriaLabel(chave: string): string {
    return (
      { health: 'Saúde', study: 'Estudos', productivity: 'Produtividade', mindfulness: 'Mindfulness', fitness: 'Fitness' }[
        chave
      ] ?? chave
    );
  }
}
