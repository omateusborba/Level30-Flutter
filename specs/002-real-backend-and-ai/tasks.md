# Tasks — Backend real (auth, banco, IA)

## Backend (`server/`)
- [x] `server/package.json`, `tsconfig.json`, `wrangler.jsonc`
- [x] `server/migrations/0001_init.sql`
- [x] `server/src/auth.ts` — hash/verify senha, sign/verify JWT, middleware
- [x] `server/src/risk.ts` — score determinístico (espelha RiskEngine Dart)
- [x] `server/src/ai.ts` — prompt + `env.AI.run` + fallback
- [x] `server/src/routes/auth.ts` — signup, login
- [x] `server/src/routes/me.ts`
- [x] `server/src/routes/challenges.ts` — CRUD + complete + recommendation
- [x] `server/src/index.ts` — monta Hono app, CORS, rotas
- [x] `npm install` em `server/`

## Setup Cloudflare (interativo)
- [x] `wrangler login`
- [x] `wrangler d1 create level30-db` → preencher `database_id`
- [x] `wrangler d1 migrations apply level30-db --remote`
- [x] `wrangler secret put JWT_SECRET`
- [x] `wrangler dev --remote` (smoke test local)
- [x] `wrangler deploy` → anotar URL

## Flutter
- [x] `pubspec.yaml` — `flutter_secure_storage`
- [x] `lib/core/constants/app_config.dart` — `apiBaseUrl`
- [x] `lib/data/service/api_client.dart`
- [x] `lib/domain/provider/user_provider.dart` — sessão real
- [x] `lib/domain/provider/challenge_provider.dart` — API-backed, sem seed
- [x] `lib/presentation/screens/login_screen.dart` — cadastro/login reais
- [x] `lib/presentation/screens/splash_screen.dart` — restaurar sessão
- [x] `lib/presentation/screens/challenge_detail_screen.dart` — recomendação IA real
- [x] `lib/presentation/screens/home_screen.dart` — estado vazio + tour condicional
- [x] `lib/main.dart` — ajustar init dos providers

## Verificação final
- [x] curl contra o Worker deployado (todos os endpoints)
- [x] `flutter analyze`
- [x] `flutter test`
- [x] App buildado e rodando no simulador iOS, conectado à API real, boot até a tela de login sem erros (`flutter analyze`/`test` limpos)
- [ ] Roteiro manual completo tocando na tela (signup → criar → completar → IA → logout) — automação de tap não disponível neste ambiente (sem idb/permissão de acessibilidade); app deixado rodando no simulador para você testar diretamente
