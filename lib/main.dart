import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';

import 'core/constants/app_theme.dart';
import 'data/repository/challenge_repository_impl.dart';
import 'data/repository/user_repository_impl.dart';
import 'data/service/challenge_cache.dart';
import 'data/service/notification_service.dart';
import 'data/service/onboarding_service.dart';
import 'domain/provider/challenge_provider.dart';
import 'domain/provider/chat_provider.dart';
import 'domain/provider/notification_provider.dart';
import 'domain/provider/user_provider.dart';
import 'presentation/screens/chat_screen.dart';
import 'presentation/screens/challenge_detail_screen.dart';
import 'presentation/screens/create_challenge_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/map_screen.dart';
import 'presentation/screens/notifications_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/programa_screen.dart';
import 'presentation/screens/progress_screen.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService.initialize falhou: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ChallengeProvider(
            repository: ChallengeRepositoryImpl(),
            cache: SharedPrefsChallengeCache(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(repository: UserRepositoryImpl()),
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..init()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
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
          '/splash': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/home': (_) => ShowCaseWidget(
                onFinish: () => OnboardingService.markAsSeen(),
                builder: (ctx) => const HomeScreen(),
              ),
          '/profile': (_) => const ProfileScreen(),
          '/progress': (_) => const ProgressScreen(),
          '/programa': (_) => const ProgramaScreen(),
          '/map': (_) => const MapScreen(),
          '/create_challenge': (_) => const CreateChallengeScreen(),
          '/notifications': (_) => const NotificationsScreen(),
          '/chat': (_) => const ChatScreen(),
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
