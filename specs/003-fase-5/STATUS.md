# Fase 5 — Status de execução

> Atualizado em 2026-08-29. Referência: [`backlog-po.md`](backlog-po.md) · [`contract.md`](contract.md).
> Legenda: ✅ feito e verificado · 🟡 parcial · ⬜ não iniciado.

## Resumo

| Épico | Estado | Verificação |
|---|---|---|
| **E1 — API Spring Boot** (`backend/`) | ✅ | `mvn test` 20/20 · jar sobe em :8080 · 27 checks curl E2E |
| **E2 — Dashboard Angular** (`dashboard/`) | ✅ | `ng build` limpo · `ng serve` :4200 OK · checklist 3.3 9/9 · CORS + RBAC validados |
| **E3 — Maturidade Flutter** (`lib/`, `test/`) | ✅ | `flutter analyze` sem warning novo · `flutter test` 17/17 · **integração da camada de dados contra o backend real: 3/3** (`test/integration/backend_smoke_test.dart`) |
| **E4 — Entregáveis acadêmicos** | ⬜ | PDF, slides, vídeo — pendentes (dependem da equipe) |

## E1 — API Spring Boot

| Story | Estado | Nota |
|---|---|---|
| US-001 scaffold + PostgreSQL/Flyway + entidades | ✅ | Boot 3.5 / Java 21 · migrations agnósticas (H2 dev/test, Postgres prod via profile `postgres`) |
| US-002 `RiskEngine.java` + testes portados | ✅ | `RiskEngineTest` = 7 casos do Dart + 3 fronteiras (0.25/0.50/0.75) |
| US-003 auth JWT + BCrypt + roles | ✅ | HS256 forçado · decisão registrada: base nova + seed, sem migrar PBKDF2 |
| US-004 refresh token | ✅ | `POST /auth/refresh` · access 1 h / refresh 30 d |
| US-005 CRUD + ownership | ✅ | `findByIdAndUserId` → 404 (não 403) |
| US-006 dia duplicado → 409 | ✅ | fuso `America/Sao_Paulo` · `ChallengeServiceTest` |
| US-007 reset de streak | ✅ | ontem → +1 · ≥ 2 dias / nunca → 1 |
| US-008 XP atômico | ✅ | `@Transactional` · `earnedXp` divisão inteira |
| US-009 recomendação IA + fallback | ✅ | `AiGatewayService` · fallback determinístico do `RiskEngine` |
| US-010 chat via gateway | ✅ | 502 quando gateway fora (sem fallback textual, conforme spec) |
| US-011 endpoints admin | ✅ | `/admin/usuarios`, `/admin/desafios` (filtro risco/categoria), `/admin/indicadores` |
| US-012 Swagger | ✅ | `/swagger-ui.html` com Bearer |
| US-013 GlobalExceptionHandler | ✅ | contrato `{status, error, mensagem, detalhes[], timestamp}` (alias `error` p/ o Flutter) |
| US-014 CORS restrito + segredo por env | ✅ | `CORS_ORIGINS` · `JWT_SECRET` só por env |
| US-015 Worker como AI gateway | ✅ | `server/src/routes/internal.ts` — `/internal/recommendation` e `/internal/chat` com `X-Service-Token` |
| US-016 seed de demonstração | ✅ | 1 admin + 3 estudantes + 7 desafios (cenários de risco variados) |

**Pendências E1**
- `AiGatewayService` só foi exercitado em modo fallback (sem `AI_WORKER_URL`). Falta 1 teste E2E com o Worker real e o deploy do Worker com `SERVICE_TOKEN`.
- `application-postgres.yml` existe mas não foi testado contra um Postgres real (ambiente sem Docker/psql).

## E2 — Dashboard Angular

| Story | Estado | Nota |
|---|---|---|
| US-020 scaffold + interceptor + guard + services | ✅ | Angular 18 standalone · `authInterceptor` · `adminGuard` |
| US-021 `/login` | ✅ | form `[(ngModel)]` · `(ngSubmit)` · erro com `*ngIf` |
| US-022 `/home` indicadores | ✅ | 6 KPIs + barras CSS por categoria e por risco · semáforo de cores |
| US-023 `/admin` tabela + filtros | ✅ | `*ngFor` · filtros category/riskLevel · badge de risco com binding dinâmico |
| US-024 form de criação de desafio | ✅ | 5 campos `[(ngModel)]` → `POST /challenges` |
| US-025 exclusão com confirmação | ✅ | `window.confirm` → `DELETE /challenges/{id}` |
| US-026 tabela de usuários | ✅ | XP, nível, rank, nº de desafios |
| US-027 identidade visual | ✅ | paleta + Poppins |
| US-028 rastreabilidade do checklist | ✅ | `dashboard/CHECKLIST.md` — 9/9 itens com arquivo:linha |

**Pendências E2**
- Interceptor faz 401 → logout (não usa o `refreshToken`, embora ele seja guardado). Alinhado ao que foi pedido; o retry via `/auth/refresh` fica como melhoria.
- Sem controles de paginação (carrega uma página do tamanho do seed).
- Sem `.spec.ts` (scaffold com `--skip-tests`).

## E3 — Maturidade Flutter

| Story | Estado | Nota |
|---|---|---|
| US-030 camada de repositório | ✅ | `lib/data/repository/` — `ChallengeRepository`/`UserRepository` (abstrato + Impl); providers recebem por construtor |
| US-031 nenhuma tela chama `ApiClient` | ✅ | `_RecommendationCard` → `ChallengeProvider.getRecommendation` · `grep ApiClient lib/presentation/` vazio |
| US-032 cache offline | ✅ | `SharedPrefsChallengeCache` · `isStale` · banner na Home · 7 testes de provider |
| US-033 refresh token no cliente | ✅ | `ApiClient` 401 → `/auth/refresh` 1× → repete requisição · `refreshToken` em secure storage |
| US-034 tratar 409 + streak não-monotônico | ✅ | SnackBar dedicado no 409 · auditado: nada na UI assume streak crescente |
| US-035 extrair `AppBottomNav` + `Challenge.toJson()` | ✅ | widget único · `toJson` usado no cache e na criação |
| US-036 config + testes | ✅ | `app_config` inalterado (override `--dart-define` ok) · fronteiras no `risk_engine_test` · `challenge_provider_test` novo |

**Pendências E3**
- `ChatProvider` ainda chama `ApiClient.instance` direto (dentro da regra "provider fala com API"; fora do escopo de US-030). Criar `ChatRepository` se quiser simetria total.
- Não foi rodado contra o backend real num emulador/dispositivo — verificação foi analyze + test + conferência de contrato.

## E4 — Entregáveis acadêmicos (pendente — equipe)

| Story | Estado |
|---|---|
| US-040 documentação PDF (justificativa da stack, roadmap, backend, dashboard) | ⬜ |
| US-041 slides PDF (≤ 10, nome/RM/foto) | ⬜ |
| US-042 vídeo YouTube não listado (≤ 5 min) | ⬜ |
| US-043 repositório GitHub com acesso liberado | ⬜ |

## Como rodar tudo junto (demo)

```bash
# 1. Backend  (Java 21)
cd backend && JAVA_HOME=/opt/homebrew/opt/openjdk@21 mvn spring-boot:run   # :8080  + Swagger em /swagger-ui.html

# 2. Dashboard (Node)
cd dashboard && npm install && npm start                                  # :4200  — login admin@level30.app / admin1234

# 3. App Flutter apontando para o backend local
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Seed: `admin@level30.app` / `admin1234` (ADMIN) · `ana@level30.app` etc. / `estudante1` (USER).
Admin do seed é configurável por env: `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD`.

## Deploy — Opção C — ✅ NO AR (2026-08-30)

| Componente | URL | Host |
|---|---|---|
| API Spring Boot | `https://api.level30.online` | VM Oracle `163.176.184.11` (E2.1.Micro 1 GB + 4 GB swap) via Cloudflare Tunnel `level30` |
| Dashboard Angular | `https://level30.online` | Cloudflare Pages (`level30-flutter`, branch `main`, root `dashboard`) |
| Worker de IA | `https://level30-ai-gateway.mateusborbasouza.workers.dev` | Cloudflare Workers (conta `mateusborbasouza@gmail.com`) |

Verificado ponta a ponta: login admin, `/admin/**`, CORS `https://level30.online`, chat + recomendação
com `aiGenerated: true` (Spring → Worker → Workers AI), RBAC, e teste de integração Flutter contra o
backend real (3/3). App (`lib/core/constants/app_config.dart`) já aponta para `https://api.level30.online`.

Operação da VM: `ssh ubuntu@163.176.184.11` · `cd ~/Level30-Flutter/deploy` · `sudo docker compose {ps,logs,restart}`.
Atualizar: `git pull && sudo docker compose up -d --build` (jar é buildado no Mac e copiado — VM de 1 GB não roda Maven).

---

## (histórico) Deploy — Opção C — preparação

Guia completo: [`deploy-oracle.md`](deploy-oracle.md).

```
Cloudflare Pages ── dashboard  │  Cloudflare Worker ── IA  │  Cloudflare Tunnel ── api.dominio
                                                                       │
                                            VM Oracle Cloud Always Free (ARM)
                                             docker compose: postgres + api(jar) + cloudflared
```

Artefatos prontos e verificados localmente:

| Arquivo | Estado |
|---|---|
| `backend/Dockerfile` (multi-stage, jar portável ARM/x86) | ✅ escrito |
| `backend/src/main/resources/application-prod.yml` (profile `prod`) | ✅ boota (validado com H2) |
| `backend/.dockerignore` | ✅ |
| `deploy/docker-compose.yml` (postgres + api + cloudflared) | ✅ |
| `deploy/.env.example` | ✅ |
| `dashboard/src/environments/environment.prod.ts` + `fileReplacements` no `angular.json` | ✅ `ng build --configuration production` gera `dist/dashboard/browser` com a URL prod |
| `DataSeeder` admin via `SEED_ADMIN_EMAIL`/`SEED_ADMIN_PASSWORD` | ✅ testado |
| `SecurityConfig` libera `/actuator/health/**` | ✅ |

**Pendente (execução pelo aluno):** criar a conta/VM Oracle, pegar domínio (GitHub Student Pack),
criar o Cloudflare Tunnel, `docker compose up -d --build`, conectar o Pages ao repo.
`mvn test` continua **20/20** após as mudanças de deploy.
