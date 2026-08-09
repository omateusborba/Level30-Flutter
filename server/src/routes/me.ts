import { Hono } from 'hono';
import type { Env, UserRow } from '../types';

type AppEnv = { Bindings: Env; Variables: { userId: string } };

const me = new Hono<AppEnv>();

// data URI base64 — 300KB decodificados dá ~400KB em base64; a foto já sai
// comprimida do app, então isso é uma margem de segurança, não o alvo normal.
const MAX_AVATAR_LENGTH = 400_000;

me.get('/', async (c) => {
  const userId = c.get('userId');
  const user = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first<UserRow>();
  if (!user) return c.json({ error: 'Usuário não encontrado.' }, 404);
  return c.json({
    id: user.id,
    name: user.name,
    email: user.email,
    totalXp: user.total_xp,
    avatar: user.avatar,
  });
});

me.put('/avatar', async (c) => {
  const userId = c.get('userId');
  const body = await c.req.json<{ avatar?: string }>();
  const avatar = body.avatar;

  if (!avatar || !avatar.startsWith('data:image/')) {
    return c.json({ error: 'Imagem inválida.' }, 400);
  }
  if (avatar.length > MAX_AVATAR_LENGTH) {
    return c.json({ error: 'Imagem muito grande.' }, 400);
  }

  await c.env.DB.prepare('UPDATE users SET avatar = ? WHERE id = ?').bind(avatar, userId).run();
  return c.json({ avatar });
});

export default me;
