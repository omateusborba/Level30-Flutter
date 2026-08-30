import '../model/challenge.dart';
import '../model/challenge_completion.dart';
import '../service/api_client.dart';
import 'challenge_repository.dart';

/// Implementação real: fala com a API via [ApiClient].
class ChallengeRepositoryImpl implements ChallengeRepository {
  final ApiClient _api;

  ChallengeRepositoryImpl({ApiClient? api}) : _api = api ?? ApiClient.instance;

  @override
  Future<List<Challenge>> list() async {
    final res = await _api.get('/challenges') as List;
    return res
        .map((j) => Challenge.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Challenge> create({
    required String title,
    required ChallengeCategory category,
    required String description,
    required int xpReward,
    required int totalDays,
  }) async {
    // Monta a partir de Challenge.toJson() (US-035) e envia só os campos
    // que o contrato de criação aceita.
    final draft = Challenge(
      id: '',
      title: title,
      category: category,
      description: description,
      xpReward: xpReward,
      totalDays: totalDays,
    ).toJson();
    final res = await _api.post('/challenges', {
      'title': draft['title'],
      'category': draft['category'],
      'description': draft['description'],
      'totalDays': draft['totalDays'],
      'xpReward': draft['xpReward'],
    });
    return Challenge.fromJson(res as Map<String, dynamic>);
  }

  @override
  Future<({Challenge challenge, int xpDelta, int totalXp})> completeDay(
      String id) async {
    final res =
        await _api.post('/challenges/$id/complete') as Map<String, dynamic>;
    return (
      challenge: Challenge.fromJson(res['challenge'] as Map<String, dynamic>),
      xpDelta: res['xpDelta'] as int,
      totalXp: res['totalXp'] as int,
    );
  }

  @override
  Future<void> delete(String id) => _api.delete('/challenges/$id');

  @override
  Future<List<ChallengeCompletion>> historico(String id) async {
    final res = await _api.get('/challenges/$id/historico') as List;
    return res
        .map((j) => ChallengeCompletion.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<AtividadeDia>> atividade(DateTime desde) async {
    final d = desde.toIso8601String().split('T').first;
    final res = await _api.get('/me/atividade?desde=$d') as List;
    return res
        .map((j) => AtividadeDia.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<({String message, bool aiGenerated})> recommendation(String id) async {
    final res =
        await _api.get('/challenges/$id/recommendation') as Map<String, dynamic>;
    return (
      message: res['message'] as String,
      aiGenerated: res['aiGenerated'] as bool,
    );
  }
}
