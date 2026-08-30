/** Item das distribuições porCategoria / porNivelDeRisco. */
export interface Distribuicao {
  chave: string;
  quantidade: number;
}

/** Resposta de GET /admin/indicadores (contract.md). */
export interface Indicadores {
  totalUsuarios: number;
  totalDesafios: number;
  desafiosConcluidos: number;
  desafiosEmRisco: number;
  xpMedioPorUsuario: number;
  melhorStreak: number;
  porCategoria: Distribuicao[];
  porNivelDeRisco: Distribuicao[];
}
