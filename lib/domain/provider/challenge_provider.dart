import 'package:flutter/foundation.dart';
import '../../data/model/challenge.dart';
import '../../data/model/risk_assessment.dart';
import '../../data/service/api_client.dart';
import '../engine/risk_engine.dart';

class ChallengeProvider extends ChangeNotifier {
  final RiskEngine _riskEngine = RiskEngine();
  List<Challenge> _challenges = [];
  ChallengeCategory? _selectedCategory;
  bool _isLoading = false;

  List<Challenge> get challenges => _selectedCategory == null
      ? List.unmodifiable(_challenges)
      : List.unmodifiable(
          _challenges.where((c) => c.category == _selectedCategory));

  List<Challenge> get allChallenges => List.unmodifiable(_challenges);
  ChallengeCategory? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get hasAnyChallenge => _challenges.isNotEmpty;

  int get completedCount => _challenges.where((c) => c.isCompleted).length;
  int get activeCount => _challenges.where((c) => !c.isCompleted).length;
  int get bestStreak =>
      _challenges.fold(0, (max, c) => c.streak > max ? c.streak : max);

  /// Busca os desafios do usuário autenticado. Conta nova = lista vazia
  /// (sem seed padrão) — o vazio é reforçado pelo próprio backend.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiClient.instance.get('/challenges') as List;
      _challenges = res
          .map((j) => Challenge.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _challenges = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _challenges = [];
    _selectedCategory = null;
    notifyListeners();
  }

  Future<void> addChallenge({
    required String title,
    required ChallengeCategory category,
    required String description,
    int xpReward = 300,
    int totalDays = 30,
  }) async {
    final res = await ApiClient.instance.post('/challenges', {
      'title': title,
      'category': category.name,
      'description': description,
      'xpReward': xpReward,
      'totalDays': totalDays,
    });
    _challenges.insert(0, Challenge.fromJson(res as Map<String, dynamic>));
    notifyListeners();
  }

  void selectCategory(ChallengeCategory? cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  /// Completa o dia de hoje via API; retorna o delta de XP e o total
  /// confirmado pelo servidor (mesma fórmula do `Challenge.earnedXp`).
  Future<({int xpDelta, int totalXp})> completeDay(String id) async {
    final res =
        await ApiClient.instance.post('/challenges/$id/complete') as Map<String, dynamic>;
    final updated = Challenge.fromJson(res['challenge'] as Map<String, dynamic>);
    final idx = _challenges.indexWhere((c) => c.id == id);
    if (idx != -1) _challenges[idx] = updated;
    notifyListeners();
    return (xpDelta: res['xpDelta'] as int, totalXp: res['totalXp'] as int);
  }

  Future<void> deleteChallenge(String id) async {
    await ApiClient.instance.delete('/challenges/$id');
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

  // Badge de risco na lista: fórmula local (mesma do servidor), resposta
  // instantânea, sem gastar chamada de IA por card.
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
}
