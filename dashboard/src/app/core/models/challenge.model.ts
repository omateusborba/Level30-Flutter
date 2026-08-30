export type Category =
  | 'health'
  | 'study'
  | 'productivity'
  | 'mindfulness'
  | 'fitness';

export type RiskLevel = 'low' | 'medium' | 'high' | 'critical';

export const CATEGORIES: Category[] = [
  'health',
  'study',
  'productivity',
  'mindfulness',
  'fitness',
];

export const RISK_LEVELS: RiskLevel[] = ['low', 'medium', 'high', 'critical'];

/** ChallengeResponse — GET /challenges, POST /challenges (contract.md). */
export interface Challenge {
  id: string;
  title: string;
  category: Category;
  description: string;
  totalDays: number;
  currentDay: number;
  xpReward: number;
  streak: number;
  lastActivityAt: string | null;
}

/** Corpo de POST /challenges e POST /admin/programa (mesmos campos). */
export interface CreateChallengeRequest {
  title: string;
  category: Category;
  description: string;
  totalDays: number;
  xpReward: number;
}

/** Item de GET /admin/programa — modelo de desafio do programa (C3). */
export interface ProgramChallenge {
  id: string;
  title: string;
  category: Category;
  description: string;
  totalDays: number;
  xpReward: number;
  active: boolean;
  adotantes: number;
}

/** Item de GET /admin/desafios — Page<AdminChallengeResponse>. */
export interface AdminChallenge {
  id: string;
  titulo: string;
  categoria: Category;
  usuarioNome: string;
  usuarioEmail: string;
  currentDay: number;
  totalDays: number;
  streak: number;
  riskScore: number;
  riskLevel: RiskLevel;
  concluido: boolean;
  /** C2 — replanejamentos aplicados (0..2). */
  replanCount: number;
}
