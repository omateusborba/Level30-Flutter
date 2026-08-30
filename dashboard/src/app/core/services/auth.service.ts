import { Injectable, computed, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, finalize, map, shareReplay, tap, throwError } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AuthResponse, LoginRequest, User } from '../models';

const TOKEN_KEY = 'level30.token';
const REFRESH_KEY = 'level30.refreshToken';
const USER_KEY = 'level30.user';

/**
 * Centraliza autenticação. Toda chamada HTTP de auth vive aqui,
 * nunca no componente (checklist 3.3 — HttpClient em service).
 */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly base = environment.apiBaseUrl;

  private readonly _user = signal<User | null>(this.readUser());
  readonly user = this._user.asReadonly();
  readonly isAuthenticated = computed(() => this._user() !== null && this.token !== null);
  /** A5 — o painel é restrito a ADMIN. O servidor ainda é a autoridade (403). */
  readonly isAdmin = computed(() => this.isAuthenticated() && this._user()?.role === 'ADMIN');

  /** A3 — refresh em andamento compartilhado: várias 401 simultâneas disparam um só. */
  private refreshInFlight$: Observable<string> | null = null;

  constructor(private http: HttpClient, private router: Router) {}

  get token(): string | null {
    return localStorage.getItem(TOKEN_KEY);
  }

  get refreshToken(): string | null {
    return localStorage.getItem(REFRESH_KEY);
  }

  login(payload: LoginRequest): Observable<AuthResponse> {
    return this.http
      .post<AuthResponse>(`${this.base}/auth/login`, payload)
      .pipe(tap((res) => this.persistSession(res)));
  }

  /**
   * A3 — troca o refresh token por um par novo (rotação, A2). Chamado pelo
   * interceptor ao receber 401. Compartilha a requisição em voo.
   */
  refreshAccessToken(): Observable<string> {
    if (this.refreshInFlight$) {
      return this.refreshInFlight$;
    }
    const refreshToken = this.refreshToken;
    if (!refreshToken) {
      return throwError(() => new Error('Sem refresh token.'));
    }
    this.refreshInFlight$ = this.http
      .post<AuthResponse>(`${this.base}/auth/refresh`, { refreshToken })
      .pipe(
        tap((res) => this.persistSession(res)),
        map((res) => res.token),
        finalize(() => (this.refreshInFlight$ = null)),
        shareReplay(1),
      );
    return this.refreshInFlight$;
  }

  private persistSession(res: AuthResponse): void {
    localStorage.setItem(TOKEN_KEY, res.token);
    if (res.refreshToken) {
      localStorage.setItem(REFRESH_KEY, res.refreshToken);
    }
    localStorage.setItem(USER_KEY, JSON.stringify(res.user));
    this._user.set(res.user);
  }

  logout(): void {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(REFRESH_KEY);
    localStorage.removeItem(USER_KEY);
    this._user.set(null);
  }

  /** Usado pelo interceptor ao receber 401 sem como recuperar, e pelo botão Sair. */
  forceLogoutToLogin(): void {
    const rt = this.refreshToken;
    if (rt) {
      // best-effort: revoga a família no servidor (A2). Não bloqueia o logout local.
      this.http.post(`${this.base}/auth/logout`, { refreshToken: rt }).subscribe({
        error: () => undefined,
      });
    }
    this.logout();
    void this.router.navigate(['/login']);
  }

  private readUser(): User | null {
    const raw = localStorage.getItem(USER_KEY);
    if (!raw) {
      return null;
    }
    try {
      return JSON.parse(raw) as User;
    } catch {
      return null;
    }
  }
}
