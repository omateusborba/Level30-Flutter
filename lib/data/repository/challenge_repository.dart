import '../model/challenge.dart';
import '../model/achievement.dart';
import '../model/challenge_completion.dart';

/// Contrato de acesso a dados de desafios. Os providers dependem desta
/// abstração (não do ApiClient diretamente), o que torna a camada de
/// domínio testável com fakes.
abstract class ChallengeRepository {
  Future<List<Challenge>> list();

  Future<Challenge> create({
    required String title,
    required ChallengeCategory category,
    required String description,
    required int xpReward,
    required int totalDays,
  });

  Future<({Challenge challenge, int xpDelta, int totalXp, List<Achievement> conquistas})>
      completeDay(String id);

  Future<void> delete(String id);

  Future<({String message, bool aiGenerated})> recommendation(String id);

  /// F1 · histórico de conclusões do desafio.
  Future<List<ChallengeCompletion>> historico(String id);

  /// F1 · conclusões por dia do usuário desde [desde] — alimenta o heatmap.
  Future<List<AtividadeDia>> atividade(DateTime desde);

  /// F4 · catálogo de conquistas com estado de desbloqueio.
  Future<List<Achievement>> conquistas();
}
