import { Hono } from 'hono';
import type { Env, UserRow } from '../types';

type AppEnv = { Bindings: Env; Variables: { userId: string } };

const me = new Hono<AppEnv>();

me.get('/', async (c) => {
  const userId = c.get('userId');
  const user = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first<UserRow>();
  if (!user) return c.json({ error: 'Usuário não encontrado.' }, 404);
  return c.json({ id: user.id, name: user.name, email: user.email, totalXp: user.total_xp });
});

export default me;
