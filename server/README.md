# level30-api (Cloudflare Worker)

Backend original do Level30 — Cloudflare Worker (Hono + TypeScript), banco D1 e Workers AI.

> **Fase 5:** o núcleo de domínio migrou para `../backend/` (Spring Boot). Este Worker continua
> vivo porque o **Workers AI só é acessível de dentro do runtime Cloudflare** — ele agora também
> serve como **gateway de IA** para o Spring Boot, via rotas `/internal/*` autenticadas por
> `X-Service-Token` (não por JWT de usuário). Ver `src/routes/internal.ts`.

Ver specs em [`../specs/002-real-backend-and-ai/`](../specs/002-real-backend-and-ai/) e
[`../specs/003-fase-5/`](../specs/003-fase-5/).

## Stack

- **Cloudflare Workers** (Hono) — API HTTP
- **D1** — banco SQLite gerenciado (`users`, `challenges`)
- **Workers AI** — `@cf/meta/llama-3.1-8b-instruct-fast`, gera o texto de recomendação do desafio
- **Auth** — e-mail/senha (PBKDF2-SHA256) + JWT HS256, ambos implementados só com Web Crypto (sem dependência externa)

Custo: tudo roda no tier gratuito da Cloudflare (D1: 500MB/5M leituras/dia; Workers AI: 10.000 neurons/dia, ~50 recomendações/dia com o modelo usado).

## Desenvolvimento

```bash
npm install
npm run typecheck      # tsc --noEmit
npm run dev            # wrangler dev --remote (IA só funciona com --remote)
```

## Deploy (Fase 5 — só o gateway de IA, sem D1)

```bash
cd server
npx wrangler logout                    # sai da conta antiga, se estiver logado
npx wrangler login                     # abre o browser -> logar na conta NOVA (a do dominio level30.online)
npx wrangler whoami                    # confere a conta
npx wrangler deploy                    # cria o Worker "level30-ai-gateway" (bindings: só AI)
npx wrangler secret put SERVICE_TOKEN  # cole um valor aleatorio (openssl rand -hex 24) — o MESMO vai em AI_SERVICE_TOKEN no backend
```

Primeiro deploy numa conta nova: o wrangler pede para registrar um subdominio `*.workers.dev`.
URL final: `https://level30-ai-gateway.<seu-subdominio>.workers.dev` → esse valor vai em
`AI_WORKER_URL` no `deploy/.env`.

> `wrangler.jsonc` **não tem mais D1**. Auth/desafios/XP vivem no Postgres do `../backend/`.
> As rotas legadas (`/auth`, `/me`, `/challenges`, `/chat`) continuam no código mas respondem
> `503` sem um binding D1 — ninguém as chama na Fase 5.

## Endpoints

| Método | Rota | Auth | Fase 5 |
|---|---|---|---|
| GET | `/` | - | health check |
| POST | `/internal/recommendation` | `X-Service-Token` | **ativo** — consumido pela API Spring Boot |
| POST | `/internal/chat` | `X-Service-Token` | **ativo** — consumido pela API Spring Boot |
| POST | `/auth/*`, GET `/me`, `/challenges/*`, `/chat` | — | legado, `503` sem D1 |

### Rotas `/internal/*` (Fase 5 — consumidas pela API Spring Boot)

- `POST /internal/recommendation` — body `{ title, category, currentDay, totalDays, streak, riskLevel }` → `{ message, aiGenerated }`. Nunca falha: sem IA, devolve a mensagem de fallback do nível de risco.
- `POST /internal/chat` — body `{ system, message, history }` → `{ message }` ou `502`.
- Se `SERVICE_TOKEN` não estiver configurado, `/internal/*` responde `503` (desabilitado).

## Logs

```bash
npx wrangler tail --format pretty
```
