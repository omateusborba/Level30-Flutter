import { Component } from '@angular/core';
import { AuthService } from '../../core/services/auth.service';

/** Tela mostrada a quem está autenticado mas não é ADMIN (A5). */
@Component({
  selector: 'app-sem-acesso',
  standalone: true,
  template: `
    <div class="card login-card">
      <div class="login-ring">30</div>
      <h1 style="text-align: center; margin-bottom: 2px;">Acesso restrito</h1>
      <p style="color: var(--text-dim); text-align: center;">
        Este painel é exclusivo da coordenação do programa. Sua conta
        (<strong>{{ auth.user()?.email }}</strong>) não tem essa permissão.
      </p>
      <button type="button" class="btn-ghost" style="width: 100%;" (click)="sair()">
        Sair
      </button>
    </div>
  `,
})
export class SemAcessoComponent {
  constructor(public auth: AuthService) {}

  sair(): void {
    this.auth.forceLogoutToLogin();
  }
}
