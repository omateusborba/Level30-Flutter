import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  AlertaEngajamentoOracle,
  InatividadeVerificacaoResultado,
  RelatorioEngajamentoOracle,
} from '../models';

/** Endpoints /admin/engajamento/** (Fase 6 — camada Oracle PL/SQL). Todo o HTTP fica aqui. */
@Injectable({ providedIn: 'root' })
export class EngajamentoOracleService {
  private readonly base = environment.apiBaseUrl;

  constructor(private http: HttpClient) {}

  gerarRelatorio(inicio: string, fim: string): Observable<RelatorioEngajamentoOracle> {
    return this.http.post<RelatorioEngajamentoOracle>(
      `${this.base}/admin/engajamento/relatorios`,
      { inicio, fim },
    );
  }

  listarAlertas(abertos = true): Observable<AlertaEngajamentoOracle[]> {
    return this.http.get<AlertaEngajamentoOracle[]>(`${this.base}/admin/engajamento/alertas`, {
      params: new HttpParams().set('abertos', String(abertos)),
    });
  }

  verificarInatividade(diasLimite = 3): Observable<InatividadeVerificacaoResultado> {
    return this.http.post<InatividadeVerificacaoResultado>(
      `${this.base}/admin/engajamento/inatividade/verificar`,
      {},
      { params: new HttpParams().set('diasLimite', String(diasLimite)) },
    );
  }
}
