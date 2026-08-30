import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/provider/user_provider.dart';

/// Chip compacto de nível/XP para o header — substitui o anel minúsculo, que
/// não comportava o texto "Nv1". Barra de progresso fina abaixo.
class LevelChip extends StatelessWidget {
  const LevelChip({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<UserProvider>().profile;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              children: [
                TextSpan(
                    text: 'Nv ${p.level}',
                    style: const TextStyle(color: AppColors.textPrimary)),
                TextSpan(
                    text: '  ·  ${p.totalXp} XP',
                    style: const TextStyle(color: AppColors.textSecond)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              width: 92,
              height: 3,
              child: LinearProgressIndicator(
                value: p.xpProgress,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
