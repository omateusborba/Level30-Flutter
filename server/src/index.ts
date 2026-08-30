import { Hono, type Context, type Next } from 'hono';
import { cors } from 'hono/cors';
import type { Env } from './types';
import { verifyJwt } from './auth';
import authRoutes from './routes/auth';
import meRoutes from './routes/me';
import challengesRoutes from './routes/challenges';
import chatRoutes from './routes/chat';
import internalRoutes from './routes/internal';

type AppEnv = { Bindings: Env; Variables: { userId: string } };

const app = new Hono<AppEnv>();

// Projeto acadêmico, sem dados sensíveis de terceiros — CORS aberto simplifica testes.
app.use('*', cors({ origin: '*', allowHeaders: ['Content-Type', 'Authorization', 'X-Service-Token'] }));

app.get('/', (c) => c.json({ name: 'level30-ai-gateway', status: 'ok' }));

// ─── Gateway de IA para a API Spring Boot (Fase 5) ──────────────────────────
// Único papel do Worker agora. Autenticado por X-Service-Token, não usa D1.
app.route('/internal', internalRoutes);

// ─── Rotas legadas (backend antigo em D1) ──────────────────────────────────
// Na Fase 5 o backend é o Spring Boot (Postgres). Estas rotas só respondem se
// houver um binding D1; sem ele, devolvem 503 explicando — sem quebrar o Worker.
async function requireDb(c: Context<AppEnv>, next: Next) {
  if (!c.env.DB) {
    return c.json(
      { error: 'Rota legada desativada. Use a API Spring Boot (Fase 5).' },
      503,
    );
  }
  await next();
}

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

app.use('/auth/*', requireDb);
app.use('/me', requireDb, requireAuth);
app.use('/me/*', requireDb, requireAuth);
app.use('/challenges', requireDb, requireAuth);
app.use('/challenges/*', requireDb, requireAuth);
app.use('/chat', requireDb, requireAuth);
app.use('/chat/*', requireDb, requireAuth);

app.route('/auth', authRoutes);
app.route('/me', meRoutes);
app.route('/challenges', challengesRoutes);
app.route('/chat', chatRoutes);

export default app;
