import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

/// Card de estatística padrão — antes reimplementado em Home, Detalhe e Perfil.
/// Ícone vetorial (cromo de interface), valor em destaque, rótulo discreto.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  /// Layout: `false` = coluna centralizada (Home / Detalhe);
  /// `true` = ícone+valor lado a lado, rótulo abaixo (grid do Perfil).
  final bool horizontal;

  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = GoogleFonts.poppins(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
      fontSize: horizontal ? 20 : 15,
    );
    const labelStyle = TextStyle(color: AppColors.textSecond, fontSize: 11);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: horizontal
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  Icon(icon, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(value, style: valueStyle),
                ]),
                const SizedBox(height: 2),
                Text(label, style: labelStyle),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.accent, size: 18),
                const SizedBox(height: 6),
                Text(value, style: valueStyle),
                Text(label, style: labelStyle, textAlign: TextAlign.center),
              ],
            ),
    );
  }
}
