# Contrato da API Level30 — CONGELADO (Fase 5)

> Fonte de verdade: `backend/` (Spring Boot). Este documento reflete o que a API **realmente**
> responde hoje (verificado com `mvn test` + curl em 2026-08-29). O app Flutter e o dashboard
> Angular consomem **exatamente** estes shapes. Mudou aqui → muda nos dois clientes no mesmo commit.

Base URL local: `http://localhost:8080` · Swagger: `/swagger-ui.html` · OpenAPI JSON: `/v3/api-docs`

## Autenticação

- `Authorization: Bearer <accessToken>` em toda rota exceto `/`, `/auth/**`, `/actuator/health`, swagger.
- **access token**: JWT HS256, validade 1 h, claims `{ sub, email, role, type:"access", iat, exp }`.
- **refresh token**: JWT HS256, validade **7 dias** (A2), claims `{ sub, email, role, type:"refresh", jti, iat, exp }`.
- `401` em qualquer rota → o cliente tenta `POST /auth/refresh` uma vez; se falhar, logout.
- **Rotação (A2):** cada `POST /auth/refresh` **consome** o token apresentado e devolve um par novo.
  Reapresentar um refresh token já usado → `401` **e revoga a família inteira** (detecção de reuso).
  → o cliente **precisa persistir o `refreshToken` retornado**.
- **Rate limit (A1):** `/auth/**` — 10 req/60 s por IP → `429` + `Retry-After`. 5 falhas de login
  consecutivas na mesma conta → bloqueio progressivo (1/5/15/60 min) → `429` + `Retry-After`.
  Login bem-sucedido zera o contador.
- **`user.role`** (`"USER"` | `"ADMIN"`) passou a vir no `user` de signup/login/refresh (aditivo, A5).

## Formato de erro (todos os status ≥ 400)

```json
{ "status": 409, "error": "Este e-mail ja esta cadastrado.",
  "mensagem": "Este e-mail ja esta cadastrado.", "detalhes": [], "timestamp": "2026-08-29T23:00:00Z" }
```

`error` e `mensagem` carregam a mesma string (o `ApiClient` do Flutter lê `body['error']`).
`detalhes` traz erros de validação campo a campo quando houver.

## Endpoints

### `GET /`  (público)
```json
{ "name": "level30-api", "status": "ok" }
```

### `POST /auth/signup`  (público) → `201`
Request: `{ "name": "Ana", "email": "ana@x.com", "password": "min8chars" }`
```json
{ "token": "<jwt>", "refreshToken": "<jwt>",
  "user": { "id": "<uuid>", "name": "Ana", "email": "ana@x.com", "totalXp": 0, "avatar": null, "role": "USER" } }
```
Erros: `400` (validação / senha < 8), `409` (e-mail já existe), `429` (rate limit por IP).

### `POST /auth/login`  (público) → `200`
Request: `{ "email": "ana@x.com", "password": "..." }` · Resposta: igual ao signup.
Erros: `401` (credenciais inválidas — mensagem não distingue e-mail de senha),
`429` + `Retry-After` (rate limit por IP, ou conta bloqueada por falhas consecutivas).

### `POST /auth/refresh`  (público) → `200`
Request: `{ "refreshToken": "<jwt>" }`
```json
{ "token": "<novo access jwt>", "refreshToken": "<novo refresh jwt>", "user": { ... } }
```
**Rotaciona**: o `refreshToken` da requisição é consumido; guarde o da resposta.
Erros: `401` (refresh inválido/expirado/**reutilizado** — reuso revoga a família), `429` (rate limit).

### `POST /auth/logout`  (público) → `204`

Request: `{ "refreshToken": "<jwt>" }` · Revoga a família do token. Sempre `204` (idempotente).

### `GET /me/sessoes` → `200` — `SessaoResponse[]`

```json
[{ "id": "<jti-uuid>", "iniciadaEm": "2026-08-30T12:00:00Z", "dispositivo": "<user-agent>", "ip": "<ip>" }]
```

### `DELETE /me/sessoes/{id}` → `204`

Revoga a família daquele `jti` (se pertencer ao usuário). Encerra a sessão em todos os dispositivos dela.

### `GET /me` → `200`
```json
{ "id": "<uuid>", "name": "Ana", "email": "ana@x.com", "totalXp": 120, "avatar": null, "role": "USER" }
```
`avatar` é `null` ou uma data URI `data:image/...;base64,...`. `role` ∈ `USER | ADMIN` (aditivo, A5).

### `PUT /me/avatar` → `200`

Request: `{ "avatar": "data:image/(png|jpeg);base64,..." }` · Resposta: `{ "avatar": "data:image/png;base64,..." }`

- **A6:** aceita só PNG e JPEG (validado por magic bytes, não pelo tipo declarado). SVG e outros → `422`.
  A imagem é redimensionada para ≤ 512 px e **reencodada como PNG** (descarta metadados/payload).
- Erros: `400` (não é data URI base64), `422` (formato não suportado / ilegível), `413/400` (muito grande).

### `GET /challenges` → `200`  — `ChallengeResponse[]`, mais recentes primeiro
```json
[{ "id": "<uuid>", "title": "Leitura diaria", "category": "study",
   "description": "Ler 20 paginas", "totalDays": 30, "currentDay": 12,
   "xpReward": 300, "streak": 12, "lastActivityAt": "2026-08-29T23:11:02.536131Z",
   "createdAt": "2026-08-17T09:00:00Z" }]
```
- `category` ∈ `health | study | productivity | mindfulness | fitness` (**minúsculas**).
- `lastActivityAt`: string ISO-8601 UTC com `Z`, ou `null`.
- `createdAt`: string ISO-8601 UTC com `Z` — **aditivo (C1)**, usado na grade de dias para o estado "atrasado".

### `POST /challenges` → `201`  — `ChallengeResponse`
Request:
```json
{ "title": "min 3 chars", "category": "study", "description": "obrigatoria",
  "totalDays": 30, "xpReward": 300 }
```
Regras: `title` ≥ 3 · `description` não-vazia · `category` válida · `totalDays` 7–90 · `xpReward` 100–1000.
Erros: `400` com `detalhes` por campo.

### `POST /challenges/{id}/complete` → `200`
Body **opcional** (C4): `{ "note": "≤ 280 chars" }` — nota do dia (diário). `400` se > 280.
```json
{ "challenge": { <ChallengeResponse atualizado> }, "xpDelta": 10, "totalXp": 130,
  "conquistas": [{ "id": "primeiro_passo", "nome": "Primeiro Passo",
                   "descricao": "...", "desbloqueada": true }] }
```
`conquistas` (F4) é **aditivo** — lista vazia quando nada foi desbloqueado.
- `xpDelta = earnedXp(currentDay+1) - earnedXp(currentDay)`, `earnedXp = currentDay*xpReward/totalDays` (**divisão inteira**).
- `streak`: última atividade = ontem → `+1`; ≥ 2 dias atrás ou nunca → `1`. **Pode diminuir.**
- `lastActivityAt` passa a ser "agora".
- Erros: `409` "Voce ja concluiu este desafio hoje." (fuso `America/Sao_Paulo`) · `400` "Desafio ja concluido." · `404` (não existe **ou não é do usuário**).

### `DELETE /challenges/{id}` → `204`  (sem corpo)
Erros: `404`.

### C2 · Replanejamento assistido por IA (aditivo)

`ChallengeResponse` e `AdminChallengeResponse` ganham `replanCount` (0..2).

- `POST /challenges/{id}/replanejar/sugestao` → `200` — **não muta nada**
  ```json
  { "totalDaysAtual": 30, "currentDay": 6, "sugestaoDias": 44, "minDias": 7, "maxDias": 90,
    "replanejamentosRestantes": 2, "mensagem": "...", "aiGenerated": false }
  ```
- `POST /challenges/{id}/replanejar` → `200` — `ChallengeResponse` atualizado.
  Request: `{ "totalDays": 7..90 }`. Aplica: `xpReward` recalculado `= xpReward*novo/atual` (**divisão inteira**, clamp 100..1000),
  `replanCount++`. Erros: `400` (já replanejou 2×, desafio concluído, nova duração ≤ dias concluídos).

### `GET /challenges/{id}/recommendation` → `200`
```json
{ "message": "Voce chegou ate aqui - nao desista agora!",
  "riskScore": 0.53, "riskLevel": "high", "aiGenerated": false }
```
- `riskLevel` ∈ `low | medium | high | critical`.
- `aiGenerated: false` = fallback determinístico (gateway de IA fora); `true` = texto do modelo.
- Nunca falha com o gateway fora — sempre cai no fallback.

### `POST /chat` → `200`
Request: `{ "message": "≤1000 chars", "history": [{ "role": "user|assistant", "content": "..." }] }`
Resposta: `{ "message": "resposta do Guia do Level30" }`
Erros: `400` (vazia / > 1000) · `502` (gateway de IA indisponível — **sem fallback textual**).

### `GET /admin/usuarios?page=0&size=20`  (ADMIN) → `200` — `Page<AdminUserResponse>`
```json
{ "content": [{ "id": "<uuid>", "nome": "Ana", "email": "ana@x.com",
    "totalXp": 120, "nivel": 1, "rank": "Iniciante", "quantidadeDesafios": 3 }],
  "totalElements": 4, "totalPages": 1, "number": 0, "size": 20, ... }
```
(Envelope `Page` padrão do Spring Data.)

### `GET /admin/desafios?riskLevel=critical&category=study&page=0&size=20`  (ADMIN) → `200`
`Page<AdminChallengeResponse>`, ordenado por `riskScore` desc. Filtros opcionais.
```json
{ "id": "<uuid>", "titulo": "...", "categoria": "study",
  "usuarioNome": "Ana", "usuarioEmail": "ana@x.com",
  "currentDay": 4, "totalDays": 30, "streak": 1,
  "riskScore": 0.53, "riskLevel": "high", "concluido": false }
```
**B1:** `risk_score`/`risk_level` são **materializados** em `challenges` (recalc no `complete` + job
diário 00:05). Filtro/ordenação/paginação acontecem no banco (índice), não mais em memória.

### `GET /admin/indicadores`  (ADMIN) → `200`
```json
{ "totalUsuarios": 4, "totalDesafios": 6, "desafiosConcluidos": 1, "desafiosEmRisco": 2,
  "xpMedioPorUsuario": 340, "melhorStreak": 21,
  "porCategoria": [{ "chave": "study", "quantidade": 2 }, ...],
  "porNivelDeRisco": [{ "chave": "critical", "quantidade": 1 }, ...] }
```
`desafiosEmRisco` = contagem de `riskLevel` HIGH ou CRITICAL. **B1:** agora via `COUNT`/`GROUP BY`
(sem `findAll()`).

### B1 · Métricas dos dashboards (ADMIN, aditivo)

| Rota | Retorno |
|---|---|
| `GET /admin/metricas/engajamento?dias=30` | `[{ data, conclusoes, usuariosAtivos, novosDesafios, xpGanho }]` — série diária |
| `GET /admin/metricas/sobrevivencia` | `[{ dia, restantes, pct }]` — % de desafios que chegam ao dia N |
| `GET /admin/metricas/retencao` | `[{ semana, tamanho, retencao: [pct...] }]` — coorte por semana de cadastro |
| `GET /admin/metricas/risco?dias=30` | `[{ data, low, medium, high, critical }]` — snapshots diários |
| `GET /admin/metricas/gamificacao` | `{ conquistas: [{id,nome,quantidade}], niveis: [{nivel,quantidade}], streaks: [{faixa,quantidade}], xpTotalPrograma }` |
| `GET /admin/metricas/padroes` | `{ porDiaSemana: [7], porHora: [24] }` (0 = segunda) |

### C3 · Desafios do programa (aditivo)

`Challenge` ganha `programChallengeId` (interno; não sai no JSON hoje).

- `GET /programa` (JWT) → `[{ id, title, category, description, totalDays, xpReward, active, adotantes, adotado }]`
  — só os ativos; `adotado` = o usuário já criou um desafio a partir deste modelo.
- `POST /programa/{id}/adotar` (JWT) → `200` `ChallengeResponse` (desafio pessoal criado).
  Erros: `409` (já adotou), `400` (modelo arquivado), `404`.
- `GET /admin/programa` (ADMIN) → todos os modelos, com `adotantes`.
- `POST /admin/programa` (ADMIN) → `201` — `{ title, category, description, totalDays 7..90, xpReward 100..1000 }`.
- `PATCH /admin/programa/{id}` (ADMIN) → `{ "active": bool }`.
- `DELETE /admin/programa/{id}` (ADMIN) → `204` (desafios já adotados não mudam).

### F1 · Histórico (aditivo)

- `GET /challenges/{id}/historico` → `[{ "dayNumber": 1, "completedOn": "2026-08-30", "note": null, "xpDelta": 10 }]`
- `GET /me/atividade?desde=YYYY-MM-DD` → `[{ "data": "2026-08-30", "quantidade": 2, "xp": 20 }]`
  (heatmap + "Meu Progresso". `xp` é aditivo — B6.)

### F4 · Conquistas (aditivo)

- `GET /me/conquistas` → `[{ "id": "veterano", "nome": "Veterano", "descricao": "...", "desbloqueada": false }]` (catálogo de 8, com estado)
- `conquistas` no corpo de `POST /challenges/{id}/complete` (ver acima).

### RBAC
- USER em `/admin/**` → `403` (formato de erro padrão, `mensagem: "Acesso negado."`).
- Sem token em rota protegida → `401` (`mensagem: "Nao autenticado."`).

## Dados de seed (dev)

| Papel | E-mail | Senha |
|---|---|---|
| ADMIN | `admin@level30.app` | `admin1234` |
| USER | `ana@level30.app`, `bruno@level30.app`, `carla@level30.app` | `estudante1` |

Ana tem 3 desafios (um concluído, um com streak quebrada, um saudável); Bruno 2; Carla 1.
