import 'package:flutter/material.dart';

enum ChallengeCategory { health, study, productivity, mindfulness, fitness }

extension ChallengeCategoryExt on ChallengeCategory {
  String get displayName => switch (this) {
    ChallengeCategory.health       => 'Saúde',
    ChallengeCategory.study        => 'Estudos',
    ChallengeCategory.productivity => 'Produtividade',
    ChallengeCategory.mindfulness  => 'Mindfulness',
    ChallengeCategory.fitness      => 'Fitness',
  };

  String get emoji => switch (this) {
    ChallengeCategory.health       => '🏥',
    ChallengeCategory.study        => '📚',
    ChallengeCategory.productivity => '⚡',
    ChallengeCategory.mindfulness  => '🧘',
    ChallengeCategory.fitness      => '💪',
  };

  /// Ícone vetorial (cromo de interface — o emoji fica para conteúdo do usuário).
  IconData get icon => switch (this) {
    ChallengeCategory.health       => Icons.favorite_outline,
    ChallengeCategory.study        => Icons.menu_book_outlined,
    ChallengeCategory.productivity => Icons.bolt_outlined,
    ChallengeCategory.mindfulness  => Icons.self_improvement_outlined,
    ChallengeCategory.fitness      => Icons.fitness_center_outlined,
  };

  // Paleta deliberadamente fora da faixa semáforo usada por AppColors.risk*
  // (verde/amarelo/laranja/vermelho), para não confundir categoria com risco.
  Color get color => switch (this) {
    ChallengeCategory.health       => const Color(0xFF00BCD4),
    ChallengeCategory.study        => const Color(0xFF2979FF),
    ChallengeCategory.productivity => const Color(0xFF7C4DFF),
    ChallengeCategory.mindfulness  => const Color(0xFFAA00FF),
    ChallengeCategory.fitness      => const Color(0xFFFF4081),
  };
}

class Challenge {
  final String id;
  final String title;
  final ChallengeCategory category;
  final String description;
  final int totalDays;
  final int currentDay;
  final int xpReward;
  final int streak;
  final DateTime? lastActivityAt;

  const Challenge({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    this.totalDays = 30,
    this.currentDay = 0,
    required this.xpReward,
    this.streak = 0,
    this.lastActivityAt,
  });

  double get progress => totalDays == 0 ? 0 : currentDay / totalDays;
  bool get isCompleted => currentDay >= totalDays;
  int get earnedXp => ((currentDay / totalDays) * xpReward).toInt();

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
    id: json['id'] as String,
    title: json['title'] as String,
    category: ChallengeCategory.values.byName(json['category'] as String),
    description: json['description'] as String,
    totalDays: json['totalDays'] as int,
    currentDay: json['currentDay'] as int,
    xpReward: json['xpReward'] as int,
    streak: json['streak'] as int,
    lastActivityAt: json['lastActivityAt'] != null
        ? DateTime.parse(json['lastActivityAt'] as String)
        : null,
  );

  /// Serialização espelhada de [Challenge.fromJson] — mesmas chaves e tipos.
  /// Usada para o cache local (US-032) e para montar o corpo de criação
  /// (US-035), evitando mapas construídos à mão espalhados pelo código.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.name,
    'description': description,
    'totalDays': totalDays,
    'currentDay': currentDay,
    'xpReward': xpReward,
    'streak': streak,
    'lastActivityAt': lastActivityAt?.toIso8601String(),
  };
}
