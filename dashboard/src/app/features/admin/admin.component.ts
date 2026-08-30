import { Component, OnInit } from '@angular/core';
import { NgClass, NgForOf, NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService, DesafioFiltro } from '../../core/services/admin.service';
import { ChallengeService } from '../../core/services/challenge.service';
import {
  AdminChallenge,
  AdminUser,
  Category,
  CATEGORIES,
  CreateChallengeRequest,
  Page,
  RiskLevel,
  RISK_LEVELS,
} from '../../core/models';
import { apiErrorMessage } from '../../core/http-error.util';
import { CategoriaLabelPipe, RiscoLabelPipe } from '../../shared/pipes/rotulos.pipe';

const RISK_COLORS: Record<RiskLevel, string> = {
  low: 'var(--risk-low)',
  medium: 'var(--risk-medium)',
  high: 'var(--risk-high)',
  critical: 'var(--risk-critical)',
};

@Component({
  selector: 'app-admin',
  standalone: true,
  imports: [NgIf, NgForOf, NgClass, FormsModule, CategoriaLabelPipe, RiscoLabelPipe],
  template: `
    <h1>Administração</h1>

    <!-- ================= Criar desafio ================= -->
    <section class="section card">
      <h2>Criar desafio (conta da coordenação)</h2>
      <p style="color: var(--text-dim); margin-top: -6px;">
        O desafio é criado na conta de administrador que está logada — serve para
        testar o fluxo e demonstrar a API. Estudantes criam os próprios desafios pelo app.
      </p>

      <div class="alert alert-success" *ngIf="createSuccess">
        Desafio "{{ createSuccess }}" criado e adicionado ao topo da lista.
      </div>
      <div class="alert alert-error" *ngIf="createError">{{ createError }}</div>

      <form (ngSubmit)="createChallenge()" #cf="ngForm">
        <div class="grid two-col">
          <label class="field">
            <span>Título (mín. 3)</span>
            <input name="title" [(ngModel)]="form.title" required minlength="3" [disabled]="creating" />
            <span class="hint" *ngIf="form.title.length > 0 && form.title.trim().length < 3">
              O título precisa de pelo menos 3 caracteres.
            </span>
          </label>

          <label class="field">
            <span>Categoria</span>
            <select name="category" [(ngModel)]="form.category" required [disabled]="creating">
              <option *ngFor="let c of categories" [value]="c">{{ c | categoriaLabel }}</option>
            </select>
          </label>
        </div>

        <label class="field">
          <span>Descrição</span>
          <textarea name="description" [(ngModel)]="form.description" required [disabled]="creating"></textarea>
          <span class="hint" *ngIf="form.description.length > 0 && form.description.trim().length === 0">
            A descrição é obrigatória.
          </span>
        </label>

        <div class="grid two-col">
          <label class="field">
            <span>Duração em dias (7–90)</span>
            <input
              name="totalDays"
              type="number"
              [(ngModel)]="form.totalDays"
              required
              min="7"
              max="90"
              [disabled]="creating"
            />
            <span class="hint" *ngIf="form.totalDays < 7 || form.totalDays > 90">
              A duração deve ficar entre 7 e 90 dias.
            </span>
          </label>

          <label class="field">
            <span>XP de recompensa (100–1000)</span>
            <input
              name="xpReward"
              type="number"
              [(ngModel)]="form.xpReward"
              required
              min="100"
              max="1000"
              [disabled]="creating"
            />
            <span class="hint" *ngIf="form.xpReward < 100 || form.xpReward > 1000">
              O XP deve ficar entre 100 e 1000.
            </span>
          </label>
        </div>

        <button type="submit" class="btn-primary" [disabled]="creating || cf.invalid || !formValid()">
          <span *ngIf="creating" class="spinner"></span>
          <span *ngIf="!creating">Criar desafio</span>
          <span *ngIf="creating">&nbsp;Criando...</span>
        </button>
      </form>
    </section>

    <!-- ================= Tabela de desafios ================= -->
    <section class="section card">
      <h2>Desafios em acompanhamento</h2>

      <div class="filters">
        <label class="field">
          <span>Categoria</span>
          <select [(ngModel)]="filtro.category" (ngModelChange)="reloadDesafios()" [disabled]="loadingDesafios">
            <option value="">Todas</option>
            <option *ngFor="let c of categories" [value]="c">{{ c | categoriaLabel }}</option>
          </select>
        </label>

        <label class="field">
          <span>Nível de risco</span>
          <select [(ngModel)]="filtro.riskLevel" (ngModelChange)="reloadDesafios()" [disabled]="loadingDesafios">
            <option value="">Todos</option>
            <option *ngFor="let r of riskLevels" [value]="r">{{ r | riscoLabel }}</option>
          </select>
        </label>

        <label class="field">
          <span>Buscar</span>
          <input [(ngModel)]="busca" name="busca" placeholder="título ou e-mail" [disabled]="loadingDesafios" />
        </label>

        <button type="button" class="btn-ghost" (click)="reloadDesafios()" [disabled]="loadingDesafios">
          Atualizar
        </button>
      </div>

      <div class="alert alert-error" *ngIf="desafiosError">{{ desafiosError }}</div>
      <div class="state" *ngIf="loadingDesafios"><span class="spinner"></span>&nbsp; Carregando desafios...</div>

      <div class="table-wrap" *ngIf="!loadingDesafios && !desafiosError">
        <div class="state" *ngIf="desafios && desafios.content.length === 0">
          Nenhum desafio para os filtros selecionados.
        </div>
        <div class="state" *ngIf="desafios && desafios.content.length > 0 && desafiosView.length === 0">
          Nenhum desafio corresponde à busca.
        </div>
        <table *ngIf="desafiosView.length > 0">
          <thead>
            <tr>
              <th class="sortable" (click)="ordenarPor('titulo')">Título {{ setaSort('titulo') }}</th>
              <th>Categoria</th>
              <th class="sortable" (click)="ordenarPor('usuarioNome')">Usuário {{ setaSort('usuarioNome') }}</th>
              <th class="sortable" (click)="ordenarPor('currentDay')">Progresso {{ setaSort('currentDay') }}</th>
              <th class="sortable" (click)="ordenarPor('streak')">Streak {{ setaSort('streak') }}</th>
              <th class="sortable" (click)="ordenarPor('riskScore')">Risco {{ setaSort('riskScore') }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr *ngFor="let d of desafiosView">
              <td>{{ d.titulo }}</td>
              <td>{{ d.categoria | categoriaLabel }}</td>
              <td>
                {{ d.usuarioNome }}
                <div style="color: var(--text-dim); font-size: 12px;">{{ d.usuarioEmail }}</div>
              </td>
              <td>{{ d.currentDay }} / {{ d.totalDays }}</td>
              <td>{{ d.streak }}</td>
              <td>
                <span
                  class="badge"
                  [ngClass]="'risk-' + d.riskLevel"
                  [style.background]="riskColor(d.riskLevel)"
                >
                  {{ d.riskLevel | riscoLabel }} · {{ (d.riskScore * 100).toFixed(0) }}%
                </span>
              </td>
              <td>
                <button
                  type="button"
                  class="btn-danger"
                  (click)="deleteChallenge(d)"
                  [disabled]="deletingId === d.id"
                >
                  {{ deletingId === d.id ? 'Excluindo...' : 'Excluir' }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <p style="color: var(--text-dim);" *ngIf="desafios">
          {{ desafiosView.length }} de {{ desafios.totalElements }} desafio(s) · página {{ desafios.number + 1 }} de
          {{ desafios.totalPages || 1 }}
        </p>
      </div>
    </section>

    <!-- ================= Tabela de usuários ================= -->
    <section class="section card">
      <h2>Usuários</h2>

      <div class="alert alert-error" *ngIf="usuariosError">{{ usuariosError }}</div>
      <div class="state" *ngIf="loadingUsuarios"><span class="spinner"></span>&nbsp; Carregando usuários...</div>

      <div class="table-wrap" *ngIf="!loadingUsuarios && !usuariosError">
        <div class="state" *ngIf="usuarios && usuarios.content.length === 0">Nenhum usuário.</div>
        <table *ngIf="usuarios && usuarios.content.length > 0">
          <thead>
            <tr>
              <th>Nome</th>
              <th>E-mail</th>
              <th>XP total</th>
              <th>Nível</th>
              <th>Rank</th>
              <th>Desafios</th>
            </tr>
          </thead>
          <tbody>
            <tr *ngFor="let u of usuarios.content">
              <td>{{ u.nome }}</td>
              <td>{{ u.email }}</td>
              <td>{{ u.totalXp }}</td>
              <td>{{ u.nivel }}</td>
              <td>{{ u.rank }}</td>
              <td>{{ u.quantidadeDesafios }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- ================= Modal de confirmação ================= -->
    <div class="modal-backdrop" *ngIf="aExcluir" (click)="aExcluir = null">
      <div class="modal card" (click)="$event.stopPropagation()">
        <h2>Excluir desafio</h2>
        <p>
          Excluir <strong>"{{ aExcluir.titulo }}"</strong> de {{ aExcluir.usuarioNome }}?
          Esta ação não pode ser desfeita.
        </p>
        <div class="modal-actions">
          <button type="button" class="btn-ghost" (click)="aExcluir = null">Cancelar</button>
          <button type="button" class="btn-danger" (click)="confirmarExclusao()">Excluir</button>
        </div>
      </div>
    </div>
  `,
})
export class AdminComponent implements OnInit {
  readonly categories: Category[] = CATEGORIES;
  readonly riskLevels: RiskLevel[] = RISK_LEVELS;

  // --- create form state ---
  form: CreateChallengeRequest = this.emptyForm();
  creating = false;
  createError = '';
  createSuccess = '';

  // --- desafios table state ---
  filtro: DesafioFiltro = { category: '', riskLevel: '' };
  busca = '';
  sortKey: keyof AdminChallenge | '' = '';
  sortDir: 1 | -1 = 1;
  aExcluir: AdminChallenge | null = null;
  desafios: Page<AdminChallenge> | null = null;
  loadingDesafios = false;
  desafiosError = '';
  deletingId: string | null = null;

  // --- usuarios table state ---
  usuarios: Page<AdminUser> | null = null;
  loadingUsuarios = false;
  usuariosError = '';

  constructor(
    private admin: AdminService,
    private challenges: ChallengeService,
  ) {}

  ngOnInit(): void {
    this.reloadDesafios();
    this.reloadUsuarios();
  }

  private emptyForm(): CreateChallengeRequest {
    return {
      title: '',
      category: 'study',
      description: '',
      totalDays: 30,
      xpReward: 300,
    };
  }

  formValid(): boolean {
    const f = this.form;
    return (
      f.title.trim().length >= 3 &&
      f.description.trim().length > 0 &&
      f.totalDays >= 7 &&
      f.totalDays <= 90 &&
      f.xpReward >= 100 &&
      f.xpReward <= 1000
    );
  }

  createChallenge(): void {
    if (this.creating || !this.formValid()) {
      return;
    }
    this.creating = true;
    this.createError = '';
    this.createSuccess = '';

    const payload: CreateChallengeRequest = {
      title: this.form.title.trim(),
      category: this.form.category,
      description: this.form.description.trim(),
      totalDays: Number(this.form.totalDays),
      xpReward: Number(this.form.xpReward),
    };

    this.challenges.create(payload).subscribe({
      next: (created) => {
        this.creating = false;
        this.createSuccess = created.title;
        this.form = this.emptyForm();
        this.reloadDesafios();
      },
      error: (err: unknown) => {
        this.creating = false;
        this.createError = apiErrorMessage(err, 'Nao foi possivel criar o desafio.');
      },
    });
  }

  reloadDesafios(): void {
    this.loadingDesafios = true;
    this.desafiosError = '';
    this.admin.getDesafios({ ...this.filtro, page: 0, size: 50 }).subscribe({
      next: (page) => {
        this.desafios = page;
        this.loadingDesafios = false;
      },
      error: (err: unknown) => {
        this.desafiosError = apiErrorMessage(err);
        this.loadingDesafios = false;
      },
    });
  }

  reloadUsuarios(): void {
    this.loadingUsuarios = true;
    this.usuariosError = '';
    this.admin.getUsuarios(0, 50).subscribe({
      next: (page) => {
        this.usuarios = page;
        this.loadingUsuarios = false;
      },
      error: (err: unknown) => {
        this.usuariosError = apiErrorMessage(err);
        this.loadingUsuarios = false;
      },
    });
  }

  deleteChallenge(d: AdminChallenge): void {
    this.aExcluir = d;
  }

  riskColor(level: RiskLevel): string {
    return RISK_COLORS[level];
  }

  get desafiosView(): AdminChallenge[] {
    let rows = this.desafios?.content ?? [];
    const q = this.busca.trim().toLowerCase();
    if (q) {
      rows = rows.filter(
        (d) =>
          d.titulo.toLowerCase().includes(q) ||
          d.usuarioEmail.toLowerCase().includes(q) ||
          d.usuarioNome.toLowerCase().includes(q),
      );
    }
    if (this.sortKey) {
      const k = this.sortKey;
      rows = [...rows].sort((a, b) => {
        const va = a[k] as string | number;
        const vb = b[k] as string | number;
        return (va < vb ? -1 : va > vb ? 1 : 0) * this.sortDir;
      });
    }
    return rows;
  }

  ordenarPor(k: keyof AdminChallenge): void {
    if (this.sortKey === k) {
      this.sortDir = this.sortDir === 1 ? -1 : 1;
    } else {
      this.sortKey = k;
      this.sortDir = 1;
    }
  }

  setaSort(k: keyof AdminChallenge): string {
    return this.sortKey === k ? (this.sortDir === 1 ? '\u2191' : '\u2193') : '';
  }

  confirmarExclusao(): void {
    const d = this.aExcluir;
    this.aExcluir = null;
    if (!d) return;
    this.deletingId = d.id;
    this.challenges.remove(d.id).subscribe({
      next: () => {
        this.deletingId = null;
        this.reloadDesafios();
      },
      error: (err: unknown) => {
        this.deletingId = null;
        this.desafiosError = apiErrorMessage(err, 'Nao foi possivel excluir o desafio.');
      },
    });
  }
}
