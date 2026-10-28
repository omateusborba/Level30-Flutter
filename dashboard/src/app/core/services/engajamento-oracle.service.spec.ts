import { TestBed } from '@angular/core/testing';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';
import { EngajamentoOracleService } from './engajamento-oracle.service';
import { environment } from '../../../environments/environment';

describe('EngajamentoOracleService', () => {
  let service: EngajamentoOracleService;
  let http: HttpTestingController;
  const base = environment.apiBaseUrl;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [EngajamentoOracleService, provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(EngajamentoOracleService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('consultar sem filtros opcionais → só ordenação', () => {
    service.consultar({ ordenarPor: 'ADESAO', direcao: 'DESC' }).subscribe();
    const req = http.expectOne((r) => r.url === `${base}/admin/engajamento`);
    expect(req.request.params.get('ordenarPor')).toBe('ADESAO');
    expect(req.request.params.get('direcao')).toBe('DESC');
    expect(req.request.params.has('nivelMin')).toBeFalse();
    expect(req.request.params.has('adesaoMin')).toBeFalse();
    expect(req.request.params.has('inicio')).toBeFalse();
    req.flush([]);
  });

  it('consultar com filtros → envia só os preenchidos (inclui zero)', () => {
    service
      .consultar({ nivelMin: 2, adesaoMin: 0, inicio: '2026-10-01', ordenarPor: 'NOME', direcao: 'ASC' })
      .subscribe();
    const req = http.expectOne((r) => r.url === `${base}/admin/engajamento`);
    expect(req.request.params.get('nivelMin')).toBe('2');
    expect(req.request.params.get('adesaoMin')).toBe('0');
    expect(req.request.params.get('inicio')).toBe('2026-10-01');
    expect(req.request.params.has('fim')).toBeFalse();
    req.flush([]);
  });

  it('auditoria → GET /admin/auditoria?limite=', () => {
    service.auditoria(20).subscribe();
    const req = http.expectOne((r) => r.url === `${base}/admin/auditoria`);
    expect(req.request.params.get('limite')).toBe('20');
    req.flush([]);
  });
});
