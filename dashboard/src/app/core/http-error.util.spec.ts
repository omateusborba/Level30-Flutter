import { HttpErrorResponse } from '@angular/common/http';
import { apiErrorMessage } from './http-error.util';
import { environment } from '../../environments/environment';

describe('apiErrorMessage', () => {
  it('usa a mensagem do contrato quando o corpo é ApiError', () => {
    const err = new HttpErrorResponse({
      status: 409,
      error: { mensagem: 'Este e-mail ja esta cadastrado.', error: 'x' },
    });
    expect(apiErrorMessage(err)).toBe('Este e-mail ja esta cadastrado.');
  });

  it('cai em `error` quando não há `mensagem`', () => {
    const err = new HttpErrorResponse({ status: 400, error: { error: 'Dados invalidos.' } });
    expect(apiErrorMessage(err)).toBe('Dados invalidos.');
  });

  it('status 0 → cita a apiBaseUrl do ambiente e usa acentuação (não o ":8080" solto antigo)', () => {
    const msg = apiErrorMessage(new HttpErrorResponse({ status: 0 }));
    expect(msg).toContain(environment.apiBaseUrl);
    expect(msg).toContain('Não foi possível');
    expect(msg).not.toContain('(:8080)');
  });

  it('corpo string não-vazio é usado como mensagem', () => {
    const err = new HttpErrorResponse({ status: 500, error: 'Boom' });
    expect(apiErrorMessage(err)).toBe('Boom');
  });

  it('erro desconhecido → fallback informado', () => {
    expect(apiErrorMessage(new Error('nope'), 'fallback custom')).toBe('fallback custom');
  });
});
