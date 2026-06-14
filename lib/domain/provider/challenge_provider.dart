import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/model/challenge.dart';
import '../../data/model/risk_assessment.dart';
import '../engine/risk_engine.dart';

class ChallengeProvider extends ChangeNotifier {
  final RiskEngine _riskEngine = RiskEngine();
  List<Challenge> _challenges = [];
  ChallengeCategory? _selectedCategory;
  final bool _isLoading = false;

  List<Challenge> get challenges => _selectedCategory == null
      ? List.unmodifiable(_challenges)
      : List.unmodifiable(
          _challenges.where((c) => c.category == _selectedCategory));

  List<Challenge> get allChallenges => List.unmodifiable(_challenges);
  ChallengeCategory? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;

  int get completedCount => _challenges.where((c) => c.isCompleted).length;
  int get activeCount => _challenges.where((c) => !c.isCompleted).length;
  int get bestStreak =>
      _challenges.fold(0, (max, c) => c.streak > max ? c.streak : max);

  void init() {
    _challenges = _defaultChallenges();
    notifyListeners();
  }

  void addChallenge({
    required String title,
    required ChallengeCategory category,
    required String description,
    int xpReward = 300,
    int totalDays = 30,
  }) {
    final challenge = Challenge(
      id: const Uuid().v4(),
      title: title,
      category: category,
      description: description,
      xpReward: xpReward,
      totalDays: totalDays,
    );
    _challenges.add(challenge);
    notifyListeners();
  }

  void selectCategory(ChallengeCategory? cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  void completeDay(String id) {
    final idx = _challenges.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final c = _challenges[idx];
    if (c.isCompleted) return;
    _challenges[idx] = c.copyWith(
      currentDay: c.currentDay + 1,
      streak: c.streak + 1,
      lastActivityAt: DateTime.now(),
    );
    notifyListeners();
  }

  void deleteChallenge(String id) {
    _challenges.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Challenge? getById(String id) {
    try {
      return _challenges.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  RiskAssessment getRisk(String id) {
    final c = _challenges.firstWhere(
      (ch) => ch.id == id,
      orElse: () => throw Exception('Desafio não encontrado: $id'),
    );
    return _riskEngine.assess(c);
  }

  List<RiskAssessment> getAllRisks() =>
      _challenges.map((c) => _riskEngine.assess(c)).toList();

  RiskAssessment? getHighestRisk() {
    if (_challenges.isEmpty) return null;
    final risks = getAllRisks();
    risks.sort((a, b) => b.riskScore.compareTo(a.riskScore));
    return risks.first;
  }

  List<Challenge> _defaultChallenges() => [
    Challenge(
      id: '1',
      title: 'Leitura Diária',
      category: ChallengeCategory.study,
      description: 'Leia pelo menos 20 páginas por dia durante 30 dias.',
      xpReward: 500,
      currentDay: 12,
      streak: 4,
      lastActivityAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Challenge(
      id: '2',
      title: 'Exercício Matinal',
      category: ChallengeCategory.fitness,
      description: '30 minutos de exercício toda manhã.',
      xpReward: 400,
      currentDay: 7,
      streak: 7,
      lastActivityAt: DateTime.now(),
    ),
    Challenge(
      id: '3',
      title: 'Meditação',
      category: ChallengeCategory.mindfulness,
      description: '10 minutos de meditação guiada diariamente.',
      xpReward: 300,
      currentDay: 3,
      streak: 0,
      lastActivityAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Challenge(
      id: '4',
      title: 'Revisão de Flashcards',
      category: ChallengeCategory.study,
      description: 'Revise 20 flashcards por dia usando espaçamento repetido.',
      xpReward: 450,
      currentDay: 20,
      streak: 10,
      lastActivityAt: DateTime.now(),
    ),
    Challenge(
      id: '5',
      title: 'Sem Redes Sociais',
      category: ChallengeCategory.productivity,
      description: 'Zero redes sociais até as 18h.',
      xpReward: 600,
      currentDay: 1,
      streak: 1,
      lastActivityAt: DateTime.now(),
    ),
  ];
}
