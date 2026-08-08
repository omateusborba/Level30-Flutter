import { Hono, type Context, type Next } from 'hono';
import { cors } from 'hono/cors';
import type { Env } from './types';
import { verifyJwt } from './auth';
import authRoutes from './routes/auth';
import meRoutes from './routes/me';
import challengesRoutes from './routes/challenges';

type AppEnv = { Bindings: Env; Variables: { userId: string } };

const app = new Hono<AppEnv>();

// Projeto acadêmico, sem dados sensíveis de terceiros — CORS aberto simplifica
// testes via navegador/Flutter Web além do app mobile nativo.
app.use('*', cors({ origin: '*', allowHeaders: ['Content-Type', 'Authorization'] }));

app.get('/', (c) => c.json({ name: 'level30-api', status: 'ok' }));

app.route('/auth', authRoutes);

async function requireAuth(c: Context<AppEnv>, next: Next) {
  const header = c.req.header('Authorization');
  const token = header?.startsWith('Bearer ') ? header.slice(7) : null;
  const payload = token ? await verifyJwt(token, c.env.JWT_SECRET) : null;

  if (!payload) {
    return c.json({ error: 'Não autenticado.' }, 401);
  }
  c.set('userId', payload.sub);
  await next();
}

// Todo endpoint abaixo exige Authorization: Bearer <token>
app.use('/me', requireAuth);
app.use('/me/*', requireAuth);
app.use('/challenges', requireAuth);
app.use('/challenges/*', requireAuth);

app.route('/me', meRoutes);
app.route('/challenges', challengesRoutes);

export default app;
