import 'dart:convert';
import 'package:http/http.dart' as http;

class QuoteService {
  static const _fallbacks = [
    '"A disciplina é a ponte entre metas e realizações." — Jim Rohn',
    '"Pequenos progressos diários levam a grandes resultados." — Satya Nava',
    '"Você não precisa ser ótimo para começar, mas precisa começar para ser ótimo." — Zig Ziglar',
    '"O sucesso é a soma de pequenos esforços repetidos dia após dia." — Robert Collier',
    '"Cada dia é uma nova chance de melhorar." — Anônimo',
  ];

  Future<String> getMotivationalQuote() async {
    try {
      final res = await http
          .get(Uri.parse('https://zenquotes.io/api/random'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        final q = data.first as Map<String, dynamic>;
        return '"${q['q']}" — ${q['a']}';
      }
    } catch (_) {}
    return _fallbacks[DateTime.now().second % _fallbacks.length];
  }
}
