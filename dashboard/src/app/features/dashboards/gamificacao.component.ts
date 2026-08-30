import { Component, OnInit } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { forkJoin } from 'rxjs';
import { MetricasService } from '../../core/services/metricas.service';
import { AdminService } from '../../core/services/admin.service';
import { EngajamentoDia, Gamificacao, Indicadores } from '../../core/models';
import { apiErrorMessage } from '../../core/http-error.util';
import { BarChartComponent } from '../../shared/charts/bar-chart.component';
import { DonutChartComponent } from '../../shared/charts/donut-chart.component';
import { LineChartComponent } from '../../shared/charts/line-chart.component';
import { BarDatum, LineSeries, SliceDatum } from '../../shared/charts/chart-types';

const CAT_CORES = ['#00ff9c', '#22c55e', '#eab308', '#f97316', '#60a5fa'];

@Component({
  selector: 'app-gamificacao',
  standalone: true,
  imports: [NgIf, NgFor, BarChartComponent, DonutChartComponent, LineChartComponent],
  template: `
    <h1>Gamificação</h1>
    <p class="hint">A mecânica de jogo está calibrada? Conquista que ninguém tira está difícil demais; a que todo mundo tem não vale nada.</p>

    <div class="state" *ngIf="loading"><span class="spinner"></span>&nbsp; Carregando…</div>
    <div class="alert alert-error" *ngIf="error && !loading">
      {{ error }}
      <button type="button" class="btn-ghost" style="margin-left: 12px;" (click)="load()">Tentar de novo</button>
    </div>

    <ng-container *ngIf="!loading && !error">
      <section class="section grid two-col">
        <div class="card">
          <h2>Conquistas desbloqueadas</h2>
          <app-bar-chart [data]="conquistas"></app-bar-chart>
        </div>
        <div class="card">
          <h2>Distribuição de nível</h2>
          <app-bar-chart [data]="niveis"></app-bar-chart>
        </div>
      </section>

      <section class="section grid two-col">
        <div class="card">
          <h2>Streaks ativos</h2>
          <app-bar-chart [data]="streaks"></app-bar-chart>
        </div>
        <div class="card">
          <h2>Desafios por categoria</h2>
          <app-donut-chart [data]="categorias"></app-donut-chart>
        </div>
      </section>

      <section class="section card">
        <h2>XP distribuído no programa</h2>
        <p class="hint">Acumulado dos últimos 90 dias — total hoje: <strong>{{ xpTotal }}</strong> XP.</p>
        <app-line-chart [series]="xpSeries" [labels]="xpLabels"></app-line-chart>
      </section>
    </ng-container>
  `,
})
export class GamificacaoComponent implements OnInit {
  loading = false;
  error = '';

  conquistas: BarDatum[] = [];
  niveis: BarDatum[] = [];
  streaks: BarDatum[] = [];
  categorias: SliceDatum[] = [];
  xpSeries: LineSeries[] = [];
  xpLabels: string[] = [];
  xpTotal = 0;

  constructor(private metricas: MetricasService, private admin: AdminService) {}

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.loading = true;
    this.error = '';
    forkJoin({
      gam: this.metricas.gamificacao(),
      ind: this.admin.getIndicadores(),
      eng: this.metricas.engajamento(90),
    }).subscribe({
      next: ({ gam, ind, eng }) => {
        this.montarGamificacao(gam);
        this.montarCategorias(ind);
        this.montarXp(eng);
        this.loading = false;
      },
      error: (err: unknown) => {
        this.error = apiErrorMessage(err);
        this.loading = false;
      },
    });
  }

  private montarGamificacao(gam: Gamificacao): void {
    this.xpTotal = gam.xpTotalPrograma;
    this.conquistas = gam.conquistas.map((c) => ({ label: c.nome, value: c.quantidade }));
    this.niveis = gam.niveis.map((n) => ({ label: 'Nível ' + n.nivel, value: n.quantidade, color: 'var(--risk-medium)' }));
    this.streaks = gam.streaks.map((s) => ({ label: s.faixa + ' dias', value: s.quantidade, color: 'var(--risk-low)' }));
  }

  private montarCategorias(ind: Indicadores): void {
    this.categorias = ind.porCategoria.map((c, i) => ({
      label: this.categoriaLabel(c.chave),
      value: c.quantidade,
      color: CAT_CORES[i % CAT_CORES.length],
    }));
  }

  private montarXp(eng: EngajamentoDia[]): void {
    this.xpLabels = eng.map((d) => d.data.slice(5));
    let acc = 0;
    this.xpSeries = [
      {
        name: 'XP acumulado',
        color: 'var(--accent)',
        values: eng.map((d) => (acc += d.xpGanho)),
      },
    ];
  }

  private categoriaLabel(chave: string): string {
    return (
      { health: 'Saúde', study: 'Estudos', productivity: 'Produtividade', mindfulness: 'Mindfulness', fitness: 'Fitness' }[
        chave
      ] ?? chave
    );
  }
}
