import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, switchMap, throwError } from 'rxjs';
import { AuthService } from '../services/auth.service';

/**
 * Adiciona `Authorization: Bearer <token>` e, ao receber 401, tenta uma única
 * vez `POST /auth/refresh` (A3). Se o refresh vier, repete a requisição
 * original com o token novo; se falhar, limpa a sessão e vai para /login.
 * Requisições `/auth/*` não passam por esse ciclo (evita loop).
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const isAuthCall = req.url.includes('/auth/');
  const token = auth.token;

  const withAuth = token && !isAuthCall
    ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
    : req;

  return next(withAuth).pipe(
    catchError((err: HttpErrorResponse) => {
      if (err.status !== 401 || isAuthCall) {
        return throwError(() => err);
      }
      return auth.refreshAccessToken().pipe(
        switchMap((newToken) =>
          next(req.clone({ setHeaders: { Authorization: `Bearer ${newToken}` } })),
        ),
        catchError(() => {
          auth.forceLogoutToLogin();
          return throwError(() => err);
        }),
      );
    }),
  );
};
