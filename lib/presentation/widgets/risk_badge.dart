import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/risk_assessment.dart';

class RiskBadge extends StatelessWidget {
  final RiskAssessment assessment;
  final bool showLabel;

  const RiskBadge({
    super.key,
    required this.assessment,
    this.showLabel = false,
  });

  Color get _bgColor => switch (assessment.riskLevel) {
        RiskLevel.low => AppColors.riskLow,
        RiskLevel.medium => AppColors.riskMedium,
        RiskLevel.high => AppColors.riskHigh,
        RiskLevel.critical => AppColors.riskCritical,
      };

  @override
  Widget build(BuildContext context) {
    final pct = (assessment.riskScore * 100).toInt();
    final badge = Tooltip(
      message: 'Risco: ${assessment.riskLevel.label} ($pct%)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _bgColor.withAlpha(51),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _bgColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: _bgColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              '$pct%',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Text(
                assessment.riskLevel.label,
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
    return badge;
  }
}
