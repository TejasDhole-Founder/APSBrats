import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/auth/presentation/screens/login_screen.dart';
import 'package:apsbrat_frontend/features/auth/presentation/screens/splash_screen.dart';
import 'package:apsbrat_frontend/features/chat/presentation/screens/chat_screen.dart';
import 'package:apsbrat_frontend/features/classroom/presentation/screens/classroom_screen.dart';
import 'package:apsbrat_frontend/features/feed/presentation/screens/home_screen.dart';
import 'package:apsbrat_frontend/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_identity_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_schools_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_socials_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_verify_screen.dart';
import 'package:apsbrat_frontend/features/profile/presentation/screens/profile_screen.dart';
import 'package:apsbrat_frontend/features/search/presentation/screens/search_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Routes are nested so go_router builds a real back stack: the system back
// button pops to the previous screen instead of closing the app.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      if (state.matchedLocation != '/') return null;
      try {
        final userId = await ref.read(authRepositoryProvider).currentUserId();
        if (userId != null && userId.isNotEmpty) return '/home';
      } catch (_) {
        // Storage unreadable — treat as logged out and stay on the welcome screen.
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
        routes: [
          GoRoute(
            path: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: 'onboarding',
            builder: (context, state) => const OnboardingIdentityScreen(),
            routes: [
              GoRoute(
                path: 'verify',
                builder: (context, state) => const OnboardingVerifyScreen(),
                routes: [
                  GoRoute(
                    path: 'schools',
                    builder: (context, state) => const OnboardingSchoolsScreen(),
                    routes: [
                      GoRoute(
                        path: 'socials',
                        builder: (context, state) => const OnboardingSocialsScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: 'profile/:username',
            builder: (context, state) {
              return ProfileScreen(username: state.pathParameters['username'] ?? '');
            },
          ),
          GoRoute(
            path: 'classroom/:id',
            builder: (context, state) {
              return ClassroomScreen(classroomId: state.pathParameters['id'] ?? '');
            },
          ),
          GoRoute(
            path: 'chat/:conversationId',
            builder: (context, state) {
              return ChatScreen(
                conversationId: state.pathParameters['conversationId'] ?? '',
              );
            },
          ),
        ],
      ),
    ],
  );
});
