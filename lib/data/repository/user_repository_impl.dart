import '../model/user_profile.dart';
import '../service/api_client.dart';
import 'user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final ApiClient _api;

  UserRepositoryImpl({ApiClient? api}) : _api = api ?? ApiClient.instance;

  @override
  Future<UserProfile> me() async {
    final res = await _api.get('/me') as Map<String, dynamic>;
    return UserProfile.fromJson(res);
  }

  @override
  Future<AuthResult> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _api.post('/auth/signup', {
      'name': name,
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;
    return _toAuthResult(res);
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post('/auth/login', {
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;
    return _toAuthResult(res);
  }

  @override
  Future<String?> refresh(String refreshToken) async {
    final res = await _api.post('/auth/refresh', {
      'refreshToken': refreshToken,
    }) as Map<String, dynamic>;
    return res['token'] as String?;
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _api.post('/auth/logout', {'refreshToken': refreshToken});
  }

  @override
  Future<String> updateAvatar(String avatarDataUri) async {
    final res = await _api.put('/me/avatar', {'avatar': avatarDataUri})
        as Map<String, dynamic>;
    return res['avatar'] as String;
  }

  AuthResult _toAuthResult(Map<String, dynamic> res) => (
        token: res['token'] as String,
        refreshToken: res['refreshToken'] as String?,
        user: UserProfile.fromJson(res['user'] as Map<String, dynamic>),
      );
}
