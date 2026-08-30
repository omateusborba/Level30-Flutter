import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/challenge.dart';
import '../../data/service/api_client.dart';
import '../../domain/provider/challenge_provider.dart';
import '../../domain/provider/notification_provider.dart';
import '../../domain/provider/user_provider.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/risk_badge.dart';
import '../widgets/stat_tile.dart';
import '../widgets/xp_progress_ring.dart';

class ChallengeDetailScreen extends StatelessWidget {
  final String challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  bool _completedToday(Challenge c) {
    if (c.lastActivityAt == null) return false;
    final now = DateTime.now();
    final last = c.lastActivityAt!;
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ChallengeProvider>();
    final challenge = cp.getById(challengeId);

    if (challenge == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Desafio')),
        body: const Center(
            child: Text('Desafio não encontrado.',
                style: TextStyle(color: AppColors.textSecond))),
      );
    }

    final risk = cp.getRisk(challengeId);
    final alreadyDone = _completedToday(challenge);
    final catColor = challenge.category.color;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header: fundo do sistema (navy escuro), categoria só como acento.
          SliverAppBar(
            expandedHeight: 168,
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.riskCritical),
                tooltip: 'Excluir desafio',
                onPressed: () async {
                  final confirmed = await showDeleteConfirmDialog(
                    context: context,
                    challengeTitle: challenge.title,
                  );
                  if (confirmed && context.mounted) {
                    try {
                      await context
                          .read<ChallengeProvider>()
                          .deleteChallenge(challengeId);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"${challenge.title}" excluído.'),
                          backgroundColor: AppColors.surface2,
                        ),
                      );
                    } on ApiException catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    }
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              background: Container(
                color: AppColors.background,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Icon(challenge.category.icon, color: catColor, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              challenge.category.displayName.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: catColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            ),
                            const Spacer(),
                            RiskBadge(assessment: risk, showLabel: true),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          challenge.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Progresso circular
                Center(
                  child: XPProgressRing(
                    progress: challenge.progress,
                    centerLabel:
                        '${(challenge.progress * 100).toInt()}%',
                    subLabel:
                        'Dia ${challenge.currentDay} / ${challenge.totalDays}',
                    size: 150,
                    strokeWidth: 12,
                  ),
                ).animate().fadeIn().scale(),
                const SizedBox(height: 24),

                // Streak + XP
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.local_fire_department_outlined,
                        label: 'Sequência',
                        value: '${challenge.streak} dias',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: Icons.bolt_outlined,
                        label: 'XP ganho',
                        value: '${challenge.earnedXp} XP',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: Icons.emoji_events_outlined,
                        label: 'Recompensa',
                        value: '${challenge.xpReward} XP',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Descrição
                Text(
                  challenge.description,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecond,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),

                // Recomendação gerada por IA (Cloudflare Workers AI)
                _RecommendationCard(
                  challengeId: challengeId,
                  catColor: catColor,
                ),
                const SizedBox(height: 20),

                // Grade de 30 dias
                Text(
                  'Progresso nos 30 dias',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _DayGrid(
                    currentDay: challenge.currentDay,
                    totalDays: challenge.totalDays),
                const SizedBox(height: 24),

                // Botão completar dia
                ElevatedButton.icon(
                  onPressed: alreadyDone || challenge.isCompleted
                      ? null
                      : () async {
                          try {
                            final result = await context
                                .read<ChallengeProvider>()
                                .completeDay(challengeId);
                            if (!context.mounted) return;
                            context.read<UserProvider>().syncTotalXp(result.totalXp);

                            final updated = context
                                .read<ChallengeProvider>()
                                .getById(challengeId)!;

                            // Notificação de marco nos dias 7, 14, 21, 30
                            if ([7, 14, 21, 30].contains(updated.currentDay)) {
                              await context.read<NotificationProvider>().checkAndNotify(
                                challenges: [updated],
                                risks: [context.read<ChallengeProvider>().getRisk(challengeId)],
                              );
                            }

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '✅ Dia ${updated.currentDay} concluído! +${result.xpDelta} XP'),
                                backgroundColor: AppColors.riskLow,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            );
                          } on ApiException catch (e) {
                            if (!context.mounted) return;
                            final isAlreadyDone = e.statusCode == 409;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isAlreadyDone
                                    ? 'Você já concluiu este desafio hoje.'
                                    : e.message),
                                backgroundColor: isAlreadyDone
                                    ? AppColors.riskMedium
                                    : null,
                              ),
                            );
                          }
                        },
                  icon: Icon(alreadyDone
                      ? Icons.check_circle
                      : Icons.add_task),
                  label: Text(challenge.isCompleted
                      ? '🏆 Desafio Concluído!'
                      : alreadyDone
                          ? 'Dia já concluído!'
                          : 'Completar Dia de Hoje'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: challenge.isCompleted
                        ? AppColors.surface2
                        : alreadyDone
                            ? AppColors.surface2
                            : AppColors.accent,
                    foregroundColor: AppColors.background,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: AppColors.surface2,
                    disabledForegroundColor: AppColors.textSecond,
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatefulWidget {
  final String challengeId;
  final Color catColor;

  const _RecommendationCard(
      {required this.challengeId, required this.catColor});

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _loading = true;
  String? _message;
  bool _aiGenerated = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context
          .read<ChallengeProvider>()
          .getRecommendation(widget.challengeId);
      if (!mounted) return;
      setState(() {
        _message = res.message;
        _aiGenerated = res.aiGenerated;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Recomendação Level30',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    if (!_loading && !_failed) ...[
                      const SizedBox(width: 8),
                      _SourcePill(aiGenerated: _aiGenerated),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  )
                else
                  Text(
                    _failed
                        ? 'Não foi possível carregar a recomendação agora.'
                        : _message!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  final bool aiGenerated;
  const _SourcePill({required this.aiGenerated});

  @override
  Widget build(BuildContext context) {
    final color = aiGenerated ? AppColors.accent : AppColors.textSecond;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Text(
        aiGenerated ? 'Gerado por IA' : 'Sugestão padrão',
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DayGrid extends StatelessWidget {
  final int currentDay;
  final int totalDays;

  const _DayGrid({required this.currentDay, required this.totalDays});

  static const _milestones = [7, 14, 21, 30];

  @override
  Widget build(BuildContext context) {
    final todayCell = currentDay < totalDays ? currentDay + 1 : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemCount: totalDays,
          itemBuilder: (_, i) {
            final day = i + 1;
            final done = day <= currentDay;
            final isMilestone = _milestones.contains(day);
            final isToday = day == todayCell;
            return Container(
              decoration: BoxDecoration(
                color: done ? AppColors.accent : AppColors.surface2,
                borderRadius: BorderRadius.circular(6),
                border: isToday
                    ? Border.all(color: AppColors.textPrimary, width: 2)
                    : (isMilestone && !done)
                        ? Border.all(color: AppColors.riskMedium, width: 1.5)
                        : null,
              ),
              child: Center(
                child: isMilestone && done
                    ? const Icon(Icons.star_rounded,
                        color: AppColors.accentInk, size: 14)
                    : Text(
                        '$day',
                        style: TextStyle(
                          color:
                              done ? AppColors.accentInk : AppColors.textSecond,
                          fontSize: 11,
                          fontWeight: isMilestone
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _LegendItem(color: AppColors.accent, label: 'Concluído'),
            _LegendItem(color: AppColors.riskMedium, label: 'Marco', outline: true),
            _LegendItem(
                color: AppColors.textPrimary, label: 'Hoje', outline: true),
            _LegendItem(color: AppColors.surface2, label: 'Pendente'),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool outline;

  const _LegendItem(
      {required this.color, required this.label, this.outline = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: outline ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(3),
            border: outline ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: AppColors.textSecond, fontSize: 11)),
      ],
    );
  }
}
