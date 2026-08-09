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

/// Cliente HTTP para a API do Level30 (Cloudflare Worker).
/// O token é gerenciado externamente (UserProvider) via [token] e
/// [onUnauthorized] é chamado sempre que o servidor responde 401,
/// para permitir logout automático sem acoplar este cliente ao provider.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? token;
  void Function()? onUnauthorized;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

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

  Future<dynamic> get(String path) async {
    final res = await http.get(_uri(path), headers: _headers).timeout(const Duration(seconds: 15));
    return _handle(res);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final res = await http
        .post(_uri(path), headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(const Duration(seconds: 15));
    return _handle(res);
  }

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final res = await http
        .put(_uri(path), headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(const Duration(seconds: 15));
    return _handle(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http.delete(_uri(path), headers: _headers).timeout(const Duration(seconds: 15));
    return _handle(res);
  }
}
