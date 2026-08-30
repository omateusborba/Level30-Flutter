import { Hono, type Context, type Next } from 'hono';
import type { Env } from '../types';
import { MODEL, CATEGORY_LABEL } from '../ai';
import { FALLBACK_MESSAGES, type RiskLevel } from '../risk';

type AppEnv = { Bindings: Env };

const internal = new Hono<AppEnv>();

const RISK_LABEL: Record<RiskLevel, string> = {
  low: 'baixo',
  medium: 'médio',
  high: 'alto',
  critical: 'crítico',
};

/**
 * Gateway de IA para a API Spring Boot (Fase 5).
 *
 * O Workers AI só é acessível de dentro do runtime Cloudflare, então o Spring Boot
 * (fonte de verdade do domínio) delega só a geração de texto para cá, autenticando
 * com um segredo compartilhado no header `X-Service-Token`.
 */
async function requireServiceToken(c: Context<AppEnv>, next: Next) {
  const expected = c.env.SERVICE_TOKEN;
  if (!expected) {
    return c.json({ error: 'Gateway interno desabilitado (SERVICE_TOKEN ausente).' }, 503);
  }
  if (c.req.header('X-Service-Token') !== expected) {
    return c.json({ error: 'Service token invalido.' }, 401);
  }
  await next();
}

internal.use('/*', requireServiceToken);

interface RecommendationInput {
  title?: string;
  category?: string;
  currentDay?: number;
  totalDays?: number;
  streak?: number;
  riskLevel?: RiskLevel;
}

internal.post('/recommendation', async (c) => {
  const body = await c.req.json<RecommendationInput>();
  const title = body.title ?? 'seu desafio';
  const category = CATEGORY_LABEL[body.category ?? ''] ?? body.category ?? 'habito';
  const currentDay = body.currentDay ?? 0;
  const totalDays = body.totalDays ?? 30;
  const streak = body.streak ?? 0;
  const riskLevel = (body.riskLevel ?? 'medium') as RiskLevel;

  try {
    const response = (await c.env.AI.run(MODEL, {
      messages: [
        {
          role: 'system',
          content:
            'Você é um coach de hábitos motivador. Responda sempre em português, em no máximo 2 frases curtas, tom encorajador e específico. Não use markdown, aspas ou emojis em excesso.',
        },
        {
          role: 'user',
          content: `Desafio "${title}" (categoria ${category}). Dia ${currentDay} de ${totalDays}. Sequência atual: ${streak} dias. Nível de risco de abandono: ${RISK_LABEL[riskLevel]}. Dê uma recomendação curta e específica para hoje.`,
        },
      ],
      temperature: 0.4,
    })) as { response?: string };

    const text = response.response?.trim();
    if (!text) throw new Error('empty AI response');
    return c.json({ message: text, aiGenerated: true });
  } catch (err) {
    console.error('internal/recommendation AI failed:', err instanceof Error ? err.message : String(err));
    return c.json({ message: FALLBACK_MESSAGES[riskLevel], aiGenerated: false });
  }
});

interface ChatInput {
  system?: string;
  message?: string;
  history?: { role: 'user' | 'assistant'; content: string }[];
}

internal.post('/chat', async (c) => {
  const body = await c.req.json<ChatInput>();
  const message = body.message?.trim();
  if (!message) {
    return c.json({ error: 'Mensagem vazia.' }, 400);
  }
  const system = body.system?.trim() || 'Você é o Guia do Level30, um mentor de RPG animado.';
  const history = (body.history ?? [])
    .filter((h) => (h.role === 'user' || h.role === 'assistant') && typeof h.content === 'string')
    .slice(-10);

  try {
    const response = (await c.env.AI.run(MODEL, {
      messages: [
        { role: 'system', content: system },
        ...history.map((h) => ({ role: h.role, content: h.content })),
        { role: 'user', content: message },
      ],
      temperature: 0.7,
    })) as { response?: string };

    const text = response.response?.trim();
    if (!text) throw new Error('empty AI response');
    return c.json({ message: text });
  } catch (err) {
    console.error('internal/chat AI failed:', err instanceof Error ? err.message : String(err));
    return c.json({ error: 'Não consegui responder agora.' }, 502);
  }
});

export default internal;
