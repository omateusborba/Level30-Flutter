import type { Env, ChallengeRow } from './types';
import { calculateRiskScore, scoreToLevel, fallbackMessage, type RiskLevel } from './risk';

export interface RecommendationResult {
  message: string;
  riskScore: number;
  riskLevel: RiskLevel;
  aiGenerated: boolean;
}

// llama-3.1-8b-instruct (sem sufixo) foi descontinuado em 2026-05-30;
// -fast é a variante atual recomendada pelo catálogo de modelos da Cloudflare.
const MODEL = '@cf/meta/llama-3.1-8b-instruct-fast';

const CATEGORY_LABEL: Record<string, string> = {
  health: 'Saúde',
  study: 'Estudos',
  productivity: 'Produtividade',
  mindfulness: 'Mindfulness',
  fitness: 'Fitness',
};

const RISK_LABEL: Record<RiskLevel, string> = {
  low: 'baixo',
  medium: 'médio',
  high: 'alto',
  critical: 'crítico',
};

export async function buildRecommendation(
  env: Env,
  challenge: ChallengeRow,
): Promise<RecommendationResult> {
  const riskScore = calculateRiskScore(challenge);
  const riskLevel = scoreToLevel(riskScore);

  try {
    const prompt = [
      {
        role: 'system' as const,
        content:
          'Você é um coach de hábitos motivador. Responda sempre em português, em no máximo 2 frases curtas, tom encorajador e específico. Não use markdown, aspas ou emojis em excesso.',
      },
      {
        role: 'user' as const,
        content: `Desafio "${challenge.title}" (categoria ${CATEGORY_LABEL[challenge.category] ?? challenge.category}). Dia ${challenge.current_day} de ${challenge.total_days}. Sequência atual: ${challenge.streak} dias consecutivos. Nível de risco de abandono: ${RISK_LABEL[riskLevel]}. Dê uma recomendação curta e específica para hoje.`,
      },
    ];

    const response = (await env.AI.run(MODEL, {
      messages: prompt,
      temperature: 0.4,
    })) as { response?: string };

    const text = response.response?.trim();
    if (!text) throw new Error('empty AI response');

    return { message: text, riskScore, riskLevel, aiGenerated: true };
  } catch (err) {
    console.error('Workers AI failed:', err instanceof Error ? err.message : String(err));
    return {
      message: fallbackMessage(challenge, riskLevel),
      riskScore,
      riskLevel,
      aiGenerated: false,
    };
  }
}
