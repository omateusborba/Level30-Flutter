import 'package:flutter_test/flutter_test.dart';
import 'package:level30/data/model/challenge.dart';
import 'package:level30/data/model/challenge_completion.dart';
import 'package:level30/data/repository/challenge_repository.dart';
import 'package:level30/data/service/api_client.dart';
import 'package:level30/data/service/challenge_cache.dart';
import 'package:level30/domain/provider/challenge_provider.dart';

Challenge _challenge(
  String id, {
  ChallengeCategory category = ChallengeCategory.study,
  int currentDay = 3,
  int streak = 3,
}) =>
    Challenge(
      id: id,
      title: 'Desafio $id',
      category: category,
      description: 'desc',
      xpReward: 300,
      totalDays: 30,
      currentDay: currentDay,
      streak: streak,
      lastActivityAt: DateTime.now(),
    );

class FakeChallengeRepository implements ChallengeRepository {
  List<Challenge> remote = [];
  bool throwOnList = false;
  Exception? completeException;

  @override
  Future<List<Challenge>> list() async {
    if (throwOnList) throw Exception('sem rede');
    return List.of(remote);
  }

  @override
  Future<Challenge> create({
    required String title,
    required ChallengeCategory category,
    required String description,
    required int xpReward,
    required int totalDays,
  }) async {
    final c = Challenge(
      id: 'new-${remote.length}',
      title: title,
      category: category,
      description: description,
      xpReward: xpReward,
      totalDays: totalDays,
    );
    remote.insert(0, c);
    return c;
  }

  @override
  Future<({Challenge challenge, int xpDelta, int totalXp})> completeDay(
      String id) async {
    if (completeException != null) throw completeException!;
    final c = remote.firstWhere((e) => e.id == id);
    return (challenge: c, xpDelta: 10, totalXp: 110);
  }

  @override
  Future<void> delete(String id) async {
    remote.removeWhere((e) => e.id == id);
  }

  @override
  Future<({String message, bool aiGenerated})> recommendation(String id) async =>
      (message: 'dica', aiGenerated: false);

  @override
  Future<List<ChallengeCompletion>> historico(String id) async => const [];

  @override
  Future<List<AtividadeDia>> atividade(DateTime desde) async => const [];
}

class FakeChallengeCache implements ChallengeCache {
  List<Challenge>? stored;

  @override
  Future<void> save(List<Challenge> challenges) async {
    stored = List.of(challenges);
  }

  @override
  Future<List<Challenge>> load() async =>
      stored == null ? <Challenge>[] : List.of(stored!);

  @override
  Future<void> clear() async {
    stored = null;
  }
}

void main() {
  late FakeChallengeRepository repo;
  late FakeChallengeCache cache;
  late ChallengeProvider provider;

  setUp(() {
    repo = FakeChallengeRepository();
    cache = FakeChallengeCache();
    provider = ChallengeProvider(repository: repo, cache: cache);
  });

  group('refresh', () {
    test('sucesso grava cache e mantém isStale = false', () async {
      repo.remote = [_challenge('a'), _challenge('b')];

      await provider.refresh();

      expect(provider.allChallenges.length, 2);
      expect(provider.isStale, isFalse);
      expect(cache.stored, isNotNull);
      expect(cache.stored!.length, 2);
    });

    test('falha de rede COM cache carrega do cache e marca isStale', () async {
      cache.stored = [_challenge('a')];
      repo.throwOnList = true;

      await provider.refresh();

      expect(provider.allChallenges.length, 1);
      expect(provider.isStale, isTrue);
    });

    test('falha de rede SEM cache mantém lista vazia e isStale = false',
        () async {
      repo.throwOnList = true;

      await provider.refresh();

      expect(provider.allChallenges, isEmpty);
      expect(provider.isStale, isFalse);
    });

    test('reconexão: refresh com sucesso limpa isStale', () async {
      cache.stored = [_challenge('a')];
      repo.throwOnList = true;
      await provider.refresh();
      expect(provider.isStale, isTrue);

      repo.throwOnList = false;
      repo.remote = [_challenge('a'), _challenge('b')];
      await provider.refresh();

      expect(provider.isStale, isFalse);
      expect(provider.allChallenges.length, 2);
    });
  });

  group('completeDay', () {
    test('propaga ApiException 409 (dia já concluído hoje)', () async {
      repo.remote = [_challenge('a')];
      await provider.refresh();
      repo.completeException =
          ApiException('Você já concluiu este desafio hoje.', 409);

      expect(
        () => provider.completeDay('a'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('sucesso atualiza o desafio local e retorna o delta', () async {
      repo.remote = [_challenge('a')];
      await provider.refresh();

      final result = await provider.completeDay('a');

      expect(result.xpDelta, 10);
      expect(result.totalXp, 110);
    });
  });

  group('filtro por categoria', () {
    test('challenges retorna apenas a categoria selecionada', () async {
      repo.remote = [
        _challenge('s1', category: ChallengeCategory.study),
        _challenge('f1', category: ChallengeCategory.fitness),
        _challenge('s2', category: ChallengeCategory.study),
      ];
      await provider.refresh();

      provider.selectCategory(ChallengeCategory.study);

      expect(provider.challenges.length, 2);
      expect(
        provider.challenges.every((c) => c.category == ChallengeCategory.study),
        isTrue,
      );
      expect(provider.allChallenges.length, 3);
    });
  });
}
