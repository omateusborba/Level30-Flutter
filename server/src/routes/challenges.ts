import { Hono } from 'hono';
import type { Env, ChallengeRow } from '../types';
import { CHALLENGE_CATEGORIES, toChallengeJson, earnedXp } from '../types';
import { buildRecommendation } from '../ai';

type AppEnv = { Bindings: Env; Variables: { userId: string } };

const challenges = new Hono<AppEnv>();

async function getOwnedChallenge(
  env: Env,
  userId: string,
  id: string,
): Promise<ChallengeRow | null> {
  return env.DB.prepare('SELECT * FROM challenges WHERE id = ? AND user_id = ?')
    .bind(id, userId)
    .first<ChallengeRow>();
}

challenges.get('/', async (c) => {
  const userId = c.get('userId');
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM challenges WHERE user_id = ? ORDER BY created_at DESC',
  )
    .bind(userId)
    .all<ChallengeRow>();
  return c.json(results.map(toChallengeJson));
});

challenges.post('/', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<{
    title?: string;
    category?: string;
    description?: string;
    totalDays?: number;
    xpReward?: number;
  }>();

  const title = body.title?.trim();
  const description = body.description?.trim();
  const category = body.category;
  const totalDays = body.totalDays;
  const xpReward = body.xpReward;

  if (!title || title.length < 3) {
    return c.json({ error: 'Título precisa ter pelo menos 3 caracteres.' }, 400);
  }
  if (!description) {
    return c.json({ error: 'Descrição é obrigatória.' }, 400);
  }
  if (!category || !CHALLENGE_CATEGORIES.includes(category as any)) {
    return c.json({ error: 'Categoria inválida.' }, 400);
  }
  if (!totalDays || totalDays < 7 || totalDays > 90) {
    return c.json({ error: 'Duração precisa estar entre 7 e 90 dias.' }, 400);
  }
  if (!xpReward || xpReward < 100 || xpReward > 1000) {
    return c.json({ error: 'Recompensa precisa estar entre 100 e 1000 XP.' }, 400);
  }

  const id = crypto.randomUUID();
  await c.env.DB.prepare(
    `INSERT INTO challenges (id, user_id, title, category, description, total_days, current_day, xp_reward, streak, last_activity_at)
     VALUES (?, ?, ?, ?, ?, ?, 0, ?, 0, NULL)`,
  )
    .bind(id, userId, title, category, description, totalDays, xpReward)
    .run();

  const row = await getOwnedChallenge(c.env, userId, id);
  return c.json(toChallengeJson(row!), 201);
});

challenges.post('/:id/complete', async (c) => {
  const userId = c.get('userId');
  const id = c.req.param('id');
  const row = await getOwnedChallenge(c.env, userId, id);
  if (!row) return c.json({ error: 'Desafio não encontrado.' }, 404);
  if (row.current_day >= row.total_days) {
    return c.json({ error: 'Desafio já concluído.' }, 400);
  }

  const xpBefore = earnedXp(row.current_day, row.total_days, row.xp_reward);
  const nextDay = row.current_day + 1;
  const xpAfter = earnedXp(nextDay, row.total_days, row.xp_reward);
  const xpDelta = xpAfter - xpBefore;
  const now = new Date().toISOString();

  await c.env.DB.batch([
    c.env.DB.prepare(
      'UPDATE challenges SET current_day = ?, streak = streak + 1, last_activity_at = ? WHERE id = ?',
    ).bind(nextDay, now, id),
    c.env.DB.prepare('UPDATE users SET total_xp = total_xp + ? WHERE id = ?').bind(xpDelta, userId),
  ]);

  const updated = await getOwnedChallenge(c.env, userId, id);
  const user = await c.env.DB.prepare('SELECT total_xp FROM users WHERE id = ?')
    .bind(userId)
    .first<{ total_xp: number }>();

  return c.json({
    challenge: toChallengeJson(updated!),
    xpDelta,
    totalXp: user?.total_xp ?? 0,
  });
});

challenges.delete('/:id', async (c) => {
  const userId = c.get('userId');
  const id = c.req.param('id');
  const row = await getOwnedChallenge(c.env, userId, id);
  if (!row) return c.json({ error: 'Desafio não encontrado.' }, 404);

  await c.env.DB.prepare('DELETE FROM challenges WHERE id = ?').bind(id).run();
  return c.body(null, 204);
});

challenges.get('/:id/recommendation', async (c) => {
  const userId = c.get('userId');
  const id = c.req.param('id');
  const row = await getOwnedChallenge(c.env, userId, id);
  if (!row) return c.json({ error: 'Desafio não encontrado.' }, 404);

  const result = await buildRecommendation(c.env, row);
  return c.json(result);
});

export default challenges;
