import { Component, OnInit } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { DatePipe, NgForOf, NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { EngajamentoOracleService } from '../../core/services/engajamento-oracle.service';
import {
  AlertaEngajamentoOracle,
  FaixaEngajamento,
  RelatorioEngajamentoOracle,
} from '../../core/models';
import { apiErrorMessage } from '../../core/http-error.util';
import { FaixaEngajamentoLabelPipe } from '../../shared/pipes/rotulos.pipe';
import { IconComponent, IconName } from '../../shared/ui/icon.component';

const FAIXA_COR: Record<FaixaEngajamento, string> = {
  ALTO: 'var(--risk-low)',
  MODERADO: 'var(--risk-medium)',
  EM_RISCO: 'var(--risk-high)',
  CRITICO: 'var(--risk-critical)',
  SEM_DESAFIO: 'var(--text-dim)',
};

const FAIXA_ICONE: Record<FaixaEngajamento, IconName> = {
  ALTO: 'check',
  MODERADO: 'bolt',
  EM_RISCO: 'warn',
  CRITICO: 'fire',
  SEM_DESAFIO: 'grid',
};

const ORDEM_FAIXAS: FaixaEngajamento[] = ['ALTO', 'MODERADO', 'EM_RISCO', 'CRITICO', 'SEM_DESAFIO'];

const SEVERIDADE_COR: Record<string, string> = {
  BAIXA: 'var(--risk-medium)',
  MEDIA: 'var(--risk-high)',
  ALTA: 'var(--risk-critical)',
};

function isoHoje(offsetDias = 0): string {
  const d = new Date();
  d.setDate(d.getDate() + offsetDias);
  return d.toISOString().slice(0, 10);
}

@Component({
  selector: 'app-oracle-engajamento',
  standalone: true,
  imports: [NgIf, NgForOf, DatePipe, FormsModule, FaixaEngajamentoLabelPipe, IconComponent],
  template: `
    <h1>Engajamento — camada Oracle</h1>
    <p class="hint">
      Indicadores e alertas calculados em PL/SQL (functions e procedures Oracle), separados dos
      indicadores de <code>/admin/metricas/**</code>.
    </p>

    <form class="filters" (ngSubmit)="gerarRelatorio()">
      <label class="field">
        <span>Início</span>
        <input type="date" name="inicio" [(ngModel)]="inicio" [disabled]="gerando" />
      </label>
      <label class="field">
        <span>Fim</span>
        <input type="date" name="fim" [(ngModel)]="fim" [disabled]="gerando" />
      </label>
      <button type="submit" class="btn-primary" [disabled]="gerando">
        {{ gerando ? 'Gerando…' : 'Gerar relatório' }}
      </button>
    </form>

    <div class="state" *ngIf="gerando"><span class="spinner"></span>&nbsp; Gerando relatório…</div>

    <div class="card state-empty" *ngIf="oracleDesabilitado">
      <h2>Camada Oracle desabilitada neste ambiente</h2>
      <p>
        Este ambiente está rodando com <code>level30.oracle.enabled=false</code>. Os indicadores
        desta página dependem da camada Oracle PL/SQL (ver <code>db/oracle/</code> e
        <code>backend/.env.example</code>).
      </p>
    </div>

    <div class="alert alert-error" *ngIf="erro && !oracleDesabilitado">
      {{ erro }}
      <button type="button" class="btn-ghost" style="margin-left: 12px;" (click)="gerarRelatorio()">
        Tentar de novo
      </button>
    </div>

    <ng-container *ngIf="relatorio && !gerando && !oracleDesabilitado">
      <p class="hint">
        Execução #{{ relatorio.execucaoId }} · período {{ relatorio.periodoInicio }} a
        {{ relatorio.periodoFim }}
      </p>

      <section class="section grid kpi-grid">
        <div class="card kpi" *ngFor="let faixa of ordemFaixas">
          <span class="kpi-icon" [style.color]="corFaixa(faixa)">
            <app-icon [name]="iconeFaixa(faixa)" />
          </span>
          <div>
            <div class="label">{{ faixa | faixaEngajamentoLabel }}</div>
            <div class="value">{{ relatorio.contagemPorFaixa[faixa] ?? 0 }}</div>
          </div>
        </div>
      </section>

      <section class="section card">
        <h2>Por aluno</h2>
        <div class="state" *ngIf="relatorio.linhas.length === 0">
          Nenhum aluno com desafio neste período.
        </div>
        <div class="table-wrap" *ngIf="relatorio.linhas.length > 0">
          <table>
            <thead>
              <tr>
                <th>Aluno</th>
                <th>Desafios ativos</th>
                <th>Conclusões</th>
                <th>Adesão</th>
                <th>Streak</th>
                <th>Faixa</th>
              </tr>
            </thead>
            <tbody>
              <tr *ngFor="let l of relatorio.linhas">
                <td>{{ l.nome }}</td>
                <td>{{ l.desafiosAtivos }}</td>
                <td>{{ l.conclusoes }}</td>
                <td>{{ l.adesaoPercentual === null ? '—' : l.adesaoPercentual.toFixed(1) + '%' }}</td>
                <td>{{ l.streakAtual }}d</td>
                <td>
                  <span class="badge" [style.background]="corFaixa(l.faixa)">
                    {{ l.faixa | faixaEngajamentoLabel }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </ng-container>

    <section class="section card" *ngIf="!oracleDesabilitado">
      <div class="fila-head">
        <h2>Alertas abertos</h2>
        <button type="button" class="btn-ghost" [disabled]="verificando" (click)="verificarInatividade()">
          {{ verificando ? 'Verificando…' : 'Verificar inatividade agora' }}
        </button>
      </div>

      <div class="state" *ngIf="carregandoAlertas">
        <span class="spinner"></span>&nbsp; Carregando alertas…
      </div>
      <div class="state" *ngIf="!carregandoAlertas && alertas.length === 0">
        Nenhum alerta aberto. 🎉
      </div>
      <div class="table-wrap" *ngIf="!carregandoAlertas && alertas.length > 0">
        <table>
          <thead>
            <tr><th>Aluno</th><th>Tipo</th><th>Severidade</th><th>Mensagem</th><th>Data</th></tr>
          </thead>
          <tbody>
            <tr *ngFor="let a of alertas">
              <td>{{ a.nomeUsuario }}</td>
              <td>{{ a.tipo }}</td>
              <td>
                <span class="badge" [style.background]="corSeveridade(a.severidade)">{{ a.severidade }}</span>
              </td>
              <td>{{ a.mensagem }}</td>
              <td>{{ a.criadoEm | date: 'dd/MM/yyyy HH:mm' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  `,
  styles: [`
    .fila-head { display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px; margin-bottom: 12px; }
  `],
})
export class OracleEngajamentoComponent implements OnInit {
  readonly ordemFaixas = ORDEM_FAIXAS;

  inicio = isoHoje(-29);
  fim = isoHoje();

  gerando = false;
  erro = '';
  oracleDesabilitado = false;
  relatorio: RelatorioEngajamentoOracle | null = null;

  carregandoAlertas = false;
  verificando = false;
  alertas: AlertaEngajamentoOracle[] = [];

  constructor(private engajamento: EngajamentoOracleService) {}

  ngOnInit(): void {
    this.gerarRelatorio();
    this.carregarAlertas();
  }

  gerarRelatorio(): void {
    this.gerando = true;
    this.erro = '';
    this.oracleDesabilitado = false;
    this.engajamento.gerarRelatorio(this.inicio, this.fim).subscribe({
      next: (relatorio) => {
        this.relatorio = relatorio;
        this.gerando = false;
      },
      error: (err: unknown) => this.tratarErro(err, () => (this.gerando = false)),
    });
  }

  carregarAlertas(): void {
    this.carregandoAlertas = true;
    this.engajamento.listarAlertas(true).subscribe({
      next: (alertas) => {
        this.alertas = alertas;
        this.carregandoAlertas = false;
      },
      error: (err: unknown) => this.tratarErro(err, () => (this.carregandoAlertas = false)),
    });
  }

  verificarInatividade(): void {
    this.verificando = true;
    this.engajamento.verificarInatividade(3).subscribe({
      next: () => {
        this.verificando = false;
        this.carregarAlertas();
      },
      error: (err: unknown) => this.tratarErro(err, () => (this.verificando = false)),
    });
  }

  corFaixa(faixa: FaixaEngajamento): string {
    return FAIXA_COR[faixa] ?? 'var(--accent)';
  }

  iconeFaixa(faixa: FaixaEngajamento): IconName {
    return FAIXA_ICONE[faixa] ?? 'grid';
  }

  corSeveridade(severidade: string): string {
    return SEVERIDADE_COR[severidade] ?? 'var(--accent)';
  }

  private tratarErro(err: unknown, pararCarregamento: () => void): void {
    if (err instanceof HttpErrorResponse && err.status === 503) {
      this.oracleDesabilitado = true;
    } else {
      this.erro = apiErrorMessage(err);
    }
    pararCarregamento();
  }
}
