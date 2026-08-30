import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/achievement.dart';

/// F4 · overlay de celebração ao desbloquear conquista(s).
Future<void> showAchievementCelebration(
    BuildContext context, List<Achievement> conquistas) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => _CelebrationDialog(conquistas: conquistas),
  );
}

class _CelebrationDialog extends StatelessWidget {
  final List<Achievement> conquistas;
  const _CelebrationDialog({required this.conquistas});

  @override
  Widget build(BuildContext context) {
    final plural = conquistas.length > 1;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              plural ? 'Conquistas desbloqueadas!' : 'Conquista desbloqueada!',
              style: GoogleFonts.poppins(
                color: AppColors.accent,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            for (final a in conquistas) ...[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
                child: Icon(a.icon, color: AppColors.accent, size: 32),
              )
                  .animate()
                  .scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack)
                  .then()
                  .shimmer(duration: 900.ms, color: AppColors.accent),
              const SizedBox(height: 10),
              Text(a.nome,
                  style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              Text(a.descricao,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecond, fontSize: 12)),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continuar'),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
