// Espelha exatamente lib/domain/engine/risk_engine.dart — mesmos pesos e thresholds.
// Fica no servidor porque a recomendação por IA depende do score, mas o cálculo em si
// continua uma fórmula determinística e auditável (não é a parte gerada por IA).

import type { ChallengeRow } from './types';

export type RiskLevel = 'low' | 'medium' | 'high' | 'critical';

export const FALLBACK_MESSAGES: Record<RiskLevel, string> = {
  low: 'Continue assim! Você está indo muito bem.',
  medium: 'Não esqueça do seu desafio de hoje!',
  high: 'Você chegou até aqui — não desista agora!',
  critical: 'Que tal reajustar o ritmo? Recomeçar é vencer.',
};

const MILESTONE_MESSAGE = '🎉 Marco atingido! Você é incrível!';

function daysSinceLastActivity(row: ChallengeRow): number {
  if (!row.last_activity_at) return row.streak === 0 ? 2 : 0;
  const last = new Date(row.last_activity_at).getTime();
  const diffMs = Date.now() - last;
  return Math.floor(diffMs / (1000 * 60 * 60 * 24));
}

export function calculateRiskScore(row: ChallengeRow): number {
  let score = 0;

  const daysSince = daysSinceLastActivity(row);
  score += daysSince === 0 ? 0.0 : daysSince === 1 ? 0.1 : daysSince === 2 ? 0.25 : 0.4;

  if (row.total_days > 0) {
    const rate = row.current_day / row.total_days;
    score += (1.0 - rate) * 0.3;
  }

  const streakFactor = row.streak === 0 ? 0.3 : Math.max(0, 0.3 - row.streak * 0.03);
  score += streakFactor;

  return Math.min(1, Math.max(0, score));
}

export function scoreToLevel(score: number): RiskLevel {
  if (score < 0.25) return 'low';
  if (score < 0.5) return 'medium';
  if (score < 0.75) return 'high';
  return 'critical';
}

export function fallbackMessage(row: ChallengeRow, level: RiskLevel): string {
  if ([7, 14, 21, 30].includes(row.current_day)) return MILESTONE_MESSAGE;
  return FALLBACK_MESSAGES[level];
}
