import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  Coorte,
  EngajamentoDia,
  Gamificacao,
  Padroes,
  RiscoDia,
  SobrevivenciaPonto,
} from '../models';

/** Endpoints /admin/metricas/** (B1). Todo o HTTP fica aqui. */
@Injectable({ providedIn: 'root' })
export class MetricasService {
  private readonly base = environment.apiBaseUrl;

  constructor(private http: HttpClient) {}

  engajamento(dias = 30): Observable<EngajamentoDia[]> {
    return this.http.get<EngajamentoDia[]>(`${this.base}/admin/metricas/engajamento`, {
      params: new HttpParams().set('dias', String(dias)),
    });
  }

  sobrevivencia(): Observable<SobrevivenciaPonto[]> {
    return this.http.get<SobrevivenciaPonto[]>(`${this.base}/admin/metricas/sobrevivencia`);
  }

  retencao(): Observable<Coorte[]> {
    return this.http.get<Coorte[]>(`${this.base}/admin/metricas/retencao`);
  }

  risco(dias = 30): Observable<RiscoDia[]> {
    return this.http.get<RiscoDia[]>(`${this.base}/admin/metricas/risco`, {
      params: new HttpParams().set('dias', String(dias)),
    });
  }

  gamificacao(): Observable<Gamificacao> {
    return this.http.get<Gamificacao>(`${this.base}/admin/metricas/gamificacao`);
  }

  padroes(): Observable<Padroes> {
    return this.http.get<Padroes>(`${this.base}/admin/metricas/padroes`);
  }
}
