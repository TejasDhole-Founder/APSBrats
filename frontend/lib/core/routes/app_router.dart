import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/auth/presentation/screens/login_screen.dart';
import 'package:apsbrat_frontend/features/auth/presentation/screens/splash_screen.dart';
import 'package:apsbrat_frontend/features/chat/presentation/screens/chat_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_chat_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/event_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/my_communities_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/post_screen.dart';
import 'package:apsbrat_frontend/features/connections/presentation/requests_screen.dart';
import 'package:apsbrat_frontend/features/feed/presentation/screens/home_screen.dart';
import 'package:apsbrat_frontend/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:apsbrat_frontend/features/settings/presentation/blocked_users_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_after_school_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_identity_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_schools_screen.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_socials_screen.dart';
import 'package:apsbrat_frontend/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:apsbrat_frontend/features/profile/presentation/screens/edit_schools_screen.dart';
import 'package:apsbrat_frontend/features/profile/presentation/screens/profile_screen.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Routes are nested so go_router builds a real back stack: the system back
// button pops to the previous screen instead of closing the app.
final appRouterProvider = Provider<GoRouter>((ref) {
  // The saved-session shortcut below is for app launch only. Later visits to
  // '/' (e.g. the back arrow on the login screen) must show the welcome screen,
  // not bounce a half-registered user back into onboarding.
  var firstNavigation = true;
  return GoRouter(
    initialLocation: '/',
    // A stale link or a mistyped web address lands here instead of a red error screen.
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: EmptyState(
        icon: HugeIcons.strokeRoundedUnlink01,
        title: "This page doesn't exist",
        message:
            'The link may be old, or the post or person may have been removed.',
        action: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Go to Home'),
        ),
      ),
    ),
    redirect: (context, state) async {
      final isLaunch = firstNavigation;
      firstNavigation = false;
      // A page reload (web) can land straight on a registration screen, so
      // load the saved draft before it is built.
      if (state.matchedLocation.startsWith('/onboarding')) {
        // Registration fills in an account that already exists, and the
        // account only exists once the email OTP (or Google) is verified.
        // No verified session yet -> send them to verify their email first.
        String? userId;
        try {
          userId = await ref.read(authRepositoryProvider).currentUserId();
        } catch (_) {
          // Storage unreadable — same as not verified.
        }
        if (userId == null || userId.isEmpty) return '/login?mode=signup';
        await ref.read(onboardingFlowProvider.notifier).hydrate();
        return null;
      }
      // Everything under /home needs a signed-in user. A logged-out visitor
      // (a shared link, a reload after the session expired) is sent to log in
      // and brought back here afterwards.
      if (state.matchedLocation.startsWith('/home')) {
        String? userId;
        try {
          userId = await ref.read(authRepositoryProvider).currentUserId();
        } catch (_) {
          // Storage unreadable — same as signed out.
        }
        if (userId == null || userId.isEmpty) {
          return '/login?from=${Uri.encodeQueryComponent(state.uri.toString())}';
        }
        return null;
      }
      final atWelcome = state.matchedLocation == '/';
      if (!atWelcome && state.matchedLocation != '/login') return null;
      try {
        final repo = ref.read(authRepositoryProvider);
        final userId = await repo.currentUserId();
        if (userId == null || userId.isEmpty) return null;
        // Signed in and set up: the welcome and login screens have nothing to
        // offer, so the browser/system back button must not land on them.
        if (await repo.onboardingDone()) return '/home';
        // Signed in but never finished the onboarding profile step (e.g. the
        // app was closed mid-flow) — resume there on launch. Later visits to
        // the welcome screen (the login back arrow) are left alone.
        if (isLaunch && atWelcome) {
          return await resumeOnboardingRoute(
            ref.read(onboardingFlowProvider.notifier),
          );
        }
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
            builder: (context, state) => LoginScreen(
              signUp: state.uri.queryParameters['mode'] == 'signup',
              from: state.uri.queryParameters['from'],
            ),
          ),
          GoRoute(
            path: 'onboarding',
            builder: (context, state) => const OnboardingIdentityScreen(),
            routes: [
              GoRoute(
                path: 'schools',
                builder: (context, state) => const OnboardingSchoolsScreen(),
                routes: [
                  // Students: schools -> socials.
                  GoRoute(
                    path: 'socials',
                    builder: (context, state) =>
                        const OnboardingSocialsScreen(),
                  ),
                  // Alumni: schools -> after school -> socials. Nested so the
                  // back button returns to the After school step.
                  GoRoute(
                    path: 'after-school',
                    builder: (context, state) =>
                        const OnboardingAfterSchoolScreen(),
                    routes: [
                      GoRoute(
                        path: 'socials',
                        builder: (context, state) =>
                            const OnboardingSocialsScreen(),
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
            path: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: 'requests',
            builder: (context, state) => const RequestsScreen(),
          ),
          GoRoute(
            path: 'blocked',
            builder: (context, state) => const BlockedUsersScreen(),
          ),
          GoRoute(
            path: 'edit-profile',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: 'edit-schools',
            builder: (context, state) => const EditSchoolsScreen(),
          ),
          GoRoute(
            path: 'profile/:id',
            builder: (context, state) {
              return ProfileScreen(userId: state.pathParameters['id'] ?? '');
            },
          ),
          GoRoute(
            path: 'communities',
            builder: (context, state) => const MyCommunitiesScreen(),
          ),
          GoRoute(
            path: 'community/:id',
            // Keyed by id so moving between communities never reuses the
            // previous one's scroll position or collapsed header.
            builder: (context, state) => CommunityScreen(
              key: ValueKey(state.pathParameters['id']),
              communityId: state.pathParameters['id'] ?? '',
            ),
            routes: [
              GoRoute(
                path: 'requests',
                builder: (context, state) => JoinRequestsScreen(
                  communityId: state.pathParameters['id'] ?? '',
                ),
              ),
              GoRoute(
                path: 'chat',
                builder: (context, state) => CommunityChatScreen(
                  communityId: state.pathParameters['id'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'event/:id',
            builder: (context, state) =>
                EventScreen(eventId: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: 'post/:id',
            builder: (context, state) =>
                PostScreen(postId: state.pathParameters['id'] ?? ''),
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
