import { Component } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { NgIf } from '@angular/common';
import { AuthService } from './core/services/auth.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive, NgIf],
  template: `
    <ng-container *ngIf="auth.isAdmin(); else bare">
      <header class="topbar">
        <div class="brand">
          <span class="logo">L30</span>
          <span>Level30 · Painel do Coordenador</span>
        </div>
        <nav class="nav">
          <a routerLink="/home" routerLinkActive="active">Visão geral</a>
          <a routerLink="/dashboards/engajamento" routerLinkActive="active">Engajamento</a>
          <a routerLink="/dashboards/risco" routerLinkActive="active">Risco</a>
          <a routerLink="/dashboards/gamificacao" routerLinkActive="active">Gamificação</a>
          <a routerLink="/admin" routerLinkActive="active">Administração</a>
        </nav>
        <div class="account">
          <span class="who">{{ auth.user()?.name }}</span>
          <button type="button" class="btn-ghost" (click)="logout()">Sair</button>
        </div>
      </header>
      <main class="content"><router-outlet /></main>
    </ng-container>

    <ng-template #bare>
      <main class="content content--bare"><router-outlet /></main>
    </ng-template>
  `,
})
export class AppComponent {
  constructor(public auth: AuthService) {}

  logout(): void {
    this.auth.forceLogoutToLogin();
  }
}
