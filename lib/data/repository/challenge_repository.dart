import '../model/challenge.dart';

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

  Future<({Challenge challenge, int xpDelta, int totalXp})> completeDay(String id);

  Future<void> delete(String id);

  Future<({String message, bool aiGenerated})> recommendation(String id);
}
