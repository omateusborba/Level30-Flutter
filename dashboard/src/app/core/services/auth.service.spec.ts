import { TestBed } from '@angular/core/testing';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideRouter } from '@angular/router';
import { AuthService } from './auth.service';
import { environment } from '../../../environments/environment';
import { AuthResponse } from '../models';

const resp = (over: Partial<AuthResponse> = {}): AuthResponse => ({
  token: 't-access',
  refreshToken: 'r-1',
  user: { id: 'u1', name: 'Ana', email: 'a@x.com', totalXp: 0, avatar: null, role: 'ADMIN', ...(over.user ?? {}) },
  ...over,
});

describe('AuthService', () => {
  let service: AuthService;
  let http: HttpTestingController;
  const base = environment.apiBaseUrl;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({
      providers: [AuthService, provideHttpClient(), provideHttpClientTesting(), provideRouter([])],
    });
    service = TestBed.inject(AuthService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
    localStorage.clear();
  });

  it('login persiste token/refresh/user e liga os signals', () => {
    service.login({ email: 'a@x.com', password: 'x' }).subscribe();
    http.expectOne(`${base}/auth/login`).flush(resp());

    expect(localStorage.getItem('level30.token')).toBe('t-access');
    expect(localStorage.getItem('level30.refreshToken')).toBe('r-1');
    expect(service.isAuthenticated()).toBeTrue();
    expect(service.isAdmin()).toBeTrue();
  });

  it('isAdmin é falso para papel USER', () => {
    service.login({ email: 'a@x.com', password: 'x' }).subscribe();
    http.expectOne(`${base}/auth/login`).flush(resp({ user: { role: 'USER' } as never }));
    expect(service.isAuthenticated()).toBeTrue();
    expect(service.isAdmin()).toBeFalse();
  });

  it('refreshAccessToken rotaciona o par e devolve o novo access token', () => {
    localStorage.setItem('level30.refreshToken', 'r-1');
    let novo = '';
    service.refreshAccessToken().subscribe((t) => (novo = t));
    const req = http.expectOne(`${base}/auth/refresh`);
    expect(req.request.body).toEqual({ refreshToken: 'r-1' });
    req.flush(resp({ token: 't-2', refreshToken: 'r-2' }));

    expect(novo).toBe('t-2');
    expect(localStorage.getItem('level30.token')).toBe('t-2');
    expect(localStorage.getItem('level30.refreshToken')).toBe('r-2');
  });

  it('refreshAccessToken sem refresh token → erro, sem HTTP', () => {
    let erro: unknown;
    service.refreshAccessToken().subscribe({ error: (e) => (erro = e) });
    expect(erro).toBeInstanceOf(Error);
    http.verify();
  });

  it('duas chamadas simultâneas de refresh disparam uma só requisição', () => {
    localStorage.setItem('level30.refreshToken', 'r-1');
    service.refreshAccessToken().subscribe();
    service.refreshAccessToken().subscribe();
    const reqs = http.match(`${base}/auth/refresh`);
    expect(reqs.length).toBe(1);
    reqs[0].flush(resp({ token: 't-2', refreshToken: 'r-2' }));
  });

  it('logout limpa o localStorage', () => {
    localStorage.setItem('level30.token', 't');
    localStorage.setItem('level30.refreshToken', 'r');
    localStorage.setItem('level30.user', '{}');
    service.logout();
    expect(localStorage.getItem('level30.token')).toBeNull();
    expect(localStorage.getItem('level30.refreshToken')).toBeNull();
    expect(localStorage.getItem('level30.user')).toBeNull();
  });
});
