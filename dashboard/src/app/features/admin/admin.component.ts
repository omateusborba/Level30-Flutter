import { AfterViewChecked, Component, ElementRef, OnInit, ViewChild } from '@angular/core';
import { NgClass, NgForOf, NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subject, debounceTime, distinctUntilChanged } from 'rxjs';
import { AdminService, DesafioFiltro } from '../../core/services/admin.service';
import { ChallengeService } from '../../core/services/challenge.service';
import {
  AdminChallenge,
  AdminUser,
  Category,
  CATEGORIES,
  CreateChallengeRequest,
  Page,
  ProgramChallenge,
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

const PAGE_SIZE = 20;

@Component({
  selector: 'app-admin',
  standalone: true,
  imports: [NgIf, NgForOf, NgClass, FormsModule, CategoriaLabelPipe, RiscoLabelPipe],
  template: `
    <h1>Administração</h1>

    <!-- ================= Desafios do programa (C3) ================= -->
    <section class="section card">
      <h2>Desafios do programa</h2>
      <p style="color: var(--text-dim); margin-top: -6px;">
        Modelos publicados pela coordenação. Os estudantes os veem no app e
        <strong>adotam</strong> — cada adoção vira um desafio pessoal do aluno.
      </p>

      <div class="alert alert-success" *ngIf="createSuccess">
        Modelo "{{ createSuccess }}" publicado.
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
            <input name="totalDays" type="number" [(ngModel)]="form.totalDays" required min="7" max="90" [disabled]="creating" />
            <span class="hint" *ngIf="form.totalDays < 7 || form.totalDays > 90">
              A duração deve ficar entre 7 e 90 dias.
            </span>
          </label>

          <label class="field">
            <span>XP de recompensa (100–1000)</span>
            <input name="xpReward" type="number" [(ngModel)]="form.xpReward" required min="100" max="1000" [disabled]="creating" />
            <span class="hint" *ngIf="form.xpReward < 100 || form.xpReward > 1000">
              O XP deve ficar entre 100 e 1000.
            </span>
          </label>
        </div>

        <button type="submit" class="btn-primary" [disabled]="creating || cf.invalid || !formValid()">
          <span *ngIf="creating" class="spinner"></span>
          <span *ngIf="!creating">Publicar modelo</span>
          <span *ngIf="creating">&nbsp;Publicando...</span>
        </button>
      </form>

      <div class="alert alert-error" *ngIf="programaError">{{ programaError }}</div>
      <div class="table-wrap" *ngIf="programa.length > 0" style="margin-top: 18px;">
        <table>
          <thead>
            <tr>
              <th scope="col">Título</th><th scope="col">Categoria</th>
              <th scope="col">Duração</th><th scope="col">XP</th>
              <th scope="col">Adotado por</th><th scope="col">Status</th><th scope="col"></th>
            </tr>
          </thead>
          <tbody>
            <tr *ngFor="let p of programa">
              <td>{{ p.title }}</td>
              <td>{{ p.category | categoriaLabel }}</td>
              <td>{{ p.totalDays }}d</td>
              <td>{{ p.xpReward }}</td>
              <td>{{ p.adotantes }} aluno(s)</td>
              <td>
                <button type="button" class="btn-ghost" (click)="alternarPrograma(p)">
                  {{ p.active ? 'Ativo' : 'Arquivado' }}
                </button>
              </td>
              <td>
                <button type="button" class="btn-danger" (click)="removerPrograma(p)">Excluir</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- ================= Tabela de desafios ================= -->
    <section class="section card">
      <h2>Desafios em acompanhamento</h2>

      <div class="filters">
        <label class="field">
          <span>Categoria</span>
          <select [(ngModel)]="filtro.category" (ngModelChange)="aoFiltrar()" [disabled]="loadingDesafios">
            <option value="">Todas</option>
            <option *ngFor="let c of categories" [value]="c">{{ c | categoriaLabel }}</option>
          </select>
        </label>

        <label class="field">
          <span>Nível de risco</span>
          <select [(ngModel)]="filtro.riskLevel" (ngModelChange)="aoFiltrar()" [disabled]="loadingDesafios">
            <option value="">Todos</option>
            <option *ngFor="let r of riskLevels" [value]="r">{{ r | riscoLabel }}</option>
          </select>
        </label>

        <label class="field">
          <span>Buscar</span>
          <input
            [(ngModel)]="busca"
            name="busca"
            placeholder="título, nome ou e-mail"
            [disabled]="loadingDesafios"
            (ngModelChange)="busca$.next($event)"
          />
        </label>

        <button type="button" class="btn-ghost" (click)="reloadDesafios()" [disabled]="loadingDesafios">
          Atualizar
        </button>
      </div>

      <div class="alert alert-error" *ngIf="desafiosError">{{ desafiosError }}</div>
      <div class="state" *ngIf="loadingDesafios"><span class="spinner"></span>&nbsp; Carregando desafios...</div>

      <div class="table-wrap" *ngIf="!loadingDesafios && !desafiosError">
        <div class="state" *ngIf="desafios && desafios.content.length === 0">
          Nenhum desafio para os filtros / busca.
        </div>
        <table *ngIf="desafiosView.length > 0">
          <thead>
            <tr>
              <th scope="col" class="sortable" tabindex="0" role="button"
                  [attr.aria-sort]="ariaSort('titulo')"
                  (click)="ordenarPor('titulo')" (keydown.enter)="ordenarPor('titulo')" (keydown.space)="ordenarPor('titulo')">
                Título {{ setaSort('titulo') }}
              </th>
              <th scope="col">Categoria</th>
              <th scope="col" class="sortable" tabindex="0" role="button"
                  [attr.aria-sort]="ariaSort('usuarioNome')"
                  (click)="ordenarPor('usuarioNome')" (keydown.enter)="ordenarPor('usuarioNome')" (keydown.space)="ordenarPor('usuarioNome')">
                Usuário {{ setaSort('usuarioNome') }}
              </th>
              <th scope="col" class="sortable" tabindex="0" role="button"
                  [attr.aria-sort]="ariaSort('currentDay')"
                  (click)="ordenarPor('currentDay')" (keydown.enter)="ordenarPor('currentDay')" (keydown.space)="ordenarPor('currentDay')">
                Progresso {{ setaSort('currentDay') }}
              </th>
              <th scope="col" class="sortable" tabindex="0" role="button"
                  [attr.aria-sort]="ariaSort('streak')"
                  (click)="ordenarPor('streak')" (keydown.enter)="ordenarPor('streak')" (keydown.space)="ordenarPor('streak')">
                Streak {{ setaSort('streak') }}
              </th>
              <th scope="col" class="sortable" tabindex="0" role="button"
                  [attr.aria-sort]="ariaSort('riskScore')"
                  (click)="ordenarPor('riskScore')" (keydown.enter)="ordenarPor('riskScore')" (keydown.space)="ordenarPor('riskScore')">
                Risco {{ setaSort('riskScore') }}
              </th>
              <th scope="col" class="sortable" tabindex="0" role="button"
                  [attr.aria-sort]="ariaSort('replanCount')"
                  (click)="ordenarPor('replanCount')" (keydown.enter)="ordenarPor('replanCount')" (keydown.space)="ordenarPor('replanCount')">
                Replan. {{ setaSort('replanCount') }}
              </th>
              <th scope="col"><span class="sr-only">Ações</span></th>
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
                <span class="badge" [ngClass]="'risk-' + d.riskLevel" [style.background]="riskColor(d.riskLevel)">
                  {{ d.riskLevel | riscoLabel }} · {{ (d.riskScore * 100).toFixed(0) }}%
                </span>
              </td>
              <td style="text-align: center;">
                <span [class.replan-max]="d.replanCount >= 2">{{ d.replanCount }}/2</span>
              </td>
              <td>
                <button type="button" class="btn-danger" (click)="deleteChallenge(d)" [disabled]="deletingId === d.id">
                  {{ deletingId === d.id ? 'Excluindo...' : 'Excluir' }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <div class="pager" *ngIf="desafios">
          <span class="hint">
            {{ desafios.totalElements }} desafio(s) · página {{ desafios.number + 1 }} de {{ desafios.totalPages || 1 }}
            <em *ngIf="sortKey">· ordenação nesta página</em>
          </span>
          <span class="pager-btns">
            <button type="button" class="btn-ghost" (click)="paginaDesafios(-1)"
                    [disabled]="loadingDesafios || desafios.number === 0">‹ Anterior</button>
            <button type="button" class="btn-ghost" (click)="paginaDesafios(1)"
                    [disabled]="loadingDesafios || desafios.number + 1 >= (desafios.totalPages || 1)">Próxima ›</button>
          </span>
        </div>
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
              <th scope="col">Nome</th>
              <th scope="col">E-mail</th>
              <th scope="col">XP total</th>
              <th scope="col">Nível</th>
              <th scope="col">Rank</th>
              <th scope="col">Desafios</th>
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

        <div class="pager" *ngIf="usuarios">
          <span class="hint">
            {{ usuarios.totalElements }} usuário(s) · página {{ usuarios.number + 1 }} de {{ usuarios.totalPages || 1 }}
          </span>
          <span class="pager-btns">
            <button type="button" class="btn-ghost" (click)="paginaUsuarios(-1)"
                    [disabled]="loadingUsuarios || usuarios.number === 0">‹ Anterior</button>
            <button type="button" class="btn-ghost" (click)="paginaUsuarios(1)"
                    [disabled]="loadingUsuarios || usuarios.number + 1 >= (usuarios.totalPages || 1)">Próxima ›</button>
          </span>
        </div>
      </div>
    </section>

    <!-- ================= Modal de confirmação ================= -->
    <div
      class="modal-backdrop"
      *ngIf="aExcluir"
      (click)="fecharModal()"
      (keydown.escape)="fecharModal()"
    >
      <div
        #modal
        class="modal card"
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-titulo"
        tabindex="-1"
        (click)="$event.stopPropagation()"
        (keydown.tab)="prenderFoco($event)"
      >
        <h2 id="modal-titulo">Excluir desafio</h2>
        <p>
          Excluir <strong>"{{ aExcluir.titulo }}"</strong> de {{ aExcluir.usuarioNome }}?
          Esta ação não pode ser desfeita.
        </p>
        <div class="modal-actions">
          <button type="button" class="btn-ghost" (click)="fecharModal()">Cancelar</button>
          <button type="button" class="btn-danger" (click)="confirmarExclusao()">Excluir</button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .pager { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; margin-top: 12px; }
    .pager-btns { display: flex; gap: 8px; }
    .pager em { color: var(--text-dim); font-style: normal; }
    .sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
    th.sortable:focus-visible { outline: 2px solid var(--accent); outline-offset: -2px; }
    .replan-max { color: var(--risk-high); font-weight: 700; }
  `],
})
export class AdminComponent implements OnInit, AfterViewChecked {
  readonly categories: Category[] = CATEGORIES;
  readonly riskLevels: RiskLevel[] = RISK_LEVELS;

  @ViewChild('modal') modalRef?: ElementRef<HTMLElement>;
  private modalJaFocado = false;
  private elementoAnterior: HTMLElement | null = null;

  form: CreateChallengeRequest = this.emptyForm();
  creating = false;
  createError = '';
  createSuccess = '';

  programa: ProgramChallenge[] = [];
  programaError = '';

  filtro: DesafioFiltro = { category: '', riskLevel: '' };
  busca = '';
  readonly busca$ = new Subject<string>();
  sortKey: keyof AdminChallenge | '' = '';
  sortDir: 1 | -1 = 1;
  aExcluir: AdminChallenge | null = null;
  desafios: Page<AdminChallenge> | null = null;
  loadingDesafios = false;
  desafiosError = '';
  deletingId: string | null = null;
  private pagDesafios = 0;

  usuarios: Page<AdminUser> | null = null;
  loadingUsuarios = false;
  usuariosError = '';
  private pagUsuarios = 0;

  constructor(
    private admin: AdminService,
    private challenges: ChallengeService,
  ) {}

  ngOnInit(): void {
    this.busca$.pipe(debounceTime(350), distinctUntilChanged()).subscribe(() => this.aoFiltrar());
    this.reloadPrograma();
    this.reloadDesafios();
    this.reloadUsuarios();
  }

  reloadPrograma(): void {
    this.programaError = '';
    this.admin.getPrograma().subscribe({
      next: (p) => (this.programa = p),
      error: (err: unknown) => (this.programaError = apiErrorMessage(err)),
    });
  }

  alternarPrograma(p: ProgramChallenge): void {
    this.admin.alternarPrograma(p.id, !p.active).subscribe({
      next: () => this.reloadPrograma(),
      error: (err: unknown) => (this.programaError = apiErrorMessage(err)),
    });
  }

  removerPrograma(p: ProgramChallenge): void {
    this.admin.removerPrograma(p.id).subscribe({
      next: () => this.reloadPrograma(),
      error: (err: unknown) => (this.programaError = apiErrorMessage(err)),
    });
  }

  ngAfterViewChecked(): void {
    if (this.aExcluir && this.modalRef && !this.modalJaFocado) {
      this.elementoAnterior = document.activeElement as HTMLElement;
      this.modalRef.nativeElement.focus();
      this.modalJaFocado = true;
    }
  }

  private emptyForm(): CreateChallengeRequest {
    return { title: '', category: 'study', description: '', totalDays: 30, xpReward: 300 };
  }

  formValid(): boolean {
    const f = this.form;
    return (
      f.title.trim().length >= 3 &&
      f.description.trim().length > 0 &&
      f.totalDays >= 7 && f.totalDays <= 90 &&
      f.xpReward >= 100 && f.xpReward <= 1000
    );
  }

  createChallenge(): void {
    if (this.creating || !this.formValid()) return;
    this.creating = true;
    this.createError = '';
    this.createSuccess = '';

    this.admin
      .criarPrograma({
        title: this.form.title.trim(),
        category: this.form.category,
        description: this.form.description.trim(),
        totalDays: Number(this.form.totalDays),
        xpReward: Number(this.form.xpReward),
      })
      .subscribe({
        next: (created) => {
          this.creating = false;
          this.createSuccess = created.title;
          this.form = this.emptyForm();
          this.reloadPrograma();
        },
        error: (err: unknown) => {
          this.creating = false;
          this.createError = apiErrorMessage(err, 'Não foi possível publicar o modelo.');
        },
      });
  }

  /** Filtro ou busca mudou → volta para a primeira página. */
  aoFiltrar(): void {
    this.pagDesafios = 0;
    this.reloadDesafios();
  }

  paginaDesafios(delta: number): void {
    this.pagDesafios = Math.max(0, this.pagDesafios + delta);
    this.reloadDesafios();
  }

  paginaUsuarios(delta: number): void {
    this.pagUsuarios = Math.max(0, this.pagUsuarios + delta);
    this.reloadUsuarios();
  }

  reloadDesafios(): void {
    this.loadingDesafios = true;
    this.desafiosError = '';
    this.admin
      .getDesafios({ ...this.filtro, busca: this.busca, page: this.pagDesafios, size: PAGE_SIZE })
      .subscribe({
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
    this.admin.getUsuarios(this.pagUsuarios, PAGE_SIZE).subscribe({
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
    this.modalJaFocado = false;
  }

  fecharModal(): void {
    this.aExcluir = null;
    this.modalJaFocado = false;
    this.elementoAnterior?.focus();
  }

  /** Foco preso: Tab/Shift+Tab só circula pelos botões do modal. */
  prenderFoco(ev: Event): void {
    const e = ev as KeyboardEvent;
    const focaveis = this.modalRef?.nativeElement.querySelectorAll<HTMLElement>('button');
    if (!focaveis || focaveis.length === 0) return;
    const primeiro = focaveis[0];
    const ultimo = focaveis[focaveis.length - 1];
    const ativo = document.activeElement;
    if (e.shiftKey && (ativo === primeiro || ativo === this.modalRef!.nativeElement)) {
      e.preventDefault();
      ultimo.focus();
    } else if (!e.shiftKey && ativo === ultimo) {
      e.preventDefault();
      primeiro.focus();
    }
  }

  riskColor(level: RiskLevel): string {
    return RISK_COLORS[level];
  }

  /** Ordenação client-side, só sobre a página carregada. */
  get desafiosView(): AdminChallenge[] {
    const rows = this.desafios?.content ?? [];
    if (!this.sortKey) return rows;
    const k = this.sortKey;
    return [...rows].sort((a, b) => {
      const va = a[k] as string | number;
      const vb = b[k] as string | number;
      return (va < vb ? -1 : va > vb ? 1 : 0) * this.sortDir;
    });
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
    return this.sortKey === k ? (this.sortDir === 1 ? '↑' : '↓') : '';
  }

  ariaSort(k: keyof AdminChallenge): 'ascending' | 'descending' | 'none' {
    if (this.sortKey !== k) return 'none';
    return this.sortDir === 1 ? 'ascending' : 'descending';
  }

  confirmarExclusao(): void {
    const d = this.aExcluir;
    this.fecharModal();
    if (!d) return;
    this.deletingId = d.id;
    this.challenges.remove(d.id).subscribe({
      next: () => {
        this.deletingId = null;
        this.reloadDesafios();
      },
      error: (err: unknown) => {
        this.deletingId = null;
        this.desafiosError = apiErrorMessage(err, 'Não foi possível excluir o desafio.');
      },
    });
  }
}
