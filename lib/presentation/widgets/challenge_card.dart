import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/challenge.dart';
import '../../domain/provider/challenge_provider.dart';
import 'risk_badge.dart';

class ChallengeCard extends StatelessWidget {
  final Challenge challenge;

  const ChallengeCard({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    final risk = context.read<ChallengeProvider>().getRisk(challenge.id);

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/challenge', arguments: challenge.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withAlpha(179)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Barra lateral colorida
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: challenge.category.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(challenge.category.emoji,
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              challenge.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          RiskBadge(assessment: risk),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: challenge.progress,
                          backgroundColor: AppColors.surface2,
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.accent),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dia ${challenge.currentDay} de ${challenge.totalDays}',
                            style: const TextStyle(
                              color: AppColors.textSecond,
                              fontSize: 12,
                            ),
                          ),
                          if (challenge.streak > 0)
                            Row(
                              children: [
                                const Text('🔥',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 2),
                                Text(
                                  '${challenge.streak} dias',
                                  style: const TextStyle(
                                    color: AppColors.textSecond,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
