import { TestBed } from '@angular/core/testing';
import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { of, throwError } from 'rxjs';
import { authInterceptor } from './auth.interceptor';
import { AuthService } from '../services/auth.service';
import { environment } from '../../../environments/environment';

describe('authInterceptor', () => {
  let httpClient: HttpClient;
  let httpMock: HttpTestingController;
  let auth: {
    token: string | null;
    refreshAccessToken: jasmine.Spy;
    forceLogoutToLogin: jasmine.Spy;
  };
  const base = environment.apiBaseUrl;

  beforeEach(() => {
    auth = {
      token: 'tok-1',
      refreshAccessToken: jasmine.createSpy('refreshAccessToken'),
      forceLogoutToLogin: jasmine.createSpy('forceLogoutToLogin'),
    };
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
        { provide: AuthService, useValue: auth },
      ],
    });
    httpClient = TestBed.inject(HttpClient);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('injeta Authorization: Bearer no request', () => {
    httpClient.get(`${base}/admin/indicadores`).subscribe();
    const req = httpMock.expectOne(`${base}/admin/indicadores`);
    expect(req.request.headers.get('Authorization')).toBe('Bearer tok-1');
    req.flush({});
  });

  it('não injeta header em chamadas /auth/*', () => {
    httpClient.post(`${base}/auth/login`, {}).subscribe();
    const req = httpMock.expectOne(`${base}/auth/login`);
    expect(req.request.headers.has('Authorization')).toBeFalse();
    req.flush({});
  });

  it('401 → tenta refresh e repete a requisição com o token novo', () => {
    auth.refreshAccessToken.and.returnValue(of('tok-2'));
    httpClient.get(`${base}/admin/usuarios`).subscribe();

    httpMock.expectOne(`${base}/admin/usuarios`).flush(null, { status: 401, statusText: 'Unauthorized' });

    const retry = httpMock.expectOne(`${base}/admin/usuarios`);
    expect(retry.request.headers.get('Authorization')).toBe('Bearer tok-2');
    retry.flush({});
    expect(auth.forceLogoutToLogin).not.toHaveBeenCalled();
  });

  it('401 + refresh falhou → forceLogoutToLogin', () => {
    auth.refreshAccessToken.and.returnValue(throwError(() => new Error('no refresh')));
    httpClient.get(`${base}/admin/usuarios`).subscribe({ error: () => undefined });

    httpMock.expectOne(`${base}/admin/usuarios`).flush(null, { status: 401, statusText: 'Unauthorized' });
    expect(auth.forceLogoutToLogin).toHaveBeenCalled();
  });

  it('erro não-401 propaga sem refresh', () => {
    httpClient.get(`${base}/admin/usuarios`).subscribe({ error: () => undefined });
    httpMock.expectOne(`${base}/admin/usuarios`).flush(null, { status: 500, statusText: 'err' });
    expect(auth.refreshAccessToken).not.toHaveBeenCalled();
  });
});
