import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/challenge_completion.dart';

/// F1 · grade estilo "contribuição": últimas 12 semanas, intensidade por
/// quantidade de conclusões no dia.
class ActivityHeatmap extends StatelessWidget {
  final List<AtividadeDia> atividade;
  static const _weeks = 12;

  const ActivityHeatmap({super.key, required this.atividade});

  Color _cell(int count) {
    if (count <= 0) return AppColors.surface2;
    if (count == 1) return AppColors.accent.withValues(alpha: 0.35);
    if (count == 2) return AppColors.accent.withValues(alpha: 0.65);
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <DateTime, int>{
      for (final a in atividade)
        DateTime(a.data.year, a.data.month, a.data.day): a.quantidade,
    };

    final today = DateTime.now();
    final start = today.subtract(Duration(days: _weeks * 7 - 1));
    // alinha o início na segunda-feira da semana
    final gridStart = start.subtract(Duration(days: (start.weekday - 1) % 7));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Atividade',
                style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const Text('12 semanas',
                style: TextStyle(color: AppColors.textSecond, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, box) {
          const gap = 3.0;
          final size =
              ((box.maxWidth - gap * (_weeks - 1)) / _weeks).clamp(8.0, 18.0);
          return Row(
            children: List.generate(_weeks, (w) {
              return Padding(
                padding: EdgeInsets.only(right: w == _weeks - 1 ? 0 : gap),
                child: Column(
                  children: List.generate(7, (d) {
                    final date = gridStart.add(Duration(days: w * 7 + d));
                    final future = date.isAfter(today);
                    final count =
                        byDay[DateTime(date.year, date.month, date.day)] ?? 0;
                    return Padding(
                      padding: EdgeInsets.only(bottom: d == 6 ? 0 : gap),
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: future ? Colors.transparent : _cell(count),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          );
        }),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('menos',
                style: TextStyle(color: AppColors.textSecond, fontSize: 10)),
            const SizedBox(width: 6),
            for (final c in [0, 1, 2, 3])
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _cell(c),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const SizedBox(width: 3),
            const Text('mais',
                style: TextStyle(color: AppColors.textSecond, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
