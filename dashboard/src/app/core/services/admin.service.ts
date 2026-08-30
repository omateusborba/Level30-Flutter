import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  AdminChallenge,
  AdminUser,
  Category,
  Indicadores,
  Page,
  RiskLevel,
} from '../models';

export interface DesafioFiltro {
  category?: Category | '';
  riskLevel?: RiskLevel | '';
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
}
