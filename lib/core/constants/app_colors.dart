import 'package:flutter/material.dart';

/// Design tokens do Level30. Fonte de verdade compartilhada com o dashboard
/// (`dashboard/src/styles.css`, mesmos valores).
///
/// Regras de uso (ver spec de design da Fase 5):
/// - `accent` é exclusivo de ação primária / estado positivo. Não em texto corrido,
///   ícone decorativo ou borda de card.
/// - `risk*` é exclusivo de risco de abandono. Nada mais usa essas cores.
/// - Cor de categoria (`ChallengeCategoryExt.color`) é acento pontual (barra de 3px,
///   ponto, ícone) — nunca pinta header ou fundo de célula.
class AppColors {
  const AppColors._();

  static const background = Color(0xFF080A17);
  static const surface = Color(0xFF111328);
  static const surface2 = Color(0xFF171A33); // elevação intermediária
  static const border = Color(0xFF232744); // sutil, não compete com o conteúdo
  static const accent = Color(0xFF00FF9C);
  static const accentInk = Color(0xFF052E1E); // texto/ícone sobre `accent`
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecond = Color(0xFF8A90B8);

  static const riskLow = Color(0xFF22C55E);
  static const riskMedium = Color(0xFFEAB308);
  static const riskHigh = Color(0xFFF97316);
  static const riskCritical = Color(0xFFEF4444);
}
