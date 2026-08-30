import { HttpErrorResponse } from '@angular/common/http';
import { ApiError } from './models';

/** Extrai a string de erro do contrato ({ mensagem | error }) sem quebrar a tela. */
export function apiErrorMessage(err: unknown, fallback = 'Algo deu errado. Tente novamente.'): string {
  if (err instanceof HttpErrorResponse) {
    if (err.status === 0) {
      return 'Nao foi possivel falar com o servidor (:8080). Ele esta rodando?';
    }
    const body = err.error as Partial<ApiError> | string | null;
    if (body && typeof body === 'object') {
      return body.mensagem ?? body.error ?? fallback;
    }
    if (typeof body === 'string' && body.trim().length > 0) {
      return body;
    }
  }
  return fallback;
}
