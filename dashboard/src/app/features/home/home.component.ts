import { Component, OnInit } from '@angular/core';
import { NgForOf, NgIf } from '@angular/common';
import { AdminService } from '../../core/services/admin.service';
import { Distribuicao, Indicadores } from '../../core/models';
import { apiErrorMessage } from '../../core/http-error.util';

interface Kpi {
  label: string;
  value: number;
}

const RISK_COLORS: Record<string, string> = {
  low: 'var(--risk-low)',
  medium: 'var(--risk-medium)',
  high: 'var(--risk-high)',
  critical: 'var(--risk-critical)',
};

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [NgIf, NgForOf],
  template: `
    <h1>Indicadores do programa</h1>

    <!-- loading -->
    <div class="state" *ngIf="loading">
      <span class="spinner"></span>&nbsp; Carregando indicadores...
    </div>

    <!-- erro -->
    <div class="alert alert-error" *ngIf="error && !loading">
      {{ error }}
      <button type="button" class="btn-ghost" style="margin-left: 12px;" (click)="load()">
        Tentar de novo
      </button>
    </div>

    <ng-container *ngIf="data && !loading && !error">
      <!-- KPIs — interpolação + *ngFor -->
      <section class="section grid kpi-grid">
        <div class="card kpi" *ngFor="let k of kpis">
          <div class="label">{{ k.label }}</div>
          <div class="value">{{ k.value }}</div>
        </div>
      </section>

      <section class="section grid two-col">
        <div class="card">
          <h2>Desafios por categoria</h2>
          <div class="state" *ngIf="data.porCategoria.length === 0">Sem dados.</div>
          <div class="bar-row" *ngFor="let c of data.porCategoria">
            <span class="name">{{ c.chave }}</span>
            <span class="bar-track">
              <span
                class="bar-fill"
                [style.width.%]="pct(c, data.porCategoria)"
              ></span>
            </span>
            <span class="count">{{ c.quantidade }}</span>
          </div>
        </div>

        <div class="card">
          <h2>Desafios por nível de risco</h2>
          <div class="state" *ngIf="data.porNivelDeRisco.length === 0">Sem dados.</div>
          <div class="bar-row" *ngFor="let r of data.porNivelDeRisco">
            <span class="name">
              <span class="badge" [style.background]="riskColor(r.chave)">{{ r.chave }}</span>
            </span>
            <span class="bar-track">
              <span
                class="bar-fill"
                [style.width.%]="pct(r, data.porNivelDeRisco)"
                [style.background]="riskColor(r.chave)"
              ></span>
            </span>
            <span class="count">{{ r.quantidade }}</span>
          </div>
        </div>
      </section>
    </ng-container>
  `,
})
export class HomeComponent implements OnInit {
  loading = false;
  error = '';
  data: Indicadores | null = null;
  kpis: Kpi[] = [];

  constructor(private admin: AdminService) {}

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.loading = true;
    this.error = '';
    this.admin.getIndicadores().subscribe({
      next: (res) => {
        this.data = res;
        this.kpis = [
          { label: 'Usuários', value: res.totalUsuarios },
          { label: 'Desafios', value: res.totalDesafios },
          { label: 'Concluídos', value: res.desafiosConcluidos },
          { label: 'Em risco', value: res.desafiosEmRisco },
          { label: 'XP médio / usuário', value: res.xpMedioPorUsuario },
          { label: 'Melhor streak', value: res.melhorStreak },
        ];
        this.loading = false;
      },
      error: (err: unknown) => {
        this.error = apiErrorMessage(err);
        this.loading = false;
      },
    });
  }

  pct(item: Distribuicao, all: Distribuicao[]): number {
    const max = Math.max(...all.map((d) => d.quantidade), 1);
    return Math.round((item.quantidade / max) * 100);
  }

  riskColor(chave: string): string {
    return RISK_COLORS[chave] ?? 'var(--accent)';
  }
}
