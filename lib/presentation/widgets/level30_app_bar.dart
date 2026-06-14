import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/provider/user_provider.dart';
import 'xp_progress_ring.dart';

class Level30AppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const Level30AppBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        Consumer<UserProvider>(
          builder: (_, up, __) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                XPProgressRing(
                  progress: up.profile.xpProgress,
                  centerLabel: 'Nv${up.profile.level}',
                  size: 40,
                  strokeWidth: 4,
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${up.profile.totalXp} XP',
                      style: GoogleFonts.poppins(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      up.profile.rankTitle,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecond,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ...?actions,
      ],
    );
  }
}
