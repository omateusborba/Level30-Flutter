import { Hono } from 'hono';
import type { Env, ChallengeRow, UserRow } from '../types';
import { MODEL, CATEGORY_LABEL } from '../ai';

type AppEnv = { Bindings: Env; Variables: { userId: string } };

const chat = new Hono<AppEnv>();

const MAX_HISTORY = 10;
const MAX_MESSAGE_LENGTH = 1000;

interface ChatTurn {
  role: 'user' | 'assistant';
  content: string;
}

// Mesma fórmula de nível/rank do UserProfile no Flutter (lib/data/model/user_profile.dart).
const RANK_TITLES = ['Iniciante', 'Aprendiz', 'Intermediário', 'Avançado', 'Especialista'];

function levelInfo(totalXp: number): { level: number; rank: string } {
  const level = Math.floor(totalXp / 500) + 1;
  const rank = RANK_TITLES[level - 1] ?? 'Lendário';
  return { level, rank };
}

function buildChallengesSummary(rows: ChallengeRow[]): string {
  if (rows.length === 0) {
    return 'O usuário ainda não criou nenhum desafio — incentive com carinho a criar o primeiro.';
  }
  return rows
    .map((r) => {
      const pctDays = r.total_days > 0 ? Math.round((r.current_day / r.total_days) * 100) : 0;
      const risco = r.streak === 0 && r.current_day > 0 ? ' (sequência quebrada, atenção)' : '';
      return `- "${r.title}" [${CATEGORY_LABEL[r.category] ?? r.category}]: dia ${r.current_day}/${r.total_days} (${pctDays}% concluído), sequência atual de ${r.streak} dia(s)${risco}`;
    })
    .join('\n');
}

chat.post('/', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<{ message?: string; history?: ChatTurn[] }>();

  const message = body.message?.trim();
  if (!message) {
    return c.json({ error: 'Mensagem vazia.' }, 400);
  }
  if (message.length > MAX_MESSAGE_LENGTH) {
    return c.json({ error: 'Mensagem muito longa.' }, 400);
  }

  const history = (body.history ?? [])
    .filter(
      (h) =>
        (h.role === 'user' || h.role === 'assistant') && typeof h.content === 'string',
    )
    .slice(-MAX_HISTORY);

  const [{ results }, user] = await Promise.all([
    c.env.DB.prepare('SELECT * FROM challenges WHERE user_id = ? ORDER BY created_at DESC')
      .bind(userId)
      .all<ChallengeRow>(),
    c.env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first<UserRow>(),
  ]);

  const { level, rank } = levelInfo(user?.total_xp ?? 0);

  const systemPrompt = `Você é o Guia do Level30, o companheiro de jornada dentro de um app de gamificação de hábitos em formato RPG (desafios de 30 dias, XP, níveis, sequências/streaks, marcos).

Personalidade: muito amigável, animado(a) e lúdico(a) — fale como um mentor de RPG empolgado torcendo pelo jogador, nunca como um assistente corporativo. Use bastante linguagem de jogo (nível, XP, sequência, marco, "sua jornada", "sua aventura") e emojis com liberdade para dar vida à resposta (🎮🔥⚡🏆🎉💪✨), pelo menos um por resposta. Respostas curtas (no máximo 3-4 frases, exceto quando o jogador pedir uma lista), em português.

Formatação: pode usar **negrito** (com asteriscos duplos) para destacar nomes de desafios, números e palavras-chave importantes. Para listas, use uma linha por item começando com "- ". Não use outros elementos de markdown (sem #, sem links, sem tabelas).

Comportamento essencial: baseie SEMPRE que possível a resposta nos dados reais do jogador abaixo — cite o nome do desafio, o dia atual, a sequência ou o nível quando forem relevantes, em vez de dar conselhos genéricos. Se a sequência de algum desafio estiver quebrada ou o progresso baixo, acolha sem julgar e incentive a retomada. Se o jogador estiver indo bem, comemore de verdade.

Jogador: ${user?.name ?? 'Aventureiro'}, nível ${level} (${rank}), ${user?.total_xp ?? 0} XP total.

Desafios do jogador:
${buildChallengesSummary(results)}`;

  try {
    const response = (await c.env.AI.run(MODEL, {
      messages: [
        { role: 'system' as const, content: systemPrompt },
        ...history.map((h) => ({ role: h.role, content: h.content })),
        { role: 'user' as const, content: message },
      ],
      temperature: 0.7,
    })) as { response?: string };

    const text = response.response?.trim();
    if (!text) throw new Error('empty AI response');

    return c.json({ message: text });
  } catch (err) {
    console.error('Chat AI failed:', err instanceof Error ? err.message : String(err));
    return c.json({ error: 'Não consegui responder agora. Tente novamente.' }, 502);
  }
});

export default chat;
