# Level30 — Smart HAS · Documentação Técnica do Projeto

> Guia de ponta a ponta para quem vai desenvolver, manter ou revisar este projeto.
> Última revisão: 2026-08-29.

---

## 1. Visão geral

**Level30** é um app de gamificação de hábitos acadêmicos em formato RPG. O usuário
cria "desafios de 30 dias" (na verdade 7 a 90 dias), marca cada dia concluído,
acumula XP, sobe de nível, mantém *streaks* e recebe alertas quando um desafio
está em risco de abandono.

O sistema é chamado de **Smart HAS** (*Smart Habit Acceleration System*) e tem quatro
pilares:

| Pilar | O que é | Onde vive |
|---|---|---|
| **Motor de risco** | Fórmula determinística (0.0–1.0) baseada em inatividade, progresso e streak | `lib/domain/engine/risk_engine.dart` **e** `server/src/risk.ts` (espelhados) |
| **Backend real** | Auth por e-mail/senha, persistência de usuários e desafios | Cloudflare Worker + D1 (`server/`) |
| **Assistente de IA** | Chat "Guia do Level30" + recomendação por desafio | Cloudflare Workers AI (Llama 3.1 8B) via `server/src/ai.ts` e `routes/chat.ts` |
| **Notificações inteligentes** | Lembrete diário agendado + alertas disparados por risco | `flutter_local_notifications`, local no dispositivo |

Contexto: **Enterprise Challenge 2026 — Fase 4 (FIAP)**, avaliado pela Leroy Merlin.
Multiplataforma **Android (5.0+) e iOS (13.0+)**.

---

## 2. Stack e dependências

### App (Flutter)

- **Flutter stable**, Dart SDK `>=3.3.0 <4.0.0`
- Gerência de estado: **`provider`** (`ChangeNotifier`)
- HTTP: **`http`** (cliente próprio fino em `api_client.dart`)
- Armazenamento:
  - **`flutter_secure_storage`** — token JWT (Keychain / Keystore)
  - **`shared_preferences`** — preferências de notificação + flag de onboarding
- Mapa: **`flutter_map`** + `latlong2` + tiles CartoDB dark (OpenStreetMap)
- Localização: **`geolocator`** + `permission_handler`
- Notificações: **`flutter_local_notifications`** + `timezone`
- UI: **`google_fonts`** (Poppins), `flutter_animate`, `fl_chart`, `showcaseview`
  (tour), `cached_network_image`, `image_picker`
- Utilidades: `uuid`, `intl`

### Backend (`server/`)

- **Cloudflare Workers** com **Hono 4** (router HTTP)
- **D1** — SQLite gerenciado (tabelas `users`, `challenges`)
- **Workers AI** — modelo `@cf/meta/llama-3.1-8b-instruct-fast`
- Auth: **PBKDF2-SHA256** (100k iterações) para senha + **JWT HS256**, tudo com
  Web Crypto puro (sem libs)
- TypeScript 5.7, Wrangler 4

Tudo cabe no *free tier* da Cloudflare.

---

## 3. Arquitetura

### 3.1 Camadas do app

O código em `lib/` segue uma separação inspirada em Clean Architecture:

```
lib/
├── main.dart                  # bootstrap: providers + MaterialApp + rotas
├── core/
│   ├── constants/             # app_colors, app_theme, app_config (env)
│   └── extensions/            # ContextX (theme/snackbar), StringX (initials)
├── data/
│   ├── model/                 # Challenge, UserProfile, ChatMessage, RiskAssessment
│   └── service/               # ApiClient, NotificationService, Quote/Weather/Onboarding
├── domain/
│   ├── engine/                # RiskEngine (regra de negócio pura)
│   └── provider/              # ChallengeProvider, UserProvider, ChatProvider, NotificationProvider
└── presentation/
    ├── screens/               # 9 telas
    └── widgets/               # componentes reutilizáveis
```

Regra prática de dependência: `presentation` → `domain` → `data` → `core`.
Os *providers* são o único ponto que fala com `ApiClient`; as telas nunca chamam
a API diretamente (exceto dois casos pontuais de leitura — `_RecommendationCard`
em `challenge_detail_screen.dart`).

### 3.2 Fluxo de dados típico (completar um dia)

```
ChallengeDetailScreen (onPressed)
  → context.read<ChallengeProvider>().completeDay(id)
      → ApiClient.instance.post('/challenges/:id/complete')
          → Worker: valida dono, calcula xpDelta, DB.batch(update challenge, update user xp)
          ← { challenge, xpDelta, totalXp }
      → substitui challenge na lista local, notifyListeners()
  ← retorna (xpDelta, totalXp)
  → context.read<UserProvider>().syncTotalXp(totalXp)   # sincroniza XP sem refetch de /me
  → se dia ∈ {7,14,21,30}: NotificationProvider.checkAndNotify(...)  # notificação de marco
  → SnackBar de confirmação
```

### 3.3 O motor de risco (espelhado nos dois lados)

`RiskEngine` (Dart) e `risk.ts` (TS) **têm de permanecer idênticos** — mesmos pesos e
thresholds. Se alterar um, altere o outro.

`score = fator_inatividade + fator_progresso + fator_streak`, com `clamp(0, 1)`:

| Fator | Peso | Regra |
|---|---|---|
| Dias sem atividade | até 0.40 | 0 dias→0.0 · 1→0.1 · 2→0.25 · 3+→0.4 |
| Progresso vs. esperado | até 0.30 | `(1 - currentDay/totalDays) * 0.3` |
| Streak | até 0.30 | streak 0→0.3 · senão `max(0, 0.3 - streak*0.03)` |

`daysSinceLastActivity`: se `lastActivityAt == null`, retorna `2` quando `streak == 0`,
senão `0` (heurística para desafios recém-criados).

Níveis: `<0.25 low` · `<0.50 medium` · `<0.75 high` · `>=0.75 critical`.

Ações sugeridas (`_determineAction`): se `currentDay ∈ {7,14,21,30}` →
`celebrateMilestone`; senão mapeia nível → `none / sendReminder / sendMotivation /
suggestReplan`.

**Por que existe nos dois lados:** o app calcula o risco localmente para o *badge*
de cada card (resposta instantânea, sem gastar chamada de IA). O servidor recalcula
para alimentar o prompt da recomendação de IA — assim o texto gerado combina com o
risco mostrado.

---

## 4. Modelo de dados

### 4.1 Banco (D1 / SQLite) — `server/migrations/`

**`users`**

| Coluna | Tipo | Notas |
|---|---|---|
| `id` | TEXT PK | `crypto.randomUUID()` |
| `email` | TEXT UNIQUE | sempre `trim().toLowerCase()` |
| `password_hash` | TEXT | PBKDF2-SHA256, hex |
| `password_salt` | TEXT | 16 bytes aleatórios, hex |
| `name` | TEXT | |
| `total_xp` | INTEGER | default 0 |
| `avatar` | TEXT nullable | data URI `data:image/...;base64,...` (migração 0002) |
| `created_at` | TEXT | `datetime('now')` |

**`challenges`**

| Coluna | Tipo | Notas |
|---|---|---|
| `id` | TEXT PK | UUID |
| `user_id` | TEXT FK → users(id) | `ON DELETE CASCADE` |
| `title` | TEXT | mín. 3 caracteres |
| `category` | TEXT | um de: `health, study, productivity, mindfulness, fitness` |
| `description` | TEXT | obrigatória |
| `total_days` | INTEGER | 7–90 |
| `current_day` | INTEGER | default 0 |
| `xp_reward` | INTEGER | 100–1000 |
| `streak` | INTEGER | default 0 |
| `last_activity_at` | TEXT nullable | ISO 8601 |
| `created_at` | TEXT | `datetime('now')` |

Índice: `idx_challenges_user (user_id)`.

### 4.2 Modelos Dart (`lib/data/model/`)

- **`Challenge`** — imutável. Getters derivados: `progress`, `isCompleted`,
  `earnedXp = (currentDay/totalDays)*xpReward` truncado. `fromJson` só (não há
  `toJson`; o POST monta o mapa manualmente no provider).
- **`UserProfile`** — `level = totalXp ~/ 500 + 1`, `xpProgress`, `xpToNextLevel`,
  `rankTitle` (Iniciante → Lendário). Tem `copyWith`.
- **`ChatMessage`** — `role` (user/assistant), `content`, `sentAt`, `isError`.
- **`RiskAssessment`** — saída do `RiskEngine`: `riskScore`, `riskLevel`,
  `suggestedAction`, `calculatedAt`.

> **Contrato JSON:** o backend converte `snake_case` → `camelCase` em
> `toChallengeJson()` (`server/src/types.ts`). Esse shape **tem de bater** com
> `Challenge.fromJson` no Dart. Mesma regra para `earnedXp` (duplicada em
> `types.ts` e no getter Dart) e para o nível/rank (duplicado em `chat.ts`).

---

## 5. API HTTP

Base URL de produção: `https://level30-api.mateus-borba.workers.dev`
(sobrescrevível com `--dart-define=API_BASE_URL=...`, ver `app_config.dart`).

Auth: header `Authorization: Bearer <jwt>`. Token válido por **30 dias**, sem
refresh. Resposta **401** em qualquer rota → o `ApiClient` chama `onUnauthorized`,
que o `UserProvider` liga a um logout automático (limpa token + perfil).

| Método | Rota | Auth | Corpo / Params | Resposta |
|---|---|---|---|---|
| `GET` | `/` | não | — | `{ name, status }` (health check) |
| `POST` | `/auth/signup` | não | `{ name, email, password }` (senha ≥ 8) | `201 { token, user }` |
| `POST` | `/auth/login` | não | `{ email, password }` | `{ token, user }` |
| `GET` | `/me` | sim | — | `{ id, name, email, totalXp, avatar }` |
| `PUT` | `/me/avatar` | sim | `{ avatar: "data:image/..." }` (≤ 400 KB) | `{ avatar }` |
| `GET` | `/challenges` | sim | — | `ChallengeJson[]` (mais recentes primeiro) |
| `POST` | `/challenges` | sim | `{ title, category, description, totalDays, xpReward }` | `201 ChallengeJson` |
| `POST` | `/challenges/:id/complete` | sim | — | `{ challenge, xpDelta, totalXp }` |
| `DELETE` | `/challenges/:id` | sim | — | `204` |
| `GET` | `/challenges/:id/recommendation` | sim | — | `{ message, riskScore, riskLevel, aiGenerated }` |
| `POST` | `/chat` | sim | `{ message (≤1000), history: [{role,content}] (últimos 10) }` | `{ message }` ou `502 { error }` |

Erros: sempre `{ error: string }` com status HTTP adequado (400/401/404/409/502).
O `ApiClient._handle` extrai `body.error` e lança `ApiException(message, statusCode)`.

### Detalhes de implementação relevantes

- **`/challenges/:id/complete`** não checa se o dia de hoje já foi concluído — essa
  trava é **só no cliente** (`_completedToday` em `challenge_detail_screen.dart`,
  compara `lastActivityAt` com a data atual). O servidor só bloqueia quando
  `current_day >= total_days`. `streak` é sempre incrementado (`streak + 1`), nunca
  reiniciado pelo backend.
- **XP** é recalculado do zero a cada `complete`: `xpDelta = earnedXp(nextDay) -
  earnedXp(currentDay)`, e some ao `users.total_xp` num `DB.batch` (atômico).
- **Chat** monta um `systemPrompt` grande com os dados reais do jogador (nível, XP,
  lista de desafios com % e streak) para respostas contextualizadas. Persona: "Guia
  do Level30", tom de mestre de RPG, emojis liberados, `**negrito**` e listas `- `.
- **IA com fallback:** se `env.AI.run` falhar ou vier vazio, `buildRecommendation`
  devolve `aiGenerated: false` + mensagem padrão do `risk.ts`. O chat, por outro
  lado, retorna `502` (não tem fallback textual).

---

## 6. Telas (`lib/presentation/screens/`)

| Tela | Rota | Papel |
|---|---|---|
| `SplashScreen` | `/splash` (inicial) | Restaura sessão (`UserProvider.restoreSession`), delay mínimo 2.5 s, redireciona para `/home` ou `/login`. Se autenticado, já faz `ChallengeProvider.refresh()`. |
| `LoginScreen` | `/login` | Alterna login/cadastro no mesmo formulário (`_Mode`). Valida e-mail por regex e senha (≥ 8 no signup). Em sucesso → `refresh()` + `/home`. |
| `HomeScreen` | `/home` | Dashboard: saudação, card de clima (Open-Meteo), card motivacional (ZenQuotes + ação de risco), stats rápidos, filtro por categoria, lista de desafios com *swipe-to-delete* (`Dismissible`), FAB "Novo desafio", bottom nav. Envolvida por `ShowCaseWidget` para o tour. |
| `CreateChallengeScreen` | `/create_challenge` | Formulário: título, categoria (chips), descrição, sliders de duração (7–90) e XP (100–1000), card de pré-visualização ao vivo. |
| `ChallengeDetailScreen` | `/challenge` (via `onGenerateRoute`, `arguments: id`) | Anel de progresso, tiles (streak/XP/recompensa), descrição, `_RecommendationCard` (IA), grade de 30 dias, botão "Completar dia de hoje", excluir. |
| `MapScreen` | `/map` | `flutter_map` com tiles dark. Marca a posição do usuário (ou São Paulo como fallback) e espalha os desafios ao redor com um offset **ilustrativo** (`_offset(i)`, determinístico). Círculo vermelho em desafios com risco > 0.7. Bottom sheet ao tocar num marcador. |
| `NotificationsScreen` | `/notifications` | Liga/desliga notificações, escolhe horário do lembrete diário, botão de teste, botão "notificar desafios em risco", e lista o status de risco de cada desafio. Mostra aviso se a permissão do SO estiver negada. |
| `ProfileScreen` | `/profile` | Avatar (câmera/galeria → base64 → `PUT /me/avatar`), anel de XP, grid de stats, marcos atingidos, "rever tour", logout. |
| `ChatScreen` | `/chat` | Chat com o Guia do Level30. Bolhas com markdown simplificado (`_FormattedMessage` faz `**negrito**` e listas manualmente), *quick replies*, indicador de digitação. |

Navegação: `MaterialApp.routes` para a maioria; `onGenerateRoute` só para
`/challenge` (que precisa de argumento). Bottom nav é reimplementado em cada tela
que o usa (`_BottomNav` em `home_screen.dart` e `profile_screen.dart`).

---

## 7. Providers (estado global)

Registrados em `main.dart` via `MultiProvider`.

### `UserProvider`
- Estado: `_profile` (`UserProfile`), `_token`, `_restoring`.
- `restoreSession()` — lê token do secure storage, valida com `GET /me`; se falhar,
  limpa a sessão.
- `signUp` / `logIn` — POST e `_applyAuthResponse` (guarda token, seta em
  `ApiClient.instance.token`, persiste).
- `syncTotalXp(int)` — atualiza só o XP local após um `complete` (evita refetch).
- `updateAvatar(dataUri)` — `PUT /me/avatar`.
- `_handleUnauthorized` — ligado a `ApiClient.onUnauthorized` no construtor.

### `ChallengeProvider`
- Estado: `_challenges`, `_selectedCategory` (filtro), `_isLoading`.
- `challenges` (getter) já aplica o filtro de categoria; `allChallenges` não.
- Derivados: `completedCount`, `activeCount`, `bestStreak`, `hasAnyChallenge`.
- `refresh()` — `GET /challenges`; em erro **zera a lista** (não mantém stale).
- `addChallenge`, `completeDay` (retorna record `(xpDelta, totalXp)`),
  `deleteChallenge`.
- `getRisk(id)` / `getAllRisks()` / `getHighestRisk()` — usam o `RiskEngine` local.

### `ChatProvider`
- `_messages` — começa com uma mensagem de boas-vindas do assistente.
- `quickReplies` — lista estática de 4 sugestões.
- `sendMessage(text)` — monta `history` (exclui mensagens de erro), faz `POST /chat`,
  trata `ApiException` e erro genérico com bolhas `isError`.

### `NotificationProvider`
- É um `WidgetsBindingObserver` — em `resumed` recheca a permissão do SO (caso o
  usuário tenha ativado nas Configurações e voltado).
- Persiste `enabled`, `hour`, `minute` em `SharedPreferences`.
- `init()` (chamado com `..init()` no `main.dart`) — carrega prefs, checa permissão,
  agenda o lembrete diário se habilitado.
- `checkAndNotify({challenges, risks})` — delega ao `NotificationService`, guarda
  `_lastSentCount`.

---

## 8. Serviços (`lib/data/service/`)

- **`ApiClient`** (singleton `ApiClient.instance`) — wrapper de `http` com
  `get/post/put/delete`, timeout de 15 s, headers com Bearer, tratamento centralizado
  em `_handle` (401 → `onUnauthorized` + `ApiException`; 2xx → body decodificado;
  senão → `ApiException`). **Desacoplado do Provider de propósito** (via callback).
- **`NotificationService`** (singleton) — inicializa canal Android + permissões iOS.
  IDs de notificação fixos por tipo (`_idDailyReminder=1`, `_idRiskBase=100`,
  `_idMilestoneBase=200`, `_idTest=999`). `scheduleDailyReminder` usa `zonedSchedule`
  com timezone `America/Sao_Paulo` (fallback UTC). `checkAndNotify` percorre desafios
  × riscos e dispara a notificação conforme `suggestedAction`.
  - iOS: `defaultPresentAlert/Badge/Sound = true` é essencial — sem isso a
    notificação não aparece com o app em primeiro plano.
- **`QuoteService`** — `GET https://zenquotes.io/api/random`, timeout 4 s, 5 frases de
  fallback locais escolhidas por `DateTime.now().second % 5`.
- **`WeatherService`** — `GET https://api.open-meteo.com/v1/forecast`, timeout 5 s.
  Converte `weathercode` em emoji/descrição e sugere uma categoria de desafio.
- **`OnboardingService`** — flag `has_seen_tour` em `SharedPreferences`
  (`isFirstTime`, `markAsSeen`, `reset`).

---

## 9. Tema e identidade visual

`lib/core/constants/app_colors.dart` + `app_theme.dart`.

- **Sempre dark** — decisão de identidade, não há tema claro. Fundo `#080A17`,
  surface `#111328`, acento `#00FF9C` (verde neon).
- Fonte: **Poppins** via `google_fonts`.
- **Semáforo de risco** (`riskLow/Medium/High/Critical` = verde/amarelo/laranja/
  vermelho) é reservado para risco. As **categorias** usam de propósito uma paleta
  fora dessa faixa (ciano/azul/roxo/magenta) — ver comentário em `challenge.dart`.
- Material 3 ativo (`useMaterial3: true`).

---

## 10. Onboarding / Tour

`showcaseview` + `lib/presentation/widgets/onboarding_tour.dart`.

- `OnboardingTourKeys` — 6 `GlobalKey`s (xpBar, motivCard, categoryRow,
  challengeCard, fabButton, bottomNav).
- `HomeScreen` é montada dentro de um `ShowCaseWidget` (em `main.dart`), e o `onFinish`
  chama `OnboardingService.markAsSeen()`.
- `startTourIfNeeded` roda em `postFrameCallback` no `initState` da Home; pula o passo
  do card de desafio se o usuário ainda não tem nenhum.
- `TourStep` envolve cada widget alvo com um `Showcase` estilizado.

---

## 11. Como rodar

### App

```bash
flutter pub get
flutter run                          # usa a API de produção por padrão
flutter run --dart-define=API_BASE_URL=http://localhost:8787   # contra backend local
flutter test                         # roda test/risk_engine_test.dart
flutter analyze
```

Ícones: `flutter pub run flutter_launcher_icons` (config no `pubspec.yaml`).

### Backend

```bash
cd server
npm install
npm run typecheck                    # tsc --noEmit
npm run dev                          # wrangler dev --remote  (IA só funciona em --remote)
npm run deploy                       # wrangler deploy
npx wrangler tail --format pretty    # logs em produção
```

Primeira configuração:

```bash
npx wrangler d1 create level30-db                        # copiar database_id → wrangler.jsonc
npx wrangler d1 migrations apply level30-db --remote
npx wrangler secret put JWT_SECRET                       # openssl rand -hex 32
```

---

## 12. Configuração de plataforma

| Item | Android | iOS |
|---|---|---|
| Bundle ID | `com.level30.level30flutter` | `com.level30.level30flutter` |
| SDK mínimo | `flutter.minSdkVersion` (21) | 13.0 |
| Target | 34 | — |
| Permissões | notificações (runtime), localização | `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` (ver `Info.plist`) |

Flutter revision fixado no `.metadata`: `00b0c91f...` (canal stable).

---

## 13. Testes

- **`test/risk_engine_test.dart`** — cobre o `RiskEngine`: streak zero → risco ≥
  médio, streak ativo + bom progresso → baixo, marcos (dias 7 e 14) →
  `celebrateMilestone`, score sempre em [0,1], desafio abandonado → crítico.
- **`test/widget_test.dart`** — vazio de propósito (só um `main()` com comentário).
- Backend: sem testes automatizados; validação por `tsc --noEmit` e `wrangler tail`.

`mockito` e `build_runner` estão nas dev deps mas ainda não há mocks gerados.

---

## 14. Especificações

Há specs versionadas em `specs/` (formato requirements / design / tasks):

- **`specs/001-prototype-readiness/`** — protótipo (Fase inicial, dados locais).
- **`specs/002-real-backend-and-ai/`** — introdução do backend real + IA (estado atual).

O diretório `agents/` na raiz é um **repositório git separado** (submódulo não
registrado) com material de apoio de outro contexto (agentes YSec) — **não faz parte
do build do Level30** e pode ser ignorado.

---

## 15. Pontos de atenção para quem for mexer

1. **Espelhamento risco:** `risk_engine.dart` ⇄ `risk.ts` precisam ficar iguais.
   Mesma coisa para `earnedXp` e a fórmula de nível/rank (duplicada em `chat.ts`).
2. **Contrato JSON:** mudou `Challenge`/`UserProfile` no Dart? Ajuste
   `toChallengeJson`/`publicUser` no servidor e vice-versa.
3. **Trava "dia já concluído hoje"** existe só no cliente — um cliente malicioso
   pode completar vários dias seguidos. Se isso importar, mover a checagem de data
   para `challenges.post('/:id/complete')`.
4. **`ChallengeProvider.refresh()` zera a lista em erro de rede** — offline = tela
   vazia, não dados em cache. Decisão intencional ("honestidade"), mas é uma UX a
   revisitar.
5. **CORS aberto (`origin: '*'`)** no Worker — ok para projeto acadêmico, revisar
   antes de qualquer uso real.
6. **Avatar como data URI no banco** — cresce a linha de `users`; há limite de
   400 KB no `PUT /me/avatar`. Para escala, migrar para R2.
7. **Sem refresh token** — quando o JWT de 30 dias expira, o usuário simplesmente
   cai para a tela de login.
8. **Bottom navigation duplicado** entre Home e Profile — candidato a extração para
   um widget compartilhado.
9. **`_RecommendationCard` e outras telas chamam `ApiClient` direto** — quebra a
   regra "só provider fala com API"; considerar mover para um provider se crescer.
10. Modelo de IA (`@cf/meta/llama-3.1-8b-instruct-fast`) está *hardcoded* em
    `server/src/ai.ts` (`MODEL`). O sem-sufixo foi descontinuado em 2026-05-30.
