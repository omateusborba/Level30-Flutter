import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/challenge.dart';

/// Cache local da lista de desafios (US-032). Permite abrir o app offline
/// exibindo o último estado conhecido.
abstract class ChallengeCache {
  Future<void> save(List<Challenge> challenges);

  /// Lista salva, ou vazia quando não há cache.
  Future<List<Challenge>> load();

  Future<void> clear();
}

class SharedPrefsChallengeCache implements ChallengeCache {
  static const _key = 'cache_challenges_v1';

  @override
  Future<void> save(List<Challenge> challenges) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(challenges.map((c) => c.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  @override
  Future<List<Challenge>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((j) => Challenge.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
