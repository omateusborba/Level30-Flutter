import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const _base = 'https://api.open-meteo.com/v1/forecast';

  Future<Map<String, dynamic>?> getCurrentWeather(
      double lat, double lon) async {
    try {
      final uri =
          Uri.parse('$_base?latitude=$lat&longitude=$lon&current_weather=true');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['current_weather'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  String getWeatherDescription(int? weatherCode) {
    if (weatherCode == null) return 'Tempo desconhecido';
    if (weatherCode <= 3) return '☀️ Ensolarado';
    if (weatherCode <= 49) return '☁️ Nublado';
    if (weatherCode <= 67) return '🌧️ Chuvoso';
    if (weatherCode <= 77) return '❄️ Neve';
    return '⛈️ Tempestade';
  }

  String getChallengeRecommendation(int? weatherCode) {
    if (weatherCode == null) return 'Estudos';
    if (weatherCode <= 3) return 'Fitness';
    if (weatherCode <= 67) return 'Estudos';
    return 'Mindfulness';
  }

  String getWeatherEmoji(int? weatherCode) {
    if (weatherCode == null) return '🌡️';
    if (weatherCode <= 3) return '☀️';
    if (weatherCode <= 49) return '☁️';
    if (weatherCode <= 67) return '🌧️';
    if (weatherCode <= 77) return '❄️';
    return '⛈️';
  }
}
