import 'package:flutter_test/flutter_test.dart';
import 'package:level30/data/model/challenge.dart';
import 'package:level30/data/model/risk_assessment.dart';
import 'package:level30/domain/engine/risk_engine.dart';

void main() {
  final engine = RiskEngine();

  group('RiskEngine', () {
    test('streak zero deve resultar em risco médio ou maior', () {
      final c = Challenge(
        id: '1',
        title: 'Test',
        category: ChallengeCategory.study,
        description: '',
        xpReward: 100,
        streak: 0,
        currentDay: 5,
      );
      expect(engine.assess(c).riskScore, greaterThan(0.25));
    });

    test('streak ativo com bom progresso deve resultar em risco baixo', () {
      // streak=10, currentDay=25/30 (83% completo), ativo hoje
      // Factor1: 0.0, Factor2: (1-0.833)*0.3=0.05, Factor3: max(0, 0.3-10*0.03)=0.0
      // Total ≈ 0.05 → low
      final c = Challenge(
        id: '2',
        title: 'Test',
        category: ChallengeCategory.study,
        description: '',
        xpReward: 100,
        streak: 10,
        currentDay: 25,
        lastActivityAt: DateTime.now(),
      );
      expect(engine.assess(c).riskLevel, RiskLevel.low);
    });

    test('dia 7 deve retornar celebração de marco', () {
      final c = Challenge(
        id: '3',
        title: 'Test',
        category: ChallengeCategory.study,
        description: '',
        xpReward: 100,
        streak: 7,
        currentDay: 7,
        lastActivityAt: DateTime.now(),
      );
      expect(engine.assess(c).suggestedAction,
          SuggestedAction.celebrateMilestone);
    });

    test('dia 14 deve retornar celebração de marco', () {
      final c = Challenge(
        id: '4',
        title: 'Test',
        category: ChallengeCategory.study,
        description: '',
        xpReward: 100,
        streak: 14,
        currentDay: 14,
        lastActivityAt: DateTime.now(),
      );
      expect(engine.assess(c).suggestedAction,
          SuggestedAction.celebrateMilestone);
    });

    test('score deve estar entre 0 e 1', () {
      for (var day = 0; day <= 30; day++) {
        final c = Challenge(
          id: 'x',
          title: 'T',
          category: ChallengeCategory.fitness,
          description: '',
          xpReward: 200,
          currentDay: day,
          streak: day,
          lastActivityAt: day > 0 ? DateTime.now() : null,
        );
        final score = engine.assess(c).riskScore;
        expect(score, inInclusiveRange(0.0, 1.0));
      }
    });

    test('progresso completo deve resultar em risco baixo', () {
      final c = Challenge(
        id: '5',
        title: 'Test',
        category: ChallengeCategory.productivity,
        description: '',
        xpReward: 300,
        streak: 10,
        currentDay: 30,
        lastActivityAt: DateTime.now(),
      );
      expect(engine.assess(c).riskLevel, RiskLevel.low);
    });

    test('score crítico para desafio abandonado', () {
      final c = Challenge(
        id: '6',
        title: 'Test',
        category: ChallengeCategory.mindfulness,
        description: '',
        xpReward: 200,
        streak: 0,
        currentDay: 1,
        lastActivityAt:
            DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(engine.assess(c).riskScore, greaterThan(0.5));
    });
  });
}
