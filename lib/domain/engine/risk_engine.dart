import '../../data/model/challenge.dart';
import '../../data/model/risk_assessment.dart';

class RiskEngine {
  RiskAssessment assess(Challenge challenge) {
    final score = _calculateScore(challenge);
    final level = _scoreToLevel(score);
    final action = _determineAction(challenge, level);
    return RiskAssessment(
      challengeId: challenge.id,
      riskScore: score,
      riskLevel: level,
      suggestedAction: action,
      calculatedAt: DateTime.now(),
    );
  }

  double _calculateScore(Challenge c) {
    double score = 0.0;

    // Fator 1: dias sem atividade (40%)
    final daysSince = _daysSinceLastActivity(c);
    score += switch (daysSince) {
      0 => 0.0,
      1 => 0.1,
      2 => 0.25,
      _ => 0.4,
    };

    // Fator 2: taxa de progresso vs esperada (30%)
    if (c.totalDays > 0) {
      final rate = c.currentDay / c.totalDays;
      score += (1.0 - rate) * 0.3;
    }

    // Fator 3: streak (30%)
    final streakFactor =
        c.streak == 0 ? 0.3 : (0.3 - (c.streak * 0.03)).clamp(0.0, 0.3);
    score += streakFactor;

    return score.clamp(0.0, 1.0);
  }

  RiskLevel _scoreToLevel(double s) => switch (s) {
        < 0.25 => RiskLevel.low,
        < 0.50 => RiskLevel.medium,
        < 0.75 => RiskLevel.high,
        _ => RiskLevel.critical,
      };

  SuggestedAction _determineAction(Challenge c, RiskLevel level) {
    if (const [7, 14, 21, 30].contains(c.currentDay)) {
      return SuggestedAction.celebrateMilestone;
    }
    return switch (level) {
      RiskLevel.low => SuggestedAction.none,
      RiskLevel.medium => SuggestedAction.sendReminder,
      RiskLevel.high => SuggestedAction.sendMotivation,
      RiskLevel.critical => SuggestedAction.suggestReplan,
    };
  }

  int _daysSinceLastActivity(Challenge c) {
    if (c.lastActivityAt == null) return c.streak == 0 ? 2 : 0;
    return DateTime.now().difference(c.lastActivityAt!).inDays;
  }
}
