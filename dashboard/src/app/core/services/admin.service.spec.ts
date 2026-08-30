import { TestBed } from '@angular/core/testing';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';
import { AdminService } from './admin.service';
import { environment } from '../../../environments/environment';

describe('AdminService', () => {
  let service: AdminService;
  let http: HttpTestingController;
  const base = environment.apiBaseUrl;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [AdminService, provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(AdminService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('getDesafios sem filtros → só page e size', () => {
    service.getDesafios().subscribe();
    const req = http.expectOne((r) => r.url === `${base}/admin/desafios`);
    expect(req.request.params.get('page')).toBe('0');
    expect(req.request.params.get('size')).toBe('20');
    expect(req.request.params.has('category')).toBeFalse();
    expect(req.request.params.has('riskLevel')).toBeFalse();
    expect(req.request.params.has('busca')).toBeFalse();
    req.flush({ content: [], totalElements: 0, totalPages: 0, number: 0, size: 20 });
  });

  it('getDesafios com filtros parciais → só os truthy viram params', () => {
    service.getDesafios({ riskLevel: 'critical', busca: '  ana  ', category: '', page: 2 }).subscribe();
    const req = http.expectOne((r) => r.url === `${base}/admin/desafios`);
    expect(req.request.params.get('riskLevel')).toBe('critical');
    expect(req.request.params.get('busca')).toBe('ana');
    expect(req.request.params.get('page')).toBe('2');
    expect(req.request.params.has('category')).toBeFalse();
    req.flush({ content: [], totalElements: 0, totalPages: 0, number: 2, size: 20 });
  });

  it('getIndicadores → GET /admin/indicadores', () => {
    service.getIndicadores().subscribe();
    http.expectOne(`${base}/admin/indicadores`).flush({});
  });
});
