import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/challenge.dart';
import '../../data/model/risk_assessment.dart';
import '../../domain/provider/challenge_provider.dart';
import '../../domain/provider/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _sending = false;
  int? _lastSent;

  Future<void> _pickTime(NotificationProvider np) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: np.hour, minute: np.minute),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: AppColors.background,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      await np.setReminderTime(picked.hour, picked.minute);
    }
  }

  Future<void> _notifyRisks(BuildContext context) async {
    setState(() { _sending = true; _lastSent = null; });
    final cp = context.read<ChallengeProvider>();
    final np = context.read<NotificationProvider>();
    final count = await np.checkAndNotify(
      challenges: cp.allChallenges,
      risks: cp.getAllRisks(),
    );
    if (mounted) setState(() { _sending = false; _lastSent = count; });
  }

  Future<void> _sendTest(NotificationProvider np) async {
    setState(() => _sending = true);
    await np.sendTest();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NotificationProvider>();
    final cp = context.watch<ChallengeProvider>();
    final risks = cp.getAllRisks();
    risks.sort((a, b) => b.riskScore.compareTo(a.riskScore));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Notificações',
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Ativar / desativar ───────────────────────────────────────────
          _Card(
            child: SwitchListTile(
              value: np.enabled,
              onChanged: np.setEnabled,
              activeThumbColor: AppColors.accent,
              activeTrackColor: AppColors.accent.withAlpha(100),
              title: Text('Notificações ativas',
                  style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              subtitle: Text(
                np.enabled
                    ? 'Você receberá alertas de risco e lembretes diários'
                    : 'Nenhuma notificação será enviada',
                style: GoogleFonts.poppins(
                    color: AppColors.textSecond, fontSize: 12),
              ),
              secondary: Icon(
                np.enabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: np.enabled ? AppColors.accent : AppColors.textSecond,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Lembrete diário ──────────────────────────────────────────────
          _SectionTitle('Lembrete Diário'),
          const SizedBox(height: 8),
          _Card(
            child: ListTile(
              enabled: np.enabled,
              leading: const Icon(Icons.access_time, color: AppColors.accent),
              title: Text('Horário do lembrete',
                  style: GoogleFonts.poppins(color: AppColors.textPrimary)),
              subtitle: Text(
                'Todo dia às ${np.timeLabel}',
                style:
                    GoogleFonts.poppins(color: AppColors.textSecond, fontSize: 12),
              ),
              trailing: Text(
                np.timeLabel,
                style: GoogleFonts.poppins(
                    color: AppColors.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              onTap: np.enabled ? () => _pickTime(np) : null,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Toque para alterar o horário do lembrete diário',
              style:
                  GoogleFonts.poppins(color: AppColors.textSecond, fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),

          // ── Ações manuais ────────────────────────────────────────────────
          _SectionTitle('Ações'),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.science_outlined,
                      color: AppColors.accent),
                  title: Text('Enviar notificação de teste',
                      style:
                          GoogleFonts.poppins(color: AppColors.textPrimary)),
                  subtitle: Text('Confirme que as notificações chegam',
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecond, fontSize: 12)),
                  trailing: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent))
                      : const Icon(Icons.chevron_right,
                          color: AppColors.textSecond),
                  onTap: _sending || !np.enabled
                      ? null
                      : () => _sendTest(np),
                ),
                const Divider(color: AppColors.primary, height: 1),
                ListTile(
                  leading: const Icon(Icons.warning_amber_outlined,
                      color: AppColors.riskHigh),
                  title: Text('Notificar desafios em risco',
                      style:
                          GoogleFonts.poppins(color: AppColors.textPrimary)),
                  subtitle: Text(
                    _lastSent == null
                        ? 'Envia alertas para todos os desafios com risco > baixo'
                        : _lastSent == 0
                            ? 'Nenhum desafio em risco agora'
                            : '$_lastSent notificação(ões) enviada(s)',
                    style: GoogleFonts.poppins(
                        color: _lastSent != null && _lastSent! > 0
                            ? AppColors.accent
                            : AppColors.textSecond,
                        fontSize: 12),
                  ),
                  trailing: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent))
                      : const Icon(Icons.chevron_right,
                          color: AppColors.textSecond),
                  onTap: _sending || !np.enabled
                      ? null
                      : () => _notifyRisks(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Status dos desafios ──────────────────────────────────────────
          _SectionTitle('Status dos Desafios'),
          const SizedBox(height: 8),
          ...risks.map((risk) {
            final challenge = cp.allChallenges.firstWhere(
              (c) => c.id == risk.challengeId,
            );
            final Color riskColor = switch (risk.riskLevel) {
              RiskLevel.low => AppColors.riskLow,
              RiskLevel.medium => AppColors.riskMedium,
              RiskLevel.high => AppColors.riskHigh,
              RiskLevel.critical => AppColors.riskCritical,
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: ListTile(
                leading: Text(challenge.category.emoji,
                    style: const TextStyle(fontSize: 22)),
                title: Text(challenge.title,
                    style: GoogleFonts.poppins(
                        color: AppColors.textPrimary, fontSize: 14)),
                subtitle: Text(
                  risk.suggestedAction.message,
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecond, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: riskColor),
                  ),
                  child: Text(
                    '${(risk.riskScore * 100).toInt()}%',
                    style: TextStyle(
                        color: riskColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.poppins(
          color: AppColors.textSecond,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
        ),
        child: child,
      );
}
