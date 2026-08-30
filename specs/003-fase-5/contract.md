# Contrato da API Level30 — CONGELADO (Fase 5)

> Fonte de verdade: `backend/` (Spring Boot). Este documento reflete o que a API **realmente**
> responde hoje (verificado com `mvn test` + curl em 2026-08-29). O app Flutter e o dashboard
> Angular consomem **exatamente** estes shapes. Mudou aqui → muda nos dois clientes no mesmo commit.

Base URL local: `http://localhost:8080` · Swagger: `/swagger-ui.html` · OpenAPI JSON: `/v3/api-docs`

## Autenticação

- `Authorization: Bearer <accessToken>` em toda rota exceto `/`, `/auth/**`, `/actuator/health`, swagger.
- **access token**: JWT HS256, validade 1 h, claims `{ sub, email, role, type:"access", iat, exp }`.
- **refresh token**: JWT HS256, validade 30 dias, `type:"refresh"`.
- `401` em qualquer rota → o cliente tenta `POST /auth/refresh` uma vez; se falhar, logout.

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
  "user": { "id": "<uuid>", "name": "Ana", "email": "ana@x.com", "totalXp": 0, "avatar": null } }
```
Erros: `400` (validação / senha < 8), `409` (e-mail já existe).

### `POST /auth/login`  (público) → `200`
Request: `{ "email": "ana@x.com", "password": "..." }` · Resposta: igual ao signup.
Erros: `401` (credenciais inválidas — mensagem não distingue e-mail de senha).

### `POST /auth/refresh`  (público) → `200`
Request: `{ "refreshToken": "<jwt>" }`
```json
{ "token": "<novo access jwt>", "refreshToken": null, "user": { ... } }
```
Erros: `401` (refresh inválido/expirado).

### `GET /me` → `200`
```json
{ "id": "<uuid>", "name": "Ana", "email": "ana@x.com", "totalXp": 120, "avatar": null }
```
`avatar` é `null` ou uma data URI `data:image/...;base64,...`.

### `PUT /me/avatar` → `200`
Request: `{ "avatar": "data:image/jpeg;base64,..." }` (≤ 400000 chars) · Resposta: `{ "avatar": "data:image/..." }`
Erros: `400` (não começa com `data:image/`, ou muito grande).

### `GET /challenges` → `200`  — `ChallengeResponse[]`, mais recentes primeiro
```json
[{ "id": "<uuid>", "title": "Leitura diaria", "category": "study",
   "description": "Ler 20 paginas", "totalDays": 30, "currentDay": 12,
   "xpReward": 300, "streak": 12, "lastActivityAt": "2026-08-29T23:11:02.536131Z" }]
```
- `category` ∈ `health | study | productivity | mindfulness | fitness` (**minúsculas**).
- `lastActivityAt`: string ISO-8601 UTC com `Z`, ou `null`.

### `POST /challenges` → `201`  — `ChallengeResponse`
Request:
```json
{ "title": "min 3 chars", "category": "study", "description": "obrigatoria",
  "totalDays": 30, "xpReward": 300 }
```
Regras: `title` ≥ 3 · `description` não-vazia · `category` válida · `totalDays` 7–90 · `xpReward` 100–1000.
Erros: `400` com `detalhes` por campo.

### `POST /challenges/{id}/complete` → `200`
```json
{ "challenge": { <ChallengeResponse atualizado> }, "xpDelta": 10, "totalXp": 130 }
```
- `xpDelta = earnedXp(currentDay+1) - earnedXp(currentDay)`, `earnedXp = currentDay*xpReward/totalDays` (**divisão inteira**).
- `streak`: última atividade = ontem → `+1`; ≥ 2 dias atrás ou nunca → `1`. **Pode diminuir.**
- `lastActivityAt` passa a ser "agora".
- Erros: `409` "Voce ja concluiu este desafio hoje." (fuso `America/Sao_Paulo`) · `400` "Desafio ja concluido." · `404` (não existe **ou não é do usuário**).

### `DELETE /challenges/{id}` → `204`  (sem corpo)
Erros: `404`.

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

### `GET /admin/indicadores`  (ADMIN) → `200`
```json
{ "totalUsuarios": 4, "totalDesafios": 6, "desafiosConcluidos": 1, "desafiosEmRisco": 2,
  "xpMedioPorUsuario": 340, "melhorStreak": 21,
  "porCategoria": [{ "chave": "study", "quantidade": 2 }, ...],
  "porNivelDeRisco": [{ "chave": "critical", "quantidade": 1 }, ...] }
```
`desafiosEmRisco` = contagem de `riskLevel` HIGH ou CRITICAL.

### RBAC
- USER em `/admin/**` → `403` (formato de erro padrão, `mensagem: "Acesso negado."`).
- Sem token em rota protegida → `401` (`mensagem: "Nao autenticado."`).

## Dados de seed (dev)

| Papel | E-mail | Senha |
|---|---|---|
| ADMIN | `admin@level30.app` | `admin1234` |
| USER | `ana@level30.app`, `bruno@level30.app`, `carla@level30.app` | `estudante1` |

Ana tem 3 desafios (um concluído, um com streak quebrada, um saudável); Bruno 2; Carla 1.
