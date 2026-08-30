import '../model/user_profile.dart';

/// Resposta de autenticação (signup/login). `refreshToken` pode ser nulo
/// (o backend não o reenvia no refresh).
typedef AuthResult = ({String token, String? refreshToken, UserProfile user});

/// Contrato de acesso a dados de usuário/sessão.
abstract class UserRepository {
  Future<UserProfile> me();

  Future<AuthResult> signup({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthResult> login({
    required String email,
    required String password,
  });

  /// Troca um refresh token por um novo access token. Retorna `null` se o
  /// refresh for inválido/expirado.
  Future<String?> refresh(String refreshToken);

  Future<String> updateAvatar(String avatarDataUri);
}
