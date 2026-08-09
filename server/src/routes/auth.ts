import { Hono } from 'hono';
import type { Env, UserRow } from '../types';
import { hashPassword, verifyPassword, signJwt } from '../auth';

type AppEnv = { Bindings: Env };

const auth = new Hono<AppEnv>();

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function publicUser(user: UserRow) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    totalXp: user.total_xp,
    avatar: user.avatar,
  };
}

auth.post('/signup', async (c) => {
  const body = await c.req.json<{ name?: string; email?: string; password?: string }>();
  const name = body.name?.trim();
  const email = body.email?.trim().toLowerCase();
  const password = body.password;

  if (!name || !email || !password) {
    return c.json({ error: 'Nome, e-mail e senha são obrigatórios.' }, 400);
  }
  if (!isValidEmail(email)) {
    return c.json({ error: 'E-mail inválido.' }, 400);
  }
  if (password.length < 8) {
    return c.json({ error: 'A senha precisa ter pelo menos 8 caracteres.' }, 400);
  }

  const existing = await c.env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(email).first();
  if (existing) {
    return c.json({ error: 'Este e-mail já está cadastrado.' }, 409);
  }

  const { hash, salt } = await hashPassword(password);
  const id = crypto.randomUUID();

  await c.env.DB.prepare(
    'INSERT INTO users (id, email, password_hash, password_salt, name, total_xp) VALUES (?, ?, ?, ?, ?, 0)',
  )
    .bind(id, email, hash, salt, name)
    .run();

  const token = await signJwt(id, email, c.env.JWT_SECRET);
  return c.json({ token, user: { id, name, email, totalXp: 0, avatar: null } }, 201);
});

auth.post('/login', async (c) => {
  const body = await c.req.json<{ email?: string; password?: string }>();
  const email = body.email?.trim().toLowerCase();
  const password = body.password;

  if (!email || !password) {
    return c.json({ error: 'E-mail e senha são obrigatórios.' }, 400);
  }

  const user = await c.env.DB.prepare('SELECT * FROM users WHERE email = ?').bind(email).first<UserRow>();
  if (!user || !(await verifyPassword(password, user.password_salt, user.password_hash))) {
    return c.json({ error: 'E-mail ou senha incorretos.' }, 401);
  }

  const token = await signJwt(user.id, user.email, c.env.JWT_SECRET);
  return c.json({ token, user: publicUser(user) });
});

export default auth;
