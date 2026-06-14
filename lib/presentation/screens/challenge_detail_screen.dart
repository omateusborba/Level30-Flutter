import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/challenge.dart';
import '../../data/model/risk_assessment.dart';
import '../../domain/provider/challenge_provider.dart';
import '../../domain/provider/notification_provider.dart';
import '../../domain/provider/user_provider.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/risk_badge.dart';
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
          // Header com cor da categoria
          SliverAppBar(
            expandedHeight: 180,
            backgroundColor: catColor.withAlpha(179),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFDE350B)),
                tooltip: 'Excluir desafio',
                onPressed: () async {
                  final confirmed = await showDeleteConfirmDialog(
                    context: context,
                    challengeTitle: challenge.title,
                  );
                  if (confirmed && context.mounted) {
                    context
                        .read<ChallengeProvider>()
                        .deleteChallenge(challengeId);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${challenge.title}" excluído.'),
                        backgroundColor: const Color(0xFF1A3A5C),
                      ),
                    );
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [catColor.withAlpha(230), AppColors.background],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(challenge.category.emoji,
                            style: const TextStyle(fontSize: 48)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                challenge.category.displayName.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: catColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                challenge.title,
                                style: GoogleFonts.poppins(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        RiskBadge(assessment: risk, showLabel: true),
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
                    _InfoTile(
                      emoji: '🔥',
                      label: 'Sequência',
                      value: '${challenge.streak} dias',
                    ),
                    const SizedBox(width: 12),
                    _InfoTile(
                      emoji: '⚡',
                      label: 'XP ganho',
                      value: '${challenge.earnedXp} XP',
                    ),
                    const SizedBox(width: 12),
                    _InfoTile(
                      emoji: '🎯',
                      label: 'Recompensa',
                      value: '${challenge.xpReward} XP',
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

                // Sugestão da IA
                _AISuggestionCard(
                  assessment: risk,
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
                    totalDays: challenge.totalDays,
                    catColor: catColor),
                const SizedBox(height: 24),

                // Botão completar dia
                ElevatedButton.icon(
                  onPressed: alreadyDone || challenge.isCompleted
                      ? null
                      : () {
                          context
                              .read<ChallengeProvider>()
                              .completeDay(challengeId);
                          context
                              .read<UserProvider>()
                              .addXp(challenge.xpReward ~/ challenge.totalDays);

                          // Notificação de marco nos dias 7, 14, 21, 30
                          final nextDay = challenge.currentDay + 1;
                          if ([7, 14, 21, 30].contains(nextDay)) {
                            final updated = challenge.copyWith(currentDay: nextDay);
                            context
                                .read<NotificationProvider>()
                                .checkAndNotify(
                                  challenges: [updated],
                                  risks: [context.read<ChallengeProvider>().getRisk(challengeId)],
                                );
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '✅ Dia ${challenge.currentDay + 1} concluído! +${challenge.xpReward ~/ challenge.totalDays} XP'),
                              backgroundColor: AppColors.riskLow,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          );
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
                        ? Colors.amber.shade700
                        : alreadyDone
                            ? AppColors.primary
                            : AppColors.accent,
                    foregroundColor: AppColors.background,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: AppColors.primary,
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

class _InfoTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _InfoTile(
      {required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecond, fontSize: 10)),
            ],
          ),
        ),
      );
}

class _AISuggestionCard extends StatelessWidget {
  final RiskAssessment assessment;
  final Color catColor;

  const _AISuggestionCard(
      {required this.assessment, required this.catColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: catColor.withAlpha(77)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🤖', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sugestão da IA',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assessment.suggestedAction.message,
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

class _DayGrid extends StatelessWidget {
  final int currentDay;
  final int totalDays;
  final Color catColor;

  const _DayGrid(
      {required this.currentDay,
      required this.totalDays,
      required this.catColor});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
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
        final isMilestone = [7, 14, 21, 30].contains(day);
        return Container(
          decoration: BoxDecoration(
            color: done
                ? catColor.withAlpha(179)
                : AppColors.primary.withAlpha(77),
            borderRadius: BorderRadius.circular(6),
            border: isMilestone
                ? Border.all(color: Colors.amber, width: 1.5)
                : null,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: done ? Colors.white : AppColors.textSecond,
                fontSize: 11,
                fontWeight:
                    isMilestone ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      },
    );
  }
}
