import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { NgIf } from '@angular/common';
import { Router } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';
import { apiErrorMessage } from '../../core/http-error.util';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule, NgIf],
  template: `
    <div class="card" style="width: 360px; max-width: 92vw;">
      <div class="brand" style="margin-bottom: 6px;">
        <span class="logo">L30</span><span>Level30</span>
      </div>
      <h1>Painel do Coordenador</h1>
      <p style="color: var(--text-dim); margin-top: -4px;">
        Entre com uma conta de administrador.
      </p>

      <!-- (ngSubmit) = event binding no form / two-way binding nos campos -->
      <form (ngSubmit)="submit()" #f="ngForm">
        <label class="field">
          <span>E-mail</span>
          <input
            name="email"
            type="email"
            autocomplete="username"
            [(ngModel)]="email"
            required
            [disabled]="loading"
          />
        </label>

        <label class="field">
          <span>Senha</span>
          <input
            name="password"
            type="password"
            autocomplete="current-password"
            [(ngModel)]="password"
            required
            [disabled]="loading"
          />
        </label>

        <!-- feedback visual de erro -->
        <div class="alert alert-error" *ngIf="error">{{ error }}</div>

        <button
          type="submit"
          class="btn-primary"
          style="width: 100%; margin-top: 4px;"
          [disabled]="loading || f.invalid"
        >
          <span *ngIf="loading" class="spinner"></span>
          <span *ngIf="!loading">Entrar</span>
          <span *ngIf="loading">&nbsp;Entrando...</span>
        </button>
      </form>

      <p class="hint" style="color: var(--text-dim);">
        Seed dev: admin&#64;level30.app / admin1234
      </p>
    </div>
  `,
})
export class LoginComponent {
  email = '';
  password = '';
  loading = false;
  error = '';

  constructor(private auth: AuthService, private router: Router) {}

  submit(): void {
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.error = '';

    this.auth.login({ email: this.email.trim(), password: this.password }).subscribe({
      next: () => {
        this.loading = false;
        void this.router.navigate(['/home']);
      },
      error: (err: unknown) => {
        this.loading = false;
        this.error = apiErrorMessage(err, 'Nao foi possivel entrar. Verifique as credenciais.');
      },
    });
  }
}
