import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';

import 'core/constants/app_theme.dart';
import 'data/service/notification_service.dart';
import 'data/service/onboarding_service.dart';
import 'domain/provider/challenge_provider.dart';
import 'domain/provider/notification_provider.dart';
import 'domain/provider/risk_provider.dart';
import 'domain/provider/user_provider.dart';
import 'presentation/screens/challenge_detail_screen.dart';
import 'presentation/screens/create_challenge_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/map_screen.dart';
import 'presentation/screens/notifications_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService().initialize();
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChallengeProvider()..init()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => RiskProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..init()),
      ],
      child: const Level30App(),
    ),
  );
}

class Level30App extends StatelessWidget {
  const Level30App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Level30',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: '/splash',
        routes: {
          '/splash'       : (_) => const SplashScreen(),
          '/login'        : (_) => const LoginScreen(),
          '/home'         : (_) => ShowCaseWidget(
            onFinish: () => OnboardingService.markAsSeen(),
            builder: (ctx) => const HomeScreen(),
          ),
          '/profile'      : (_) => const ProfileScreen(),
          '/map'          : (_) => const MapScreen(),
          '/create_challenge' : (_) => const CreateChallengeScreen(),
          '/notifications': (_) => const NotificationsScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/challenge') {
            final id = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => ChallengeDetailScreen(challengeId: id),
            );
          }
          return null;
        },
      );
}
