import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/provider/challenge_provider.dart';
import '../../domain/provider/user_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final userProvider = context.read<UserProvider>();
    final minDelay = Future.delayed(const Duration(milliseconds: 2500));

    await userProvider.restoreSession();
    await minDelay;
    if (!mounted) return;

    if (userProvider.isAuthenticated) {
      await context.read<ChallengeProvider>().refresh();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Anel "30" com círculo de progresso
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    value: null,
                    strokeWidth: 3,
                    color: AppColors.accent.withAlpha(102),
                  ),
                ),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '30',
                      style: GoogleFonts.poppins(
                        color: AppColors.accent,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
            const SizedBox(height: 24),
            Text(
              'Level30',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 8),
            Text(
              'Smart HAS',
              style: GoogleFonts.poppins(
                color: AppColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 4,
              ),
            ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
            const SizedBox(height: 60),
            Text(
              'Gamificação de Hábitos Acadêmicos',
              style: GoogleFonts.poppins(
                color: AppColors.textSecond,
                fontSize: 12,
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 500.ms),
          ],
        ),
      ),
    );
  }
}
