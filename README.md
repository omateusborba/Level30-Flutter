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
  <img src="https://img.shields.io/badge/FIAP-Enterprise%20Challenge%202026-ED1C24" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
</p>

---

## Sobre o Projeto

**Level30** transforma o desenvolvimento de hábitos acadêmicos em um jogo de RPG. O usuário cria desafios de 30 dias, acumula XP a cada dia completado, avança de nível e recebe alertas inteligentes quando uma sequência está em risco.

O sistema **Smart HAS** (Smart Habit Acceleration System) combina:
- **Motor de risco com IA** — avalia cada desafio com score de 0,0 a 1,0 baseado em inatividade, progresso e streak
- **Notificações inteligentes** — alertas contextuais agendados por horário e disparados por nível de risco
- **Mapa geolocalizado** — visualização dos desafios em mapa dark com CartoDB/OpenStreetMap
- **Tour de onboarding** — guia interativo de 6 passos para novos usuários
- **Integração com APIs reais** — clima em tempo real (Open-Meteo) e citações motivacionais (ZenQuotes)

> Projeto desenvolvido para o **Enterprise Challenge 2026 — Fase 4 (FIAP)**, avaliado pela **Leroy Merlin**.

---

## Funcionalidades

### Gamificação
- Sistema de XP com progressão de nível (500 XP por nível)
- Streak diário por desafio (dias consecutivos completados)
- Marcos desbloqueáveis: 7, 14, 21 e 30 dias
- Rankings de título: Iniciante → Lendário

### Desafios
- Criação de desafios com 5 categorias (Saúde, Estudos, Fitness, Mindfulness, Produtividade)
- Duração configurável: 7 a 90 dias
- Recompensa de XP: 100 a 1000 pontos
- Grade visual de progresso dia a dia
- **Swipe para excluir** com confirmação obrigatória

### Motor de Risco (RiskEngine)
```
Score = inatividade(40%) + progressRate(30%) + streak(30%)

LOW      < 0,25  → Nenhuma ação
MEDIUM   < 0,50  → Lembrete
HIGH     < 0,75  → Motivação
CRITICAL ≥ 0,75  → Sugestão de replanejamento
```

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
| **Login** | Formulário com validação de nome |
| **Home** | Dashboard com desafios, clima atual, citação motivacional e estatísticas |
| **Criar Desafio** | Formulário com categorias, sliders de duração (7–90 dias) e XP (100–1000) |
| **Detalhe do Desafio** | Grade 30 dias, streak, anel de progresso, sugestão da IA e botão de concluir |
| **Mapa** | Mapa dark com marcadores dos desafios e localização GPS |
| **Perfil** | Nível, XP, estatísticas, marcos atingidos e botão de rever tour |
| **Notificações** | Toggle, seletor de horário, notificação de teste e alertas de risco |

---

## Arquitetura

O projeto segue **Clean Architecture** adaptada com três camadas:

```
lib/
├── core/                          # Tema, cores, extensões
│   ├── constants/
│   │   ├── app_colors.dart        # Paleta de cores (sempre via AppColors.*)
│   │   └── app_theme.dart         # MaterialApp ThemeData dark
│   └── extensions/
│       ├── context_extensions.dart
│       └── string_extensions.dart
│
├── data/                          # Camada de dados
│   ├── model/
│   │   ├── challenge.dart         # Entidade Challenge + ChallengeCategory
│   │   ├── risk_assessment.dart   # Entidade RiskAssessment + SuggestedAction
│   │   └── user_profile.dart      # Entidade UserProfile com cálculo de nível
│   └── service/
│       ├── notification_service.dart  # Singleton de notificações locais
│       ├── onboarding_service.dart    # Estado do tour (SharedPreferences)
│       ├── quote_service.dart         # ZenQuotes API + fallback local
│       └── weather_service.dart       # Open-Meteo API
│
├── domain/                        # Camada de domínio
│   ├── engine/
│   │   └── risk_engine.dart       # Algoritmo de pontuação de risco
│   └── provider/
│       ├── challenge_provider.dart    # Estado dos desafios
│       ├── notification_provider.dart # Estado das notificações + SharedPreferences
│       ├── risk_provider.dart         # Wrapper do RiskEngine
│       └── user_provider.dart         # Estado do usuário e XP
│
└── presentation/                  # Camada de apresentação
    ├── screens/                   # 8 telas
    └── widgets/                   # Componentes reutilizáveis
        ├── challenge_card.dart
        ├── category_chip.dart
        ├── delete_confirm_dialog.dart
        ├── level30_app_bar.dart
        ├── motivation_card.dart
        ├── onboarding_tour.dart
        ├── risk_badge.dart
        └── xp_progress_ring.dart
```

### Gerenciamento de Estado — Provider

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ChallengeProvider()..init()),
    ChangeNotifierProvider(create: (_) => UserProvider()),
    ChangeNotifierProvider(create: (_) => RiskProvider()),
    ChangeNotifierProvider(create: (_) => NotificationProvider()..init()),
  ],
)
```

**Fluxo de dados:**
```
UI (context.watch) → Provider → Engine/Service → notifyListeners() → UI rebuild
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

---

## Como Rodar

### Pré-requisitos

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.x
- Android Studio ou VS Code com extensão Flutter/Dart
- Emulador Android (API 21+) ou dispositivo físico
- Nenhuma chave de API necessária

### Instalação

```bash
# 1. Clone o repositório
git clone https://github.com/omateusborba/Level30-Flutter.git
cd Level30-Flutter

# 2. Instale as dependências
flutter pub get

# 3. Rode no emulador ou dispositivo conectado
flutter run
```

### Build APK Release

```bash
flutter build apk --release
# Saída: build/app/outputs/flutter-apk/app-release.apk (~53 MB)
```

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

---

## Informações do App

| Item | Valor |
|---|---|
| Package ID | `com.level30.level30flutter` |
| Versão | 1.0.0+1 |
| Min SDK Android | API 21 (Android 5.0) |
| Target SDK Android | API 34 (Android 14) |
| APK Release | ~52,9 MB |

---

## Contexto Acadêmico

| Campo | Detalhe |
|---|---|
| Instituição | FIAP |
| Desafio | Enterprise Challenge 2026 — Fase 4 |
| Avaliador | Leroy Merlin |
| Tema | Sociedade 5.0 — Tecnologia a serviço do ser humano |

A documentação técnica completa (arquitetura de rede, NOC, comparativo Flutter vs Kotlin) está em [`DOCUMENTACAO_FASE4.md`](DOCUMENTACAO_FASE4.md).

---

<p align="center">
  Feito com ❤️ para o Enterprise Challenge FIAP 2026 — Level30 Smart HAS
</p>
