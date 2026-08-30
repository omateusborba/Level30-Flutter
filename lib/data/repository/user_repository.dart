import '../model/user_profile.dart';

/// Resposta de autenticação (signup/login/refresh). Desde a Fase 5 (A2) o
/// backend rotaciona: `/auth/refresh` devolve um `refreshToken` NOVO e invalida
/// o anterior. Pode ser nulo em respostas antigas.
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

  /// Revoga a família do refresh token no servidor (A2). Best-effort.
  Future<void> logout(String refreshToken);

  Future<String> updateAvatar(String avatarDataUri);
}
