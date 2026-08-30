import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/challenge.dart';
import '../../data/model/risk_assessment.dart';
import '../../data/service/api_client.dart';
import '../../data/service/quote_service.dart';
import '../../data/service/weather_service.dart';
import '../../domain/provider/challenge_provider.dart';
import '../../domain/provider/user_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/category_chip.dart';
import '../widgets/challenge_card.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/level30_app_bar.dart';
import '../widgets/motivation_card.dart';
import '../widgets/onboarding_tour.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _weatherService = WeatherService();
  final _quoteService = QuoteService();

  String _quote = 'Carregando citação…';
  String _weatherEmoji = '🌡️';
  String _weatherDesc = '';
  String _weatherRec = '';
  bool _weatherLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hasChallenge = context.read<ChallengeProvider>().hasAnyChallenge;
      await startTourIfNeeded(context, includeChallengeCard: hasChallenge);
    });
  }

  Future<void> _refreshAll() => Future.wait([
        _loadData(),
        context.read<ChallengeProvider>().refresh(),
      ]);

  Future<void> _loadData() async {
    final quote = await _quoteService.getMotivationalQuote();
    if (!mounted) return;
    setState(() => _quote = quote);

    final (lat, lon) = await _resolveLocation();
    try {
      final geoRes = await _weatherService.getCurrentWeather(lat, lon);
      if (!mounted) return;
      if (geoRes != null) {
        final code = geoRes['weathercode'] as int?;
        setState(() {
          _weatherEmoji = _weatherService.getWeatherEmoji(code);
          _weatherDesc = _weatherService.getWeatherDescription(code);
          _weatherRec = _weatherService.getChallengeRecommendation(code);
          _weatherLoaded = true;
        });
      }
    } catch (_) {}
  }

  // Tenta localização real do dispositivo; fallback para São Paulo.
  Future<(double, double)> _resolveLocation() async {
    const fallback = (-23.5505, -46.6333);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return fallback;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return fallback;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ChallengeProvider>();
    final up = context.watch<UserProvider>();
    final highRisk = cp.getHighestRisk();
    final highRiskId = highRisk?.challengeId;
    final showRiskAlert = highRisk != null && highRisk.riskScore > 0.5;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: Level30AppBar(
        title: 'Level30',
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.accent),
            tooltip: 'Assistente',
            onPressed: () => Navigator.pushNamed(context, '/chat'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: _refreshAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Saudação
                    Text(
                      'Olá, ${up.profile.name}! 👋',
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Continue construindo seus hábitos hoje.',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecond,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Alerta de risco — sinal de produto, acima da lista.
                    if (showRiskAlert && highRiskId != null) ...[
                      _RiskAlert(
                        assessment: highRisk,
                        title: cp.getById(highRiskId)?.title ?? 'Desafio',
                        onTap: () => Navigator.pushNamed(context, '/challenge',
                            arguments: highRiskId),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Estatísticas rápidas
                    TourStep(
                      globalKey: OnboardingTourKeys.xpBar,
                      title: 'Seu Progresso',
                      description: 'Aqui você acompanha seu XP total e nível atual.\nCada dia completado vale pontos de experiência.',
                      child: _StatsRow(cp: cp),
                    ),
                    const SizedBox(height: 20),

                    // Filtro de categorias
                    Text(
                      'Meus Desafios',
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // Chips de categoria
            SliverToBoxAdapter(
              child: TourStep(
                globalKey: OnboardingTourKeys.categoryRow,
                title: 'Filtre seus Desafios',
                description: 'Toque em uma categoria para ver apenas os desafios desse tipo:\nEstudos, Saúde, Fitness, Mindfulness ou Produtividade.',
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      CategoryChip(
                        category: null,
                        isSelected: cp.selectedCategory == null,
                        onTap: () => cp.selectCategory(null),
                      ),
                      const SizedBox(width: 8),
                      ...ChallengeCategory.values.map(
                        (cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CategoryChip(
                            category: cat,
                            isSelected: cp.selectedCategory == cat,
                            onTap: () => cp.selectCategory(cat),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Banner discreto de dados offline (US-032)
            if (cp.isStale)
              const SliverToBoxAdapter(child: _StaleBanner()),

            // Lista de desafios
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: cp.challenges.isEmpty
                  ? SliverToBoxAdapter(
                      child: cp.hasAnyChallenge
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 40),
                                child: Text(
                                  'Nenhum desafio nesta categoria.',
                                  style: TextStyle(color: AppColors.textSecond),
                                ),
                              ),
                            )
                          : const _EmptyChallenges(),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final challenge = cp.challenges[i];
                          final card = i == 0
                              ? TourStep(
                                  globalKey: OnboardingTourKeys.challengeCard,
                                  title: 'Seus Desafios de 30 Dias',
                                  description: 'Cada card mostra seu progresso, streak e nível de risco.\nToque para ver os detalhes e marcar o dia de hoje.',
                                  child: ChallengeCard(challenge: challenge),
                                )
                              : ChallengeCard(challenge: challenge);

                          return Dismissible(
                            key: Key(challenge.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              final confirmed = await showDeleteConfirmDialog(
                                context: context,
                                challengeTitle: challenge.title,
                              );
                              if (!confirmed) return false;
                              if (!context.mounted) return false;
                              try {
                                await context
                                    .read<ChallengeProvider>()
                                    .deleteChallenge(challenge.id);
                                return true;
                              } on ApiException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.message)),
                                  );
                                }
                                return false;
                              }
                            },
                            onDismissed: (_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${challenge.title}" excluído.'),
                                  backgroundColor: const Color(0xFF1A3A5C),
                                ),
                              );
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDE350B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFDE350B).withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_forever,
                                      color: Color(0xFFDE350B), size: 28),
                                  SizedBox(height: 4),
                                  Text(
                                    'Excluir',
                                    style: TextStyle(
                                        color: Color(0xFFDE350B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            child: card,
                          );
                        },
                        childCount: cp.challenges.length,
                      ),
                    ),
            ),
            // Clima + citação — enfeite, no rodapé.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_weatherLoaded) ...[
                      _WeatherCard(
                        emoji: _weatherEmoji,
                        description: _weatherDesc,
                        recommendation: _weatherRec,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TourStep(
                      globalKey: OnboardingTourKeys.motivCard,
                      title: 'Motivação Diária',
                      description: 'Uma frase para dar um estímulo ao seu dia. Toque para expandir.',
                      child: MotivationCard(quote: _quote),
                    ),
                  ],
                ),
              ),
            ),

            // Espaço para o FAB não cobrir o último card.
            const SliverToBoxAdapter(child: SizedBox(height: 104)),
          ],
        ),
      ),
      floatingActionButton: TourStep(
        globalKey: OnboardingTourKeys.fabButton,
        title: 'Crie um Novo Desafio',
        description: 'Toque aqui para criar seu próximo desafio de 30 dias.\nEscolha a categoria, duração e recompensa de XP.',
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/create_challenge'),
          tooltip: 'Novo desafio',
          icon: const Icon(Icons.add),
          label: const Text('Novo desafio'),
        ),
      ),
      bottomNavigationBar: TourStep(
        globalKey: OnboardingTourKeys.bottomNav,
        title: 'Navegação Principal',
        description: 'Use a barra inferior para navegar entre Home, Mapa e Perfil.\nO mapa organiza seus desafios ao redor da sua localização atual.',
        child: const AppBottomNav(currentIndex: 0),
      ),
    );
  }
}

class _RiskAlert extends StatelessWidget {
  final RiskAssessment assessment;
  final String title;
  final VoidCallback onTap;

  const _RiskAlert({
    required this.assessment,
    required this.title,
    required this.onTap,
  });

  Color get _color => switch (assessment.riskLevel) {
        RiskLevel.low => AppColors.riskLow,
        RiskLevel.medium => AppColors.riskMedium,
        RiskLevel.high => AppColors.riskHigh,
        RiskLevel.critical => AppColors.riskCritical,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"$title" em risco ${assessment.riskLevel.label.toLowerCase()}',
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    assessment.suggestedAction.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecond,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: _color, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyChallenges extends StatelessWidget {
  const _EmptyChallenges();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 16),
      child: Column(
        children: [
          const Text('🚀', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'Você ainda não tem desafios',
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Crie seu primeiro desafio de 30 dias e comece a construir o hábito hoje.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: AppColors.textSecond, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/create_challenge'),
            icon: const Icon(Icons.add_task),
            label: const Text('Criar meu primeiro desafio'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(260, 48),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final String emoji;
  final String description;
  final String recommendation;

  const _WeatherCard({
    required this.emoji,
    required this.description,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'Sugestão: $recommendation',
                  style: const TextStyle(
                      color: AppColors.textSecond, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent.withAlpha(77)),
            ),
            child: Text(
              recommendation,
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ChallengeProvider cp;
  const _StatsRow({required this.cp});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(label: 'Ativos', value: '${cp.activeCount}',
            icon: Icons.local_fire_department),
        const SizedBox(width: 10),
        _StatChip(label: 'Concluídos', value: '${cp.completedCount}',
            icon: Icons.check_circle_outline),
        const SizedBox(width: 10),
        _StatChip(label: 'Melhor streak', value: '${cp.bestStreak}d',
            icon: Icons.bolt),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecond, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.riskMedium.withAlpha(102)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined,
              color: AppColors.riskMedium, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Exibindo dados salvos localmente',
              style: TextStyle(color: AppColors.textSecond, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
