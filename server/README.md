# level30-api

Backend do Level30 — Cloudflare Worker (Hono + TypeScript), banco D1 e recomendações via Workers AI.

Ver a spec completa em [`../specs/002-real-backend-and-ai/`](../specs/002-real-backend-and-ai/).

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

## Deploy

```bash
npx wrangler d1 create level30-db          # uma vez; copiar o database_id para wrangler.jsonc
npx wrangler d1 migrations apply level30-db --remote
npx wrangler secret put JWT_SECRET         # gerar com: openssl rand -hex 32
npm run deploy
```

URL atual de produção: `https://level30-api.mateus-borba.workers.dev`

## Endpoints

| Método | Rota | Auth |
|---|---|---|
| POST | `/auth/signup` | - |
| POST | `/auth/login` | - |
| GET | `/me` | sim |
| GET | `/challenges` | sim |
| POST | `/challenges` | sim |
| POST | `/challenges/:id/complete` | sim |
| DELETE | `/challenges/:id` | sim |
| GET | `/challenges/:id/recommendation` | sim |

Auth via header `Authorization: Bearer <token>`, token retornado por `/auth/signup` ou `/auth/login` (validade 30 dias).

## Logs

```bash
npx wrangler tail --format pretty
```
