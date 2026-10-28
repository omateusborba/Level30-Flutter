import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  AlertaEngajamentoOracle,
  EngajamentoFiltradoOracle,
  FiltroEngajamentoOracle,
  InatividadeVerificacaoResultado,
  RegistroAuditoriaOracle,
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

  /** Só envia os filtros preenchidos; o servidor valida ordenação por whitelist. */
  consultar(filtro: FiltroEngajamentoOracle): Observable<EngajamentoFiltradoOracle[]> {
    let params = new HttpParams().set('ordenarPor', filtro.ordenarPor).set('direcao', filtro.direcao);
    if (filtro.inicio) params = params.set('inicio', filtro.inicio);
    if (filtro.fim) params = params.set('fim', filtro.fim);
    if (filtro.nivelMin != null) params = params.set('nivelMin', String(filtro.nivelMin));
    if (filtro.adesaoMin != null) params = params.set('adesaoMin', String(filtro.adesaoMin));
    return this.http.get<EngajamentoFiltradoOracle[]>(`${this.base}/admin/engajamento`, { params });
  }

  auditoria(limite = 50): Observable<RegistroAuditoriaOracle[]> {
    return this.http.get<RegistroAuditoriaOracle[]>(`${this.base}/admin/auditoria`, {
      params: new HttpParams().set('limite', String(limite)),
    });
  }
}
