import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

/// Cliente HTTP para a API do Level30.
///
/// O token é gerenciado externamente (UserProvider) via [token] e
/// [onUnauthorized] é chamado quando o servidor responde 401 e não há como
/// recuperar a sessão, para permitir logout automático sem acoplar este
/// cliente ao provider.
///
/// Refresh token (US-033): ao receber 401, o cliente tenta uma única vez
/// `POST /auth/refresh` usando o token lido por [readRefreshToken]; se um novo
/// access token voltar, ele é aplicado (e propagado por [onAccessTokenRefreshed])
/// e a requisição original é repetida uma vez. Nunca há mais de uma tentativa
/// de refresh por requisição — sem loop.
///
/// A2 (rotação): o servidor devolve um refresh token NOVO a cada `/auth/refresh`
/// e invalida o anterior. É obrigatório persistir o novo via
/// [onRefreshTokenRotated] — senão a próxima renovação reapresenta um token já
/// consumido e o servidor derruba a sessão (detecção de reuso). Refreshes
/// concorrentes são serializados ([_refreshInFlight]) para não reapresentar o
/// mesmo token em duas chamadas.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? token;
  void Function()? onUnauthorized;

  /// Lê o refresh token persistido (secure storage). Ligado pelo UserProvider.
  Future<String?> Function()? readRefreshToken;

  /// Persiste o novo access token obtido no refresh. Ligado pelo UserProvider.
  void Function(String newAccessToken)? onAccessTokenRefreshed;

  /// Persiste o refresh token rotacionado (A2). Ligado pelo UserProvider.
  void Function(String newRefreshToken)? onRefreshTokenRotated;

  /// Refresh em andamento — evita duas chamadas reapresentarem o mesmo token.
  Future<bool>? _refreshInFlight;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<http.Response> _dispatch(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) {
    final uri = _uri(path);
    const timeout = Duration(seconds: 15);
    final encoded = body != null ? jsonEncode(body) : null;
    switch (method) {
      case 'GET':
        return http.get(uri, headers: _headers).timeout(timeout);
      case 'POST':
        return http
            .post(uri, headers: _headers, body: encoded)
            .timeout(timeout);
      case 'PUT':
        return http.put(uri, headers: _headers, body: encoded).timeout(timeout);
      case 'DELETE':
        return http.delete(uri, headers: _headers).timeout(timeout);
      default:
        throw ArgumentError('Método HTTP não suportado: $method');
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retried = false,
  }) async {
    final res = await _dispatch(method, path, body);
    if (res.statusCode == 401 && !retried) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(method, path, body: body, retried: true);
      }
    }
    return _handle(res);
  }

  /// Tenta obter um novo par de tokens. Retorna `true` se conseguiu.
  /// Não lança — qualquer falha resulta em `false` (cai no fluxo de 401).
  /// Serializa chamadas concorrentes: só um `/auth/refresh` por vez.
  Future<bool> _tryRefresh() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await readRefreshToken?.call();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final res = await http
          .post(
            _uri('/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
      if (decoded is! Map) return false;
      final newToken =
          decoded['token'] is String ? decoded['token'] as String : null;
      if (newToken == null) return false;
      token = newToken;
      onAccessTokenRefreshed?.call(newToken);
      // A2: persiste o refresh token rotacionado (obrigatório).
      final rotated = decoded['refreshToken'];
      if (rotated is String && rotated.isNotEmpty) {
        onRefreshTokenRotated?.call(rotated);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _handle(http.Response res) async {
    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('Sessão expirada. Faça login novamente.', 401);
    }
    if (res.statusCode == 204) return null;

    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    final message = (body is Map && body['error'] is String)
        ? body['error'] as String
        : 'Erro inesperado (${res.statusCode}).';
    throw ApiException(message, res.statusCode);
  }

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);
}
