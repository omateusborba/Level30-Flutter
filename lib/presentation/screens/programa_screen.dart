import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/challenge.dart';
import '../../data/service/api_client.dart';
import '../../domain/provider/challenge_provider.dart';

/// C3 · "Desafios do programa" — o aluno navega e adota modelos da coordenação.
class ProgramaScreen extends StatefulWidget {
  const ProgramaScreen({super.key});

  @override
  State<ProgramaScreen> createState() => _ProgramaScreenState();
}

class _ProgramaScreenState extends State<ProgramaScreen> {
  List<ProgramChallenge>? _lista;
  String? _erro;
  String? _adotando;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final r = await context.read<ChallengeProvider>().getPrograma();
      if (mounted) setState(() => _lista = r);
    } catch (_) {
      if (mounted)
        setState(
            () => _erro = 'Não foi possível carregar os desafios do programa.');
    }
  }

  Future<void> _adotar(ProgramChallenge p) async {
    setState(() => _adotando = p.id);
    try {
      await context.read<ChallengeProvider>().adotarPrograma(p.id);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${p.title}" adicionado aos seus desafios.'),
          backgroundColor: AppColors.riskLow,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _adotando = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Desafios do programa'),
        backgroundColor: AppColors.surface,
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        color: AppColors.accent,
        child: _erro != null
            ? _msg(_erro!)
            : _lista == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : _lista!.isEmpty
                    ? _msg('A coordenação ainda não publicou desafios.')
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _lista!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _card(_lista![i]),
                      ),
      ),
    );
  }

  Widget _card(ProgramChallenge p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(p.category.icon, color: p.category.color, size: 16),
              const SizedBox(width: 6),
              Text(p.category.displayName.toUpperCase(),
                  style: GoogleFonts.poppins(
                      color: p.category.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(p.title,
              style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(p.description,
              style: const TextStyle(
                  color: AppColors.textSecond, fontSize: 13, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip('${p.totalDays} dias'),
              const SizedBox(width: 8),
              _chip('${p.xpReward} XP'),
              const SizedBox(width: 8),
              if (p.adotantes > 0) _chip('${p.adotantes} adotaram'),
              const Spacer(),
              if (p.adotado)
                const Text('Já adotei ✓',
                    style: TextStyle(
                        color: AppColors.riskLow,
                        fontSize: 12,
                        fontWeight: FontWeight.w600))
              else
                ElevatedButton(
                  onPressed: _adotando == p.id ? null : () => _adotar(p),
                  child: Text(_adotando == p.id ? '...' : 'Adotar'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.surface2, borderRadius: BorderRadius.circular(6)),
        child: Text(t,
            style: const TextStyle(color: AppColors.textSecond, fontSize: 11)),
      );

  Widget _msg(String t) => ListView(
        padding: const EdgeInsets.all(40),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.workspaces_outline,
              color: AppColors.textSecond, size: 48),
          const SizedBox(height: 16),
          Text(t,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textSecond, fontSize: 14)),
        ],
      );
}
