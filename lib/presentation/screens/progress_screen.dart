import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/challenge.dart';
import '../../data/model/challenge_completion.dart';
import '../../domain/provider/challenge_provider.dart';
import '../widgets/activity_heatmap.dart';

/// B6 · "Meu Progresso" — visão de trajetória do estudante consigo mesmo.
/// Sem comparação com outros alunos (LGPD / fora do escopo).
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<AtividadeDia>? _atividade;
  bool _erro = false;

  static const _catCores = {
    ChallengeCategory.health: AppColors.riskLow,
    ChallengeCategory.study: AppColors.accent,
    ChallengeCategory.productivity: AppColors.riskMedium,
    ChallengeCategory.mindfulness: Color(0xFF60A5FA),
    ChallengeCategory.fitness: AppColors.riskHigh,
  };

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = false);
    try {
      final desde = DateTime.now().subtract(const Duration(days: 84));
      final res = await context.read<ChallengeProvider>().getAtividade(desde);
      if (mounted) setState(() => _atividade = res);
    } catch (_) {
      if (mounted) setState(() => _erro = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meu Progresso'),
        backgroundColor: AppColors.surface,
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        color: AppColors.accent,
        child: _erro
            ? _mensagem('Não foi possível carregar seu progresso.',
                acao: _carregar)
            : _atividade == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : _conteudo(_atividade!),
      ),
    );
  }

  Widget _conteudo(List<AtividadeDia> atividade) {
    final totalConclusoes = atividade.fold<int>(0, (s, a) => s + a.quantidade);
    if (totalConclusoes < 7) {
      return _mensagem(
        'Complete mais alguns dias de desafio para ver seus padrões aqui.\n'
        'Faltam ${7 - totalConclusoes} conclusões.',
      );
    }

    final cp = context.read<ChallengeProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _comparativoSemana(atividade),
        const SizedBox(height: 20),
        _card('XP acumulado', 'Sua evolução nas últimas 12 semanas.',
            SizedBox(height: 180, child: _linhaXp(atividade))),
        const SizedBox(height: 16),
        _card(
            'Consistência semanal',
            'Em que dia da semana você costuma concluir.',
            SizedBox(height: 180, child: _barrasDiaSemana(atividade))),
        const SizedBox(height: 16),
        _card('Onde está seu esforço', 'Desafios por categoria.',
            SizedBox(height: 200, child: _pizzaCategorias(cp.allChallenges))),
        const SizedBox(height: 16),
        _card(
            'Atividade', '12 semanas.', ActivityHeatmap(atividade: atividade)),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---- blocos ----

  Widget _comparativoSemana(List<AtividadeDia> atividade) {
    final agora = DateTime.now();
    int naJanela(int inicio, int fim) => atividade.where((a) {
          final d = agora.difference(a.data).inDays;
          return d >= inicio && d < fim;
        }).fold(0, (s, a) => s + a.quantidade);

    final estaSemana = naJanela(0, 7);
    final semanaPassada = naJanela(7, 14);
    final delta = estaSemana - semanaPassada;
    final texto = semanaPassada == 0
        ? 'Você concluiu $estaSemana dia(s) esta semana.'
        : delta == 0
            ? 'Mesmo ritmo da semana passada: $estaSemana dia(s).'
            : delta > 0
                ? '$delta a mais que a semana passada. Bom ritmo!'
                : '${-delta} a menos que a semana passada.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(delta >= 0 ? Icons.trending_up : Icons.trending_down,
              color: delta >= 0 ? AppColors.accent : AppColors.riskHigh),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto,
                style: GoogleFonts.poppins(
                    color: AppColors.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _linhaXp(List<AtividadeDia> atividade) {
    final ordenado = [...atividade]..sort((a, b) => a.data.compareTo(b.data));
    double acc = 0;
    final spots = <FlSpot>[];
    for (var i = 0; i < ordenado.length; i++) {
      acc += ordenado[i].xp;
      spots.add(FlSpot(i.toDouble(), acc));
    }
    if (spots.length < 2) spots.add(FlSpot(spots.length.toDouble(), acc));

    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: AppColors.border, strokeWidth: 1),
      ),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.accent,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
              show: true, color: AppColors.accent.withValues(alpha: 0.12)),
        ),
      ],
    ));
  }

  Widget _barrasDiaSemana(List<AtividadeDia> atividade) {
    final porDia = List<int>.filled(7, 0); // 0 = segunda
    for (final a in atividade) {
      porDia[a.data.weekday - 1] += a.quantidade;
    }
    const nomes = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    final maxY = (porDia.reduce((a, b) => a > b ? a : b))
        .toDouble()
        .clamp(1, double.infinity);

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY + 1,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(enabled: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(nomes[v.toInt() % 7],
                  style: const TextStyle(
                      color: AppColors.textSecond, fontSize: 11)),
            ),
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < 7; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: porDia[i].toDouble(),
              color: AppColors.accent,
              width: 16,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]),
      ],
    ));
  }

  Widget _pizzaCategorias(List<Challenge> challenges) {
    final contagem = <ChallengeCategory, int>{};
    for (final c in challenges) {
      contagem.update(c.category, (v) => v + 1, ifAbsent: () => 1);
    }
    if (contagem.isEmpty) {
      return const Center(
        child: Text('Sem desafios ainda.',
            style: TextStyle(color: AppColors.textSecond)),
      );
    }
    final total = contagem.values.fold<int>(0, (s, v) => s + v);
    return Row(
      children: [
        Expanded(
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 34,
            sections: [
              for (final e in contagem.entries)
                PieChartSectionData(
                  value: e.value.toDouble(),
                  color: _catCores[e.key],
                  title: '${(e.value * 100 / total).round()}%',
                  radius: 46,
                  titleStyle: const TextStyle(
                      color: AppColors.accentInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
            ],
          )),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in contagem.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: _catCores[e.key],
                          borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text('${e.key.displayName} (${e.value})',
                      style: const TextStyle(
                          color: AppColors.textSecond, fontSize: 12)),
                ]),
              ),
          ],
        ),
      ],
    );
  }

  // ---- helpers ----

  Widget _card(String titulo, String hint, Widget corpo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(hint,
              style:
                  const TextStyle(color: AppColors.textSecond, fontSize: 12)),
          const SizedBox(height: 14),
          corpo,
        ],
      ),
    );
  }

  Widget _mensagem(String texto, {Future<void> Function()? acao}) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.insights_outlined,
            color: AppColors.textSecond, size: 48),
        const SizedBox(height: 16),
        Text(texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecond, fontSize: 14)),
        if (acao != null) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(
                onPressed: acao, child: const Text('Tentar de novo')),
          ),
        ],
      ],
    );
  }
}
