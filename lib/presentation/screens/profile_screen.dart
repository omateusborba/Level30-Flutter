import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/extensions/string_extensions.dart';
import '../../data/model/challenge.dart';
import '../../data/model/user_profile.dart';
import '../../data/service/api_client.dart';
import '../../data/service/onboarding_service.dart';
import '../../domain/provider/challenge_provider.dart';
import '../../domain/provider/user_provider.dart';
import '../widgets/app_bottom_nav.dart';
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
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

class _AvatarSection extends StatefulWidget {
  final UserProfile profile;
  const _AvatarSection({required this.profile});

  @override
  State<_AvatarSection> createState() => _AvatarSectionState();
}

class _AvatarSectionState extends State<_AvatarSection> {
  bool _uploading = false;

  Uint8List? _decodeAvatar(String? dataUri) {
    if (dataUri == null) return null;
    final commaIndex = dataUri.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      return base64Decode(dataUri.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickFrom(ImageSource source) async {
    Navigator.of(context).pop();
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      await context.read<UserProvider>().updateAvatar(dataUri);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.riskCritical),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar a foto. Tente novamente.'),
            backgroundColor: AppColors.riskCritical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
              title: Text('Câmera', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
              onTap: () => _pickFrom(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: Text('Galeria', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
              onTap: () => _pickFrom(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final avatarBytes = _decodeAvatar(profile.avatar);

    return Column(
      children: [
        GestureDetector(
          onTap: _uploading ? null : _showPicker,
          child: Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: AppColors.accent, width: 2),
                  image: avatarBytes != null
                      ? DecorationImage(image: MemoryImage(avatarBytes), fit: BoxFit.cover)
                      : null,
                ),
                child: avatarBytes == null
                    ? Center(
                        child: _uploading
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.accent),
                              )
                            : Text(
                                profile.name.initials,
                                style: GoogleFonts.poppins(
                                  color: AppColors.textPrimary,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      )
                    : _uploading
                        ? Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black45,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.accent),
                              ),
                            ),
                          )
                        : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                  child: const Icon(Icons.edit, size: 14, color: AppColors.background),
                ),
              ),
            ],
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

