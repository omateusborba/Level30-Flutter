import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/challenge.dart';
import '../../data/service/api_client.dart';
import '../../domain/provider/challenge_provider.dart';

/// C2 · bottom sheet de replanejamento assistido por IA.
Future<void> showReplanSheet(BuildContext context, String challengeId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReplanSheet(challengeId: challengeId),
  );
}

class _ReplanSheet extends StatefulWidget {
  final String challengeId;
  const _ReplanSheet({required this.challengeId});

  @override
  State<_ReplanSheet> createState() => _ReplanSheetState();
}

class _ReplanSheetState extends State<_ReplanSheet> {
  ReplanSugestao? _sugestao;
  String? _erro;
  double _dias = 30;
  bool _aplicando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final s = await context
          .read<ChallengeProvider>()
          .getReplanSugestao(widget.challengeId);
      if (!mounted) return;
      setState(() {
        _sugestao = s;
        _dias = s.sugestaoDias.toDouble();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _erro = 'Não foi possível carregar a sugestão.');
    }
  }

  Future<void> _aplicar() async {
    setState(() => _aplicando = true);
    try {
      await context
          .read<ChallengeProvider>()
          .replanejar(widget.challengeId, _dias.toInt());
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Desafio replanejado para ${_dias.toInt()} dias.'),
          backgroundColor: AppColors.riskLow,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _aplicando = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: _erro != null
          ? _msg(_erro!)
          : _sugestao == null
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent)),
                )
              : _conteudo(_sugestao!),
    );
  }

  Widget _conteudo(ReplanSugestao s) {
    final semReplan = s.replanejamentosRestantes <= 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _grip(),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Text('Replanejar desafio',
                style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            s.mensagem,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13, height: 1.5),
          ),
        ),
        if (s.aiGenerated)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('sugestão do Guia do Level30',
                style: TextStyle(color: AppColors.textSecond, fontSize: 10)),
          ),
        const SizedBox(height: 16),
        if (semReplan)
          const Text(
            'Este desafio já foi replanejado 2 vezes — o limite. Foco no que falta! 💪',
            style: TextStyle(color: AppColors.textSecond, fontSize: 13),
          )
        else ...[
          Text('Nova duração: ${_dias.toInt()} dias',
              style: GoogleFonts.poppins(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          Text('era ${s.totalDaysAtual} · você está no dia ${s.currentDay}',
              style:
                  const TextStyle(color: AppColors.textSecond, fontSize: 11)),
          Slider(
            value: _dias.clamp(s.minDias.toDouble(), s.maxDias.toDouble()),
            min: s.minDias.toDouble(),
            max: s.maxDias.toDouble(),
            activeColor: AppColors.accent,
            inactiveColor: AppColors.surface2,
            label: '${_dias.toInt()} dias',
            onChanged: _aplicando ? null : (v) => setState(() => _dias = v),
          ),
          Text('${s.replanejamentosRestantes} replanejamento(s) restante(s)',
              style:
                  const TextStyle(color: AppColors.textSecond, fontSize: 11)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _aplicando ? null : _aplicar,
              child: Text(_aplicando ? 'Aplicando…' : 'Aplicar'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _grip() => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _msg(String t) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _grip(),
          const SizedBox(height: 16),
          Text(t,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecond)),
        ]),
      );
}
