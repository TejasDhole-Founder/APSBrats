# APSBrats Frontend Guide (Flutter)

The mobile/web client. Talks to the API in [`API.md`](./API.md).

---

## 1. Tech stack
| Concern | Choice |
|---------|--------|
| Framework | Flutter (Dart 3) |
| State management | Riverpod (`flutter_riverpod`) |
| Routing | `go_router` |
| HTTP | `dio` (+ `pretty_dio_logger`) |
| Secure storage | `flutter_secure_storage` (tokens) |
| Forms | `reactive_forms` |
| Other | `cached_network_image`, `image_picker`, `intl`, `firebase_messaging`, `socket_io_client` (future realtime) |

App package name: `apsbrat_frontend` (imports use `package:apsbrat_frontend/...`).

---

## 2. Project structure — feature-first

```
lib/
├── main_dev.dart / main_staging.dart / main_prod.dart   # flavor entry points
├── app.dart                                             # MaterialApp.router + flavor banner
├── core/
│   ├── constants/   env.dart · api_endpoints.dart · app_strings.dart · asset_paths.dart
│   ├── models/      person.dart            # shared Person (mirrors backend PersonDto)
│   ├── network/     dio_client.dart · api_response.dart · app_config_provider.dart
│   ├── routes/      app_router.dart        # go_router config
│   ├── theme/       app_theme.dart · app_color_palette.dart (AppColors)
│   ├── utils/       date_utils.dart · validators.dart
│   └── widgets/     shared UI (gold_button, dark_input_field, ...)
└── features/<feature>/
    ├── data/         models + repository (+ Riverpod providers)
    ├── domain/       (placeholder stubs for now)
    └── presentation/ screens/ · widgets/ · providers/
```

Each feature mirrors a backend module: `auth, feed, community, chat, connections, notifications, search, profile, onboarding, classroom`.

---

## 3. Networking layer

`core/network/dio_client.dart` exposes `dioProvider`:
- Base URL from `Env.baseUrl` (`http://localhost:8080/api`, override via `--dart-define=BASE_URL=...`).
- An interceptor reads `access_token` from secure storage and adds `Authorization: Bearer <token>` to every request.
- Pretty logging in non-prod builds.

Responses are the `{ success, message, data, error }` envelope. Repositories read the payload from `res.data['data']` (the existing onboarding service set this pattern):
```dart
final res = await dio.get('/feed/activity');
final list = (res.data['data'] as List?) ?? const [];
return list.map((e) => FeedEvent.fromJson(e)).toList();
```

---

## 4. Data layer pattern  (model → repository → provider)

Each feature's `data/` folder has three things:

1. **Models** with `fromJson` (`feed_models.dart`, `chat_models.dart`, ...).
2. **Repository** that calls `dio` using `ApiEndpoints` (`feed_repository.dart`, ...).
3. **Riverpod providers** (declared at the bottom of the repository file) the UI watches.

Providers available today:
| Provider | Returns |
|----------|---------|
| `feedActivityProvider` / `recentJoinsProvider` / `batchmateBannerProvider` | feed data |
| `myCommunitiesProvider` / `discoverCommunitiesProvider` / `communityProvider(id)` / `communityMessagesProvider(id)` | communities |
| `conversationsProvider` / `conversationMessagesProvider(id)` | DMs |
| `batchmatesProvider` / `pendingConnectionsProvider` | connections |
| `notificationsProvider` / `unreadNotificationCountProvider` | notifications |
| `searchProvider(query)` | search results |
| `profileProvider(username)` | a profile |
| `authControllerProvider` / `currentUserIdProvider` | auth/session |

`ApiEndpoints` (`core/constants/api_endpoints.dart`) is the single source of every path.

---

## 5. State management with Riverpod

- **Read-only async data** → `FutureProvider` (e.g. `feedActivityProvider`). Use `.family` when parameterised (`communityProvider(id)`).
- **Mutable flows** → `StateNotifierProvider` (e.g. `authControllerProvider`).
- In a `ConsumerWidget` / `ConsumerStatefulWidget`:
```dart
final feed = ref.watch(feedActivityProvider);
return feed.when(
  data: (events) => ListView(...),
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Text('Could not load feed'),
);
```
- After a mutation (send message, accept connection), refresh with `ref.invalidate(conversationsProvider)`.

---

## 6. Auth flow on the client
- `auth_repository.dart` calls `/auth/request-otp` and `/auth/verify-otp`; on success it stores `access_token`, `refresh_token`, `user_id` in secure storage (keys: `kAccessTokenKey`, `kRefreshTokenKey`, `kUserIdKey`).
- `auth_provider.dart` — `AuthController` (StateNotifier) drives the login UI state (`loading / otpSent / user / error`).
- `login_screen.dart` — phone field → "Send code" → code field → "Verify & log in" → `context.go('/home')`. The dio interceptor then authenticates all subsequent calls automatically.
- Logout: `AuthController.logout()` clears stored tokens.

---

## 7. Routing (`go_router`)

`appRouterProvider` in `core/routes/app_router.dart`. Navigate with **`context.go(...)` only** (never `Navigator.push`).

| Path | Screen |
|------|--------|
| `/splash` | SplashScreen (initial) |
| `/login` | LoginScreen |
| `/onboarding`, `/onboarding/identity\|verify\|schools\|socials` | onboarding flow |
| `/home` | HomeScreen (feed/batch/messages/profile tabs) |
| `/profile/:username` | ProfileScreen |
| `/classroom/:id` | ClassroomScreen (community) |
| `/chat/:conversationId` | ChatScreen |
| `/search` | SearchScreen |
| `/notifications` | NotificationsScreen |

---

## 8. Shared `Person` model

`core/models/person.dart` mirrors the backend `PersonDto` and replaces the old hard-coded `AppPerson`. Avatar colours are derived deterministically from the name (`person.bg` / `person.fg`) so the UI keeps colourful avatars without the backend storing colours.

---

## 9. Theme & conventions (from `CLAUDE.md`)
- Colours via `AppColors` (`crimson #7B1414`, `crimsonDark`, `crimsonMuted`, `gold #D4A84A`, cream background).
- State: `ConsumerWidget` / `ConsumerStatefulWidget` / `StateNotifier`.
- Navigation: `context.go()` only.
- Avoid deprecations: `withValues(alpha:)` not `withOpacity()`; `initialValue:` not `value:` on `DropdownButtonFormField`.
- No mock data in new code — screens hit the real API.

---

## 10. ⚠️ Remaining work — wire screens to providers

The **data layer is done and login works**, but most feature **widgets still read the legacy `features/feed/data/dummy_data.dart`**. Migrating each is the next task:

| Widget / screen | Replace dummy with |
|-----------------|--------------------|
| `home_tab.dart` | `feedActivityProvider`, `recentJoinsProvider`, `batchmateBannerProvider` |
| `batch_tab.dart` | `myCommunitiesProvider`, `discoverCommunitiesProvider` |
| `messages_tab.dart` | `conversationsProvider` |
| `chat_overlay.dart` / `chat_screen.dart` | `conversationMessagesProvider(id)` + send via `ChatRepository` |
| `batchmate_overlay.dart` | `connectionRepositoryProvider` (status/request) |
| `profile_tab.dart` / `profile_screen.dart` | `profileProvider(username)` |
| `classroom_screen.dart` | `communityProvider(id)` + `communityMessagesProvider(id)` |
| `notifications_screen.dart` | `notificationsProvider` |
| `search_screen.dart` | `searchProvider(query)` |

**Pattern to follow** (example for the feed):
```dart
class HomeTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joins = ref.watch(recentJoinsProvider);
    return joins.when(
      data: (people) => Row(children: people.map(_avatar).toList()),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Text('Could not load'),
    );
  }
}
```
After all widgets are migrated, delete `dummy_data.dart`.

---

## 11. Run
```
cd frontend
flutter pub get
flutter run -t lib/main_dev.dart        # dev flavor (default base URL localhost:8080)
# physical device: flutter run -t lib/main_dev.dart --dart-define=BASE_URL=http://<your-ip>:8080/api
```
Then log in with phone `919999000001`, OTP `000000`.
