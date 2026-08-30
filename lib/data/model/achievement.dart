import 'package:flutter/material.dart';

/// F4 · conquista (GET /me/conquistas e campo `conquistas` de completeDay).
class Achievement {
  final String id;
  final String nome;
  final String descricao;
  final bool desbloqueada;

  const Achievement({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.desbloqueada,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        nome: json['nome'] as String,
        descricao: json['descricao'] as String,
        desbloqueada: json['desbloqueada'] as bool? ?? true,
      );

  IconData get icon => switch (id) {
        'primeiro_passo' => Icons.flag_outlined,
        'semana_cheia' => Icons.date_range_outlined,
        'constancia' => Icons.trending_up,
        'maratonista' => Icons.directions_run,
        'poliglota' => Icons.grid_view_outlined,
        'madrugador' => Icons.wb_sunny_outlined,
        'resiliente' => Icons.restart_alt,
        'veterano' => Icons.military_tech_outlined,
        _ => Icons.emoji_events_outlined,
      };
}
