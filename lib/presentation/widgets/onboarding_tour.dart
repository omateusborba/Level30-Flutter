import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../data/service/onboarding_service.dart';

class OnboardingTourKeys {
  static final xpBar = GlobalKey();
  static final motivCard = GlobalKey();
  static final categoryRow = GlobalKey();
  static final challengeCard = GlobalKey();
  static final fabButton = GlobalKey();
  static final bottomNav = GlobalKey();

  static List<GlobalKey> get all => [
        xpBar,
        motivCard,
        categoryRow,
        challengeCard,
        fabButton,
        bottomNav,
      ];
}

Future<void> startTourIfNeeded(
  BuildContext context, {
  bool includeChallengeCard = true,
}) async {
  final isFirst = await OnboardingService.isFirstTime();
  if (!isFirst) return;
  if (!context.mounted) return;

  final keys = includeChallengeCard
      ? OnboardingTourKeys.all
      : OnboardingTourKeys.all
          .where((k) => k != OnboardingTourKeys.challengeCard)
          .toList();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    ShowCaseWidget.of(context).startShowCase(keys);
  });
}

class TourStep extends StatelessWidget {
  final GlobalKey globalKey;
  final String title;
  final String description;
  final Widget child;

  const TourStep({
    super.key,
    required this.globalKey,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: globalKey,
      title: title,
      description: description,
      onToolTipClick: () => ShowCaseWidget.of(context).next(),
      tooltipBackgroundColor: const Color(0xFF1A3A5C),
      titleTextStyle: const TextStyle(
        color: Color(0xFF00FF9C),
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      descTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        height: 1.5,
      ),
      overlayColor: Colors.black,
      overlayOpacity: 0.82,
      targetBorderRadius: BorderRadius.circular(12),
      targetPadding: const EdgeInsets.all(8),
      child: child,
    );
  }
}
