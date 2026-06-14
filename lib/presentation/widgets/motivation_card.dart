import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/risk_assessment.dart';

class MotivationCard extends StatelessWidget {
  final String quote;
  final RiskAssessment? highRisk;
  final VoidCallback? onViewChallenge;

  const MotivationCard({
    super.key,
    required this.quote,
    this.highRisk,
    this.onViewChallenge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(179),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Citação do Dia',
                style: GoogleFonts.poppins(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            quote,
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          if (highRisk != null) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.primary),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('🤖', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    highRisk!.suggestedAction.message,
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecond,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (onViewChallenge != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onViewChallenge,
                child: Text(
                  'Ver desafio em risco →',
                  style: GoogleFonts.poppins(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
