import 'package:flutter_test/flutter_test.dart';
import 'package:level30/core/constants/app_config.dart';
import 'package:level30/data/model/challenge.dart';
import 'package:level30/data/repository/challenge_repository_impl.dart';
import 'package:level30/data/repository/user_repository_impl.dart';
import 'package:level30/data/service/api_client.dart';

/// Teste de integração da camada de dados do app contra a API Spring Boot rodando.
///
/// Desligado por padrão — o `flutter test` normal não precisa do backend.
/// Para rodar (requer `backend/` de pé com o seed):
///   flutter test --dart-define=BACKEND_IT=true \
///     --dart-define=API_BASE_URL=http://localhost:8080 \
///     test/integration/backend_smoke_test.dart
const _enabled = bool.fromEnvironment('BACKEND_IT', defaultValue: false);

void main() {
  if (!_enabled) {
    test('backend integration (desligado — passe --dart-define=BACKEND_IT=true)',
        () {}, skip: true);
    return;
  }

  final api = ApiClient.instance;
  final userRepo = UserRepositoryImpl();
  final challengeRepo = ChallengeRepositoryImpl();

  setUpAll(() {
    expect(AppConfig.apiBaseUrl, startsWith('http'),
        reason: 'defina --dart-define=API_BASE_URL=<url do backend>');
  });

  test('signup -> me -> repositório de usuário', () async {
    final email = 'it_${DateTime.now().microsecondsSinceEpoch}@test.com';
    final auth = await userRepo.signup(
        name: 'IT User', email: email, password: 'segredo123');

    expect(auth.token, isNotEmpty);
    expect(auth.refreshToken, isNotNull);
    expect(auth.user.totalXp, 0);

    api.token = auth.token;
    final me = await userRepo.me();
    expect(me.name, 'IT User');
    expect(me.level, 1);
  });

  test('ciclo completo de desafio via ChallengeRepository', () async {
    final email = 'it_${DateTime.now().microsecondsSinceEpoch}@test.com';
    final auth = await userRepo.signup(
        name: 'IT Challenge', email: email, password: 'segredo123');
    api.token = auth.token;

    final created = await challengeRepo.create(
      title: 'Ler todo dia',
      category: ChallengeCategory.study,
      description: 'pelo menos 15 min',
      xpReward: 300,
      totalDays: 30,
    );
    expect(created.currentDay, 0);
    expect(created.category, ChallengeCategory.study);

    final list = await challengeRepo.list();
    expect(list, hasLength(1));

    final done = await challengeRepo.completeDay(created.id);
    expect(done.challenge.currentDay, 1);
    expect(done.challenge.streak, 1);
    expect(done.xpDelta, 10); // earnedXp(1,30,300) - earnedXp(0,...) = 10
    expect(done.totalXp, 10);

    // 2º complete no mesmo dia -> 409 propagado como ApiException
    await expectLater(
      challengeRepo.completeDay(created.id),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
    );

    final rec = await challengeRepo.recommendation(created.id);
    expect(rec.message, isNotEmpty);
    expect(rec.aiGenerated, isFalse); // gateway de IA offline -> fallback

    await challengeRepo.delete(created.id);
    expect(await challengeRepo.list(), isEmpty);
  });

  test('refresh token: access expirado -> ApiClient renova sozinho', () async {
    final email = 'it_${DateTime.now().microsecondsSinceEpoch}@test.com';
    final auth = await userRepo.signup(
        name: 'IT Refresh', email: email, password: 'segredo123');

    // simula o wiring do UserProvider
    api.token = auth.token;
    api.readRefreshToken = () async => auth.refreshToken;
    var refreshedTo = '';
    api.onAccessTokenRefreshed = (t) => refreshedTo = t;

    // força 401: token de acesso obviamente inválido
    api.token = 'ey.invalid.token';
    final me = await userRepo.me(); // deve disparar o refresh e repetir
    expect(me.name, 'IT Refresh');
    expect(refreshedTo, isNotEmpty);
    expect(api.token, refreshedTo);

    api.readRefreshToken = null;
    api.onAccessTokenRefreshed = null;
  });
}
