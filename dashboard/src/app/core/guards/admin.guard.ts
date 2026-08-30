import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth.service';

/**
 * Painel restrito à coordenação:
 * - não autenticado → /login
 * - autenticado sem papel ADMIN → /sem-acesso (o servidor já responde 403 nas rotas /admin/**)
 */
export const adminGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (!auth.isAuthenticated()) {
    return router.createUrlTree(['/login']);
  }
  if (!auth.isAdmin()) {
    return router.createUrlTree(['/sem-acesso']);
  }
  return true;
};
