/// F1 · um dia de desafio concluído (GET /challenges/{id}/historico).
class ChallengeCompletion {
  final int dayNumber;
  final DateTime completedOn;
  final String? note;
  final int xpDelta;

  const ChallengeCompletion({
    required this.dayNumber,
    required this.completedOn,
    this.note,
    required this.xpDelta,
  });

  factory ChallengeCompletion.fromJson(Map<String, dynamic> json) =>
      ChallengeCompletion(
        dayNumber: json['dayNumber'] as int,
        completedOn: DateTime.parse(json['completedOn'] as String),
        note: json['note'] as String?,
        xpDelta: json['xpDelta'] as int,
      );
}

/// Item de GET /me/atividade — conclusões e XP por dia (heatmap + "Meu Progresso").
class AtividadeDia {
  final DateTime data;
  final int quantidade;

  /// XP ganho no dia. Aditivo (B6) — 0 em respostas antigas.
  final int xp;

  const AtividadeDia({
    required this.data,
    required this.quantidade,
    this.xp = 0,
  });

  factory AtividadeDia.fromJson(Map<String, dynamic> json) => AtividadeDia(
        data: DateTime.parse(json['data'] as String),
        quantidade: json['quantidade'] as int,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
      );
}
