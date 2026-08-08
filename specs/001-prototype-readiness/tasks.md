# Tasks — Prontidão do protótipo Level30

Ordem de implementação. Marcar `[x]` ao concluir cada item.

## Modelos e persistência (R1)
- [x] `lib/data/model/challenge.dart` — `toJson`/`fromJson`
- [x] `lib/data/model/user_profile.dart` — `toJson`/`fromJson`
- [x] `lib/domain/provider/challenge_provider.dart` — `init()` assíncrono lendo/gravando `SharedPreferences`; `_save()` chamado em `addChallenge`, `completeDay`, `deleteChallenge`
- [x] `lib/domain/provider/user_provider.dart` — `init()` assíncrono; `_save()` chamado em `setName`, `addXp`
- [x] `lib/main.dart` — `UserProvider()..init()`

## Bug de XP (R2)
- [x] `lib/presentation/screens/challenge_detail_screen.dart` — creditar delta de `earnedXp` em vez de `xpReward ~/ totalDays`; atualizar texto do snackbar

## Honestidade IA (R3)
- [x] `lib/presentation/screens/home_screen.dart` — texto do tour do card motivacional
- [x] `lib/presentation/screens/home_screen.dart` — texto do tour do bottom nav (remover "geolocalizados")
- [x] `lib/presentation/screens/challenge_detail_screen.dart` — `_AISuggestionCard` (emoji, título, subtítulo)
- [x] `README.md` — seção do motor de risco

## Mapa: posição ilustrativa (R4)
- [x] `lib/presentation/screens/map_screen.dart` — linha extra na legenda

## Preview reativo (R5)
- [x] `lib/presentation/screens/create_challenge_screen.dart` — listener no `_titleController`

## Contraste do RiskBadge (R6)
- [x] `lib/presentation/widgets/risk_badge.dart` — texto em `AppColors.textPrimary`

## Paleta de categorias (R7)
- [x] `lib/data/model/challenge.dart` — novos hex em `ChallengeCategoryExt.color`

## Botão de tema não interativo (R8)
- [x] `lib/presentation/screens/profile_screen.dart` — remover `onPressed` do ícone de tema, virar indicador estático

## Remover RiskProvider morto (R9)
- [x] deletar `lib/domain/provider/risk_provider.dart`
- [x] `lib/main.dart` — remover import e registro do provider

## Geolocalização real na Home (R10)
- [x] `lib/presentation/screens/home_screen.dart` — tentar `Geolocator` antes do fallback São Paulo

## Sem SnackBarAction morto (R11)
- [x] `lib/presentation/screens/home_screen.dart` — remover `SnackBarAction` vazio

## Token de borda (R12)
- [x] `lib/core/constants/app_colors.dart` — adicionar `border`
- [x] `lib/presentation/widgets/challenge_card.dart`
- [x] `lib/presentation/widgets/category_chip.dart`
- [x] `lib/presentation/screens/home_screen.dart` (`_WeatherCard`, `_StatChip`)
- [x] `lib/presentation/screens/create_challenge_screen.dart` (`_CategorySelector`, `_PreviewCard`)
- [x] `lib/presentation/screens/challenge_detail_screen.dart` (`_InfoTile`)
- [x] `lib/presentation/screens/profile_screen.dart` (`_StatsGrid`)
- [x] `lib/presentation/screens/map_screen.dart` (legenda, bottom sheet, banner)
- [x] `lib/core/constants/app_theme.dart` (`inputDecorationTheme`, `chipTheme`)

## Paleta oficial no Mapa e Marcos (R13)
- [x] `lib/presentation/screens/map_screen.dart` — `Colors.blue/red/amber` → `AppColors.*`
- [x] `lib/presentation/screens/profile_screen.dart` — `_MilestonesSection` `Colors.amber` → `AppColors.riskMedium`

## Ícone adaptativo (R14)
- [x] `pubspec.yaml` — `adaptive_icon_background`

## Verificação final
- [x] `flutter analyze` — limpo, mesmos 27 avisos de estilo pré-existentes
- [x] `flutter test` — 7/7 passando
