import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  AdminChallenge,
  AdminUser,
  Category,
  CreateChallengeRequest,
  Indicadores,
  Page,
  ProgramChallenge,
  RiskLevel,
} from '../models';

export interface DesafioFiltro {
  category?: Category | '';
  riskLevel?: RiskLevel | '';
  busca?: string;
  page?: number;
  size?: number;
}

/**
 * Endpoints /admin/** (contract.md). Toda chamada HTTP fica aqui,
 * os componentes apenas assinam os Observables.
 */
@Injectable({ providedIn: 'root' })
export class AdminService {
  private readonly base = environment.apiBaseUrl;

  constructor(private http: HttpClient) {}

  getIndicadores(): Observable<Indicadores> {
    return this.http.get<Indicadores>(`${this.base}/admin/indicadores`);
  }

  getDesafios(filtro: DesafioFiltro = {}): Observable<Page<AdminChallenge>> {
    let params = new HttpParams()
      .set('page', String(filtro.page ?? 0))
      .set('size', String(filtro.size ?? 20));
    if (filtro.category) {
      params = params.set('category', filtro.category);
    }
    if (filtro.riskLevel) {
      params = params.set('riskLevel', filtro.riskLevel);
    }
    if (filtro.busca?.trim()) {
      params = params.set('busca', filtro.busca.trim());
    }
    return this.http.get<Page<AdminChallenge>>(`${this.base}/admin/desafios`, {
      params,
    });
  }

  getUsuarios(page = 0, size = 20): Observable<Page<AdminUser>> {
    const params = new HttpParams()
      .set('page', String(page))
      .set('size', String(size));
    return this.http.get<Page<AdminUser>>(`${this.base}/admin/usuarios`, {
      params,
    });
  }

  // ---- C3 · desafios do programa ----

  getPrograma(): Observable<ProgramChallenge[]> {
    return this.http.get<ProgramChallenge[]>(`${this.base}/admin/programa`);
  }

  criarPrograma(payload: CreateChallengeRequest): Observable<ProgramChallenge> {
    return this.http.post<ProgramChallenge>(`${this.base}/admin/programa`, payload);
  }

  alternarPrograma(id: string, active: boolean): Observable<ProgramChallenge> {
    return this.http.patch<ProgramChallenge>(`${this.base}/admin/programa/${id}`, { active });
  }

  removerPrograma(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/admin/programa/${id}`);
  }
}
