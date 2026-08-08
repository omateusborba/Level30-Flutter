import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/extensions/string_extensions.dart';
import '../../data/model/challenge.dart';
import '../../data/model/user_profile.dart';
import '../../data/service/onboarding_service.dart';
import '../../domain/provider/challenge_provider.dart';
import '../../domain/provider/user_provider.dart';
import '../widgets/xp_progress_ring.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final cp = context.watch<ChallengeProvider>();
    final profile = up.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.accent),
            tooltip: 'Notificações',
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecond),
            tooltip: 'Sair',
            onPressed: () async {
              await context.read<UserProvider>().logOut();
              if (!context.mounted) return;
              context.read<ChallengeProvider>().clear();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Tooltip(
                message: 'Level30 é sempre Dark ⚡ — faz parte da identidade!',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dark_mode, color: AppColors.textSecond, size: 14),
                      SizedBox(width: 4),
                      Text('Dark',
                          style: TextStyle(
                              color: AppColors.textSecond, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar + nome
            _AvatarSection(profile: profile),
            const SizedBox(height: 24),

            // Anel XP
            XPProgressRing(
              progress: profile.xpProgress,
              centerLabel: 'Nível ${profile.level}',
              subLabel: '${profile.xpInLevel} / 500 XP',
              size: 160,
              strokeWidth: 12,
            ),
            const SizedBox(height: 8),
            Text(
              'Faltam ${profile.xpToNextLevel} XP para o próximo nível',
              style: GoogleFonts.poppins(
                color: AppColors.textSecond,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            _StatsGrid(cp: cp, profile: profile),
            const SizedBox(height: 24),

            // Marcos
            _MilestonesSection(cp: cp),
            const SizedBox(height: 24),

            // Rever tour
            TextButton.icon(
              onPressed: () async {
                await OnboardingService.reset();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Tour resetado! Volte para a Home para ver o guia.'),
                      backgroundColor: Color(0xFF1A3A5C),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.help_outline,
                  color: AppColors.accent, size: 18),
              label: const Text(
                'Rever tour do app',
                style: TextStyle(color: AppColors.textSecond, fontSize: 13),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(currentIndex: 2),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  final UserProfile profile;
  const _AvatarSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          child: Center(
            child: Text(
              profile.name.initials,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.name,
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          profile.rankTitle,
          style: GoogleFonts.poppins(
            color: AppColors.accent,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final ChallengeProvider cp;
  final UserProfile profile;

  const _StatsGrid({required this.cp, required this.profile});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('🎯', 'Ativos', '${cp.activeCount}'),
      ('✅', 'Concluídos', '${cp.completedCount}'),
      ('⚡', 'XP Total', '${profile.totalXp}'),
      ('🔥', 'Melhor streak', '${cp.bestStreak} dias'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: stats
          .map((s) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(s.$1,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          s.$3,
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      s.$2,
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecond, fontSize: 12),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _MilestonesSection extends StatelessWidget {
  final ChallengeProvider cp;
  const _MilestonesSection({required this.cp});

  @override
  Widget build(BuildContext context) {
    final reached = <(String, String)>[];
    for (final c in cp.allChallenges) {
      for (final m in [7, 14, 21, 30]) {
        if (c.currentDay >= m) {
          reached.add(('${c.title} — $m dias', c.category.emoji));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Marcos Atingidos',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (reached.isEmpty)
          const Text(
            'Continue seus desafios para desbloquear marcos!',
            style: TextStyle(color: AppColors.textSecond, fontSize: 13),
          )
        else
          ...reached.map(
            (m) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.riskMedium.withAlpha(102)),
              ),
              child: Row(
                children: [
                  Text(m.$2, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.$1,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13),
                    ),
                  ),
                  const Icon(Icons.star, color: AppColors.riskMedium, size: 16),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        if (i == currentIndex) return;
        switch (i) {
          case 0:
            Navigator.pushReplacementNamed(context, '/home');
          case 1:
            Navigator.pushNamed(context, '/map');
          case 2:
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), label: 'Início'),
        BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined), label: 'Mapa'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: 'Perfil'),
      ],
    );
  }
}
