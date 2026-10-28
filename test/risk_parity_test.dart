import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:level30/data/model/challenge.dart';
import 'package:level30/data/model/risk_assessment.dart';
import 'package:level30/domain/engine/risk_engine.dart';

/// Paridade Dart x Java: lê a MESMA fixture que `RiskEngineParityTest` (backend), então os dois motores
/// têm de chegar ao mesmo score e à mesma faixa para cada caso.
void main() {
  final fixture = jsonDecode(File('test/fixtures/risk_parity.json').readAsStringSync())
      as Map<String, dynamic>;
  final casos = (fixture['casos'] as List).cast<Map<String, dynamic>>();
  final engine = RiskEngine();

  group('RiskEngine — paridade com o back-end (fixture compartilhada)', () {
    for (final caso in casos) {
      test(caso['nome'] as String, () {
        final dias = caso['diasSemAtividade'] as int?;
        final c = Challenge(
          id: 'parity',
          title: 'Parity',
          category: ChallengeCategory.study,
          description: '',
          xpReward: 100,
          totalDays: caso['totalDays'] as int,
          currentDay: caso['currentDay'] as int,
          streak: caso['streak'] as int,
          lastActivityAt: dias == null
              ? null
              : DateTime.now().subtract(Duration(days: dias, hours: 1)),
        );
        final r = engine.assess(c);
        expect(r.riskScore, closeTo((caso['scoreEsperado'] as num).toDouble(), 1e-6));
        expect(r.riskLevel, RiskLevel.values.byName(caso['nivelEsperado'] as String));
      });
    }
  });
}
