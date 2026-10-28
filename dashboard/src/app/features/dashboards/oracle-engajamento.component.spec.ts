import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { OracleEngajamentoComponent } from './oracle-engajamento.component';
import { RegistroAuditoriaOracle } from '../../core/models';

describe('OracleEngajamentoComponent — auditoria', () => {
  let comp: OracleEngajamentoComponent;

  const registro = (over: Partial<RegistroAuditoriaOracle>): RegistroAuditoriaOracle => ({
    id: 1, tabela: 'L30_COMPLETIONS', operacao: 'I', registroId: '10',
    dadosAntigos: null,
    dadosNovos: '{"id":10,"challenge_id":"6c47ef2d-9e09-4b05-bdb0-899000000000","user_id":"u","day_number":5,"completed_on":"2026-10-28","xp_delta":20}',
    usuarioBanco: 'LEVEL30', criadoEm: '2026-10-28T20:14:22Z', ...over,
  });

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    comp = TestBed.createComponent(OracleEngajamentoComponent).componentInstance;
    TestBed.inject(HttpTestingController); // requisições do ngOnInit ficam pendentes; o teste não depende delas
  });

  it('resume em uma linha: desafio curto, dia e XP (sem despejar o JSON)', () => {
    expect(comp.resumoAuditoria(registro({}))).toBe('desafio 6c47ef2d · dia 5 · +20 XP');
  });

  it('UPDATE mostra a mudança de XP; DELETE usa os dados antigos', () => {
    const antigo = '{"challenge_id":"abcdef12-0000","day_number":3,"xp_delta":10}';
    const novo = '{"challenge_id":"abcdef12-0000","day_number":3,"xp_delta":15}';
    expect(comp.resumoAuditoria(registro({ operacao: 'U', dadosAntigos: antigo, dadosNovos: novo }))).toContain('XP 10 → 15');
    expect(comp.resumoAuditoria(registro({ operacao: 'D', dadosAntigos: antigo, dadosNovos: null }))).toBe('desafio abcdef12 · dia 3 · −10 XP');
  });

  it('JSON só aparece depois de expandir e vem formatado', () => {
    expect(comp.jsonAberto(1)).toBeFalse();
    comp.alternarJson(1);
    expect(comp.jsonAberto(1)).toBeTrue();
    expect(comp.jsonFormatado(registro({}))).toContain('depois: {\n  "id": 10');
    comp.alternarJson(1);
    expect(comp.jsonAberto(1)).toBeFalse();
  });
});
