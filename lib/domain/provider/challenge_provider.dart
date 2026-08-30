import 'package:flutter/foundation.dart';
import '../../data/model/challenge.dart';
import '../../data/model/risk_assessment.dart';
import '../../data/model/challenge_completion.dart';
import '../../data/repository/challenge_repository.dart';
import '../../data/repository/challenge_repository_impl.dart';
import '../../data/service/challenge_cache.dart';
import '../engine/risk_engine.dart';

class ChallengeProvider extends ChangeNotifier {
  final RiskEngine _riskEngine = RiskEngine();
  final ChallengeRepository _repository;
  final ChallengeCache _cache;

  ChallengeProvider({
    ChallengeRepository? repository,
    ChallengeCache? cache,
  })  : _repository = repository ?? ChallengeRepositoryImpl(),
        _cache = cache ?? SharedPrefsChallengeCache();

  List<Challenge> _challenges = [];
  ChallengeCategory? _selectedCategory;
  bool _isLoading = false;
  bool _isStale = false;

  List<Challenge> get challenges => _selectedCategory == null
      ? List.unmodifiable(_challenges)
      : List.unmodifiable(
          _challenges.where((c) => c.category == _selectedCategory));

  List<Challenge> get allChallenges => List.unmodifiable(_challenges);
  ChallengeCategory? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get hasAnyChallenge => _challenges.isNotEmpty;

  /// `true` quando a lista exibida veio do cache local por falha de rede
  /// (US-032). A Home mostra um banner discreto enquanto isso for verdade.
  bool get isStale => _isStale;

  int get completedCount => _challenges.where((c) => c.isCompleted).length;
  int get activeCount => _challenges.where((c) => !c.isCompleted).length;
  int get bestStreak =>
      _challenges.fold(0, (max, c) => c.streak > max ? c.streak : max);

  /// Busca os desafios do usuário autenticado.
  ///
  /// - Sucesso: grava o cache e limpa [isStale].
  /// - Falha de rede COM cache: carrega do cache e marca [isStale].
  /// - Falha SEM cache: mantém o comportamento antigo (lista vazia).
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      _challenges = await _repository.list();
      _isStale = false;
      await _cache.save(_challenges);
    } catch (_) {
      final cached = await _cache.load();
      if (cached.isNotEmpty) {
        _challenges = cached;
        _isStale = true;
      } else {
        _challenges = [];
        _isStale = false;
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _challenges = [];
    _selectedCategory = null;
    _isStale = false;
    _cache.clear();
    notifyListeners();
  }

  Future<void> addChallenge({
    required String title,
    required ChallengeCategory category,
    required String description,
    int xpReward = 300,
    int totalDays = 30,
  }) async {
    final created = await _repository.create(
      title: title,
      category: category,
      description: description,
      xpReward: xpReward,
      totalDays: totalDays,
    );
    _challenges.insert(0, created);
    await _cache.save(_challenges);
    notifyListeners();
  }

  void selectCategory(ChallengeCategory? cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  /// Completa o dia de hoje via API; retorna o delta de XP e o total
  /// confirmado pelo servidor. Propaga ApiException (ex.: 409 quando o
  /// dia já foi concluído hoje) para a UI tratar.
  Future<({int xpDelta, int totalXp})> completeDay(String id) async {
    final res = await _repository.completeDay(id);
    final idx = _challenges.indexWhere((c) => c.id == id);
    if (idx != -1) _challenges[idx] = res.challenge;
    await _cache.save(_challenges);
    notifyListeners();
    return (xpDelta: res.xpDelta, totalXp: res.totalXp);
  }

  Future<void> deleteChallenge(String id) async {
    await _repository.delete(id);
    _challenges.removeWhere((c) => c.id == id);
    await _cache.save(_challenges);
    notifyListeners();
  }

  /// Recomendação (IA com fallback) para um desafio — via repositório,
  /// para que nenhuma tela precise falar com o ApiClient direto (US-031).
  Future<({String message, bool aiGenerated})> getRecommendation(String id) =>
      _repository.recommendation(id);

  Future<List<ChallengeCompletion>> getHistorico(String id) =>
      _repository.historico(id);

  Future<List<AtividadeDia>> getAtividade(DateTime desde) =>
      _repository.atividade(desde);

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
