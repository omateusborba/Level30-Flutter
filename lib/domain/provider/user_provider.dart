import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/model/user_profile.dart';
import '../../data/repository/user_repository.dart';
import '../../data/repository/user_repository_impl.dart';
import '../../data/service/api_client.dart';

class UserProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';

  final UserRepository _repository;

  UserProfile _profile = const UserProfile();
  String? _token;
  bool _restoring = true;

  UserProfile get profile => _profile;
  bool get isAuthenticated => _token != null;
  bool get isRestoringSession => _restoring;

  UserProvider({UserRepository? repository})
      : _repository = repository ?? UserRepositoryImpl() {
    final api = ApiClient.instance;
    api.onUnauthorized = _handleUnauthorized;
    // US-033: o ApiClient tenta o refresh sozinho ao receber 401; aqui só
    // fornecemos como ler o refresh token e onde guardar o novo access token.
    api.readRefreshToken = () => _storage.read(key: _keyRefreshToken);
    api.onAccessTokenRefreshed = _persistRefreshedToken;
    // A2: o refresh token é rotacionado a cada uso — persistir o novo é obrigatório.
    api.onRefreshTokenRotated =
        (rt) => _storage.write(key: _keyRefreshToken, value: rt);
  }

  /// Tenta restaurar uma sessão salva (chamado no boot do app, na Splash).
  Future<void> restoreSession() async {
    final stored = await _storage.read(key: _keyToken);
    if (stored == null) {
      _restoring = false;
      notifyListeners();
      return;
    }
    _token = stored;
    ApiClient.instance.token = stored;
    try {
      // Se o access token estiver expirado, o ApiClient faz o refresh e
      // repete a chamada de forma transparente.
      _profile = await _repository.me();
    } catch (_) {
      await _clearSession();
    }
    _restoring = false;
    notifyListeners();
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _repository.signup(
      name: name,
      email: email,
      password: password,
    );
    await _applyAuthResponse(res);
  }

  Future<void> logIn({required String email, required String password}) async {
    final res = await _repository.login(email: email, password: password);
    await _applyAuthResponse(res);
  }

  Future<void> logOut() async {
    // A2: revoga a família no servidor (best-effort — não bloqueia o logout local).
    final rt = await _storage.read(key: _keyRefreshToken);
    if (rt != null && rt.isNotEmpty) {
      try {
        await _repository.logout(rt);
      } catch (_) {
        // ignora — a sessão local é limpa de qualquer forma
      }
    }
    await _clearSession();
    notifyListeners();
  }

  /// Sincroniza o XP local com o valor confirmado pelo servidor após uma ação
  /// (ex: completar um dia de desafio), sem precisar rebuscar /me inteiro.
  void syncTotalXp(int totalXp) {
    _profile = _profile.copyWith(totalXp: totalXp);
    notifyListeners();
  }

  /// Envia a foto (já em data URI base64) para o backend e atualiza o perfil local.
  Future<void> updateAvatar(String avatarDataUri) async {
    final avatar = await _repository.updateAvatar(avatarDataUri);
    _profile = _profile.copyWith(avatar: avatar);
    notifyListeners();
  }

  Future<void> _applyAuthResponse(AuthResult res) async {
    _token = res.token;
    _profile = res.user;
    ApiClient.instance.token = _token;
    await _storage.write(key: _keyToken, value: _token);
    if (res.refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: res.refreshToken);
    }
    notifyListeners();
  }

  Future<void> _persistRefreshedToken(String newAccessToken) async {
    _token = newAccessToken;
    await _storage.write(key: _keyToken, value: newAccessToken);
  }

  Future<void> _clearSession() async {
    _token = null;
    _profile = const UserProfile();
    ApiClient.instance.token = null;
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  void _handleUnauthorized() {
    _clearSession();
    notifyListeners();
  }
}
