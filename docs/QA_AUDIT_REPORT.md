# APSBrats — QA Audit Report

> Status: **In progress** — findings added as each section is verified against the actual codebase and running app.
> All findings are code-verified unless marked `[not yet tested]`.
> Last updated: 2026-11-10. Fix pass done across all sections; see "Fix log: Sections 4–18" and "Backlog summary (what's left)" at the end.

---

## How to read this report

| Severity | Meaning |
|---|---|
| 🔴 High | Can create bad data, data loss, security hole, or crash in production |
| 🟡 Medium | Degrades experience noticeably; workaround exists |
| 🟢 Low | Minor polish, nice-to-have |
| ✅ Pass | Verified working |
| ⚠️ Partial | Partly covered, gap noted |
| ❌ Missing | Not implemented |

Each finding has: **what was checked**, **what was found**, **recommended fix**, and a **backlog label** to copy into your issue tracker.

---

## 1. Network connectivity and offline behaviour

**Verified by reading:** `dio_client.dart`, `chat_socket.dart`, `community_repository.dart`, `pubspec.yaml`, grep over all `.dart` files.

> **Fixed 2026-11-10.** All Section 1 findings fixed in code. `IdempotencyFilterTest` (5 tests) passes, `flutter analyze` shows no errors, and `flutter test` passes 95/95. Still to do: a device test with airplane mode (steps under "Fix verification").

### Findings

| # | Item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 1.1 | Offline user message shown | ✅ Fixed (app-wide banner) | — | — |
| 1.2 | 15-second request timeout | ✅ | — | — |
| 1.3 | Duplicate submit (button guard) | ✅ | — | — |
| 1.4 | Server-side duplicate prevention | ✅ Fixed (`IdempotencyFilter`) | — | — |
| 1.5 | WebSocket auto-reconnect | ✅ via stomp_dart_client | — | — |
| 1.6 | WebSocket reconnect on app resume | ✅ Fixed (`AppLifecycleListener`) | — | — |
| 1.7 | WebSocket error visible to user | ✅ Fixed (logged + "Reconnecting to chat…" banner) | — | — |
| 1.8 | Failed request retry (non-401) | ✅ Fixed (retry interceptor) | — | — |
| 1.9 | Idempotency key on POST | ✅ Fixed (`Idempotency-Key` header) | — | — |
| 1.10 | Draft preserved on submit failure | ✅ Fixed (post composer + 1:1 chat) | — | — |
| 1.11 | Image upload resume / retry | ✅ Fixed (Retry action keeps remaining photos) | — | — |
| 1.12 | Connectivity detection before call | ✅ Closed, no package needed (see detail) | — | — |

### Fix verification

| What changed | Where |
|---|---|
| Server runs each keyed POST once per user; stores 2xx for 24 h, replays it with `Idempotent-Replayed: true`; 409 while the first is still running; failures are forgotten so the retry can run | `apsbrat-api/.../common/web/IdempotencyFilter.java` + `IdempotencyFilterTest.java` |
| Every POST gets a random `Idempotency-Key`; retries reuse it | `dio_client.dart` `onRequest` |
| Retry: connection error / connect timeout / 502-503-504, 2 retries (0.5 s, 1 s). GETs, and POSTs that have a key, no FormData, and aren't `/auth/` calls | `dio_client.dart` second interceptor |
| `networkOfflineProvider` set by real request outcomes | `dio_client.dart` |
| Socket errors logged; `reconnecting` notifier; dead socket replaced on app resume | `chat_socket.dart` |
| Banner above every screen: "You're offline…" / "Reconnecting to chat…" | `app.dart` `_ConnectionBanner` |
| Post draft (text + uploaded photos) saved to SharedPreferences when the sheet closes; cleared on success | `community_screen.dart` `PostComposer` |
| Failed photo upload → snackbar **Retry** with the photos not yet uploaded | `community_screen.dart` `_upload` |
| 1:1 chat puts the text back in the box if a send fails | `chat_controller.dart` (`send` returns bool), `chat_screen.dart` |

**Device test to do:** turn on airplane mode, then (a) open any tab: the banner appears and the GET is retried twice in the debug log; (b) write a post, close the sheet, reopen it: the draft is back; (c) add photos mid-outage: tap **Retry** once you're back online. Turn airplane mode off: the banner clears on the next successful request, and the socket's reconnect loop calls `/users/me` every few seconds, so this happens without any action from the user.

### Detail (original findings)

**1.1 — Offline message ⚠️ Partial**
`friendlyError()` in `community_repository.dart` returns `"Couldn't connect. Check your internet and try again."` when `error.response == null`. Used on community and post screens. Not a persistent banner — only a snackbar that disappears. User gets no ongoing indicator that they are offline.
> Fix: add `connectivity_plus`, expose a stream provider, show a banner via `MaterialBanner` on `ConnectivityResult.none`.

**1.4 / 1.9 — No idempotency key on POST 🔴**
Posts, comments, RSVPs, and chat messages carry no idempotency key. If a request times out (the server may or may not have processed it) and the user retries, a duplicate record is created. DB UNIQUE constraints cover memberships, connections, and blocks — not posts or messages.
> Fix: generate a UUID client-side before each POST, send as `X-Idempotency-Key` header, cache server-side in Redis for 60 s and return the original response on a duplicate.

**1.6 — WebSocket not reconnected on app resume ❌**
`ChatSocket.connect()` is called once at login / cold start. When the app is backgrounded and foregrounded the STOMP connection may be stale. No `WidgetsBindingObserver` watches `AppLifecycleState.resumed`.
> Fix: add a lifecycle observer in the socket provider or `HomeScreen` that calls `socket.connect()` when the client is inactive on resume.

**1.7 — WebSocket errors silently swallowed ❌**
```dart
// chat_socket.dart:63-64
onWebSocketError: (dynamic _) {},
onStompError: (_) {},
```
No reconnection state is surfaced to the user.
> Fix: expose a `ValueNotifier<bool> isConnected` from `ChatSocket`, show a "Reconnecting…" chip in the community chat and 1:1 chat headers.

**1.8 — Failed request retry ❌**
The Dio interceptor retries only on 401. A timeout, `SocketException`, or 503 on any other call shows a snackbar (or nothing). The user must press again manually.
> Fix: add a retry interceptor for GET requests (max 2 retries, exponential back-off). Do not auto-retry POSTs without an idempotency key (see 1.9).

**1.10 — Draft lost on submit failure ❌**
If a post-compose submit fails, the text field content is not saved. Navigating away loses the draft.
> Fix: autosave composer text to `SharedPreferences` keyed by community ID on every change. Clear on success.

**1.11 — Image upload — no retry ❌**
If the network drops mid-upload the DioException is caught, `_uploading` resets, and the selected file is gone from the UI.
> Fix: short-term — keep the local file reference in state after failure and show "Upload failed — tap to retry" with the same file pre-selected.

**1.12 — No pre-call connectivity check ❌**
No `connectivity_plus` in `pubspec.yaml`. The app discovers offline status only after a 15-second timeout.
> Fix: `connectivity_plus` + a `connectivityProvider` that all repositories can fast-fail against before even opening a socket.
>
> **Resolution:** closed without the package. With no network, the OS fails the socket immediately (`connectionError`), so there is no 15 s wait. And `connectivity_plus` reports "Wi-Fi" even when there's no internet, so it would miss the case that does take 15 s. The banner is driven by real request results instead.

---

## 2. Performance and response time

**Verified by:** static code reading + running app measurements (Flutter web dev build on `localhost:5173`, Spring Boot API on `localhost:8081`, 2026-11-09). Runtime items measured with Navigation Timing API (browser), `curl -w "%{time_total}"` against the live API, and Chrome DevTools network log via `read_network_requests`.

> **Fixed 2026-11-10.** 2.5, 2.6, 2.8, 2.10, 2.14 fixed in code; 2.15 now has a slow-query log; 2.7 closed by design. `flutter analyze` shows no new issues, `flutter test` passes 95/95, and the backend has 52 tests with 0 failures (1 Docker-based integration test skipped because Docker wasn't running). **Not re-measured live:** the API and Docker were down, so the new startup call count (2.14) still needs a DevTools capture. Steps under "Fix verification".

### Findings

| # | Item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 2.1 | Post/memory/event feed pagination | ✅ cursor-based, 20/page | — | — |
| 2.2 | Image compression before upload | ✅ flutter_image_compress | — | — |
| 2.3 | Cached network images | ✅ cached_network_image | — | — |
| 2.4 | Shimmer / loading indicators | ✅ shimmer package | — | — |
| 2.5 | Feed list virtualisation | ✅ Was already lazy (finding overstated); now `SliverList.builder` | — | — |
| 2.6 | 5 tab widgets built on startup (IndexedStack) | ✅ Fixed: each tab is built on its first visit, then kept alive | — | — |
| 2.7 | Members API called on community open | ✅ Closed by design: one request shared with the Members tab's page 0 | — | — |
| 2.8 | Batchmates tab switch invalidates 10 providers | ✅ Fixed: 3 providers, and only on a return visit | — | — |
| 2.9 | FutureProvider.autoDispose re-fetches on return | ⚠️ by design, no cache TTL | 🟢 | `perf/provider-cache` |
| 2.10 | Members list not virtualised | ✅ Fixed: rows built lazily (`DecoratedSliver` + `SliverList.builder`) | — | — |
| 2.11 | No HTTP response caching (ETag / Cache-Control) | ❌ | 🟢 | `perf/http-cache` |
| 2.12 | Initial load time (dev build) | ✅ measured: **~11 s** (dev) | 🟡 | `perf/load-time` |
| 2.13 | API response times (localhost) | ✅ measured: **2–17 ms** | — | `perf/api-latency` |
| 2.14 | Simultaneous API calls on home load | ✅ Fixed in code (root cause was 2.6); live re-count pending | — | — |
| 2.15 | DB query execution time | ✅ Slow-query log on (>100 ms, `SLOW_QUERY_MS` to override); timings still to collect | — | — |
| 2.16 | Memory / CPU consumption | `[not yet measured]` | — | `perf/memory-cpu` |
| 2.17 | Bundle size | `[not yet measured — run flutter build apk --analyze-size]` | — | `perf/bundle` |
| 2.18 | Performance degradation over time | `[not yet tested]` | — | `perf/endurance` |

### Fix verification

| What changed | Where |
|---|---|
| Tabs 1–4 are a `SizedBox.shrink()` until first opened, then stay alive in the `IndexedStack`. An unbuilt tab watches no providers, so it fetches nothing | `home_screen.dart` `_visited` / `_goTo` |
| Returning to Batchmates invalidates only `circleSummaryProvider`, `batchmatesProvider`, `peopleSearchProvider` (what that tab shows). Pull-to-refresh still runs the full `refreshConnections` | `home_screen.dart` `_goTo` |
| Feed: header / `SliverList.builder` posts / footer inside a `SliverMainAxisGroup`, keyed by post id | `community_screen.dart` `_FeedTab` |
| Members: the eager `Column` inside one card replaced by `DecoratedSliver(communityCard()) → SliverList.builder`, keyed by person id | `community_screen.dart` members tab |
| `hibernate.session.events.log.LOG_QUERIES_SLOWER_THAN_MS: ${SLOW_QUERY_MS:100}` + logger `org.hibernate.SQL_SLOW: INFO`, all profiles | `application.yml` (base section) |

**Correction to 2.5:** `SliverList.list` / `SliverGrid.count` use `SliverChildListDelegate`, which already **builds and lays out only children near the viewport**. Only the lightweight widget objects were created up front. So the feed, memories grid and events lists were not the real problem (memories and events are unchanged). The genuinely eager case was **2.10**: all member rows sat in one `Column`, which lays out every row.

**Correction to 2.6 / 2.14:** the original 2.6 note said "data fetches are still lazy". That was wrong. A tab in the `IndexedStack` is built, and a built tab `ref.watch`es its providers, so Batchmates, Communities, Messages and Profile all fetched on startup (`/connections`, `/communities/mine`, `/communities/discover`, `/conversations`, `/users/{id}/school-history`, `/users/{id}/career`, `/profiles/{id}`, …). That, not leftover community providers, is the main source of the 16-call burst. The `/communities/{id}/…` calls in the capture come from the community page actually being open: on web, reloading a `/home/community/{id}` URL rebuilds that route, which is expected.

**2.7 closed by design:** the header's `communityMembersProvider(page: 0)` query is exactly the Members tab's page 0, so it is a single ~8 ms request shared by both. The avatar stack is part of the design; replacing it with placeholders would make the UI worse to save one cheap request.

**To re-measure 2.14:** start Postgres + Redis + API, run the web app, log in and open DevTools → Network on `/home`. Expected: only Home-tab calls (`/feed/home`, `/users/me`, circle summary / notifications badge, plus the socket's `/users/me`). Then open each tab once and confirm its calls fire only at that point.

### Detail (original findings)

**2.5 / 2.10 — Feed and members lists not virtualised 🟡**

Community feed (`_FeedTab`) and members (`_MembersTab`) both use `SliverList.list`:
```dart
// community_screen.dart:681
sliver: SliverList.list(
  children: [
    for (final p in feed.items) ...[
      PostCard(post: p, ...),   // all 20 built, even off-screen
    ],
  ],
)
```
`SliverList.list` builds every item regardless of visibility. With 20 posts and their images this is acceptable for now, but will visibly lag as the user loads more pages. Same pattern in `MemoriesTab` and `EventsTab`.

> Fix: replace `SliverList.list(children: [...])` with `SliverList.builder(itemCount: items.length, itemBuilder: (_, i) => ...)`. One-line change per tab; only visible items are built.

---

**2.6 — All 5 tab widgets built on startup 🟡**

`HomeScreen` uses `IndexedStack` with all 5 children constructed immediately:
```dart
// home_screen.dart:96-109
IndexedStack(
  index: _tab,
  children: [
    HomeTab(...),     // built now
    BatchTab(),       // built now
    CommunitiesTab(), // built now
    MessagesTab(),    // built now
    ProfileTab(),     // built now
  ],
)
```
Widget trees for all five tabs are built on the first render. Data fetches are still lazy (`.autoDispose` FutureProviders only run when watched), but five widget subtrees are in memory and in the build pipeline even when not visible. On a low-end phone the first frame will be slower than necessary.

> Fix: wrap each tab child in an `Offstage` + `AutomaticKeepAlive`, or use `PageView` with `keepPage: true`. The tradeoff is instant tab switching (IndexedStack, current behaviour) vs. a small first-frame cost. Keep IndexedStack but add `AutomaticKeepAlive` so each tab's state survives without repeated rebuilds.

---

**2.7 — Members API called the moment a community page opens 🟡**

The community header (`_Header.build`, `community_screen.dart:452-464`) watches `communityMembersProvider` to show the avatar stack of the first few members. This fires a `/communities/{id}/members` GET call immediately when the community page opens, before the user visits the Members tab.

```dart
// community_screen.dart:452-464
final faces = readable
    ? ref.watch(communityMembersProvider(...)).valueOrNull ?? []
    : [];
```

Combined with the members tab also watching the same provider (just for page 0), it is one call not two — but it is still an API call the user did not ask for and may not need.

> Fix: replace the avatar stack in the header with the `memberCount` from the community object (already in the payload) and render placeholder avatars. Watch `communityMembersProvider` only inside the Members tab widget.

---

**2.8 — Batchmates tab switch fires up to 10 API calls 🟡**

Every time the user taps the Batchmates bottom-nav item, `refreshConnections(ref)` is called unconditionally:
```dart
// home_screen.dart:117
if (i == 1 && _tab != 1) refreshConnections(ref);
```
`refreshConnections` invalidates 10 providers including `notificationsProvider`, `profileProvider`, and `peopleSearchProvider`. All 10 re-fetch immediately from the network.

> Fix: either remove `refreshConnections` from the tab-switch handler entirely (`.autoDispose` already re-fetches stale data when the provider is next watched), or narrow it to `batchmatesProvider` + `pendingConnectionsProvider` only — the two that actually change when a connection is accepted.

---

**2.9 — autoDispose re-fetches on every return to a tab 🟢**

All community-related providers use `.autoDispose`. When a user opens a community, navigates away (e.g. opens a post), and comes back, the provider has been disposed and re-fetches from the server. This is correct for data freshness but means every back-navigation costs a network round trip.

> Fix when needed: add a short in-memory TTL using Riverpod's `keepAlive` + a timer (60 s), or use `cacheTime` in Riverpod 3. Not urgent — only optimise if the re-fetch delay is noticeable.

---

**2.12 — Initial load time ~11 s (dev build) 🟡**

Measured via browser Navigation Timing API against the running Flutter web dev build:

```
navigationStart → loadComplete: 11,034 ms
  CanvasKit download (gstatic.com): ~374 ms
  Flutter engine bootstrap: ~8 s
  First frame rendered: ~11 s
```

This is a **dev build** — no tree-shaking, no minification, CanvasKit loaded from CDN on every cold start. A `flutter build web --release` with `--web-renderer canvaskit` will be significantly faster (typically 3–5 s on a real device over LTE). Not actionable until a release build exists.

> Measure on release build: `flutter build web --release && serve build/web`. Target: <4 s on a mid-range Android.

---

**2.13 — API response times (localhost baseline)**

Measured with `curl -w "%{time_total}"` against the live API on `localhost:8081`, 3 runs each, authenticated with a dev token:

| Endpoint | Avg (ms) |
|---|---|
| `GET /feed/home?limit=20` | 2 |
| `GET /users/me` | 2 |
| `GET /conversations` | 3 |
| `GET /communities/{id}/events` | 3 |
| `GET /communities/{id}/chat/messages` | 3 |
| `GET /connections` | 7 |
| `GET /communities/{id}/chat` | 7 |
| `GET /communities/mine` | 8 |
| `GET /communities/{id}/members` | 8 |
| `GET /communities/{id}/posts?sort=latest` | 9 |
| `GET /users/me/circle/summary` | 11 |
| `GET /communities/discover?q=` | 17 |

All within acceptable range for localhost. **On production over a real network, add ~100–300 ms per call.** With 16 calls firing in parallel on home load, the total wall time is bounded by the slowest one — currently `discover` at 17 ms locally, but potentially ~300 ms in prod.

---

**2.14 — 16 API calls fire simultaneously on home load ❌**

Captured from the Chrome DevTools network log on a cold app load (Navigation Timing: 11 s). After the Flutter engine initialises and the user reaches the home screen, **16 HTTP GET requests fire in a single burst**:

1. `GET /feed/home` — home feed posts
2. `GET /users/me/circle/summary` — connection count badge
3. `GET /connections` — batchmates list
4. `GET /communities/mine` — joined communities
5. `GET /communities/discover?q=` — discover tab
6. `GET /conversations` — messages badge
7. `GET /communities/{id}` — last-visited community (from route cache)
8. `GET /users/{id}/school-history`
9. `GET /users/me`
10. `GET /users/{id}/career`
11. `GET /profiles/{id}`
12. `GET /communities/{id}/members` — header avatar stack (see 2.7)
13. `GET /communities/{id}/chat`
14. `GET /communities/{id}/posts`
15. `GET /communities/{id}/events`
16. `GET /communities/{id}/chat/messages`

Calls 7–16 are from community providers that weren't fully disposed between sessions — the last community the user visited re-mounts its providers on next cold start because the home route restores navigation state.

> Fix: ensure community-specific providers are disposed when the user leaves the community route. Add `ref.onDispose` assertions in the community providers. This should eliminate calls 7–16 from the startup burst (~10 of the 16 calls).

---

**Items that still need a running profiler or staging environment**

| Item | How to measure |
|---|---|
| DB query time | `spring.jpa.properties.hibernate.session.events.log.LOG_QUERIES_SLOWER_THAN_MS=100` |
| Memory / CPU | Flutter DevTools Memory tab, 15-min soak |
| Bundle size | `flutter build apk --analyze-size` → size report |
| Prod API latency | Re-run curl measurements against staging/prod URL |

---

## 3. High-load and scalability testing

**Verified by:** `application.yml`, `WebSocketConfig.java`, `AuthService.java`, `PostService.java`, `CommunityChatService.java`, `ImageUploadService.java`. Items marked `[needs load runner]` require a staging env + k6/Gatling to quantify real breaking points.

### Findings

| # | Item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 3.1 | OTP rate limiting (per-email + per-IP) | ✅ Redis-backed | — | — |
| 3.2 | Post rate limiting | ✅ 10 posts/hr per user, Redis | — | — |
| 3.3 | Comment rate limiting | ✅ 60 comments/hr per user, Redis | — | — |
| 3.4 | Community chat rate limiting | ✅ 120 messages/hr per user, Redis | — | — |
| 3.5 | Image upload rate limiting | ✅ 30 uploads/hr per user, Redis | — | — |
| 3.6 | Global API rate limiting (all endpoints) | ✅ Fixed: `RateLimitFilter`, 300 req/min per user, 60/min per IP before sign-in | — | — |
| 3.7 | WebSocket broker clustering | ⏸ Deferred: needs RabbitMQ; single-instance deployment until then (see detail) | 🟡 | `infra/stomp-cluster` |
| 3.8 | HikariCP pool size configured | ✅ Fixed: explicit `DB_POOL_SIZE` (default 10), 10 s connect timeout, 20 s leak detection | — | — |
| 3.9 | Tomcat thread pool configured | ✅ Closed by design: 200 is sufficient (WebSockets use NIO, not a thread each); `SERVER_TOMCAT_THREADS_MAX` if ever needed | — | — |
| 3.10 | Background job queue (async tasks) | ✅ Fixed the real issue: event-RSVP fan-out batched (`createAll`); no other fan-out exists | — | — |
| 3.11 | Horizontal scaling / sticky sessions | ⏸ Same as 3.7: run one API instance | 🟡 | `infra/stomp-cluster` |
| 3.12 | Simulate 10 / 100 / 500 / 1 000 concurrent users | ✅ Run 2026-11-10 (results below) | — | — |
| 3.13 | Simultaneous login storm | ⏭ Skipped at user request; scenario ready (`SCENARIO=login`) | — | `load/login-storm` |
| 3.14 | Concurrent chat messages | ⏭ Skipped at user request; scenario ready (`SCENARIO=chat`) | — | `load/chat-flood` |
| 3.15 | DB connection pool exhaustion | ✅ None at 1 000 users: 0 pool timeouts, 0 leak warnings, 0 slow queries | — | — |
| 3.16 | Traffic spike behaviour | ✅ 0→1 000 users in 30 s: 0 errors, p95 600 ms | — | — |
| 3.17 | Maximum sustainable throughput | ✅ ~785 req/s on one laptop (API + DB + k6 on the same machine) | — | — |
| 3.18 | **New:** OTP per-IP limit spoofable via `X-Forwarded-For` | ✅ Fixed: header trusted only from private-network proxies | — | — |

### Fixes (2026-11-10)

| What changed | Where |
|---|---|
| Per-minute request budget for every API call: per signed-in user (300) or per IP before sign-in (60). Returns 429 with `Retry-After`. Skips `/media`, `/ws`, `/actuator`. **Fails open** if Redis is down | `common/web/RateLimitFilter.java` + `RateLimitFilterTest` (4 tests). Limits: `RATE_LIMIT_USER_PER_MINUTE`, `RATE_LIMIT_IP_PER_MINUTE` |
| `AuthController.clientIp()` read `X-Forwarded-For` from anyone, so a caller could pick a new IP per request and dodge the 15/hr OTP-per-IP limit. Now uses `getRemoteAddr()`, with `server.forward-headers-strategy: native` (Tomcat RemoteIpValve trusts the header only from 10/8, 172.16/12, 192.168/16, 127/8 proxies) | `AuthController.java`, `application.yml`. **If prod sits behind a public-IP proxy (e.g. Cloudflare)**, set `server.tomcat.remoteip.internal-proxies` to its ranges |
| Event cancel/update notified RSVPs one by one (`findById` + `INSERT` each, so ~1 000 queries for 500 RSVPs). Now `NotificationService.createAll`: no lookups, inserts in JDBC batches of 50 | `NotificationService.java`, `CommunityEventService.notifyRsvps`, `hibernate.jdbc.batch_size: 50` + `order_inserts/updates` |
| Hikari: `maximum-pool-size: ${DB_POOL_SIZE:10}`, `connection-timeout: 10000`, `leak-detection-threshold: 20000` | `application.yml` (base section, all profiles) |
| Filter order made explicit: Security → RateLimit → Idempotency | `@Order` on both filters |
| Reusable k6 script: baseline / normal / stress / spike / login / chat | `apsbrat-api/load/k6-load.js` |

Backend suite: 56 tests run, 0 failures (1 Docker-based integration test skipped).

### Load test results (2026-11-10)

Run against a **throwaway** `apsbrat_loadtest` database (Flyway-migrated and seeded, then dropped) and Redis db 1, so dev data was untouched. Each virtual user is its own onboarded account in APS Pune. One session = Home calls (feed, me, unread count), then the community page (community, posts, members), plus a 10% chance of creating a post, with 1–3 s think time. API, Postgres, Redis and k6 all ran on **one laptop**, so absolute numbers are a floor, not a production estimate.

| Scenario | Users | Requests | Errors | Median | p95 | Throughput |
|---|---|---|---|---|---|---|
| Baseline | 10, 1 min | 904 | 0 | 29 ms | 61 ms | 14 req/s |
| Normal | 100, 2 min | 18 164 | 0 | 16 ms | 37 ms | 146 req/s |
| Stress | ramp to 500 | 57 672 | 0 | 14 ms | 27 ms | 367 req/s |
| Spike | 0→1 000 in 30 s, hold 1 min | 93 163 | 0 | 429 ms | 600 ms | 785 req/s |

- **Degradation point:** between 500 and 1 000 users. Latency jumps ~20× but nothing fails. The API log shows **0 pool timeouts, 0 leak warnings, 0 slow queries (>100 ms)**, so the database was not the bottleneck. CPU on the shared laptop is the likely limit. Re-run on staging hardware before tuning `DB_POOL_SIZE` or threads.
- The only 429s (37 total) were the per-user **post** limit (10/hour) on test users who had already posted in earlier runs, which is expected.
- **Not run (user asked to skip):** login storm (3.13) and chat flood (3.14). WebSocket delivery under load was not measured; the chat scenario covers the HTTP send path only.

**How to re-run:** start the API with `--spring.datasource.url=jdbc:postgresql://localhost:5432/apsbrat_loadtest --spring.data.redis.database=1` and `RATE_LIMIT_IP_PER_MINUTE=100000` (all test logins share one IP), then
`k6 run -e SCENARIO=normal -e COMMUNITY_ID=<school community> -e SCHOOL_ID=<its school> load/k6-load.js` (the script header has the query).

### Detail (original findings)

**3.1–3.5 — Rate limits are Redis-backed per user ✅**

All write-path rate limits use the same Redis `INCR + EXPIRE` sliding-window pattern. Limits in code:

| Action | Limit | Window |
|---|---|---|
| OTP requests per email | 5 | 1 hour |
| OTP requests per IP | 15 | 1 hour |
| OTP verify attempts | 5 | 15 min → then account locked |
| Post creation | 10 | 1 hour |
| Comments | 60 | 1 hour |
| Community chat messages | 120 | 1 hour |
| Image uploads | 30 | 1 hour |

Limits are per-user, not per-community. 100 users each sending 120 chat messages in one community = 12,000 DB writes/hour with no community-level throttle.

---

**3.6 — No global API rate limit on GET endpoints ❌ 🔴**

There is no servlet filter or Spring Security rate limit on read endpoints (`/feed/home`, `/communities/*`, `/users/*`). A single unauthenticated or authenticated client can hammer the feed endpoint indefinitely. There is no nginx, API Gateway, or Bucket4j layer in front of the app.

> Fix (short-term): Add a Bucket4j Spring Boot filter with a Redis backend: 60 GET requests/min per IP globally, 300/min per authenticated user. Long-term: put Cloudflare or an API Gateway in front.

---

**3.7 — WebSocket broker cannot scale horizontally ❌ 🔴**

`WebSocketConfig` enables `SimpleBroker("/queue")` — an in-process message broker. The broker state (connected sessions, subscriptions) lives in one JVM's heap. If the app is deployed with more than one instance, users on different instances cannot receive each other's messages.

> Fix: replace `enableSimpleBroker` with `enableStompBrokerRelay` pointing at a RabbitMQ or ActiveMQ broker. This is a prerequisite for horizontal scaling.
>
> **Decision 2026-11-10: deferred, lowered to 🟡.** One instance handled 1 000 concurrent users with 0 errors (results above), so a second instance isn't needed yet, and the relay can't be tested without running RabbitMQ. Until then: **deploy exactly one API instance** (no autoscaling). Do this before adding a second instance: RabbitMQ with the STOMP plugin, `enableStompBrokerRelay`, plus `spring-boot-starter-reactor-netty`.

---

**3.8 — HikariCP pool not tuned 🟡**

No `hikari.maximum-pool-size`, `hikari.minimum-idle`, or `hikari.connection-timeout` in `application.yml` for any profile. Spring Boot defaults to 10 connections. At 100 concurrent requests each doing a DB query, threads will queue waiting for a connection.

Rule of thumb for PostgreSQL: `pool_size = (num_cores × 2) + num_disks`. On a 2-core server that's ~5 connections — the default 10 is fine for low load but needs tuning before any real concurrency.

> Fix: add to `application.yml` (adjust to your server):
> ```yaml
> hikari:
>   maximum-pool-size: 20
>   minimum-idle: 5
>   connection-timeout: 20000
>   idle-timeout: 300000
> ```

---

**3.9 — Tomcat thread pool not tuned 🟡**

Spring Boot's embedded Tomcat defaults to 200 worker threads. With WebSocket connections using threads and each HTTP request consuming a thread for its duration, 200 threads limits effective concurrency. Not configured in any profile.

> Fix: add to `application.yml`:
> ```yaml
> server:
>   tomcat:
>     threads:
>       max: 400
>       min-spare: 20
> ```
> Then measure actual thread utilisation under load before choosing final values.

---

**3.10 — No background job queue ❌ 🟡**

No `@Scheduled`, `@EnableAsync`, or external queue (Celery, SQS, Redis Queue) found in the codebase. Notification delivery, cleanup, and feed aggregation all happen synchronously inside request threads. Under load, a slow notification fan-out will block the request thread and inflate p99 latency.

> Fix: add `@EnableAsync` and move `NotificationService.notify(...)` calls to `@Async` methods. For longer jobs (feed rebuild, cleanup), add a Redis-backed task queue or Spring Batch job.
>
> **Correction 2026-11-10:** there is no notification fan-out to make async. `NotificationService.create` writes one row per event (connection request/accept, comment). The only loop was event cancel/update notifying every RSVP, and that is now one batched `createAll`. An async queue would add failure modes (lost notifications on restart) without a measured need.

---

**3.11 — Horizontal scaling blocked by in-process WebSocket broker ❌ 🔴**

(See 3.7.) Even with a load balancer, sticky sessions (IP or cookie affinity) would be required while `SimpleBroker` is in use, because STOMP subscriptions are per-JVM. Without sticky sessions, chat messages sent to one instance never reach users connected to another instance.

---

**Load tests to run before beta launch**

Recommended k6 script targets (staging environment):

| Scenario | Virtual users | Duration | Pass criteria |
|---|---|---|---|
| Baseline read | 10 VU | 5 min | p95 < 500 ms, 0 errors |
| Normal load | 100 VU | 10 min | p95 < 1 s, error rate < 0.1% |
| Stress | 500 VU | 5 min | identify degradation point |
| Spike | ramp 0→1 000 in 30 s | 2 min | no crash; graceful 429s |
| Login storm | 200 concurrent `/auth/verify-otp` | 2 min | rate limiter fires, no DB lock |
| Chat flood | 50 VU × 120 msg/hr in one community | 10 min | all delivered, broker stable |

---

## 4. Database and query performance

**Verified by:** all 35 Flyway migrations + every Repository and Service file across all features: Posts, Chat (1:1), Community chat, Connections, Circle (schoolmates/classmates), Notifications, Blocks, Auth, Career, School history, Feed events, Profile. `show-sql: true` confirmed active in dev.

### Index coverage — all tables

| Table | Key queries | Index status |
|---|---|---|
| `users` | search by name/username, created_at sort, id lookup | ✅ trigram GIN + created_at index |
| `connections` | by requester, by addressee, status filter | ✅ both FK indexes; ⚠️ no index on `accepted_at` (ORDER BY sorts in memory) |
| `community_members` | by community, by user | ✅ PK + idx_community_members_user |
| `posts` | community feed, event posts, memory posts, pinned | ✅ community+time, event partial, memories; ❌ no pinned_at index |
| `comments` | by post + time | ✅ |
| `notifications` | by user + time, unread count | ✅ composite; ❌ no partial index for `is_read = false` |
| `chat_messages` | by conversation + time, unread | ✅ composite + partial unread index |
| `conversations` | by user_a, user_b, last_message_at | ✅ separate user indexes; ❌ no compound (user_id, last_message_at) |
| `community_messages` | by community + time | ✅ |
| `community_events` | by community + starts_at | ✅ |
| `event_rsvps` | by event (PK), by user | ✅ PK; ❌ no user_id index |
| `community_join_requests` | by community (PK), by user | ✅ PK; ❌ no user_id index |
| `user_school_history` | by user, by school+section+batch | ✅ both indexes |
| `career_entries` | by user + date, by org | ✅ |
| `organizations` / `job_titles` | autocomplete | ✅ trigram GIN |
| `user_blocks` | blocker → blocked, blocked → blocker | ✅ UNIQUE(blocker_id, blocked_id) + idx_blocked |
| `feed_events` | newest first | ✅ created_at index; ❌ no actor_id index (N+1 lazy load) |
| `otp_codes` | by email | ✅ |
| `reports` | by status, by target_user | ✅ |

### Findings

| # | Feature | Item | Status | Severity | Backlog label |
|---|---|---|---|---|---|
| 4.1 | Chat | N+1 on `listConversations` | ✅ Fixed: 4 queries total (participants join-fetched, `DISTINCT ON` latest message, grouped unread counts, one `toPeople`) | — | — |
| 4.2 | Feed | N+1 on activity feed actor | ✅ Fixed: `@EntityGraph("actor")` on the feed query | — | — |
| 4.3 | Batchmates | Unbounded schoolmate/classmate load | ✅ Fixed: ids queried only on cache miss; names-only projection; capped at 5 000 candidates (Postgres 32k bind limit) | — | — |
| 4.4 | Home banner | No LIMIT | ✅ Fixed: `count` + top-3 names | — | — |
| 4.5 | Search | `NOT IN (:blockedIds)` | ✅ Closed, no bug: every call passes a placeholder (list never empty) and ids are non-null UUIDs, so the NULL trap can't occur; block lists are small | — | — |
| 4.6 | Posts | Member rows loaded twice per request | ✅ Fixed: id-only queries (`findCommunityIdsByUserId[AndRole]`) | — | — |
| 4.7 | Posts | `isStaff()` lookup per page | ✅ Fixed: role read from the signed-in token; DB only for other users | — | — |
| 4.8 | Posts | No index on `posts.pinned_at` | ✅ Fixed: `idx_posts_pinned` (V36) | — | — |
| 4.9 | Notifications | No unread partial index | ✅ Fixed: `idx_notif_unread` (V36) | — | — |
| 4.10 | Chat | 2 conversation queries merged in Java | ✅ Fixed: one `findActiveFor` query (see 4.1) | — | — |
| 4.11 | Chat | No `(user, last_message_at)` index | ✅ Fixed: `idx_conv_user_a_last` / `_b_last` (V36) | — | — |
| 4.12 | Events | No `user_id` index on `event_rsvps` | ✅ Fixed: `idx_rsvps_user` (V36) | — | — |
| 4.13 | Communities | No `user_id` index on `community_join_requests` | ✅ Fixed: `idx_join_requests_user` (V36) | — | — |
| 4.14 | Home banner | Deleted/banned users in banner | ✅ Fixed: banner and recent joins exclude deleted and banned users | — | — |
| 4.15 | Connections | `accepted_at` sort | ✅ Fixed: partial indexes on accepted connections (V36) | — | — |
| 4.16 | Posts | Popular-posts pagination uses OFFSET | ⚠️ acceptable at community scale (unchanged) | 🟢 | `db/popular-offset` |
| 4.17 | All | Slow-query logging | ✅ Fixed (Section 2.15): `SQL_SLOW` > 100 ms | — | — |
| 4.18 | All | No cleanup job | ✅ Fixed: nightly `MaintenanceJobs` (expired OTPs, read notifications > 180 days). Orphaned media: skipped (see 10.5) | — | — |
| 4.19 | All | No backup/restore procedure | ⏭ Not in our hands: needs the hosting provider's DB backups | 🔴 | `ops/backup` |
| — | Posts/Feed | Post feed N+1: `toDtos()` batches authors, communities, likes, events | ✅ fixed number of queries | — | — |
| — | Notifications | Actor N+1: `@EntityGraph` loads actor in same query | ✅ | — | — |
| — | Career | `@EntityGraph` on `CareerEntryRepository` loads org in one query | ✅ | — | — |
| — | School history | `findAllWithSchoolByUserIds` batch-loads histories + school in one query | ✅ | — | — |
| — | All | Optimistic locking (`@Version`) on users, connections, community_members | ✅ | — | — |
| — | All | `@Transactional(readOnly)` used on all read paths | ✅ | — | — |
| — | All | No cross-table deadlock risk found | ✅ | — | — |
| — | Auth | Soft-delete + tombstone email on user deletion | ✅ | — | — |

### Detail

---

**4.1 — N+1 on conversation list 🔴**

`ChatService.listConversations()` runs **two** separate repository queries to find conversations, merges them in Java, then calls `toConversationDto()` per conversation:

```java
// ChatService.java:94-105
List<Conversation> asA = conversationRepository.findByUserA_IdAndLastMessageAtIsNotNull(myId);
List<Conversation> asB = conversationRepository.findByUserB_IdAndLastMessageAtIsNotNull(myId);
// then per conversation:
toConversationDto(c, myId)   // calls personService.toPerson(other) + 2 msg queries each
```

`personService.toPerson(other)` runs `historyRepository.findAllByUser_Id()` + `settingsService.forUsers()`. For N conversations, this is 2 initial queries + 4N followup queries.

> Fix: load all conversations in one UNION query (the existing `findActiveFor` already exists but isn't used here). Pre-load last messages and unread counts in two batch queries keyed by conversation ID, then map them onto the conversations list. This reduces N conversations from 4N+2 queries to 5 queries total.

---

**4.2 — N+1 on activity feed actor 🔴**

`FeedEvent.actor` is mapped `FetchType.LAZY`. `FeedService.activity()` calls `events.stream().map(FeedEvent::getActor)`, which triggers one `SELECT * FROM users WHERE id = ?` per event:

```java
// FeedService.java:32
List<User> actors = events.stream().map(FeedEvent::getActor).toList();  // N lazy loads
```

For a 20-item feed, this is 20 extra queries before the existing batch personService call.

> Fix: either add `@EntityGraph(attributePaths = "actor")` to `findAllByOrderByCreatedAtDesc`, or change `FeedEvent.actor` to `EAGER` (safe here — actor is always needed). One extra JOIN in the main query vs. N extra queries.

---

**4.3 — Schoolmates/classmates load unbounded ID lists into memory 🔴**

`CircleService` for schoolmates:
```java
List<UUID> ids = historyRepository.findSchoolmateIds(me, batchOnly);  // ALL matching IDs, no LIMIT
// ...then inside rank():
for (User u : userRepository.findAllById(candidateIds)) { ... }   // loads ALL user rows for name sort
```

A school with 10,000 alumni returns 10,000 UUIDs, then 10,000 `User` rows are loaded into the JVM heap to extract names for ranking. Only 30 are shown per page. The ranked list is cached in Redis after the first compute, but the first request by each user hits the DB hard.

> Fix: perform ranking in SQL — a single query with `ORDER BY mutual_count DESC, same_batch DESC, full_name ASC LIMIT :limit OFFSET :offset`. The mutual-count CTE already exists in `countMutual`; extend it to include same-batch and name, and use it as the main query instead of a Java sort over loaded objects.

---

**4.4 — Banner loads all of today's registrations with no LIMIT 🔴**

```java
// FeedService.java:59
List<User> today = userRepository
    .findByCreatedAtAfterOrderByCreatedAtDesc(startOfDay)  // no LIMIT, no deleted_at filter
    .stream().filter(u -> !u.getId().equals(currentUserId))
    .toList();
List<String> names = today.stream().limit(3)...;   // only 3 names are used
```

On a busy day this loads the full `User` row for every registration. At 500 sign-ups/day that's 500 rows fetched, filtered and discarded for 3 names.

> Fix: two targeted native queries — `COUNT(*)` with `deleted_at IS NULL AND id <> :me`, and `SELECT id, full_name ... LIMIT 3` with the same filters.

---

**4.5 — `NOT IN (:blockedIds)` in `searchPeople` 🔴**

```sql
AND u.id NOT IN (:blockedIds)
```
If `:blockedIds` contains any `NULL`, the entire predicate returns no rows (SQL NULL semantics for `NOT IN`). Additionally, `NOT IN` with large value sets cannot use an index and forces a sequential filter over all candidate rows.

> Fix: replace with a correlated `NOT EXISTS` using the indexed `user_blocks` columns:
> ```sql
> AND NOT EXISTS (
>   SELECT 1 FROM user_blocks b
>   WHERE (b.blocker_id = u.id AND b.blocked_id = :viewerId)
>      OR (b.blocker_id = :viewerId AND b.blocked_id = u.id)
> )
> ```

---

**4.6 / 4.7 — Two duplicate queries per home feed post-page 🟡**

Per home feed request, `myCommunityIds(userId)` runs `findByUserId(userId)`, then `toDtos()` calls `ownedCommunityIds(userId)` which runs the same `findByUserId(userId)` again. Additionally, `isStaff(userId)` runs `userRepository.findById(userId)` — the user's role is already in the JWT.

> Fix: hoist both calls to the controller layer, pass them as parameters into `toDtos()`. Eliminates 2 DB queries per post-page load.

---

**4.8 — No index on `posts.pinned_at` 🟡**

`findByCommunityIdAndStatusAndPinnedAtIsNotNullOrderByPinnedAtDesc` can't use `idx_posts_community_newest` — that index doesn't include `pinned_at`. PostgreSQL scans all ACTIVE posts in the community.

> Fix: `CREATE INDEX idx_posts_pinned ON posts (community_id) WHERE pinned_at IS NOT NULL;`

---

**4.9 — No partial index for notification unread count 🟡**

`countByUser_IdAndReadFalse` scans the full user notification set, filtering in memory on `is_read = false`. Once a user has hundreds of old read notifications, every unread-badge refresh scans all of them.

> Fix: `CREATE INDEX idx_notif_unread ON notifications (user_id) WHERE is_read = false;`

---

**4.10 / 4.11 — Conversation list: two queries + no compound index 🟡**

`listConversations` calls `findByUserA_IdAndLastMessageAtIsNotNull` and `findByUserB_IdAndLastMessageAtIsNotNull` as separate queries, merges and sorts in Java. The sort on `lastMessageAt` is in-memory because the indexes on `user_a_id` and `user_b_id` don't include `lastMessageAt`.

> Fix: use the existing `findActiveFor(userId)` JPQL query (`OR` on user_a/user_b, ordered by lastMessageAt) — it already exists in `ConversationRepository`. Add a compound partial index:
> ```sql
> CREATE INDEX idx_conv_a_last ON conversations (user_a_id, last_message_at DESC) WHERE last_message_at IS NOT NULL;
> CREATE INDEX idx_conv_b_last ON conversations (user_b_id, last_message_at DESC) WHERE last_message_at IS NOT NULL;
> ```

---

**4.12 / 4.13 — Missing user-side indexes on rsvps and join requests 🟡**

Both tables' PKs are keyed on the community/event side. Looking up "which events have I RSVP'd to" or "which communities have I requested to join" requires a full table scan.

> Fix:
> ```sql
> CREATE INDEX idx_rsvp_user ON event_rsvps (user_id);
> CREATE INDEX idx_join_req_user ON community_join_requests (user_id);
> ```

---

**4.17 — Slow-query logging not configured 🟡**

None of the three Spring profiles (`dev`, `qa`, `prod`) sets `hibernate.session.events.log.LOG_QUERIES_SLOWER_THAN_MS` or PostgreSQL's `log_min_duration_statement`. Queries that degrade as data grows are invisible until users report slowness.

> Fix: add to `application-qa.yml` and `application-prod.yml`:
> ```yaml
> spring.jpa.properties.hibernate.session.events.log.LOG_QUERIES_SLOWER_THAN_MS: 100
> ```

---

**4.18 — No archival / cleanup job 🟡**

Rows accumulate with no bound in: `otp_codes` (10-min TTL in logic, never deleted from DB), `notifications` (no retention policy), `feed_events` (no rotation), and `media/` files for deleted posts.

> Fix: `@Scheduled` weekly cleanup: delete `otp_codes WHERE created_at < NOW() - INTERVAL '1 day'`, `notifications WHERE created_at < NOW() - INTERVAL '6 months'`, media files whose `image_url` no longer appears in any content column.

---

**4.19 — No backup procedure 🔴**

No `pg_dump` schedule, no point-in-time recovery config, no restore runbook.

> Fix: daily `pg_dump | gzip` to S3 (30-day retention). Test restore to a fresh DB before the first real users join — the runbook must be exercised, not just written.

---

## 5. Application logs and monitoring

> Verified by reading: `RequestIdFilter.java`, `JwtAuthFilter.java`, `GlobalExceptionHandler.java`, `logback-spring.xml`, `ErrorReporter.dart`, `dio_client.dart`, `chat_socket.dart`.

| # | Item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 5.1 | Timestamps in every backend log line | ✅ `%d{yyyy-MM-dd HH:mm:ss.SSS}` in logback pattern | — | — |
| 5.2 | Request correlation ID in every log line | ✅ `RequestIdFilter` → MDC → `%X{requestId:-no-rid}` | — | — |
| 5.3 | 5xx errors logged with stack trace | ✅ `GlobalExceptionHandler` logs `log.error(..., ex)` | — | — |
| 5.4 | 4xx errors logged | ✅ `log.warn(...)` for AppException, AccessDeniedException, DB conflicts | — | — |
| 5.5 | 404 (NoResourceFoundException) logged | ✅ Fixed: logged at INFO with the path | — | — |
| 5.6 | JWT auth failure logged | ✅ Fixed: expired tokens at DEBUG (routine); invalid, tampered or revoked tokens at WARN with path + reason | — | — |
| 5.7 | WebSocket errors logged (Flutter) | ✅ Fixed 2026-11-10: `_dropped()` logs socket/STOMP errors via `debugPrint` (see 1.7) | — | — |
| 5.8 | Sensitive data excluded from logs | ✅ `PrettyDioLogger(requestHeader: false, requestBody: false)` and dev-only | — | — |
| 5.9 | Global Flutter crash handler installed | ✅ `ErrorReporter.install()` wires `FlutterError.onError` + `PlatformDispatcher.onError` | — | — |
| 5.10 | Crash backend wired (Crashlytics/Sentry) | ⏭ Not in our hands: needs a Firebase/Sentry project. `ErrorReporter.report()` is the single seam to wire it into | 🔴 | `ops/crashlytics` |
| 5.11 | Log file appender / persistence | ✅ Fixed: qa/prod also write `$LOG_DIR/api.log`. **`LOG_DIR` must be a mounted volume** | — | — |
| 5.12 | Log rotation configured | ✅ Fixed: daily + 50 MB, 30 days, 2 GB cap, gzipped | — | — |
| 5.13 | Structured / JSON log format | ⏭ Deferred: only useful once a log aggregator is chosen. Lines now carry `[requestId] [userId]` and are greppable | 🟢 | `ops/log-json` |
| 5.14 | Separate ERROR alert channel | ⏭ Not in our hands: needs an alerting service | 🔴 | `ops/alerts` |
| 5.15 | Request ID echoed to client | ✅ `RequestIdFilter` adds `X-Request-Id` response header + included in 500 body | — | — |

### Detail

**5.6 — JWT auth failure silently swallowed 🟡**
In `JwtAuthFilter.java`, the token validation block is wrapped in `catch (Exception ignored)`. Any malformed or expired token causes a silent no-op — no log at WARN or DEBUG. The filter continues the request chain unauthenticated, so the downstream 401/403 is logged by `GlobalExceptionHandler`, but the _reason_ (which token, which error) is never recorded.
```java
// JwtAuthFilter.java — current
} catch (Exception ignored) { }   // ← silently swallows every JWT parse failure
```
> Fix: replace `ignored` with `e` and add `log.warn("JWT validation failed: {}", e.getMessage())`.

**5.7 — WebSocket errors silent on Flutter side 🟡**
Both STOMP error callbacks are empty lambdas:
```dart
onWebSocketError: (dynamic _) {},  // chat_socket.dart
onStompError:     (_) {},
```
A network drop or server-side STOMP error produces no log, no user feedback, and no reconnect trigger beyond the auto-reconnect built into stomp_dart_client.
> Fix: in both callbacks call `ErrorReporter.report(_, null, context: 'STOMP')` and emit to a stream that the UI observes to show a "Reconnecting…" chip.

**5.10 — Crash backend not wired 🔴**
`ErrorReporter.report()` calls `debugPrint` and, only in `kDebugMode`, prints the stack. In release builds, exceptions are captured but never sent anywhere.
```dart
static void report(Object error, StackTrace? stack, {String? context}) {
  debugPrint('[ErrorReporter...] $error');           // ← dev-only visibility
  if (stack != null && kDebugMode) { ... }           // ← stack invisible in prod
}
```
> Fix: add `firebase_crashlytics` (Firebase is already configured), replace the `debugPrint` line with `FirebaseCrashlytics.instance.recordError(error, stack)`. Two lines, one import.

**5.11 — Logs lost on container restart 🔴**
`logback-spring.xml` configures a single `ConsoleAppender` writing to STDOUT. When the container restarts, all prior logs are gone.
```xml
<appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">...</appender>
<root level="INFO"><appender-ref ref="CONSOLE"/></root>
```
> Fix (choose one): (a) add a `RollingFileAppender` writing to a mounted volume; or (b) ship STDOUT to a log aggregator (Loki, CloudWatch, Datadog) via Docker log driver — this is the cloud-native approach and requires no logback change, only deployment config.

**5.13 — Plain-text format blocks log aggregation 🟡**
Current pattern: `%d{yyyy-MM-dd HH:mm:ss.SSS} %-5level [%X{requestId:-no-rid}] %logger{36} - %msg%n`. Parsing this with regexes in Elasticsearch or CloudWatch Logs Insights is fragile.
> Fix: add `logstash-logback-encoder` and switch to `LogstashEncoder`. Each log line becomes a JSON object with `timestamp`, `level`, `requestId`, `logger`, `message` as top-level keys — query and filter without regex.

---

## 6. Analytics and event tracking

> ⏭ **2026-11-10: whole section skipped, not in our hands.** Every item depends on choosing an analytics provider (Firebase Analytics, Mixpanel…) and a consent policy. Once chosen: one `NavigatorObserver` in the router covers screen views (6.11), and the existing auth/onboarding/post controllers are the event call sites.
>
> Verified by: grepping all `lib/**/*.dart` for analytics, trackEvent, logEvent, screen_view, RouteObserver; reading `pubspec.yaml`.
> **Result: analytics is entirely absent.** No SDK, no call sites, no route observer, no consent UI.

| # | Checklist item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 6.1 | Analytics SDK installed | ❌ not in pubspec.yaml | 🟡 | `analytics/sdk` |
| 6.2 | Important actions generate events | ❌ zero call sites in codebase | 🟡 | `analytics/events` |
| 6.3 | Consistent event naming convention | ❌ N/A — no events | 🟢 | `analytics/naming` |
| 6.4 | Event parameters defined and correct | ❌ N/A | 🟢 | `analytics/params` |
| 6.5 | User ID / anonymous ID handling | ❌ N/A | 🟡 | `analytics/identity` |
| 6.6 | Duplicate event prevention | ❌ N/A | 🟢 | `analytics/dedup` |
| 6.7 | Events queued during network outage | ❌ N/A | 🟢 | `analytics/offline-queue` |
| 6.8 | No spurious events on route rebuild | ❌ N/A | 🟢 | `analytics/rebuild-guard` |
| 6.9 | Conversion events (onboarding complete) | ❌ N/A | 🟡 | `analytics/conversion` |
| 6.10 | Funnel tracking (onboarding steps) | ❌ N/A | 🟡 | `analytics/funnel` |
| 6.11 | Screen / page-view tracking | ❌ no `NavigatorObserver` wired | 🟡 | `analytics/screen-views` |
| 6.12 | Login / logout / registration events | ❌ N/A | 🟡 | `analytics/auth-events` |
| 6.13 | Failed actions tracked separately | ❌ N/A | 🟢 | `analytics/failures` |
| 6.14 | Analytics consent / privacy UI | ❌ no consent flow exists | 🟡 | `analytics/consent` |
| 6.15 | Analytics data matches backend records | ❌ N/A | 🟢 | `analytics/reconcile` |

### Detail

**6.1 — No analytics SDK 🟡**
`pubspec.yaml` contains `firebase_core: ^2.31.1` and `firebase_messaging: ^14.9.4` but no analytics package. All 15 checklist items above are blocked on this single missing dependency.

**Recommended path (zero extra packages):**
`firebase_analytics` is a first-party FlutterFire package that sits on the existing `firebase_core` and `firebase_messaging` setup. Adding it costs one `pubspec.yaml` line and no architectural change.

```yaml
# pubspec.yaml — add under dependencies
firebase_analytics: ^10.10.6
```

Then wire a `FirebaseAnalyticsObserver` as a `NavigatorObserver` on your router. Every `GoRouter` / `MaterialApp.router` call accepts an `observers` list — that one line gives automatic screen-view tracking for free, covering 6.11 at zero extra call-site cost.

**6.14 — No analytics consent flow 🟡**
India's DPDP Act 2023 requires informed consent before collecting personal data for analytics. Currently there is no consent dialog, opt-out toggle, or privacy policy acknowledgement for analytics collection.
> Fix: before initialising Firebase Analytics, show a one-time consent dialog. Store the boolean in `flutter_secure_storage`. Pass `setAnalyticsCollectionEnabled(false)` if the user declines.

**Priority order for implementation:**
1. Add SDK + `FirebaseAnalyticsObserver` → automatic screen views with zero per-screen work
2. Add consent dialog at first launch
3. Log auth events (login, register, logout) in `AuthNotifier`
4. Log onboarding funnel steps (Identity saved, Schools saved, Socials saved)
5. Log community conversion events (join, post created, comment, chat message)
6. Everything else

---

## 7. Real-time functionality

> Verified by reading: `chat_socket.dart`, `chat_controller.dart`, `chat_models.dart`, `ChatService.java`, `NotificationService.java`, `WebSocketConfig.java`, grepping all Dart for `AppLifecycleState`/`FirebaseMessaging`.

| # | Item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 7.1 | WS connection established on login | ✅ single shared `ChatSocket`, activated on HomeScreen | — | — |
| 7.2 | Token refreshed before each (re)connect | ✅ `beforeConnect` hook calls `/users/me` to trigger Dio refresh | — | — |
| 7.3 | Community messages routed by community ID | ✅ listeners filter client-side by `communityId` | — | — |
| 7.4 | WS auto-reconnect after drop | ✅ stomp_dart_client built-in reconnect | — | — |
| 7.5 | WS reconnect after app resume | ✅ Fixed in Section 1.6 (`AppLifecycleListener`) | — | — |
| 7.6 | Reconnection status visible to user | ✅ Fixed 2026-11-10: "Reconnecting to chat…" banner (see 1.7) | — | — |
| 7.7 | Online / last-seen presence | ✅ Redis-backed, toggleable in settings | — | — |
| 7.8 | Message ordering correct | ✅ backend `ORDER BY created_at DESC` → reversed for client; cursor preserves order | — | — |
| 7.9 | Duplicate message prevention on receive | ✅ `receive()` checks `any((m) => m.id == message.id)` before inserting | — | — |
| 7.10 | Duplicate prevention across devices | ✅ Closed, no bug: an optimistic entry exists only on the sending device and is swapped for the server copy; a device that reloads over HTTP replaces its whole list (`load()`), so it can't hold a duplicate. Server-side, `Idempotency-Key` (1.9) stops a retried send creating two rows | — | — |
| 7.11 | WS push sent only after DB commit | ✅ `TransactionSynchronizationManager.afterCommit()` guards `messagingTemplate.convertAndSendToUser` | — | — |
| 7.12 | Unread message count | ✅ `countByConversation_IdAndSender_IdNotAndReadAtIsNull` + `markRead` | — | — |
| 7.13 | In-app notification delivery | ✅ DB-persisted; bell badge shows unread count | — | — |
| 7.14 | Push notification delivery (FCM) | ⏭ Not in our hands: needs Firebase project + credentials | 🔴 | `notif/fcm-push` |
| 7.15 | Multiple devices — same account WS | ⚠️ Live delivery reaches every connected device. An offline device catches up on next open (HTTP load). Missed push alerts depend on FCM (7.14) | 🟢 | `notif/fcm-push` |
| 7.16 | Stale WS connections removed | ✅ STOMP heartbeat via SimpleBroker | — | — |
| 7.17 | High concurrent connections / horizontal scale | ⏸ Deferred 2026-11-10 (see 3.7): run one API instance; RabbitMQ relay before adding a second | 🟡 | `infra/stomp-cluster` |

### Detail

**7.5 — WS not reconnected on app resume ❌**
`ChatSocket.connect()` guard (`if (_client?.isActive ?? false) return`) means if the OS killed the socket while backgrounded, `connect()` is a no-op and the user silently misses messages until they cold-restart.
No `WidgetsBindingObserver.didChangeAppLifecycleState` or equivalent exists anywhere in the codebase.
> Fix: in HomeScreen (or the `chatSocketProvider` itself), implement `WidgetsBindingObserver`, call `socket.disconnect()` then `socket.connect()` on `AppLifecycleState.resumed`.

**7.14 — FCM push never wired 🔴**
`firebase_messaging: ^14.9.4` is in `pubspec.yaml` but:
- No `FirebaseMessaging.instance.getToken()` call in the app
- `fcm_token` field exists on the `User` entity (confirmed: `AccountService.deleteAccount()` nulls it), but no endpoint ever writes it — the Flutter app never POSTs a token to the backend
- `NotificationService.create()` saves to DB only — no call to any push-send path

Result: a user whose app is backgrounded or killed receives no notification. They only see it next time they open the app and poll the notifications endpoint.
> Fix: call `FirebaseMessaging.instance.getToken()` after login, POST the token to a new `/users/me/fcm-token` endpoint, store it in a `user_fcm_tokens` table, and call Firebase Admin SDK from `NotificationService.create()`.

**7.17 — SimpleBroker cannot scale horizontally 🔴**
`enableSimpleBroker("/queue")` in `WebSocketConfig` uses Spring's in-process message broker. If the API ever runs as more than one instance (behind a load balancer), a WS connection on instance A cannot receive a message pushed on instance B.
> Fix: replace with `enableStompBrokerRelay(...)` pointing at a RabbitMQ or ActiveMQ instance. Zero application-layer code changes needed — only the broker config line changes.

---

## 8. Security and privacy (runtime and operational)

> Verified by reading: `AuthService.java`, `AuthController.java`, `JwtService.java`, `SecurityConfig.java`, `AccountService.java`, `JwtAuthFilter.java`, `OnboardingGate.java`, `dio_client.dart`, all Spring profiles.

| # | Checklist item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 8.1 | Session expiration (access token 15 min) | ✅ 900,000ms in application.yml | — | — |
| 8.2 | Refresh token rotation on use | ✅ old JTI deleted, new one issued | — | — |
| 8.3 | Session invalidated after logout | ✅ `logout()` deletes JTI from Redis | — | — |
| 8.4 | Revocation of already-issued access tokens | ✅ `revoked:userId` key checked in `JwtAuthFilter` via `isRevoked()` | — | — |
| 8.5 | Simultaneous sessions (multiple devices) | ✅ Fixed: Settings → "Log out of all devices" (`POST /auth/logout-all`); verified both sessions go 200 → 401 | — | — |
| 8.6 | Access restrictions across user accounts | ✅ `requireParticipant`, onboarding gate, ownership checks in controllers | — | — |
| 8.7 | Sensitive data not exposed in API responses | ✅ email not in profile DTOs; OTP logged only in non-prod; export endpoint returns caller's own data only | — | — |
| 8.8 | Tokens stored in app secure storage | ✅ `flutter_secure_storage` — not in SharedPreferences or plain files | — | — |
| 8.9 | Unauthorized API access blocked | ✅ `.anyRequest().authenticated()` in `SecurityConfig` | — | — |
| 8.10 | Brute-force on OTP code | ✅ 5 wrong attempts → 15-min lockout (Redis) | — | — |
| 8.11 | Rate limiting — OTP requests | ✅ 5/email/hr + 15/IP/hr + 60s resend cooldown | — | — |
| 8.12 | Rate limiting — content endpoints | ✅ posts 10/hr, comments 60/hr, chat 120/hr, uploads 30/hr | — | — |
| 8.13 | Global API rate limit (unauthenticated or per-token) | ✅ Fixed 2026-11-10: `RateLimitFilter` (see 3.6) | — | — |
| 8.14 | IP spoofing on `X-Forwarded-For` | ✅ Fixed in Section 3 (3.18): header trusted only from private-network proxies | — | — |
| 8.15 | CORS from env var, not wildcard | ✅ `app.cors.allowed-origins`; `setAllowedOriginPatterns(allowedOrigins)` | — | — |
| 8.16 | CSRF protection | ✅ N/A — stateless JWT, no session cookies; `csrf.disable()` is correct | — | — |
| 8.17 | File upload MIME type / size restriction | ✅ `ImageProcessor`: `ALLOWED_TYPES = {jpeg, jpg, png}`, `MAX_BYTES = 5 MB`; Spring `multipart.max-file-size: 5MB`; EXIF/GPS stripped on re-encode | — | — |
| 8.18 | Account enumeration (OTP flow) | ✅ `requestOtp` creates OTP regardless of whether email exists — same response | — | — |
| 8.19 | Account enumeration (username check) | ⚠️ `/users/username-available` is public by design (required for onboarding); reveals taken usernames | 🟢 | — |
| 8.20 | Password reset workflow | ✅ N/A — OTP IS the authentication; requesting an OTP to email is the reset flow | — | — |
| 8.21 | Access revocation (ban / delete) | ✅ `revokeAllFor()` deletes all JTIs + sets `revoked:userId` key | — | — |
| 8.22 | Google Sign-In / Firebase integration | ✅ `FirebaseAuthVerifier` validates ID token server-side before accepting identity | — | — |
| 8.23 | springdoc / Swagger disabled in qa/prod | ✅ `springdoc.api-docs.enabled: false` in qa/prod profiles | — | — |
| 8.24 | Master OTP `000000` absent in prod | ✅ blocked by `isProd()` check in `masterOtpMatches()` | — | — |
| 8.25 | Security headers (HSTS, CSP, Referrer-Policy) | ✅ Fixed: HSTS 1 yr + subdomains (on HTTPS), `Referrer-Policy: no-referrer`, CSP `frame-ancestors/object-src/base-uri 'none'`, `Permissions-Policy`; verified on live responses | — | — |
| 8.26 | Personal data fully removed on account delete | ✅ bio, city, dob, gender, profession, profilePicUrl, websiteUrl, fcmToken all nulled; school history + social links hard-deleted; email and username tombstoned | — | — |
| 8.27 | Data retention schedule for deleted accounts | ✅ Closed by design: deletion erases all personal data **immediately** (name, email, phone, DOB, photo, schools, links, tokens). The anonymous row stays so posts keep an author, which holds no personal data | — | — |
| 8.28 | Audit log of deletion request (DPDP) | ✅ Fixed: `account_deletions` table (V37): user id, time, request id; written in the same transaction; verified | — | — |

### Detail

**8.14 — X-Forwarded-For IP spoofing ⚠️**
```java
// AuthController.java
String forwarded = request.getHeader("X-Forwarded-For");
if (forwarded != null && !forwarded.isBlank()) {
    return forwarded.split(",")[0].trim();   // ← first value, not validated
}
```
If the API is not behind a reverse proxy that strips and re-writes `X-Forwarded-For`, any client can forge the header and claim any IP, bypassing the 15 OTP requests/IP/hr limit.
> Fix: either (a) configure the reverse proxy to overwrite the header; or (b) use Spring's `ForwardedHeaderFilter` with a trusted proxy list (`server.forward-headers-strategy: native` or `framework` in application.yml).

**8.17 — Upload validation ✅ (correction)**
`ImageProcessor.toSanitizedJpeg()` enforces `ALLOWED_TYPES = {image/jpeg, image/jpg, image/png}` and `MAX_BYTES = 5 MB` server-side before writing to storage. Spring's `multipart.max-file-size: 5MB` / `max-request-size: 6MB` enforces the HTTP layer. EXIF/GPS metadata is stripped on re-encode — important for military-family users. This finding was previously marked ❌ in error; the correct status is ✅.

**8.25 — Missing security headers 🟡**
`SecurityConfig.securityFilterChain()` calls no `.headers()` configuration. Spring Security 6 defaults add `X-Content-Type-Options: nosniff` and `X-Frame-Options: DENY`, but do NOT add:
- `Strict-Transport-Security` (HSTS) — requires HTTPS enforcement
- `Content-Security-Policy`
- `Referrer-Policy`
- `Permissions-Policy`

> Fix: add to `SecurityConfig`:
```java
http.headers(h -> h
    .httpStrictTransportSecurity(hsts -> hsts.includeSubDomains(true).maxAgeInSeconds(31536000))
    .referrerPolicy(r -> r.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN))
    .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'"))
);
```

---

## 9. Error handling and failure scenarios

> Verified by reading: `GlobalExceptionHandler.java`, `community_repository.dart` (`friendlyError`), `dio_client.dart`, `AuthService.java`, `ImageUploadService.java`, grepping for `@Scheduled`/`@Async`.

| # | Scenario | Backend | Frontend | Severity | Backlog label |
|---|---|---|---|---|---|
| 9.1 | API returns 400 | `AppException` / validation → structured `{error, code}` JSON | ✅ `friendlyError()` shows server message | — | — |
| 9.2 | API returns 401 | JWT expired or invalid | ✅ Dio interceptor auto-refresh → retry → `clearSession()` → redirects to login | — | — |
| 9.3 | API returns 403 | `AppException` with reason | ✅ `friendlyError()` surfaces reason ("Join this community first") | — | — |
| 9.4 | API returns 404 | `NoResourceFoundException` → `{error: "Not found"}` | ✅ Fixed: router `errorBuilder` shows "This page doesn't exist" + Go to Home | — | — |
| 9.5 | API returns 429 | `AppException(TOO_MANY_REQUESTS)` with reason | ✅ Correction: `friendlyError()` already shows the server's specific reason ("You're posting a lot…"); the global limiter adds `Retry-After` | — | — |
| 9.6 | API returns 500 | `handleUnexpected()` → `{error: "...", ref: <requestId>}` | ✅ Fixed: error states now have an inline **Retry** (see 13.3); the message carries the ref | — | — |
| 9.7 | Request timeout (15s) | — | ✅ Fixed in Section 1.8 (retry interceptor) | — | — |
| 9.8 | Database unavailable | Spring `DataSourceException` → 500 via `handleUnexpected` | ✅ generic error snackbar | — | — |
| 9.9 | Redis unavailable | ✅ Fixed: reads keep working (token-revocation check and global rate limit **fail open**; circle cache already did). Endpoints that need Redis (sign-in, refresh, posting, chat, uploads) return a retryable **503** instead of 500 | — | — |
| 9.10 | Firebase (Google sign-in) unavailable | ⏭ Skipped (Firebase) | 🟡 | `infra/firebase-resilience` |
| 9.11 | Email provider unavailable | ✅ N/A — email is a TODO (`// TODO: send the code by email`); OTP delivered via log only | — | — |
| 9.12 | Background job failure | ✅ N/A — no `@Scheduled` or `@Async` jobs exist | — | — |
| 9.13 | Technical errors hidden from user | ✅ `friendlyError()` returns server `error` field or fallback; no stack traces reach client | — | — |
| 9.14 | Fallback / graceful degradation | ✅ Fixed for Redis (the dependency on every request, 9.9). A circuit-breaker library isn't needed: Redis calls fail fast and are handled; Firebase is skipped | — | — |
| 9.15 | Recovery without app restart | ✅ Riverpod state survives errors; snackbar dismisses, buttons stay active | — | — |

### Detail

**9.9 — Redis unavailability causes total failure 🔴**
Redis is used in hot paths: every rate-limited endpoint (`PostService`, `CommunityChatService`, `AuthService`, `ImageUploadService`), every token operation (`refresh`, `logout`, `revokeAllFor`), and WS session revocation. If Redis goes down, `StringRedisTemplate` operations throw `RedisConnectionException`, which propagates to `handleUnexpected()` → 500. Users cannot log in, post, chat, or upload photos.
> Fix: wrap Redis operations in a try/catch with a warn log and fail-open behaviour for non-security operations (rate limiting). For security operations (token revocation), fail closed and document the outage scenario in a runbook.

**9.14 — No fallback or degradation strategy ⚠️**
The app has no circuit breakers, feature flags, or fallback paths. A single dependency outage (Redis, storage service, Firebase) takes down the full surface area it touches with no graceful degradation.
> Consider: Resilience4j `@CircuitBreaker` on `StorageService.store()` and `FirebaseAuthVerifier.verify()`. Rate-limiting fail-open (log + allow) during Redis outage is a simple first step.

---

## 10. Data integrity and consistency

> Verified by reading: `PostService.java`, `ChatService.java`, `AccountService.java`, `ImageUploadService.java`, `CircleCache.java`, `PresenceService.java`, Flyway migrations, `chat_controller.dart`.

| # | Item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 10.1 | Duplicate post on double-submit | ✅ Fixed in Section 1.9 (`Idempotency-Key`) | — | — |
| 10.2 | Duplicate community membership on retry | ✅ DB UNIQUE constraint on `(community_id, user_id)` | — | — |
| 10.3 | Duplicate conversation creation (race) | ✅ `DataIntegrityViolationException` caught → re-fetches existing row | — | — |
| 10.4 | Missing records (soft-deleted users in queries) | ✅ Fixed (4.14): banner and recent joins filter deleted and banned users | — | — |
| 10.5 | Partial submission — upload succeeds, post save fails | ⏭ Deferred: orphaned files are harmless (unreferenced, private). Cleaning them safely means checking every table that stores a media URL; do it as an S3 lifecycle rule when storage moves (11.16) | 🟢 | `data/orphaned-uploads` |
| 10.6 | Transaction rollback on DB error | ✅ all write paths are `@Transactional`; `DataIntegrityViolationException` → 409 and rollback | — | — |
| 10.7 | Concurrent post creation | ✅ Fixed in Section 1.9: a concurrent duplicate with the same key gets 409 while the first runs | — | — |
| 10.8 | Concurrent event RSVP | ✅ event end-time gate prevents RSVP after event closes | — | — |
| 10.9 | Concurrent profile update | ✅ `@Version` optimistic lock on `User` entity | — | — |
| 10.10 | Data sync — chat messages | ✅ Riverpod `invalidate(conversationsProvider)` after send/receive; cursor keeps order stable | — | — |
| 10.11 | Data sync — circle / schoolmates list | ✅ Correction: school-history changes **do** evict the user's own cache (`UserSchoolHistoryService`); other users' lists refresh within the 5-min TTL. Also fixed: eviction used blocking `KEYS`, now `SCAN` | — | — |
| 10.12 | Data sync — notifications unread count | ✅ polled on HomeScreen; `markAllRead` clears server-side | — | — |
| 10.13 | Deleted user references on posts/chat | ✅ tombstone — name kept, all PII blanked, `deleted_at` set | — | — |
| 10.14 | Stale blocked-user cache in community chat | ✅ block check runs live per message in `CommunityChatService` | — | — |
| 10.15 | Repeated form submissions (post, comment) | ✅ Fixed in Section 1.9 | — | — |
| 10.16 | Data corruption — image EXIF/GPS stripping | ✅ `ImageProcessor` re-encodes to sanitized JPEG — all metadata dropped | — | — |
| 10.17 | Backup and restore | ⏭ Not in our hands (hosting provider) | 🔴 | `ops/backup` |
| 10.18 | Flyway migration accuracy (V1–V35) | ✅ sequential, no gaps, checksums enforced by Flyway | — | — |
| 10.19 | Frontend ↔ backend DTO consistency | ✅ cursor fields (`nextCursor`, `hasMore`) match; `ChatMessage.fromJson` uses null-safe accessors | — | — |

### Detail

**10.5 — Orphaned uploads ⚠️**
The two-step upload flow (`POST /media/images` → `POST /posts`) means: if the second call fails (network error, 400, 500), the already-written image file stays in storage with no post referencing it.
```
Upload → ✅ file written to storage
Post   → ❌ DB transaction rolls back
                 └── image file remains orphaned, storage leaks
```
> Fix: a nightly job that queries storage for `uploads/{userId}/{uuid}.jpg` files older than 24h with no matching `image_url` reference in `posts` or `chat_messages`, and deletes them. Alternatively, track uploads in a DB table with a `claimed` flag.

**10.11 — Circle cache not evicted on profile change ⚠️**
`CircleCache` stores the ranked schoolmates list in Redis. When a user changes their `batch_start`, `batch_end`, `section`, or `school_id`, the cache for everyone who had them as a schoolmate is not invalidated. The stale list persists until the Redis TTL expires.
> Fix: in `UserSchoolHistoryService.save()`, call `circleCache.evict(userId)` and also evict any users whose cached list includes this userId. Simpler: reduce the TTL and accept eventual consistency.

---

## 11. Third-party integrations and dependencies

> ⏭ **2026-11-10:** Firebase (11.2, 11.5, 11.9, 11.15, 11.17), OTP email (11.14) and S3/GCS storage (11.16) are skipped: they need outside accounts and credentials. Redis handling (11.10, 11.13) is fixed.
>
> Verified by reading: `FirebaseAuthVerifier.java`, `LocalStorageService.java`, `StorageService.java`, `AuthService.java`, `pom.xml`, `pubspec.yaml`. Grep for webhooks, timeouts, outage handlers.

### Integrations inventory

| Integration | Backend | Flutter | Status |
|---|---|---|---|
| Firebase Auth (Google Sign-In ID token) | `firebase-admin 9.3.0` | `firebase_auth ^4.17.4`, `google_sign_in ^6.2.1` | ⚠️ Partially wired |
| FCM Push Notifications | `fcmToken` field on User entity | `firebase_messaging ^14.9.4` | ❌ Not wired end-to-end |
| Firebase Crashlytics | — | seam in `ErrorReporter.dart` | ❌ `debugPrint` only |
| OTP email delivery | explicit TODO comment | — | ❌ Not implemented |
| File storage | `LocalStorageService` (local disk) | Dio PUT | ❌ Prod S3/GCS implementation missing |
| Redis | Spring Data Redis (Lettuce) | — | ✅ Used for auth, rate limiting, presence, cache |
| PostgreSQL | Spring Data JPA / Flyway | — | ✅ |
| Webhooks | — | — | ✅ N/A — no webhooks |

### Checklist

| # | Item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 11.1 | All integrations operational | ❌ email not wired; FCM not wired; prod storage not wired | 🔴 | see per-item |
| 11.2 | Firebase service-account credentials present and valid | ⚠️ lazy-init; missing credentials file → 503 on first Google sign-in attempt; no startup validation | 🟡 | `integration/firebase-credentials` |
| 11.3 | Firebase credential expiration handling | ✅ Firebase Admin SDK auto-refreshes service-account token; handled transparently | — | — |
| 11.4 | Third-party API rate limits | ✅ Firebase verifyIdToken has very high limits; not a practical concern at this scale | — | — |
| 11.5 | Timeout on external service calls | ❌ `FirebaseAuth.verifyIdToken()` has no timeout config — hangs indefinitely if Firebase is unreachable | 🟡 | `integration/firebase-timeout` |
| 11.6 | Webhook delivery | ✅ N/A — app sends no webhooks and receives none | — | — |
| 11.7 | Webhook signature verification | ✅ N/A | — | — |
| 11.8 | Webhook retry behaviour | ✅ N/A | — | — |
| 11.9 | Dependency outage handling (Firebase Auth) | ⚠️ uncaught exception → 503 response; `log.warn(...)` ✅ but no alert, no fallback | 🟡 | `integration/firebase-resilience` |
| 11.10 | Dependency outage handling (Redis) | ✅ Fixed (9.9) | — | — |
| 11.11 | Dependency outage handling (storage) | ⏭ Tied to the S3/GCS move (11.16); the app's upload Retry (1.11) covers transient failures | 🟡 | `infra/object-storage` |
| 11.12 | Integration failure notifications | ⏭ Not in our hands (alerting service). Failures are now in a persistent rotated log (5.11) | 🔴 | `ops/alerts` |
| 11.13 | Fallback when external service fails | ✅ Redis handled (9.14); external services skipped | — | — |
| 11.14 | OTP email delivery | ❌ explicit `// TODO: send the code by email` in `AuthService`; OTP only reaches server log | 🔴 | `integration/otp-email` |
| 11.15 | FCM push notifications end-to-end | ❌ Flutter never calls `getToken()`; no token POST to backend; no Firebase Admin SDK send call | 🔴 | `notif/fcm-push` |
| 11.16 | Prod file storage (S3/GCS) implementation | ❌ only `LocalStorageService` (local disk) exists — comment says "in prod this is swapped for S3/GCS" but no such impl is present | 🔴 | `infra/object-storage` |
| 11.17 | Crashlytics / error reporting | ❌ `ErrorReporter.report()` calls `debugPrint` only | 🔴 | `ops/crashlytics` |
| 11.18 | Backend dependency versions current | ✅ Spring Boot 3.2.5, firebase-admin 9.3.0, jjwt 0.12.6, Lombok 1.18.34 — no known CVEs at audit date | — | — |
| 11.19 | Flutter dependency versions pinned | ✅ Closed, standard practice: `pubspec.lock` pins exact versions for an app; `^` in pubspec only bounds upgrades | — | — |

### Detail

**11.2 — Firebase credentials not validated at startup ⚠️**
`FirebaseAuthVerifier.app()` is lazy-initialised — the credentials file is not read until the first Google sign-in attempt. If the file is missing or malformed in production, every Google sign-in call returns HTTP 503 ("Google sign-in is misconfigured on this server"). Users who registered via email+OTP are unaffected.
> Fix: add an `@EventListener(ApplicationReadyEvent.class)` that calls `app()` on startup and throws `IllegalStateException` if it fails — fast-fail before serving traffic.

**11.5 — Firebase `verifyIdToken()` has no timeout ❌**
The Firebase Admin SDK's token verification makes an HTTPS call to Google's public key endpoint. No timeout is configured. If Google's key endpoint is slow, the Spring request thread blocks indefinitely.
> Fix: wrap `FirebaseAuth.getInstance(app()).verifyIdToken(idToken)` in a `CompletableFuture.supplyAsync(...).get(5, TimeUnit.SECONDS)` and catch `TimeoutException` → throw `AppException(503)`.

**11.14 — OTP email never sent 🔴**
```java
// AuthService.java line 73-76
if (!isProd()) {
    log.info("OTP for {} is {}", email, code);
}
// TODO: send the code by email in qa/prod
```
In production there is no email provider (Mailgun, SES, Postmark) configured. OTP codes are written to the server log only, which users cannot access. Authentication is completely broken for new users on any qa/prod deployment.
> Fix: add `spring-boot-starter-mail` or a transactional email SDK (`mailgun-java`, `aws-sdk-ses`), inject an `EmailSender` interface, call it after `otpCodeRepository.save(otp)`. The seam is already the right shape.

**11.16 — No production object-storage implementation 🔴**
`LocalStorageService` writes files to `./media` on the API container's local disk. The comment explicitly notes "in prod this is swapped for an S3/GCS-backed implementation", but no such implementation exists in the codebase. In a containerised deployment, local disk is ephemeral — images are lost on every restart or redeploy. Horizontal scaling would split image reads across instances.
> Fix: implement `S3StorageService implements StorageService` using the AWS SDK (`software.amazon.awssdk:s3`) or GCS equivalent. Inject via `@Primary` in a prod profile `@Configuration`. Zero call-site changes needed — `StorageService` is already an interface.

---

## 12. Browser, device and compatibility testing

> Code-verified: `app_router.dart`, `AndroidManifest.xml`, `build.gradle.kts`, `pubspec.yaml`, grep for `kIsWeb`/`LayoutBuilder`/`PopScope`. Items marked `[device test required]` need physical hardware or emulators — they cannot be confirmed from code alone.

### Platform targets

| Platform | Build configured | Code-verified |
|---|---|---|
| Android | ✅ `android/` present, Gradle configured | ✅ |
| iOS | ✅ `ios/` present | `[device test required]` |
| Flutter web | ✅ `web/` present, PWA manifest, `index.html` | `[browser test required]` |
| Windows / macOS / Linux desktop | ❌ no desktop target directories | — |

### Checklist

| # | Item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 12.1 | Chrome (web) | `[browser test required]` | — | `compat/web-chrome` |
| 12.2 | Edge (web) | `[browser test required]` | — | `compat/web-edge` |
| 12.3 | Firefox (web) | `[browser test required]` | — | `compat/web-firefox` |
| 12.4 | Safari (web + iOS) | `[browser test required]` | — | `compat/web-safari` |
| 12.5 | Android phone | `[device test required]` | — | `compat/android-phone` |
| 12.6 | iOS phone | `[device test required]` | — | `compat/ios-phone` |
| 12.7 | Different screen sizes / notch / dynamic island | ✅ `SafeArea` used throughout; `LayoutBuilder` + `SingleChildScrollView` on splash and login | — | — |
| 12.8 | Tablet layout | ✅ Fixed: app capped at 640 px and centred on wide screens; `MediaQuery` reports the capped width. Phones unchanged. (A true two-pane tablet design would be a product decision) | — | — |
| 12.9 | Mobile and desktop layouts (web) | ✅ Fixed (same as 12.8) | — | — |
| 12.10 | Browser refresh behaviour (web) | ✅ `app_router.dart` redirect guards onboarding routes on page reload — hydrates draft state before rebuilding | — | — |
| 12.11 | Browser back/forward navigation | ✅ GoRouter nested routes build a real browser history stack; `PopScope` closes emoji panel before popping screen | — | — |
| 12.12 | Multiple browser tabs | ⚠️ each tab is an independent Flutter app with its own WS connection and Riverpod state; real-time messages received in one tab are not reflected in another until that tab's next API poll | 🟢 | `compat/multi-tab` |
| 12.13 | Background → foreground transitions | ✅ Fixed in Section 1.6 (socket replaced on resume; its reconnect calls `/users/me`, which also clears the offline banner) | — | — |
| 12.14 | Browser storage restrictions (private mode) | ⚠️ `flutter_secure_storage` uses IndexedDB on web — unavailable in Safari private mode; app would lose session on browser restart in private mode | 🟡 | `compat/private-mode-storage` |
| 12.15 | Android `applicationId` finalised | ❓ **Needs your decision:** the package name is permanent once published (e.g. `com.apsbrats.app`). One-line change once chosen | 🔴 | `release/app-id` |
| 12.16 | Android release signing configured | ⏭ Not in our hands: the keystore must be created and kept by the owner | 🔴 | `release/keystore` |
| 12.17 | Android `launchMode` for notification tap | ✅ `singleTop` in `AndroidManifest.xml` — prevents duplicate activities | — | — |
| 12.18 | iOS camera / photo library permissions | `[device test required]` — `image_picker` requires `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` in `Info.plist` | — | `compat/ios-permissions` |

### Detail

**12.8 / 12.9 — No tablet or web-desktop layout ❌**
No `LayoutBuilder` breakpoints wider than 375px exist. On an iPad or a 1280px web viewport every screen renders as a stretched single column. For an alumni social app likely used on web by desktop alumni, this is a poor experience.
> Fix: wrap root screens in a `ConstrainedBox(constraints: BoxConstraints(maxWidth: 600))` centered in the viewport — the cheapest fix that makes phone-layout UIs tolerable at desktop widths.

**12.14 — Private-mode storage on Safari ⚠️**
Safari in private browsing either blocks or heavily restricts IndexedDB. `flutter_secure_storage` on Flutter web stores tokens in IndexedDB. A user opening the web app in Safari private mode will find themselves immediately logged out (or unable to log in) on each browser restart.
> Fix: test specifically in Safari private mode; consider a `sessionStorage` fallback for tokens (less secure but functional — tokens expire with the tab anyway).

**12.15 — Placeholder `applicationId` 🔴**
`build.gradle.kts` has `applicationId = "com.example.apsbrat_frontend"`. The Play Store treats `com.example.*` as a test application and will reject the submission. This must be changed before the first internal testing release.
> Fix: set `applicationId = "com.apsbrats.app"` (or whichever ID is registered in Play Console) in `build.gradle.kts`. Also update the iOS Bundle ID in Xcode.

---

## 13. User experience and usability

> Verified by reading: `search_screen.dart`, `search_repository.dart`, `community_screen.dart`, `edit_profile_screen.dart`, `chat_controller.dart`, `app_router.dart`. Grep for `showSnackBar`, `validator`, `Semantics`, sort/filter patterns.

| # | Item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 13.1 | Loading indicators | ✅ shimmer / `CircularProgressIndicator` on all data screens | — | — |
| 13.2 | Empty states | ✅ Fixed: requests, join requests and attendees errors now use `EmptyState` (notifications and connections already had it) | — | — |
| 13.3 | Error states | ✅ Fixed: `EmptyState` gained an `action` slot; **Retry** added to notifications, messages, requests, the 3 Batchmates lists, comments, join requests, attendees | — | — |
| 13.4 | Success messages | ⚠️ profile save shows `'Profile updated'` snackbar ✅; chat send is optimistic (message appears instantly — no separate toast needed ✅); other mutations (join community, RSVP, connect) rely on immediate UI state change with no explicit confirmation | 🟢 | `ux/success-feedback` |
| 13.5 | Button disabled during submit | ✅ `_busy` guards on all submit paths | — | — |
| 13.6 | Accidental double-tap prevention | ✅ `_busy` guards prevent concurrent taps | — | — |
| 13.7 | Form validation (client-side) | ✅ `TextFormField` + `validator` + `GlobalKey<FormState>` on profile, event, career, onboarding identity, school history forms | — | — |
| 13.8 | Form validation feedback timing | ✅ Fixed: `AutovalidateMode.onUserInteraction` on both `Form`s (onboarding identity, edit profile) | — | — |
| 13.9 | Navigation consistency | ✅ GoRouter nested routes; system back pops one level; tab switching returns to Home tab first | — | — |
| 13.10 | Search experience | ✅ Correction (false positive): search is fully built into the **Batchmates tab** (search box, my-schools/everywhere scope, paging, no-match state). `SearchScreen` was an unused placeholder that nothing linked to; it and the equally unused `ClassroomScreen` were **deleted** | — | — |
| 13.11 | Search filters | ✅ Correction: the filter sheet exists in the Batchmates tab (`_openFilters`) | — | — |
| 13.12 | Sorting | ✅ community posts have Latest / Popular segmented toggle; sort state per community via `postSortProvider` | — | — |
| 13.13 | Pagination / infinite scroll | ✅ cursor-based `loadMore` on posts, chat messages, notifications; `hasMore` guard prevents redundant fetches | — | — |
| 13.14 | Accessibility (semantic labels) | ⚠️ `Semantics` / `Tooltip` present in ~10 files but not systematic; no audit against WCAG 2.1 AA | 🟡 | `ux/a11y` |
| 13.15 | Keyboard navigation (web / desktop) | `[device test required]` — cannot verify focus traversal and shortcut keys from code alone | 🟢 | `ux/keyboard` |
| 13.16 | Responsive design | ✅ Fixed (12.8) | — | — |
| 13.17 | Confirmation before destructive actions | ✅ delete account has confirm dialog; community leave has confirm; post delete has confirm | — | — |
| 13.18 | Offline indicator (persistent banner) | ✅ Fixed 2026-11-10: app-wide offline banner (see 1.1) | — | — |

### Detail

**13.10 — Search not implemented 🔴**
```dart
// search_screen.dart
body: const Center(child: Text('Search APS classmates, and schools')),
```
The search screen is a stub. The `SearchRepository.searchPeople(PeopleQuery)` method is fully implemented and the backend `searchPeople` query is wired with trigram GIN indexes — the data layer is ready. Only the UI is missing.
> Fix: build the search screen: a `TextField` that updates a `StateProvider<PeopleQuery>`, a `ConsumerWidget` that calls `searchPeople()` on query change, renders results as `BatchmateCard` rows. Filter chips for school/batch can follow.

**13.4 — Success feedback gaps ⚠️**
Mutations that complete silently (no snackbar, no animation change):
- Joining a community → button changes to "Member" ✅ (state change is the feedback)
- RSVP to event → button changes ✅
- Sending a connection request → button changes ✅
- Posting a comment → comment appears ✅

The pattern of immediate UI state change is acceptable for these. The gap is on less obvious mutations: liking a post and unliking have no haptic or animation feedback beyond the icon fill change.

---

## 14. Deployment and release management

> Verified by reading `application.yml`, `DEPLOYMENT.md`, `ENVIRONMENTS.md`.

| # | Item | Status | Backlog label |
|---|---|---|---|
| 14.1 | Dev / staging / prod profiles | ✅ | — |
| 14.2 | Master OTP removed in qa/prod | ✅ | — |
| 14.3 | Flyway migrations checked before deploy | ✅ | — |
| 14.4 | Release keystore created | ❌ debug fallback warning in build.gradle.kts | `release/keystore` |
| 14.5 | applicationId finalised | ❌ still apsbrat_frontend | `release/app-id` |
| 14.6 | Zero-downtime deployment | `[not yet configured]` | `infra/zero-downtime` |
| 14.7 | Health check endpoint | `[not yet added]` | `ops/health-check` |
| 14.8 | Production smoke tests | `[not yet written]` | `ops/smoke-tests` |
| 14.9 | Rollback procedure | `[not yet documented]` | `ops/runbook` |

---

## 15. Backup, disaster recovery and business continuity

> `[not yet configured]` — no backup jobs exist.

| # | Item | Backlog label |
|---|---|---|
| 15.1 | Automated DB backups | `ops/backup` |
| 15.2 | Backup integrity test | `ops/backup` |
| 15.3 | Restore drill | `ops/backup` |
| 15.4 | RTO / RPO defined | `ops/runbook` |

---

## 16. Resource utilisation and infrastructure health

> Code-verified: `application.yml` (all profiles), `pom.xml`, grep for HikariCP/Redis config, Riverpod disposal patterns, subscription cleanup. Runtime items (CPU, RAM, actual connection counts) require a live staging deployment with APM — marked accordingly.

| # | Item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 16.1 | HikariCP pool size configured | ✅ Fixed 2026-11-10: `DB_POOL_SIZE` (default 10, enough for 1 000 users in the load test), 10 s connect timeout, 20 s leak detection (see 3.8) | — | — |
| 16.2 | Redis maxmemory policy | ✅ Fixed in `docker-compose.yml`: 256 MB, `volatile-lru` (never evicts TTL-less keys such as revocation markers). **Production Redis must get the same two settings**; the dev container picks it up on `docker compose up` | — | — |
| 16.3 | DB connection count | `[runtime test required]` — 10 HikariCP + WS thread pool; measure under load | — | `infra/db-pool` |
| 16.4 | CPU / RAM consumption | `[runtime test required]` — no APM configured | — | `ops/apm` |
| 16.5 | Disk utilisation (storage) | ❌ `LocalStorageService` writes to container local disk — ephemeral, not monitored, fills up silently | 🔴 | `infra/object-storage` |
| 16.6 | Network bandwidth | `[runtime test required]` | — | `ops/apm` |
| 16.7 | Background job queue / worker backlog | ✅ N/A — no background jobs or workers | — | — |
| 16.8 | Cache hit / miss ratio | ⏭ Needs a metrics/monitoring stack (16.13) | 🟡 | `ops/metrics` |
| 16.9 | Riverpod provider memory leaks | ✅ `autoDispose` + `ref.onDispose(subscription.cancel)` pattern used consistently; no dangling subscriptions found | — | — |
| 16.10 | ChatSocket connection leak | ✅ `ref.onDispose(socket.disconnect)` on `chatSocketProvider`; single shared instance | — | — |
| 16.11 | Memory growth over prolonged session | `[runtime test required]` — code is clean; needs Flutter DevTools memory profiler under real usage | — | `perf/endurance` |
| 16.12 | Actuator health endpoint | ✅ `/actuator/health` with liveness/readiness probes enabled and `permitAll()` in `SecurityConfig` | — | — |
| 16.13 | Metrics / APM endpoint | ⏭ Not in our hands: choose a monitoring stack first (Prometheus/Grafana, CloudWatch…). Exposing `/actuator/prometheus` is then two lines | 🟡 | `ops/metrics` |

### Detail

**16.1 — HikariCP defaults in all profiles 🟡**
Every profile sets only `connection-init-sql: SET TIME ZONE '+05:30'`. HikariCP defaults: `maximumPoolSize = 10`, `connectionTimeout = 30s`, `idleTimeout = 10min`, `leakDetectionThreshold = 0` (disabled). With 16+ API calls on home screen load (measured in Section 2) and concurrent users, 10 connections will be exhausted quickly under any real traffic.
> Fix: set `hikari.maximum-pool-size: 20`, `hikari.leak-detection-threshold: 5000` (5s) in the base profile. Tune down or up based on actual `HikariCP.pool.TotalConnections` metric once APM is added.

**16.2 — Redis has no eviction policy 🟡**
Rate-limit keys have TTLs ✅ but `rtu:{userId}` (token set) grows indefinitely for active users, and CircleCache entries accumulate. Without `maxmemory-policy: allkeys-lru`, Redis will refuse writes and throw `RedisConnectionException` once memory is exhausted (Section 9.9 risk compounds this).
> Fix: set `maxmemory 256mb` and `maxmemory-policy allkeys-lru` in the Redis instance config, or via Spring `spring.data.redis.maxmemory` property.

---

## 17. Long-running and endurance testing

> All items below require a running staging environment. Code-level risks are noted where identifiable without runtime data.

| # | Test scenario | Code-level risk | Runtime test status |
|---|---|---|---|
| 17.1 | 24-hour continuous API traffic | HikariCP defaults may exhaust under sustained load (Section 16.1) | `[not yet run]` |
| 17.2 | Repeated login / logout cycles | Refresh token JTI set (`rtu:{userId}`) grows if old JTIs not cleaned up on rotate — `issueTokens()` adds but only `revokeAllFor()` / `logout()` removes | `[not yet run]` |
| 17.3 | Prolonged chat session | ChatSocket is a single shared instance; `autoDispose` + `ref.onDispose` clean up screen-level subscriptions ✅ — unlikely to leak | `[not yet run]` |
| 17.4 | Repeated file uploads | `LocalStorageService` writes to container disk with no size cap — disk fills up silently | `[not yet run]` |
| 17.5 | Continuous API traffic — memory growth | No Spring heap / metaspace tuning in JVM args; Kotlin/Spring baseline RAM ~300MB, no growth expected without load | `[not yet run]` |
| 17.6 | Repeated navigation (Flutter) | Riverpod `autoDispose` reclaims provider state on route pop ✅; no leaked controllers identified | `[not yet run]` |
| 17.7 | Performance degradation over time | OFFSET-free cursor pagination ✅; no scheduled maintenance jobs that compact tables | `[not yet run]` |
| 17.8 | Connection leaks (DB, Redis, WS) | ✅ Leak detection on (20 s); 0 leak warnings across the Section 3 load tests (~150 k requests) | partly run |
| 17.9 | Background job accumulation | ✅ N/A — no background jobs | — |
| 17.10 | Memory growth under post/image load | `ImageProcessor` re-encodes in memory per request; large concurrent uploads could spike heap | `[not yet run]` |

---

## 18. Operational readiness and incident management

> Verified by reading: `logback-spring.xml`, `application.yml` (management config), `SecurityConfig.java`, `GlobalExceptionHandler.java`, `RequestIdFilter.java`.

| # | Item | Status | Severity | Backlog label |
|---|---|---|---|---|
| 18.1 | Central monitoring dashboard | ❌ none — no APM, no Grafana, no CloudWatch | 🔴 | `ops/monitoring` |
| 18.2 | Critical failures automatically alerted | ❌ no alerting — failures appear only in console logs (Section 5.14) | 🔴 | `ops/alerts` |
| 18.3 | Alerts are actionable | ❌ N/A — no alerts exist | 🔴 | `ops/alerts` |
| 18.4 | Incidents are traceable | ✅ Fixed: request id in every response, error body and log line; qa/prod logs persisted to a rotated file (5.11) | — | — |
| 18.5 | Incident severity classification | ✅ Fixed: SEV1–4 in `docs/RUNBOOK.md` | — | — |
| 18.6 | Affected users identifiable | ✅ Fixed: every log line of a signed-in request carries `[userId]`; auth failures logged (5.6) | — | — |
| 18.7 | Incident response procedure | ✅ Fixed: "First five minutes" + "After an incident" in `docs/RUNBOOK.md` | — | — |
| 18.8 | Production health dashboard | ❌ `/actuator/health` returns `UP`/`DOWN` ✅ but no dashboard consuming it | 🟡 | `ops/monitoring` |
| 18.9 | Known issues documented | ✅ This report + the runbook's "Known failure modes" table | — | — |
| 18.10 | Operational runbook | ✅ Fixed: `docs/RUNBOOK.md` (severity, first 5 minutes, known failure modes, routine jobs, config pitfalls, releases/rollback) | — | — |
| 18.11 | Release ↔ failure traceability | ✅ Fixed: `build-info` → `GET /actuator/info` returns version + build time (public, nothing sensitive) | — | — |

### Detail

**18.1 / 18.2 — No monitoring or alerting 🔴**
The backend exposes `/actuator/health` and `/actuator/info` only. No metrics endpoint, no Micrometer, no Prometheus scrape config, no Grafana dashboard, no CloudWatch alarms, no PagerDuty/OpsGenie integration. A production outage will not be detected until a user reports it.

**Minimum viable observability stack (in priority order):**
1. Add `spring-boot-actuator` Micrometer + Prometheus endpoint (`management.endpoints.web.exposure.include: health,info,prometheus`)
2. Add a log aggregator (Loki or CloudWatch Logs) so console logs survive container restarts
3. Set a CloudWatch/Grafana alarm on `jvm_memory_used_bytes` and 5xx error rate
4. Add `info.app.version: @project.version@` to `application.yml` so the health endpoint exposes the deployed version

**18.11 — Release traceability gap ⚠️**
If a failure is first seen in production there is no easy way to know which commit or version introduced it without reading Git history manually. Flyway schema version in `schema_version` table gives DB migration state, but application code version is not exposed anywhere at runtime.
> Fix: add `info.app.version: @project.version@` and `info.git.commit: @git.commit.id.abbrev@` (via `spring-boot-maven-plugin` git-commit-id plugin) to `application.yml`. Then `GET /actuator/info` returns the deployed SHA — fast incident triage without a CI lookup.

---

## Fix log: Sections 4–18 (2026-11-10)

Everything in our hands was fixed; outside-service items were skipped (marked ⏭ in each section).

| Area | Change | Files |
|---|---|---|
| DB N+1 / unbounded | Conversations list 4N → 4 queries; feed actor fetch-joined; banner = count + top 3; schoolmates queried only on cache miss, names-only, capped at 5 000 | `ChatService`, `ChatMessageRepository`, `ConversationRepository`, `FeedEventRepository`, `FeedService`, `UserRepository`, `CircleService` |
| DB per-request lookups | `isStaff()` reads the token's role; member checks are id-only queries | `CommunityService`, `CommunityMemberRepository` |
| DB indexes | 9 indexes (pinned posts, unread notifications, conversations by user + recency, RSVPs/join requests by user, accepted connections) | `V36__query_performance_indexes.sql` |
| Cleanup | Nightly job: expired OTPs, read notifications > 180 days | `maintenance/MaintenanceJobs.java` |
| Redis resilience | Revocation check fails open (bounded by 15-min tokens); Redis errors → 503 not 500; circle-cache eviction `KEYS` → `SCAN` | `AuthService`, `GlobalExceptionHandler`, `ErrorCode`, `CircleCache` |
| Logging | 404s logged; JWT rejections logged (expired at DEBUG); `[userId]` on every line; qa/prod rotated file log | `GlobalExceptionHandler`, `JwtAuthFilter`, `logback-spring.xml` |
| Security | Security headers; log out of all devices; account-deletion audit table | `SecurityConfig`, `AuthController`, `AccountService`, `V37__account_deletion_audit.sql`, `profile_tab.dart`, `auth_provider.dart`, `auth_repository.dart` |
| Ops | Build version on public `/actuator/info`; Redis memory cap; operations runbook | `pom.xml`, `SecurityConfig`, `docker-compose.yml`, `docs/RUNBOOK.md` |
| App UX | 404 page; Retry on 10 error states; `EmptyState.action`; validation as you type; 640 px max width on tablet/web; dead `SearchScreen` + `ClassroomScreen` deleted | `app_router.dart`, `feed_shared.dart`, 8 screens, `app.dart` |

**Verification:** backend 56 tests (0 failures, 1 Docker-only skipped); `flutter analyze` no new issues; `flutter test` 95/95. The API was booted on a throwaway database: V36 + V37 applied, all new JPQL validated at startup, and the changed endpoints were smoke-tested (conversations, activity, banner, recent joins, home feed, schoolmates, security headers, logout-all 200→401, deletion audit row written). The throwaway DB was dropped afterwards. **Not exercised live:** Redis-outage paths (would have meant stopping your shared Redis), the nightly job's schedule (SQL dry-run as counts only), and the UI changes in a browser.

## Backlog summary (what's left)

### ❓ Needs your decision

| Label | Item | Section |
|---|---|---|
| `release/app-id` | Pick the permanent Android package name (e.g. `com.apsbrats.app`); one-line change | 12.15 |
| `infra/stomp-cluster` | Before running a 2nd API instance: RabbitMQ + STOMP relay. Until then deploy exactly one | 3.7, 7.17 |

### ⏭ Needs an outside service or account (not in our hands)

| Label | Item | Section |
|---|---|---|
| `ops/backup` 🔴 | Automated DB backups + restore drill (hosting provider) | 4.19, 10.17, 15 |
| `infra/object-storage` 🔴 | S3/GCS `StorageService` implementation (needs bucket + credentials) | 11.16, 16.5 |
| `ops/crashlytics` 🔴 | Crash reporting (Firebase/Sentry); wire into `ErrorReporter.report()` | 5.10, 11.17 |
| `ops/alerts`, `ops/monitoring` 🔴 | Alerting + dashboard; then `/actuator/prometheus` (two lines) | 5.14, 16.13, 18.1–18.3 |
| `notif/fcm-push` 🔴 | FCM push end to end | 7.14, 11.15 |
| `integration/otp-email` 🔴 | OTP email delivery (email provider) | 11.14 |
| `release/keystore` 🔴 | Release signing key, created and kept by the owner | 12.16, 14.4 |
| `analytics/*` 🟡 | Analytics SDK + consent (whole of Section 6) | 6 |
| `integration/firebase-*` 🟡 | Firebase credentials check, timeout, outage handling | 9.10, 11.2, 11.5, 11.9 |
| Prod Redis | Apply `maxmemory 256mb` + `volatile-lru` to the production Redis too | 16.2 |

### 🟢 Open, low priority

| Label | Item | Section |
|---|---|---|
| `ux/a11y` | Accessibility audit (WCAG 2.1 AA) | 13.14 |
| `ops/log-json` | JSON log format, once a log aggregator is chosen | 5.13 |
| `data/orphaned-uploads` | Unreferenced uploaded files; do as an S3 lifecycle rule | 10.5 |
| `db/popular-offset` | OFFSET paging on Popular sort; fine at community scale | 4.16 |
| `perf/provider-cache`, `perf/http-cache` | Short client cache / ETags, only if re-fetch delay becomes noticeable | 2.9, 2.11 |
| `load/login-storm`, `load/chat-flood` | Skipped load scenarios, ready in `load/k6-load.js` | 3.13, 3.14 |

---

*Device/browser checks still worth doing by hand: airplane-mode flow (Section 1), tab call count in DevTools (2.14), 404 page, Retry buttons, wide-window layout.*
