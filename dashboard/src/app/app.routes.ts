import { Routes } from '@angular/router';
import { adminGuard } from './core/guards/admin.guard';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'home' },
  {
    path: 'login',
    loadComponent: () =>
      import('./features/login/login.component').then((m) => m.LoginComponent),
  },
  {
    path: 'sem-acesso',
    loadComponent: () =>
      import('./features/sem-acesso/sem-acesso.component').then((m) => m.SemAcessoComponent),
  },
  {
    path: 'home',
    canActivate: [adminGuard],
    loadComponent: () =>
      import('./features/home/home.component').then((m) => m.HomeComponent),
  },
  {
    path: 'dashboards/engajamento',
    canActivate: [adminGuard],
    loadComponent: () =>
      import('./features/dashboards/engajamento.component').then((m) => m.EngajamentoComponent),
  },
  {
    path: 'dashboards/risco',
    canActivate: [adminGuard],
    loadComponent: () =>
      import('./features/dashboards/risco.component').then((m) => m.RiscoComponent),
  },
  {
    path: 'dashboards/gamificacao',
    canActivate: [adminGuard],
    loadComponent: () =>
      import('./features/dashboards/gamificacao.component').then((m) => m.GamificacaoComponent),
  },
  {
    path: 'admin',
    canActivate: [adminGuard],
    loadComponent: () =>
      import('./features/admin/admin.component').then((m) => m.AdminComponent),
  },
  { path: '**', redirectTo: 'home' },
];
