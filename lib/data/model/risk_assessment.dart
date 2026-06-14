enum RiskLevel { low, medium, high, critical }

enum SuggestedAction {
  none,
  sendReminder,
  sendMotivation,
  suggestReplan,
  celebrateMilestone,
}

extension RiskLevelExt on RiskLevel {
  String get label => switch (this) {
    RiskLevel.low      => 'Baixo',
    RiskLevel.medium   => 'Médio',
    RiskLevel.high     => 'Alto',
    RiskLevel.critical => 'Crítico',
  };
}

extension SuggestedActionExt on SuggestedAction {
  String get message => switch (this) {
    SuggestedAction.none               => 'Continue assim! Você está indo muito bem.',
    SuggestedAction.sendReminder       => 'Não esqueça do seu desafio de hoje!',
    SuggestedAction.sendMotivation     => 'Você chegou até aqui — não desista agora!',
    SuggestedAction.suggestReplan      => 'Que tal reajustar o ritmo? Recomeçar é vencer.',
    SuggestedAction.celebrateMilestone => '🎉 Marco atingido! Você é incrível!',
  };
}

class RiskAssessment {
  final String challengeId;
  final double riskScore;
  final RiskLevel riskLevel;
  final SuggestedAction suggestedAction;
  final DateTime calculatedAt;

  const RiskAssessment({
    required this.challengeId,
    required this.riskScore,
    required this.riskLevel,
    required this.suggestedAction,
    required this.calculatedAt,
  });
}
