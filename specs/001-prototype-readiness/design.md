# Design técnico — Prontidão do protótipo Level30

Cobre a implementação dos requisitos em `requirements.md`. Sem mudança de arquitetura: continua Clean Architecture leve (data/domain/presentation) + Provider.

## R1 — Persistência (SharedPreferences + JSON)

Padrão já validado em `NotificationProvider` (chaves simples via `SharedPreferences`). Para listas/objetos, serializar como JSON string.

`Challenge` e `UserProfile` ganham `toJson()`/`fromJson(Map)`:

```dart
// Challenge
Map<String, dynamic> toJson() => {
  'id': id, 'title': title, 'category': category.name, 'description': description,
  'totalDays': totalDays, 'currentDay': currentDay, 'xpReward': xpReward,
  'streak': streak, 'lastActivityAt': lastActivityAt?.toIso8601String(),
};
factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
  id: j['id'] as String, title: j['title'] as String,
  category: ChallengeCategory.values.byName(j['category'] as String),
  description: j['description'] as String,
  totalDays: j['totalDays'] as int, currentDay: j['currentDay'] as int,
  xpReward: j['xpReward'] as int, streak: j['streak'] as int,
  lastActivityAt: j['lastActivityAt'] != null
      ? DateTime.parse(j['lastActivityAt'] as String) : null,
);
```

`UserProfile` análogo, com `name` e `totalXp`.

`ChallengeProvider`:
- `Future<void> init()` — lê `SharedPreferences.getStringList('challenges_json')`; se presente, decodifica cada item com `Challenge.fromJson`; senão usa `_defaultChallenges()`. Sempre `notifyListeners()` ao final.
- `_save()` privado, `Future<void>`, chamado (fire-and-forget, sem `await` no call site) ao final de `addChallenge`, `completeDay`, `deleteChallenge` — serializa `_challenges` e grava.

`UserProvider`:
- `Future<void> init()` — lê `SharedPreferences.getString('user_profile_json')`; se presente, `UserProfile.fromJson`; senão mantém o perfil padrão atual (`name: 'Mateus', totalXp: 2350`) para não quebrar a primeira impressão da demo.
- `_save()` chamado ao final de `setName` e `addXp`.

`main.dart`: `ChangeNotifierProvider(create: (_) => ChallengeProvider()..init())` já é o padrão existente (só muda o corpo de `init()`); adicionar o mesmo `..init()` fire-and-forget em `UserProvider()`.

## R2 — XP sem perda por arredondamento

`Challenge.earnedXp` já existe e é exato: `((currentDay / totalDays) * xpReward).toInt()`. Em vez de creditar `xpReward ~/ totalDays` a cada dia (que perde resto), o botão "Completar Dia" passa a:

```dart
final beforeEarned = challenge.earnedXp;
context.read<ChallengeProvider>().completeDay(challengeId);
final after = context.read<ChallengeProvider>().getById(challengeId)!;
final delta = after.earnedXp - beforeEarned;
context.read<UserProvider>().addXp(delta);
```

Como `earnedXp` no último dia (`currentDay == totalDays`) é exatamente `xpReward`, a soma telescópica dos deltas ao longo do desafio fecha exatamente no valor prometido.

## R3 — Honestidade "IA"

Trocas de texto (sem mudança de lógica):
- `home_screen.dart`, descrição do `TourStep` do card motivacional: remove "Gerada em tempo real via IA", substitui por frase que descreve a busca via API de citações.
- `home_screen.dart`, descrição do `TourStep` do `_BottomNav`: remove "desafios geolocalizados", substitui por "organiza seus desafios ao redor da sua localização atual".
- `challenge_detail_screen.dart`, `_AISuggestionCard`: emoji 🤖 → 📊, título "Sugestão da IA" → "Recomendação Level30", adiciona subtítulo curto "Baseada no seu streak e frequência de atividade" acima da mensagem existente.
- `README.md`: seção "Motor de Risco (RiskEngine)" ganha uma frase explícita: sistema de regras/heurísticas determinísticas, sem machine learning, com nota de que é candidato a evoluir para IA real no roadmap.

## R4 — Legenda do Mapa

`_Legend` em `map_screen.dart` ganha uma linha de texto pequena (11px, `AppColors.textSecond`) abaixo dos itens existentes: "Posição do desafio é ilustrativa, calculada a partir da sua localização". Não muda a lógica de `_offset`.

## R5 — Preview reativo

`create_challenge_screen.dart`, `_CreateChallengeScreenState`:
```dart
@override
void initState() {
  super.initState();
  _titleController.addListener(_onTitleChanged);
}
void _onTitleChanged() => setState(() {});
@override
void dispose() {
  _titleController.removeListener(_onTitleChanged);
  _titleController.dispose();
  _descController.dispose();
  super.dispose();
}
```

## R6 — Contraste do RiskBadge

`risk_badge.dart`: o texto (`$pct%` e o label do nível) passa de `TextStyle(color: _bgColor, ...)` para `TextStyle(color: AppColors.textPrimary, ...)`. O `Container` (dot de 6×6) e a `border` continuam usando `_bgColor` — o nível de risco continua comunicado por cor + posição do dot + texto (não só cor, conforme heurística de acessibilidade), mas o texto em si passa a ter contraste ~18:1 contra o fundo escuro do badge em vez de ~3:1.

## R7 — Paleta de categoria sem colisão com risco

`AppColors.risk*` usa a faixa semáforo: verde (low) / amarelo (medium) / laranja (high) / vermelho (critical). Nova paleta de `ChallengeCategoryExt.color` evita essa faixa inteira:

| Categoria | Antes | Depois | Motivo |
|---|---|---|---|
| health | `#00C853` (= riskLow) | `#00BCD4` (ciano) | Colidia com risco baixo |
| study | `#2979FF` | `#2979FF` (mantido) | Já fora da faixa de risco |
| productivity | `#FF6D00` (= riskHigh) | `#7C4DFF` (violeta) | Colidia com risco alto |
| mindfulness | `#AA00FF` | `#AA00FF` (mantido) | Já fora da faixa de risco |
| fitness | `#D50000` (= riskCritical) | `#FF4081` (rosa) | Colidia com risco crítico |

## R8 — Botão de tema não interativo

`profile_screen.dart`: o `IconButton(Icons.dark_mode, onPressed: ...)` na AppBar vira um indicador estático — `Tooltip` + `Icon` sem `onPressed` (ou um pequeno `Container`/chip não clicável), mantendo a mesma mensagem hoje só visível via snackbar agora como `Tooltip` sempre disponível ao segurar/passar o mouse. Sem `GestureDetector`/`InkWell` envolvendo o ícone.

## R9 — Remover RiskProvider morto

Deletar `lib/domain/provider/risk_provider.dart` e a linha correspondente em `main.dart` (`ChangeNotifierProvider(create: (_) => RiskProvider())` e o import). `ChallengeProvider` já resolve risco via sua própria instância de `RiskEngine` — nenhuma tela referencia `RiskProvider`.

## R10 — Geolocalização real na Home

`home_screen.dart`, `_loadData`: antes de chamar `WeatherService`, tenta obter a posição real via `Geolocator` com o mesmo padrão de `map_screen.dart` (`isLocationServiceEnabled`, `checkPermission`/`requestPermission`, timeout de 5s), com fallback para as coordenadas de São Paulo já existentes em caso de erro/negação/timeout. Não introduz um serviço novo — a lógica replica o bloco já usado e testado em `_MapScreenState._initLocation`.

## R11 — Sem SnackBarAction morto

`home_screen.dart`: remove o `action: SnackBarAction(label: 'OK', ..., onPressed: () {})` do `SnackBar` de exclusão. O `SnackBar` continua mostrando a confirmação textual, sem um botão que finge fazer algo.

## R12 — Token de borda

`AppColors.border = Color(0xFF4A6890)` — validado por cálculo de luminância relativa WCAG: contraste de 3.20:1 contra `surface` (#111328) e 3.45:1 contra `background` (#080A17), acima do mínimo de 3:1 para elementos de UI não-textuais. Substitui `AppColors.primary` nos usos como `Border.all(...)` em containers decorativos (cards, chips, inputs) — `AppColors.primary` continua sendo usado onde representa cor de marca/preenchimento (avatar, botão desabilitado, fundo de snackbar).

## R13 — Paleta oficial no Mapa e Marcos

`map_screen.dart`: marcador do usuário e círculo de precisão trocam `Colors.blue` → `AppColors.accent`; círculo de zona de risco troca `Colors.red` → `AppColors.riskCritical`; marcador de desafio concluído troca `Colors.amber` → `AppColors.riskMedium`; `_LegendDot` dos mesmos itens acompanha a troca.
`profile_screen.dart`, `_MilestonesSection`: borda/ícone `Colors.amber` → `AppColors.riskMedium` (mesmo tom dourado/amarelo, agora vindo da paleta central).

## R14 — Ícone adaptativo

`pubspec.yaml`, bloco `flutter_launcher_icons`: adicionar `adaptive_icon_background: "#080A17"` (mesmo tom de `AppColors.background`).

## Verificação

- `flutter analyze` limpo.
- `flutter test` — 7/7 em `risk_engine_test.dart` continuam passando (nenhuma mudança no `RiskEngine`).
- Roteiro manual descrito no plano de implementação (persistência sobrevive a restart, XP fecha exato, preview reativo, badge legível).
