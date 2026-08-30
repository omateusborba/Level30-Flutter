# level30-api (Spring Boot) — Fase 5

Núcleo de domínio do Level30: auth, usuários, desafios, motor de risco, gateway de IA e
endpoints administrativos. Consumido pelo app **Flutter** e pelo dashboard **Angular** sobre
o **mesmo contrato JSON congelado** (ver [`../specs/003-fase-5/contract.md`](../specs/003-fase-5/contract.md)).

## Stack

- Java 21, Spring Boot 3.5, Maven
- Spring Web, Data JPA, Security, Validation, Actuator
- Flyway (migrations agnósticas) · **H2** para dev/test · **PostgreSQL** em produção (profile `postgres`)
- JWT HS256 (jjwt 0.12) + BCrypt(10)
- springdoc-openapi (Swagger UI)

## Rodar

```bash
# precisa de Java 21 no PATH (ou export JAVA_HOME)
mvn spring-boot:run
# API em http://localhost:8080  ·  Swagger em http://localhost:8080/swagger-ui.html
```

No primeiro boot o `DataSeeder` cria dados de demonstração (base vazia):

| Papel | E-mail | Senha |
|---|---|---|
| ADMIN | `admin@level30.app` | `admin1234` |
| USER | `ana@level30.app` / `bruno@level30.app` / `carla@level30.app` | `estudante1` |

Desligar seed: `SEED_ENABLED=false`.

## Testes

```bash
mvn test
```

- `RiskEngineTest` — porte de `test/risk_engine_test.dart` (contrato do motor de risco)
- `ChallengeServiceTest` — dia duplicado → 409, reset de streak, xpDelta atômico, ownership → 404
- `AuthFlowTest` — signup/login/`/me`, 409 duplicado, 401 sem token, 403 USER em `/admin/**`

## Configuração (variáveis de ambiente)

| Var | Default | Uso |
|---|---|---|
| `JWT_SECRET` | dev inseguro | **obrigatório em produção** — `openssl rand -hex 32` |
| `DB_URL` / `DB_USER` / `DB_PASSWORD` | H2 local | banco |
| `CORS_ORIGINS` | `http://localhost:4200` | origem(ns) do Angular, separadas por vírgula |
| `AI_WORKER_URL` | vazio | URL do Cloudflare Worker (gateway de IA). Vazio = modo fallback |
| `AI_SERVICE_TOKEN` | vazio | `X-Service-Token` compartilhado com o Worker |
| `SEED_ENABLED` | `true` | popular dados de demonstração |

## Produção (PostgreSQL)

```bash
mvn -Dspring-boot.run.profiles=postgres spring-boot:run
# ou: java -jar target/level30-api-1.0.0.jar --spring.profiles.active=postgres
```

## Gateway de IA

`AiGatewayService` chama o Worker em `POST {AI_WORKER_URL}/internal/recommendation` e
`/internal/chat` com header `X-Service-Token` (rotas em `../server/src/routes/internal.ts`).
Para ligar de ponta a ponta:

```bash
export AI_WORKER_URL=https://level30-api.mateus-borba.workers.dev
export AI_SERVICE_TOKEN=<mesmo valor do `wrangler secret put SERVICE_TOKEN`>
```

Sem `AI_WORKER_URL`, a API opera em **modo fallback**: recomendação usa a mensagem
determinística do `RiskEngine` (`aiGenerated: false`); chat responde `502`.

## Estrutura

```
domain/model      entidades + enums (Category, RiskLevel, SuggestedAction, Role)
domain/engine     RiskEngine  ← espelho de risk.ts / risk_engine.dart
domain/Leveling   nível/rank  ← espelho de UserProfile / chat.ts
repository         Spring Data JPA
dto/request,resp   contrato de entrada/saída (records)
service           AuthService, ChallengeService, UserService, ChatService, AiGatewayService, AdminService
controller        Auth, User, Challenge, Chat, Admin, Root
security          JwtService, JwtAuthFilter, AuthPrincipal, RestAuthErrorHandlers
config           SecurityConfig, OpenApiConfig, EnumConverters, DataSeeder
exception        GlobalExceptionHandler + exceções de domínio
```
