import { Component, OnInit } from '@angular/core';
import { NgForOf, NgIf } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AdminService } from '../../core/services/admin.service';
import { AdminChallenge, Distribuicao, Indicadores } from '../../core/models';
import { apiErrorMessage } from '../../core/http-error.util';
import { CategoriaLabelPipe, RiscoLabelPipe } from '../../shared/pipes/rotulos.pipe';
import { IconComponent, IconName } from '../../shared/ui/icon.component';

interface Kpi {
  label: string;
  value: number;
  icon: IconName;
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
  imports: [NgIf, NgForOf, RouterLink, CategoriaLabelPipe, RiscoLabelPipe, IconComponent],
  template: `
    <h1>Indicadores do programa</h1>

    <div class="state" *ngIf="loading">
      <span class="spinner"></span>&nbsp; Carregando indicadores...
    </div>

    <div class="alert alert-error" *ngIf="error && !loading">
      {{ error }}
      <button type="button" class="btn-ghost" style="margin-left: 12px;" (click)="load()">
        Tentar de novo
      </button>
    </div>

    <ng-container *ngIf="data && !loading && !error">
      <!-- estado vazio: só o admin, sem desafios -->
      <div class="card state-empty" *ngIf="vazio">
        <h2>Nenhum dado ainda</h2>
        <p>
          Os indicadores aparecem conforme os estudantes se cadastram no app e
          criam desafios. Assim que houver movimento, esta tela se preenche
          automaticamente.
        </p>
      </div>

      <ng-container *ngIf="!vazio">
        <!-- KPIs -->
        <section class="section grid kpi-grid">
          <div class="card kpi" *ngFor="let k of kpis">
            <span class="kpi-icon"><app-icon [name]="k.icon" /></span>
            <div>
              <div class="label">{{ k.label }}</div>
              <div class="value">{{ k.value }}</div>
            </div>
          </div>
        </section>

        <!-- Desafios que precisam de atenção -->
        <section class="section card" *ngIf="atencao.length > 0">
          <h2>Desafios que precisam de atenção</h2>
          <div class="attn-row" *ngFor="let d of atencao" [routerLink]="['/admin']">
            <span class="badge" [style.background]="riskColor(d.riskLevel)">
              {{ d.riskLevel | riscoLabel }}
            </span>
            <div class="attn-main">
              <strong>{{ d.titulo }}</strong>
              <span class="attn-sub">
                {{ d.usuarioNome }} · {{ d.categoria | categoriaLabel }} ·
                dia {{ d.currentDay }}/{{ d.totalDays }}
              </span>
            </div>
            <span class="attn-score">{{ (d.riskScore * 100).toFixed(0) }}%</span>
          </div>
        </section>

        <!-- Distribuições -->
        <section class="section grid two-col">
          <div class="card">
            <h2>Desafios por categoria</h2>
            <div class="state" *ngIf="data.porCategoria.length === 0">Sem dados.</div>
            <div class="bar-row" *ngFor="let c of data.porCategoria">
              <span class="name">{{ c.chave | categoriaLabel }}</span>
              <span class="bar-track">
                <span class="bar-fill" [style.width.%]="pct(c, data.porCategoria)"></span>
              </span>
              <span class="count">{{ c.quantidade }}</span>
            </div>
          </div>

          <div class="card">
            <h2>Desafios por nível de risco</h2>
            <div class="state" *ngIf="data.porNivelDeRisco.length === 0">Sem dados.</div>
            <div class="bar-row" *ngFor="let r of data.porNivelDeRisco">
              <span class="name">
                <span class="badge" [style.background]="riskColor(r.chave)">{{ r.chave | riscoLabel }}</span>
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
    </ng-container>
  `,
})
export class HomeComponent implements OnInit {
  loading = false;
  error = '';
  data: Indicadores | null = null;
  kpis: Kpi[] = [];
  atencao: AdminChallenge[] = [];

  constructor(private admin: AdminService) {}

  get vazio(): boolean {
    return !!this.data && this.data.totalDesafios === 0 && this.data.totalUsuarios <= 1;
  }

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
          { label: 'Usuários', value: res.totalUsuarios, icon: 'users' },
          { label: 'Desafios', value: res.totalDesafios, icon: 'grid' },
          { label: 'Concluídos', value: res.desafiosConcluidos, icon: 'check' },
          { label: 'Em risco', value: res.desafiosEmRisco, icon: 'warn' },
          { label: 'XP médio / usuário', value: res.xpMedioPorUsuario, icon: 'bolt' },
          { label: 'Melhor streak', value: res.melhorStreak, icon: 'fire' },
        ];
        this.loading = false;
      },
      error: (err: unknown) => {
        this.error = apiErrorMessage(err);
        this.loading = false;
      },
    });

    this.admin.getDesafios({ page: 0, size: 6 }).subscribe({
      next: (page) => {
        this.atencao = page.content.filter(
          (d) => d.riskLevel === 'high' || d.riskLevel === 'critical',
        );
      },
      error: () => {
        this.atencao = [];
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
