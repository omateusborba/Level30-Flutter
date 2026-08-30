/** Respostas de GET /admin/metricas/* (contract.md — B1). */

export interface EngajamentoDia {
  data: string;
  conclusoes: number;
  usuariosAtivos: number;
  novosDesafios: number;
  xpGanho: number;
}

export interface SobrevivenciaPonto {
  dia: number;
  restantes: number;
  pct: number;
}

export interface Coorte {
  semana: string;
  tamanho: number;
  retencao: number[];
}

export interface RiscoDia {
  data: string;
  low: number;
  medium: number;
  high: number;
  critical: number;
}

export interface ContagemNomeada {
  id: string;
  nome: string;
  quantidade: number;
}

export interface NivelContagem {
  nivel: number;
  quantidade: number;
}

export interface FaixaContagem {
  faixa: string;
  quantidade: number;
}

export interface Gamificacao {
  conquistas: ContagemNomeada[];
  niveis: NivelContagem[];
  streaks: FaixaContagem[];
  xpTotalPrograma: number;
}

export interface Padroes {
  porDiaSemana: number[];
  porHora: number[];
}
