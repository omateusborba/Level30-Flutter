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

/** GET /admin/engajamento — Dynamic SQL seguro (Fase 7, PKG_L30_CONSULTAS). */
export type OrdenacaoEngajamento = 'ADESAO' | 'STREAK' | 'NOME' | 'NIVEL';
export type DirecaoOrdenacao = 'ASC' | 'DESC';

export interface FiltroEngajamentoOracle {
  inicio?: string;
  fim?: string;
  nivelMin?: number | null;
  adesaoMin?: number | null;
  ordenarPor: OrdenacaoEngajamento;
  direcao: DirecaoOrdenacao;
}

export interface EngajamentoFiltradoOracle {
  userId: string;
  nome: string;
  totalXp: number;
  nivel: number;
  streak: number;
  conclusoes: number;
  adesaoPercentual: number | null;
  faixa: FaixaEngajamento;
}

/** GET /admin/auditoria — linhas de L30_AUDIT_LOG (dados antigos/novos são JSON em texto). */
export interface RegistroAuditoriaOracle {
  id: number;
  tabela: string;
  operacao: 'I' | 'U' | 'D';
  registroId: string | null;
  dadosAntigos: string | null;
  dadosNovos: string | null;
  usuarioBanco: string;
  criadoEm: string;
}
