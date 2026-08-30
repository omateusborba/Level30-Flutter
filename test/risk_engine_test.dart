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

  // Fronteiras exatas entre níveis: <0.25 low · <0.50 medium · <0.75 high · resto critical.
  group('RiskEngine — fronteiras de score', () {
    test('score na fronteira 0.25 cai em medium (limite inclusivo por baixo)', () {
      // f_inatividade 0.0 (ativo hoje) + f_progresso 0.25 (dia 5/30) + f_streak 0.0 (streak 10)
      final c = Challenge(
        id: 'b25',
        title: 'T',
        category: ChallengeCategory.study,
        description: '',
        xpReward: 100,
        streak: 10,
        currentDay: 5,
        lastActivityAt: DateTime.now(),
      );
      final a = engine.assess(c);
      expect(a.riskScore, closeTo(0.25, 0.001));
      expect(a.riskLevel, RiskLevel.medium);
    });

    test('score na fronteira 0.50 cai em high', () {
      // f_inatividade 0.0 + f_progresso 0.20 (dia 10/30) + f_streak 0.30 (streak 0)
      final c = Challenge(
        id: 'b50',
        title: 'T',
        category: ChallengeCategory.study,
        description: '',
        xpReward: 100,
        streak: 0,
        currentDay: 10,
        lastActivityAt: DateTime.now(),
      );
      final a = engine.assess(c);
      expect(a.riskScore, closeTo(0.50, 0.001));
      expect(a.riskLevel, RiskLevel.high);
    });

    test('score na fronteira 0.75 cai em critical', () {
      // f_inatividade 0.25 (sem atividade + streak 0) + f_progresso 0.20 + f_streak 0.30
      const c = Challenge(
        id: 'b75',
        title: 'T',
        category: ChallengeCategory.study,
        description: '',
        xpReward: 100,
        streak: 0,
        currentDay: 10,
      );
      final a = engine.assess(c);
      expect(a.riskScore, closeTo(0.75, 0.001));
      expect(a.riskLevel, RiskLevel.critical);
    });
  });
}
