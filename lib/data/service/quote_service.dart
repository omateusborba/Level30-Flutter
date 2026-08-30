/// Citações motivacionais. Só português — um app PT-BR não deve exibir frase em
/// idioma estrangeiro (a API ZenQuotes retornava tudo em inglês).
class QuoteService {
  static const _quotes = [
    '"A disciplina é a ponte entre metas e realizações." — Jim Rohn',
    '"Pequenos progressos diários levam a grandes resultados." — Robert Collier',
    '"Você não precisa ser ótimo para começar, mas precisa começar para ser ótimo." — Zig Ziglar',
    '"O sucesso é a soma de pequenos esforços repetidos dia após dia." — Robert Collier',
    '"Cada dia é uma nova chance de melhorar." — Anônimo',
    '"Motivação é o que te faz começar. Hábito é o que te mantém em movimento." — Jim Ryun',
    '"Não conte os dias, faça os dias contarem." — Muhammad Ali',
    '"A persistência realiza o impossível." — Provérbio chinês',
    '"Foco não é dizer sim para a coisa certa, é dizer não para mil outras." — Steve Jobs',
    '"O melhor momento para plantar uma árvore foi há 20 anos. O segundo melhor é agora." — Provérbio',
  ];

  Future<String> getMotivationalQuote() async {
    final index =
        DateTime.now().difference(DateTime(2026)).inDays % _quotes.length;
    return _quotes[index];
  }
}
