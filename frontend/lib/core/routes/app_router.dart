import 'package:apsbrat_frontend/features/auth/presentation/screens/login_screen.dart';
import 'package:apsbrat_frontend/features/auth/presentation/screens/splash_screen.dart';
import 'package:apsbrat_frontend/features/chat/presentation/screens/chat_screen.dart';
import 'package:apsbrat_frontend/features/classroom/presentation/screens/classroom_screen.dart';
import 'package:apsbrat_frontend/features/feed/presentation/screens/home_screen.dart';
import 'package:apsbrat_frontend/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_identity_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_schools_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_socials_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_verify_screen.dart';
import 'package:apsbrat_frontend/features/profile/presentation/screens/profile_screen.dart';
import 'package:apsbrat_frontend/features/search/presentation/screens/search_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/onboarding/identity',
        builder: (context, state) => const OnboardingIdentityScreen(),
      ),
      GoRoute(
        path: '/onboarding/verify',
        builder: (context, state) => const OnboardingVerifyScreen(),
      ),
      GoRoute(
        path: '/onboarding/schools',
        builder: (context, state) => const OnboardingSchoolsScreen(),
      ),
      GoRoute(
        path: '/onboarding/socials',
        builder: (context, state) => const OnboardingSocialsScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/profile/:username',
        builder: (context, state) {
          return ProfileScreen(username: state.pathParameters['username'] ?? '');
        },
      ),
      GoRoute(
        path: '/classroom/:id',
        builder: (context, state) {
          return ClassroomScreen(classroomId: state.pathParameters['id'] ?? '');
        },
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) {
          return ChatScreen(
            conversationId: state.pathParameters['conversationId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});
