import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/model/user_profile.dart';
import '../../data/service/api_client.dart';

class UserProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'auth_token';

  UserProfile _profile = const UserProfile();
  String? _token;
  bool _restoring = true;

  UserProfile get profile => _profile;
  bool get isAuthenticated => _token != null;
  bool get isRestoringSession => _restoring;

  UserProvider() {
    ApiClient.instance.onUnauthorized = _handleUnauthorized;
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
      final me = await ApiClient.instance.get('/me');
      _profile = UserProfile.fromJson(me as Map<String, dynamic>);
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
    final res = await ApiClient.instance.post('/auth/signup', {
      'name': name,
      'email': email,
      'password': password,
    });
    await _applyAuthResponse(res as Map<String, dynamic>);
  }

  Future<void> logIn({required String email, required String password}) async {
    final res = await ApiClient.instance.post('/auth/login', {
      'email': email,
      'password': password,
    });
    await _applyAuthResponse(res as Map<String, dynamic>);
  }

  Future<void> logOut() async {
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
    final res = await ApiClient.instance.put('/me/avatar', {'avatar': avatarDataUri});
    _profile = _profile.copyWith(avatar: (res as Map<String, dynamic>)['avatar'] as String);
    notifyListeners();
  }

  Future<void> _applyAuthResponse(Map<String, dynamic> res) async {
    _token = res['token'] as String;
    _profile = UserProfile.fromJson(res['user'] as Map<String, dynamic>);
    ApiClient.instance.token = _token;
    await _storage.write(key: _keyToken, value: _token);
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _token = null;
    _profile = const UserProfile();
    ApiClient.instance.token = null;
    await _storage.delete(key: _keyToken);
  }

  void _handleUnauthorized() {
    _clearSession();
    notifyListeners();
  }
}
