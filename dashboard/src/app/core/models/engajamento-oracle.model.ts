/** Respostas de GET/POST /admin/engajamento/* — camada Oracle PL/SQL (Fase 6). */

export type FaixaEngajamento = 'ALTO' | 'MODERADO' | 'EM_RISCO' | 'CRITICO' | 'SEM_DESAFIO';

export interface LinhaEngajamentoOracle {
  userId: string;
  nome: string;
  desafiosAtivos: number;
  conclusoes: number;
  adesaoPercentual: number | null;
  streakAtual: number;
  faixa: FaixaEngajamento;
}

export interface RelatorioEngajamentoOracle {
  execucaoId: number;
  periodoInicio: string;
  periodoFim: string;
  contagemPorFaixa: Record<string, number | undefined>;
  linhas: LinhaEngajamentoOracle[];
}

export interface AlertaEngajamentoOracle {
  id: number;
  userId: string;
  nomeUsuario: string;
  challengeId: string | null;
  tipo: string;
  severidade: 'BAIXA' | 'MEDIA' | 'ALTA';
  mensagem: string;
  valorMedido: number | null;
  resolvido: boolean;
  criadoEm: string;
}

export interface InatividadeVerificacaoResultado {
  alertasGerados: number;
}
