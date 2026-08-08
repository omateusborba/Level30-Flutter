# Design técnico — Backend real (auth, banco, IA)

## Stack

- **Worker**: Cloudflare Workers + Hono (TypeScript), em `server/`.
- **Banco**: Cloudflare D1 (SQLite), binding `DB`.
- **IA**: Cloudflare Workers AI, binding `AI`, modelo `@cf/meta/llama-3.1-8b-instruct`.
- **Auth**: PBKDF2-SHA256 (Web Crypto) para senha, JWT HS256 manual (Web Crypto) para sessão.

## Schema D1 (`server/migrations/0001_init.sql`)

```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  name TEXT NOT NULL,
  total_xp INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE challenges (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  total_days INTEGER NOT NULL,
  current_day INTEGER NOT NULL DEFAULT 0,
  xp_reward INTEGER NOT NULL,
  streak INTEGER NOT NULL DEFAULT 0,
  last_activity_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_challenges_user ON challenges(user_id);
```

`category` é validada contra o enum: `health | study | productivity | mindfulness | fitness` (mesmos valores do `ChallengeCategory` em Dart, via `.name`).

## Auth

### Hash de senha

```typescript
async function hashPassword(password: string, salt: Uint8Array): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100_000, hash: 'SHA-256' }, key, 256
  );
  return bufferToHex(bits);
}
// salt: crypto.getRandomValues(new Uint8Array(16)), armazenado em hex em password_salt
```

### JWT (HS256 manual, sem dependência)

Header fixo `{"alg":"HS256","typ":"JWT"}`. Payload: `{ sub: userId, email, iat, exp }` (exp = iat + 30 dias). Assinatura: `crypto.subtle.sign('HMAC', key, data)` com a secret `JWT_SECRET` (Worker secret). Codificação base64url em todas as partes, formato `header.payload.signature`.

```typescript
async function signJwt(payload: object, secret: string): Promise<string> { /* ... */ }
async function verifyJwt(token: string, secret: string): Promise<JwtPayload | null> { /* valida assinatura + exp */ }
```

### Middleware Hono

```typescript
app.use('/challenges/*', async (c, next) => {
  const auth = c.req.header('Authorization');
  const token = auth?.replace('Bearer ', '');
  const payload = token && await verifyJwt(token, c.env.JWT_SECRET);
  if (!payload) return c.json({ error: 'unauthorized' }, 401);
  c.set('userId', payload.sub);
  await next();
});
```

## Endpoints

| Método | Rota | Auth | Body/Resposta |
|---|---|---|---|
| POST | `/auth/signup` | - | `{name,email,password}` → 201 `{token, user}` / 409 se e-mail existe |
| POST | `/auth/login` | - | `{email,password}` → 200 `{token, user}` / 401 se inválido |
| GET | `/me` | sim | 200 `{id,name,email,totalXp}` |
| GET | `/challenges` | sim | 200 `Challenge[]` (só do usuário autenticado) |
| POST | `/challenges` | sim | `{title,category,description,totalDays,xpReward}` → 201 `Challenge` |
| POST | `/challenges/:id/complete` | sim | 200 `{challenge, xpDelta, totalXp}` |
| DELETE | `/challenges/:id` | sim | 204 |
| GET | `/challenges/:id/recommendation` | sim | 200 `{message, riskScore, riskLevel, aiGenerated}` |

`Challenge` JSON usa **camelCase** (mesmo shape que `Challenge.toJson()` no Dart) para o Flutter poder reaproveitar o `Challenge.fromJson` já existente — o Worker faz a tradução de/para `snake_case` do D1 internamente.

### `/challenges/:id/complete`

```typescript
const before = earnedXp(challenge); // trunc((current_day/total_days) * xp_reward)
const updated = { ...challenge, current_day: challenge.current_day + 1, streak: challenge.streak + 1, last_activity_at: now };
const after = earnedXp(updated);
const delta = after - before;
// UPDATE challenges SET ...; UPDATE users SET total_xp = total_xp + delta WHERE id = ?;
```

### `/challenges/:id/recommendation` — `server/src/ai.ts`

1. Calcula `riskScore`/`riskLevel` com `risk.ts` (mesmos pesos: inatividade 40%, progresso 30%, streak 30%; mesmos thresholds 0.25/0.5/0.75 do `RiskEngine` Dart).
2. Monta prompt:
```
Sistema: Você é um coach de hábitos motivador. Responda em português, em 1-2 frases curtas, tom encorajador, sem markdown.
Usuário: Desafio "{title}" (categoria {category}). Dia {currentDay} de {totalDays}. Sequência atual: {streak} dias. Nível de risco: {riskLevel}. Dê uma recomendação curta e específica para hoje.
```
3. `env.AI.run('@cf/meta/llama-3.1-8b-instruct', { messages, temperature: 0.4 })`.
4. Sucesso → `{ message: response.response.trim(), riskScore, riskLevel, aiGenerated: true }`.
5. Falha (try/catch) → `{ message: FALLBACK_MESSAGES[riskLevel], riskScore, riskLevel, aiGenerated: false }` (mesmas 5 mensagens de `risk_assessment.dart`, portadas para TS).

## CORS

`app.use('*', cors({ origin: '*' }))` — projeto acadêmico, sem dados sensíveis de terceiros; simplifica testes via navegador/Flutter Web além do app mobile.

## wrangler.jsonc

```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "name": "level30-api",
  "main": "src/index.ts",
  "compatibility_date": "2026-08-08",
  "d1_databases": [{ "binding": "DB", "database_name": "level30-db", "database_id": "<preenchido após wrangler d1 create>" }],
  "ai": { "binding": "AI" },
  "observability": { "enabled": true }
}
```

`JWT_SECRET` via `wrangler secret put` (nunca no arquivo de config).

## Flutter — contratos

`ApiClient` (`lib/data/service/api_client.dart`) centraliza:
- `Uri.parse('${AppConfig.apiBaseUrl}$path')`
- Header `Authorization: Bearer $token` quando houver token salvo
- Decodifica `{error: string}` em erro 4xx/5xx → lança `ApiException(message, statusCode)`
- 401 → dispara um callback registrado pelo `UserProvider` para fazer logout automático (evita import circular entre `ApiClient` e `UserProvider`)

`UserProvider` passa a guardar:
```dart
String? _token; // em flutter_secure_storage, chave 'auth_token'
bool get isAuthenticated => _token != null;
Future<void> restoreSession() // lê token salvo, chama GET /me; se 401, limpa
Future<void> signUp(...) / logIn(...) // chama API, salva token, popula profile
Future<void> logOut() // limpa token salvo e estado
```

`ChallengeProvider.init()` só popula a lista se `UserProvider.isAuthenticated`; caso contrário fica vazio. Nenhum `_defaultChallenges()`.

## Verificação

- `curl` local (`wrangler dev --remote`) e depois contra a URL de produção: signup → login → criar desafio → completar dia → recommendation.
- `flutter analyze` / `flutter test` (RiskEngine client-side inalterado).
- Roteiro manual descrito no plano de implementação.
