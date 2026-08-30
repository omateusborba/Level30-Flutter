<p align="center">
  <img src="assets/icon/app_icon.png" width="120" alt="Level30 Logo"/>
</p>

<h1 align="center">Level30 — Smart HAS</h1>

<p align="center">
  <strong>Smart Habit Acceleration System</strong><br/>
  Gamificação de hábitos acadêmicos com inteligência de risco, mapas e notificações inteligentes
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" />
  <img src="https://img.shields.io/badge/Dart-3.3+-0175C2?logo=dart" />
  <img src="https://img.shields.io/badge/Android-5.0+-3DDC84?logo=android" />
  <img src="https://img.shields.io/badge/iOS-13.0+-000000?logo=apple" />
  <img src="https://img.shields.io/badge/Backend-Spring%20Boot%203.5-6DB33F?logo=springboot" />
  <img src="https://img.shields.io/badge/Web-Angular%2018-DD0031?logo=angular" />
  <img src="https://img.shields.io/badge/AI-Llama%203.1%20(Workers%20AI)-005BBB" />
  <img src="https://img.shields.io/badge/FIAP-Enterprise%20Challenge%202026-ED1C24" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
</p>

---

## Sobre o Projeto

**Level30** transforma o desenvolvimento de hábitos acadêmicos em um jogo de RPG. O usuário cria desafios de 30 dias, acumula XP a cada dia completado, avança de nível e recebe alertas inteligentes quando uma sequência está em risco.

O sistema **Smart HAS** (Smart Habit Acceleration System) combina:
- **Motor de risco baseado em regras** — avalia cada desafio com score de 0,0 a 1,0 a partir de uma fórmula determinística (inatividade, progresso e streak) — ver nota abaixo
- **Backend real na nuvem** — API própria em **Java + Spring Boot** (auth JWT com refresh token, RBAC, persistência em banco relacional), documentada em **Swagger** (ver [Backend](#backend))
- **Assistente de IA (chat + recomendações)** — companheiro de jornada dentro do app, com respostas geradas por modelo de linguagem na Cloudflare Workers AI
- **Replanejamento assistido por IA** — quando um desafio entra em risco crítico, o app sugere um novo ritmo (até 2 replanejamentos por desafio)
- **Histórico e conquistas** — heatmap de atividade dos últimos 84 dias, tela de progresso e catálogo de 8 conquistas com celebração ao desbloquear
- **Desafios do programa** — a coordenação publica modelos de desafio no dashboard e o estudante os adota com um toque
- **Modo offline** — os desafios continuam visíveis sem rede, com aviso de "dados salvos localmente"
- **Notificações inteligentes** — alertas contextuais agendados por horário e disparados por nível de risco, em Android e iOS
- **Mapa de desafios** — mapa dark (CartoDB/OpenStreetMap) com os desafios ao redor da localização real do usuário
- **Tour de onboarding** — guia interativo de 6 passos para novos usuários
- **Foto de perfil** — captura por câmera ou galeria, com upload para o backend
- **Integração com APIs reais** — clima em tempo real (Open-Meteo) e citações motivacionais (ZenQuotes)

> Projeto desenvolvido para o **Enterprise Challenge 2026 (FIAP)**, avaliado pela **Leroy Merlin**. Multiplataforma: **Android e iOS**.

---

## Fase 5 — três aplicações, um contrato

A partir da Fase 5 (atividade "Mobile Hybrid App e a Sociedade 5.0"), o projeto é composto por
**três aplicações sobre a mesma API**:

| App | Pasta | Stack | Papel |
|---|---|---|---|
| **App mobile** | `lib/` | Flutter (`provider`) | experiência do estudante |
| **API / núcleo de domínio** | `backend/` | **Java + Spring Boot** | fonte única de verdade: auth, desafios, risco, admin |
| **Dashboard administrativo** | `dashboard/` | **Angular 18** | visão agregada do programa (coordenação) |
| Gateway de IA | `server/` | Cloudflare Worker | único caminho até o Workers AI; agora também proxy do Spring Boot |

O Spring Boot **replica exatamente** o contrato JSON que o Worker já produzia — o app Flutter roda
sem alterar `Challenge.fromJson` / `UserProfile.fromJson`. Contrato congelado em
[`specs/003-fase-5/contract.md`](specs/003-fase-5/contract.md). Planejamento e status em
[`specs/003-fase-5/`](specs/003-fase-5/) (`backlog-po.md`, `STATUS.md`).

### Ambiente em produção

| Componente | URL |
|---|---|
| **API — Swagger UI** | **[api.level30.online/swagger-ui.html](https://api.level30.online/swagger-ui.html)** |
| API — base | `https://api.level30.online` |
| Dashboard Angular | [level30.online](https://level30.online) |
| Gateway de IA (Worker) | `https://level30-ai-gateway.mateusborbasouza.workers.dev` |

O app Flutter (`lib/core/constants/app_config.dart`) já aponta para `https://api.level30.online` por padrão.

**Rodar tudo junto (local):**
```bash
cd backend && JAVA_HOME=$(/usr/libexec/java_home -v 21) mvn spring-boot:run   # API :8080 + Swagger em /swagger-ui.html
cd dashboard && npm install && npm start                                       # dashboard :4200
flutter run --dart-define=API_BASE_URL=http://localhost:8080                    # app apontando pro backend local
```
Seed (local): `admin@level30.app` / `admin1234` (ADMIN) · `ana@level30.app` / `estudante1` (USER).

---

## Funcionalidades

### Conta e Perfil
- Cadastro e login reais por **e-mail e senha** (senha com hash + salt, sessão via **JWT**)
- Sessão persistida no dispositivo com `flutter_secure_storage` — token não fica em texto puro
- Foto de perfil via câmera ou galeria (`image_picker`), enviada para o backend e exibida com `cached_network_image`
- Logout automático quando o token expira (interceptado nas chamadas à API)

### Assistente de IA
- **Chat** com o "Guia do Level30": tira dúvidas, dá dicas e conversa sobre o progresso do jogador, com respostas rápidas sugeridas
- **Recomendação diária por desafio**: dica curta gerada por IA para cada desafio, combinada com o risco de abandono calculado pelo RiskEngine
- Roda sobre **Cloudflare Workers AI** (modelo Llama 3.1 8B) — ver seção [Backend](#backend)
- Se a IA falhar, o app não quebra: cai em uma sugestão padrão local (fallback), sinalizado na tela com o selo "Sugestão padrão"

### Replanejamento assistido por IA
- Quando um desafio entra em **risco crítico**, o app abre uma folha de replanejamento com uma sugestão de novo ritmo gerada por IA (`POST /challenges/{id}/replanejar/sugestao`)
- O estudante confirma e o desafio é reajustado (`POST /challenges/{id}/replanejar`) — limite de **2 replanejamentos** por desafio
- A folha mostra o antes/depois (dias restantes, meta diária) antes de aplicar

### Gamificação
- Sistema de XP com progressão de nível (500 XP por nível)
- Streak diário por desafio (dias consecutivos completados)
- Marcos desbloqueáveis: 7, 14, 21 e 30 dias
- Rankings de título: Iniciante → Lendário

### Histórico e Conquistas
- **Heatmap de atividade** dos últimos 84 dias no Perfil, no estilo "contribution graph" (`GET /me/atividade`)
- Tela **Meu Progresso** com a evolução de XP e conclusões ao longo do tempo
- **Histórico dia a dia** de cada desafio, com a nota registrada na conclusão (`GET /challenges/{id}/historico`)
- Catálogo de **8 conquistas** com estado bloqueada/desbloqueada (`GET /me/conquistas`)
- **Overlay de celebração** quando uma conquista é desbloqueada ao concluir um dia

### Desafios
- Criação de desafios com 5 categorias (Saúde, Estudos, Fitness, Mindfulness, Produtividade)
- Duração configurável: 7 a 90 dias
- Recompensa de XP: 100 a 1000 pontos
- Grade visual de 30 dias no detalhe, distinguindo dia concluído, **atrasado** e futuro
- **Nota opcional** ao marcar o dia como concluído
- **Swipe para excluir** com confirmação obrigatória

### Desafios do programa
- Tela dedicada onde a **coordenação** (via dashboard) publica modelos de desafio prontos
- O estudante **adota** um modelo com um toque e ele vira um desafio pessoal (`GET /programa`, `POST /programa/{id}/adotar`)
- Mostra quantos estudantes já adotaram cada modelo

### Modo offline
- Os desafios ficam em **cache local** (`shared_preferences`) e continuam visíveis sem rede
- Banner discreto de "Exibindo dados salvos localmente" quando os dados estão defasados
- **Refresh token no cliente**: a sessão é renovada automaticamente no `401` sem deslogar o usuário

### Motor de Risco (RiskEngine)
```
Score = inatividade(40%) + progressRate(30%) + streak(30%)

LOW      < 0,25  → Nenhuma ação
MEDIUM   < 0,50  → Lembrete
HIGH     < 0,75  → Motivação
CRITICAL ≥ 0,75  → Sugestão de replanejamento
```

> **Nota sobre "IA":** o RiskEngine é um sistema de regras/heurísticas determinísticas e testáveis — não há machine learning, modelo estatístico treinado ou chamada a IA generativa. É uma escolha de engenharia deliberada para um protótipo auditável. Evoluir esse motor para aprendizado de máquina real (ex.: prever risco a partir de padrões históricos de múltiplos usuários) é um candidato natural de roadmap futuro.

### Notificações
- Lembrete diário agendado por horário (timezone America/Sao_Paulo)
- Alertas por nível de risco do desafio
- Notificação de marcos (dias 7, 14, 21, 30)
- Botão de teste na tela de configurações

### Mapa
- Tiles dark CartoDB (sem API key necessária)
- Localização em tempo real via GPS
- Marcadores coloridos por categoria de desafio
- Bottom sheet ao tocar no marcador

### Tour de Onboarding
- 6 passos interativos com overlay escuro e tooltip verde neon
- Aparece apenas na primeira sessão após o login
- Pode ser revisto a qualquer momento pelo Perfil

### Integrações
| Serviço | Uso | Autenticação |
|---|---|---|
| Open-Meteo API | Clima em tempo real + sugestão de desafio | Nenhuma |
| ZenQuotes API | Citações motivacionais | Nenhuma |
| flutter_local_notifications | Notificações locais agendadas | N/A |

---

## Telas

> Identidade visual **100% dark**: fundo `#080A17`, verde neon `#00FF9C`, superfície `#111328`.

| Tela | Descrição |
|---|---|
| **Splash** | Animação de entrada com logo e transição automática |
| **Login / Cadastro** | Autenticação real por e-mail e senha, com alternância entre entrar e criar conta |
| **Home** | Dashboard com desafios, clima atual, citação motivacional e estatísticas |
| **Criar Desafio** | Formulário com categorias, sliders de duração (7–90 dias) e XP (100–1000) |
| **Detalhe do Desafio** | Grade 30 dias (concluído / atrasado / futuro), streak, anel de progresso, histórico com notas, recomendação por IA e botão de concluir (com nota opcional) |
| **Replanejar** | Folha que abre em risco crítico: sugestão de novo ritmo por IA, antes/depois e confirmação |
| **Desafios do Programa** | Modelos publicados pela coordenação; adoção com um toque |
| **Chat (Guia do Level30)** | Conversa com o assistente de IA, com respostas rápidas sugeridas e histórico de contexto |
| **Mapa** | Mapa dark com marcadores dos desafios e localização GPS |
| **Perfil** | Foto de perfil, nível, XP, estatísticas, heatmap de atividade (84 dias), grade de conquistas e marcos atingidos |
| **Meu Progresso** | Evolução de XP e conclusões ao longo do tempo |
| **Notificações** | Toggle, seletor de horário, notificação de teste e alertas de risco (Android e iOS) |

---

## Arquitetura

O projeto segue **Clean Architecture** adaptada com três camadas:

```
lib/
├── core/                          # Tema, cores, extensões, config
│   ├── constants/
│   │   ├── app_colors.dart        # Paleta de cores (sempre via AppColors.*)
│   │   ├── app_config.dart        # apiBaseUrl (override via --dart-define)
│   │   └── app_theme.dart         # MaterialApp ThemeData dark
│   └── extensions/
│
├── data/                          # Camada de dados
│   ├── model/                     # challenge, risk_assessment, user_profile,
│   │                              # achievement, challenge_completion, chat_message
│   ├── repository/                # ChallengeRepository / UserRepository (abstrato + Impl)
│   └── service/                   # api_client (HTTP), challenge_cache (offline),
│                                  # notification_service, onboarding_service,
│                                  # quote_service, weather_service
│
├── domain/                        # Camada de domínio
│   ├── engine/
│   │   └── risk_engine.dart       # Algoritmo de pontuação de risco (espelha o backend)
│   └── provider/                  # challenge, user, chat, notification (ChangeNotifier)
│
└── presentation/                  # Camada de apresentação
    ├── screens/                   # 11 telas (splash, login, home, detalhe, criar,
    │                              # perfil, progresso, programa, mapa, chat, notificações)
    └── widgets/                   # challenge_card, xp_progress_ring, activity_heatmap,
                                   # achievement_celebration, replan_sheet,
                                   # complete_note_sheet, risk_badge, level30_app_bar, …
```

Os `Provider` recebem o repositório por construtor; **nenhuma tela chama `ApiClient` direto**
(regra US-030/031). A camada de dados tem **cache offline** (`SharedPrefsChallengeCache`) e o
`ApiClient` renova a sessão sozinho no `401` (`POST /auth/refresh`) antes de deslogar.

### Backend

A fonte de verdade é a **API em Java + Spring Boot** (pasta `backend/`) — auth, desafios,
motor de risco, admin e métricas. O **Cloudflare Worker** (`server/`) passou a ser apenas o
**gateway de IA** (único caminho até o Workers AI).

```
backend/src/main/java/com/level30/api/
├── controller/     # Auth, Challenge, User, Programa, Chat, Admin, Metricas
├── service/        # regras de negócio (ChallengeService, AuthService, RiskMaterialization, …)
├── domain/
│   ├── model/      # entidades JPA (User, Challenge, ChallengeCompletion, RiskSnapshot, …)
│   └── engine/RiskEngine.java   # mesma lógica do risk_engine.dart (testes portados)
├── security/       # JwtService, JwtAuthFilter, rate limiter de login
├── config/         # SecurityConfig, OpenApiConfig (Swagger), DataSeeder, CORS
└── dto/            # response/request

server/  (Cloudflare Worker — só IA)
└── src/routes/internal.ts   # /internal/recommendation e /internal/chat (X-Service-Token)
```

**Documentação da API:** Swagger UI em **[api.level30.online/swagger-ui.html](https://api.level30.online/swagger-ui.html)**
(local: `http://localhost:8080/swagger-ui.html`). Contrato JSON completo em
[`specs/003-fase-5/contract.md`](specs/003-fase-5/contract.md).

| Camada | Tecnologia |
|---|---|
| API | Java 21 + Spring Boot 3.5 (Spring Web, Spring Security, Spring Data JPA) |
| Banco de dados | H2 (dev/test) · PostgreSQL (prod, via profile) — migrations Flyway |
| Autenticação | JWT HS256 (access 1 h) + refresh token rotativo (30 d), BCrypt, RBAC USER/ADMIN |
| Documentação | springdoc-openapi — Swagger UI em `/swagger-ui.html` |
| IA generativa | Cloudflare Workers AI (`@cf/meta/llama-3.1-8b-instruct-fast`) via gateway Worker |
| Hospedagem | VM Oracle + Cloudflare Tunnel (`api.level30.online`) |

Todas as rotas de dados exigem `Authorization: Bearer <token>`. O app aponta para a API via `AppConfig.apiBaseUrl` (`lib/core/constants/app_config.dart`), configurável em build time com `--dart-define=API_BASE_URL=...`.

### Gerenciamento de Estado — Provider

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ChallengeProvider(
      repository: ChallengeRepositoryImpl(),
      cache: SharedPrefsChallengeCache(),
    )),
    ChangeNotifierProvider(create: (_) => UserProvider(repository: UserRepositoryImpl())),
    ChangeNotifierProvider(create: (_) => NotificationProvider()..init()),
    ChangeNotifierProvider(create: (_) => ChatProvider()),
  ],
)
```

**Fluxo de dados:**
```text
UI (context.watch) → Provider → Repository → ApiClient / Cache → notifyListeners() → UI rebuild
```

---

## Stack Técnica

| Categoria | Tecnologia | Versão |
|---|---|---|
| Framework | Flutter | 3.x |
| Linguagem | Dart | ≥ 3.3.0 |
| State Management | Provider + ChangeNotifier | ^6.1.2 |
| Mapa | flutter_map + CartoDB OSM | ^7.0.2 |
| Coordenadas | latlong2 | ^0.9.0 |
| Geolocalização | geolocator | ^13.0.1 |
| Notificações | flutter_local_notifications | ^18.0.1 |
| Timezone | timezone | ^0.9.4 |
| HTTP | http | ^1.2.2 |
| Persistência | shared_preferences | ^2.3.2 |
| Fontes | google_fonts | ^6.2.1 |
| Gráficos | fl_chart | ^0.69.0 |
| Animações | flutter_animate | ^4.5.0 |
| Tour | showcaseview | ^3.0.0 |
| UUID | uuid | ^4.5.1 |
| Permissões | permission_handler | ^11.3.1 |
| Sessão segura | flutter_secure_storage | ^11.0.0 |
| Foto de perfil | image_picker | ^1.1.2 |
| Cache de imagem | cached_network_image | ^3.4.1 |

| Cache offline | shared_preferences (`SharedPrefsChallengeCache`) |

### Backend e Web

| Categoria | Tecnologia |
|---|---|
| API (`backend/`) | Java 21 · Spring Boot 3.5 · Spring Web / Security / Data JPA · Flyway · springdoc-openapi |
| Banco | H2 (dev/test) · PostgreSQL (prod) |
| Dashboard web (`dashboard/`) | Angular 18 (standalone) · HttpClient · RxJS |
| Gateway de IA (`server/`) | Cloudflare Worker (Hono, TypeScript) → Workers AI (Llama 3.1 8B) |

---

## Como Rodar

### Pré-requisitos

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.x
- Android Studio ou VS Code com extensão Flutter/Dart
- Emulador Android (API 21+) ou simulador/dispositivo iOS (13.0+, requer Xcode e macOS)
- Nenhuma chave de API própria necessária — o app já aponta para a API em produção (`https://api.level30.online`)

### Instalação

```bash
# 1. Clone o repositório
git clone https://github.com/omateusborba/Level30-Flutter.git
cd Level30-Flutter

# 2. Instale as dependências
flutter pub get

# 3. (iOS) instale os pods
cd ios && pod install && cd ..

# 4. Rode no emulador/simulador ou dispositivo conectado
flutter run
```

### Build APK Release (Android)

```bash
flutter build apk --release
# Saída: build/app/outputs/flutter-apk/app-release.apk (~53 MB)
```

### Build iOS

```bash
flutter build ios --release
# Requer assinatura de código configurada no Xcode (ios/Runner.xcworkspace)
```

### Rodar o backend localmente (opcional)

Por padrão o app usa a API em produção (`https://api.level30.online`). Para rodar o backend Spring Boot local:

```bash
cd backend
JAVA_HOME=$(/usr/libexec/java_home -v 21) mvn spring-boot:run   # API em :8080, Swagger em /swagger-ui.html

# Depois, rode o app apontando para o backend local:
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Seed local: `admin@level30.app` / `admin1234` (ADMIN) · `ana@level30.app` / `estudante1` (USER).

### Rodar Testes

```bash
# Todos os testes
flutter test

# Testes unitários do RiskEngine
flutter test test/risk_engine_test.dart
```

---

## Configuração Android

Permissões declaradas no `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

**Core Library Desugaring** habilitado para `flutter_local_notifications` no Android < 26:

```kotlin
// android/app/build.gradle.kts
compileOptions {
    isCoreLibraryDesugaringEnabled = true
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

---

## Configuração iOS

Permissões declaradas no `ios/Runner/Info.plist` (necessárias para foto de perfil):

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>O Level30 precisa acessar suas fotos para você escolher uma foto de perfil.</string>
<key>NSCameraUsageDescription</key>
<string>O Level30 precisa acessar a câmera para você tirar uma foto de perfil.</string>
```

**Deployment target**: iOS 13.0 (`ios/Podfile` e `ios/Runner.xcodeproj`).

**Notificações em primeiro plano**: o iOS, por padrão, não exibe banner/som quando o app está aberto. Isso foi corrigido habilitando a apresentação padrão no `DarwinInitializationSettings`:

```dart
// lib/data/service/notification_service.dart
const ios = DarwinInitializationSettings(
  requestAlertPermission: true,
  requestBadgePermission: true,
  requestSoundPermission: true,
  defaultPresentAlert: true,
  defaultPresentBadge: true,
  defaultPresentSound: true,
);
```

---

## APIs Utilizadas

### Open-Meteo
```
GET https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current_weather=true
```
Retorna código meteorológico → app sugere categoria de desafio (sol → Fitness, chuva → Estudos).

### ZenQuotes
```
GET https://zenquotes.io/api/random
```
Retorna `[{"q": "frase", "a": "autor"}]` → exibido na HomeScreen com fallback local.

Ambas as APIs são **gratuitas, sem autenticação** e com **fallback gracioso** — se a rede falhar, o app usa dados locais.

### Level30 API (backend próprio)

Base: `https://api.level30.online` · Swagger: [`/swagger-ui.html`](https://api.level30.online/swagger-ui.html)

| Rota | Método | Descrição | Auth |
|---|---|---|---|
| `/auth/signup` · `/auth/login` | POST | Cria conta / login (retorna access + refresh token) | Não |
| `/auth/refresh` · `/auth/logout` | POST | Renova / encerra a sessão | Não |
| `/me` · `/me/avatar` | GET · PUT | Dados do usuário / foto de perfil | Bearer |
| `/me/sessoes` | GET · DELETE | Lista / revoga sessões ativas | Bearer |
| `/challenges` | GET · POST | Lista / cria desafios | Bearer |
| `/challenges/{id}/complete` | POST | Marca o dia (retorna XP, streak e conquistas desbloqueadas) | Bearer |
| `/challenges/{id}` | DELETE | Exclui o desafio | Bearer |
| `/challenges/{id}/historico` | GET | Histórico dia a dia com notas | Bearer |
| `/challenges/{id}/replanejar/sugestao` · `/challenges/{id}/replanejar` | POST | Sugestão de novo ritmo por IA / aplica o replanejamento | Bearer |
| `/challenges/{id}/recommendation` | GET | Dica gerada por IA para o desafio | Bearer |
| `/me/atividade` · `/me/conquistas` | GET | Heatmap de atividade / catálogo de conquistas | Bearer |
| `/programa` · `/programa/{id}/adotar` | GET · POST | Modelos de desafio da coordenação / adotar | Bearer |
| `/chat` | POST | Conversa com o assistente de IA | Bearer |
| `/admin/**` | — | Usuários, desafios, indicadores e métricas do programa | Bearer + ADMIN |

As rotas de IA (`/chat`, `/challenges/{id}/recommendation`, `/challenges/{id}/replanejar/sugestao`) passam pelo gateway **Cloudflare Workers AI** (Llama 3.1 8B) e têm fallback determinístico caso a IA falhe.

---

## Informações do App

| Item | Valor |
|---|---|
| Package ID (Android) | `com.level30.level30flutter` |
| Bundle ID (iOS) | `com.level30.level30flutter` |
| Versão | 1.0.0+1 |
| Min SDK Android | API 21 (Android 5.0) |
| Target SDK Android | API 34 (Android 14) |
| iOS Deployment Target | iOS 13.0+ |
| APK Release | ~52,9 MB |

---

## Contexto Acadêmico

| Campo | Detalhe |
|---|---|
| Instituição | FIAP |
| Desafio | Enterprise Challenge 2026 — Fase 5 (Mobile Hybrid App e a Sociedade 5.0) |
| Avaliador | Leroy Merlin |
| Tema | Sociedade 5.0 — Tecnologia a serviço do ser humano |

Planejamento, contrato da API e status de execução da Fase 5 em [`specs/003-fase-5/`](specs/003-fase-5/).

---

<p align="center">
  Feito com ❤️ para o Enterprise Challenge FIAP 2026 — Level30 Smart HAS
</p>
