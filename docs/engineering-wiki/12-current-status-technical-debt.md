# 12 - Current Status and Technical Debt

What works, what is partial or missing, and every known bug, limit and risk, with where to look. This is the honest list; update it whenever something is fixed or discovered.

Last verified: 2026-11-16 against commit 168d987 (working tree has uncommitted changes).
Tags: **[re-verified]** = I checked the code line myself after the audit; **[audit]** = reported by an area audit with a file reference, not independently re-run; **UNVERIFIED** = could not be confirmed from the repo.

## 1. Top risks (read these first)

| # | Risk | Where | Tag |
|---|---|---|---|
| 1 | **Email OTP depends on Brevo being configured on the live API.** Delivery was implemented on 2026-11-20 (`email/` package). Until `BREVO_API_KEY` and a verified `EMAIL_SENDER_ADDRESS` are set and `GET /api/v1/admin/email/health` says UP, prod answers code requests with 503. Not yet verified with a real key and a delivered email. The Firebase client config files are still not in the repo. | `apsbrat-api/.../email/`, `auth/AuthService.requestOtp` | implemented, live setup UNVERIFIED |
| 2 | **Demo seed runs in every environment.** `V14__seed_demo_data.sql` is a Flyway migration that inserts 11 demo users (example.com emails), schools, communities, memberships and messages, so a fresh production DB gets them and they appear in people search. | `db/migration/V14__seed_demo_data.sql` | [re-verified] |
| 3 | **A moderator can undo an admin ban.** `reinstateUser` has no `requireAdmin` (ban and set-role do). | `api/safety/AdminService.java:73` | [re-verified] |
| 4 | **Block, `discoverable` and ban are not applied on every read path.** Old DM threads stay readable after a block; circle lists, career, school history, mutual lists, recent joins, `GET /users` and legacy `/search` skip some or all checks. | `chat/ChatService.messages`, `circle/CircleService`, `career/CareerService.java:34`, `user/UserController.java:25`, `search/SearchService.java:41` | [audit] |
| 5 | **Account deletion leaves personal data** (career entries, location fields, memberships, connections, settings, notifications, uploaded files); the export omits most data. | `user/AccountService.java:62-90` | [audit] |
| 6 | **Ban/suspend rely on token revocation only.** `JwtAuthFilter` and `OnboardingGate` never check `banned_at`/`suspended_until`; revocation fails open when Redis is down (up to 15 min). | `auth/JwtAuthFilter.java`, `user/OnboardingGate.java:37` | [audit] |
| 7 | **Redis outage behaves inconsistently**: rate limit and revocation fail open, OTP, posts, group chat and uploads return 503, keyed POSTs may return a raw 500 (the idempotency filter does not catch Redis errors). | `common/web/IdempotencyFilter.java:68` | [re-verified] |
| 8 | **Chat is single-instance only**: in-memory STOMP broker, STOMP auth only at CONNECT (socket survives token expiry), no catch-up after a dropped socket. | `chat/WebSocketConfig.java:36`, `chat/StompAuthChannelInterceptor.java`, `frontend/lib/features/chat/data/chat_socket.dart` | [audit] |
| 9 | **Secrets and personal data hygiene**: `local_dump.sql` and `clean_dump.sql` are untracked and not gitignored (no `.gitignore` pattern covers a Firebase service-account JSON either; `.env` is ignored); weak dev defaults for the JWT secret and master OTP are in `application.yml` and `docker-compose.yml`; the uncommitted edit of `docs/DEPLOYMENT.md` (around line 184) contains an Upstash Redis hostname: replace it with a placeholder before committing. | repo root, `application.yml`, `docker-compose.yml` | dumps [re-verified] |
| 10 | **Code and schema not in git**: migrations V38, V39, V40, `ConnectionQueryService`, `UserPair`, `ConnectionEvent*`, the `places/` package, `frontend/lib/core/location/`, `app_icons.dart`, `my_communities_screen.dart`, `dob_picker_sheet.dart`, new image assets and the new tests are untracked while tracked files already depend on them: a checkout of `168d987` does not compile or start. V39 is also not backward compatible with the previous app version and locks `connections` while it runs. | `db/migration/V38..V40` | [re-verified] |
| 11 | **Frontend**: a network blip during token refresh logs the user out; `devSkipLogin()` (seeded demo login with the dev master code) is reachable only from a `kDebugMode` button but stays compiled into every build (comment: "Remove before release"); fake data feeds live UI; only `main.dart` initialises Firebase (the dev, staging and prod entrypoints skip it, so Google sign-in only works through `main.dart`). | `dio_client.dart` `refreshAccessToken`, `auth_provider.dart`, `dummy_data.dart` importers, `main.dart` vs `main_*.dart` | dummy data [re-verified] |
| 12 | **Memory exhaustion hangs the whole API and nothing restarts it.** Chat sockets, REST and the DB pool share one JVM with no `-Xmx`, no container memory limit, no `-XX:+ExitOnOutOfMemoryError` and no restart policy for the `api` service. There is also no cap on sockets per user or in total. In a local test with a 160 MB heap the API threw `OutOfMemoryError` in the WebSocket threads while about 880 sockets were connecting, then stopped answering: the health endpoint returned nothing, REST calls took up to 18 s or failed, and the process stayed up. With a 512 MB heap the same 1000 sockets and 1.3 million pushes ran cleanly (heap peak 390 MB). | `apsbrat-api/Dockerfile` (since 2026-11-17 `JAVA_OPTS` also sets `-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError`, and `docker-compose.yml` has a 1 GB limit and `restart: unless-stopped`; the Cloud Run memory setting, the socket cap and the outbound queue bound are still open, not verified on a running deployment), `docker-compose.yml`, `chat/WebSocketConfig.java` | measured 2026-11-16 (laptop, dev profile) |

## 2. Implemented features

Sign-in flow and refresh tokens (email OTP logic, Google), onboarding gate, profile/school history/social links/career/settings, communities (school and interest), events and RSVP, memories, posts with photos, likes, comments, pins, reports, Home feed, connections with history and blocking, DMs and group chat with push, people search and circle, in-app notifications, admin/moderation API. Per-feature detail: [03-features/](03-features/README.md).

## 3. Partially implemented

- Sign-in: logic present, email delivery missing (risk 1).
- Notifications: rows are created for comments, connection requests/acceptances and event changes only. No push (`users.fcm_token` is only ever set to null; `firebase_messaging` is declared but unused), no unread badge (`unreadNotificationCountProvider` unused), tapping does not mark read (`markRead` unused in the UI), `JOIN`/`MESSAGE` types and `group_key` are never written, and no notification for join requests, approvals, RSVPs or likes.
- Moderation: reports and an admin API exist; the app has no moderator/admin screens; the first ADMIN has no provisioning path (UNVERIFIED).
- Owner tools: the endpoint to remove a member works, but no screen calls it. School communities have no OWNER at all (no code creates SCHOOL communities; V27 backfilled them), so only staff can pin or manage their events and nobody can delete them.
- Feed: `/feed/activity`, `/feed/recent-joins`, `/feed/banner` exist but the app calls none of them; `feed_events` has no writers (only the V14 seed).
- Realtime: chat only. Nothing else is pushed.
- Force-update/maintenance gate: `appRemoteConfigProvider` and `GET /api/v1/app/config` exist but the app never consumes them.

## 4. Not implemented (verified by search)

Post and comment editing, comment replies, reactions other than likes, reposts, saved posts, follow, community editing, event deletion (cancel only), DM edit/delete/hide, notification delete and preferences, avatar removal, accept-all/decline-all for requests, push notifications, email OTP delivery, admin UI, backups and restore, alerting and crash reporting (`ErrorReporter` only prints), CD pipeline, rollback procedure.

## 5. Known bugs

| Bug | Where | Tag |
|---|---|---|
| Editing a social link resets a hidden link to visible (privacy) | `user/social/UserSocialLinkService.upsertLink`, `profile_tab.dart:717` | [audit] |
| Leaving a community does not invalidate the Home feed, so its posts stay until refresh | `communities_tab.dart` `CommunityTile._leave` | [audit] |
| Comments beyond the first 50 cannot be viewed | `post_screen.dart` ~222 | [audit] |
| Pin limit (3) can be exceeded by a race (check then set) | `PostService.java` ~241 | [audit] |
| Post rate limit counts before validation (a rejected post uses a slot); it throws when Redis is down | `PostService.java:71` | [audit] |
| First-page Home feed error hides the section with no retry; a failed "Show more" removes the button (`hasMore=false`) | `home_tab.dart:454`, `community_repository.dart` `PostFeedNotifier` | [audit] |
| `resolveReport` accepts any status string; over 20 chars causes a 500; never un-hides content | `safety/AdminService.resolveReport` | [audit] |
| A moderator restore revives posts their author deleted | `PostService.restorePost` | [audit] |
| JWT `iat` is in seconds but the revocation marker in milliseconds: a token issued in the same second after revocation is rejected | `AuthService.java:191` | [audit] |
| OTP consume is not atomic: two parallel verifies can both succeed; 5 wrong guesses lock a victim's OTP for 15 min; OTPs are stored in plain text | `AuthService.verifyOtp`, `:95` | [audit] |
| Refresh-token reuse is not detected | `AuthService` | [audit] |
| Stranger-DM rule (one message until reply) is check-then-write without a lock: two concurrent sends can both pass | `ChatService.sendMessage` ~185-195 | [audit] |
| `endForBlock` writes REMOVED even for a PENDING request | `ConnectionService.endForBlock` | [audit] |
| Legacy pending/sent lists do not filter deleted users (the paged ones do) | `ConnectionQueryService.listPending/listSent` | [audit] |
| Framework-level 413/415 (multipart limit, content type) use code `BAD_REQUEST` while `ImageProcessor` uses the correct codes; 409s are logged at ERROR with a stack (convention says WARN) | `GlobalExceptionHandler` | [audit] |
| Duplicate report returns 409 although the first report counted | `ReportService` | [audit] |
| Report shown on the user's own posts and rejected by the server; delete dialog says "can't be undone" but delete is soft | `post_card.dart` | [audit] |

## 6. Known limitations

- One API instance only (in-memory chat broker); the nightly cleanup has no lock but is idempotent, so extra instances are harmless. Redis required.
- Media files are public by URL, including chat photos; orphaned uploads and old avatars are never deleted; no pixel-size cap before image decode (`media/ImageProcessor.java:49`); avatar upload has no specific rate limit.
- `Env` defaults to localhost with cleartext `ws://`/`http://`; no Android network-security config found (UNVERIFIED for emulator use).
- `LocalDateTime` everywhere: event times are zone-less and the JVM zone matters (only the Docker image pins it).
- `CircleService.MAX_CANDIDATES = 5000` silently truncates large schools.
- Idempotency key is not tied to the request body.
- Request ids from the client are trusted without validation (`RequestIdFilter`).
- OTP re-request after a decline or removed connection is unlimited; every re-request notifies.

## 7. Performance concerns

| Concern | Where | Tag |
|---|---|---|
| A like tap costs about 15-20 SQL statements (membership/community checks 2-3 times plus a full DTO rebuild); counted from code, not measured in production | `PostService.like` | [audit] |
| Unpaged lists: DM conversations, legacy connections/pending/sent/mutual | `ChatService.listConversations:101`, `ConnectionQueryService` | [audit] |
| `CommunityChatService.myChats` runs 2 queries per joined community | `CommunityChatService.java:71` | [audit] |
| Legacy `GET /search` (still called by the app, `search_repository.dart:60`) loads every `LIKE '%term%'` match into memory | `SearchService.java:41` | [audit] |
| `OnboardingGate` adds a user read to every gated request | `OnboardingGate.java:37` | [audit] |
| Popular-posts sort has no supporting index; people search and circle use offset paging | `PostRepository.findPopularPage` | [audit] |
| Home builds every loaded post at once (no lazy list); no pull-to-refresh | `home_tab.dart` | [audit] |
| Users with tens of thousands of connections: A-to-Z list 60-75 ms, mutual 80-150 ms (measured on 2M rows) | `ConnectionRepository` | measured |
| Group chat push runs inside the sender's request after commit: it lists all online user ids, runs 2 queries, then makes one `convertAndSendToUser` call per online member, so one message costs as many pushes as there are online members and the sender's POST waits for them. Measured with 1000 online members, 512 MB heap, API, Postgres and test client on one laptop: all 1.3 million pushes delivered (100%); at 30 messages/s (about 30,000 pushes/s) push p95 331 ms, POST p95 up to 212 ms, CPU peak 46%, DB pool busy peak 6 of 10, outbound executor queue peak 2,669 tasks; unrelated API calls stayed under 90 ms p95 in their worst second. The ceiling was not found: the test client was the limit (loop lag up to 185 ms). The outbound queue has no size limit in this repo's config (Spring's default is also unbounded: not re-checked here), which is the likely route to the memory exhaustion in risk 12 (inference, not proven) | `CommunityChatService.pushAfterCommit:220`, `tools/ws_load.py` | measured |
| REST load, k6 `spike` scenario: 1000 virtual users, browse mix: 566 requests/s, 0 failures, p95 883 ms against the 1 s threshold, max 2.4 s; Hikari pool stays at its default of 10 | `apsbrat-api/load/k6-load.js` | measured |
| Geoapify calls have no timeout or caching; errors become a generic 500 | `places/PlacesService.java:24` | [audit] |

## 8. Security concerns not in the top list

- `GET /api/v1/users` lists all non-deleted accounts (50 per page) to any logged-in user, including bare accounts, ignoring `discoverable`, blocks and bans; it is outside `OnboardingGate`.
- Any 3 accounts can auto-hide any post, comment or message; no notice to the author, no appeal, no rate limit on reports (`ReportService.java:69`).
- Connection requests, likes, RSVPs, reports, join requests and block/unblock have no per-action rate limit (only the global 300/min per user).
- Proxy trust for `X-Forwarded-For` is configured for private ranges only: if the production proxy is outside them, all users share one IP budget (UNVERIFIED).
- Block race: `BlockService.block` is exists-then-insert without a lock; a parallel duplicate returns 409 (harmless).

## 9. Technical debt

- **Duplicate indexes**: `idx_users_fullname_trgm` = `idx_users_full_name_trgm`; `idx_school_history_lookup` = `idx_school_history_classmates`; `idx_notif_user` overlaps `idx_notif_user_created_desc` (`db/migration`).
- **Dead code/data**: `users.password_hash`, the `PasswordEncoder` bean, `notifications.group_key`, `feed_events` (never written), `ChatOverlay` fake chat (`dummy_data.dart`), `Env.cdnUrl`, unused packages (`riverpod_annotation`, `riverpod_generator`, `video_player`, `chewie`, `shimmer`, `reactive_forms`, `url_launcher`, `flutter_image_compress`, `firebase_messaging`, `flutter_local_notifications`).
- **Missing constraints/validation**: no CHECK on `users.role` or `reports.status`; the four admin request bodies and the RSVP body have no `@Valid`.
- **Error handling vs convention** (`docs/conventions/error-handling.md`): no handler for `ConstraintViolationException`, `MissingRequestHeaderException`, `TransactionSystemException`; test coverage of the 400/404/409/500 matrix UNVERIFIED.
- **Tests**: 18 failing Flutter tests block `flutter test` as a CI gate; no tests for Dio interceptors, `ChatSocket` or `PostFeedNotifier`; no integration test of the HTTP layer; no coverage tooling; CI Flutter channel unpinned; `ApiApplicationTests` skipped without Docker. See [testing.md](testing.md).
- **Config drift**: `main.dart` duplicates `main_dev.dart` and hard-codes the dev flavor; dev sets `baseline-on-migrate: true` with baseline version 4 (an existing database without a Flyway history table is assumed to contain V1-V4 and those scripts never run; an empty database migrates normally); `AppTheme` is green while the screens are crimson; `EmptyState` and colour constants live in `feed_shared.dart`; several files exceed 1000 lines (`batch_tab.dart` ~2250, `community_screen.dart` ~2000).
- **Error utilities** `friendlyError`/`statusOf` live in the community repository and are duplicated in `ChatController`; backend `code` and `requestId` are never read by the app; `AuthController` replaces all server messages with fixed text (ban/suspend/429 are hidden).
- **Post draft key** `post_draft:*` has no user id and survives logout.
- **No auth guard on `/home/**`** in the router; session validity is found on the first API call.

## 10. Documentation drift (old docs and rules)

These existing files disagree with the code. This wiki is the source of truth until they are updated or removed.

| File | Problem |
|---|---|
| `docs/API.md`, `docs/BACKEND.md`, `BACKEND_NOTES.md`, `docs/DEPLOYMENT.md`, `docker-compose.yml` header, `apsbrat-api/README.md` | Say `/api/...`; the real prefix is `/api/v1`. Describe phone OTP, password endpoints, `POST /users`, and call chat "REST only, no websocket" (STOMP `/ws` exists); `BACKEND_NOTES.md` uses a non-existent `./mvnw`; the API README calls auth/community/chat/notifications "placeholder". |
| `docs/API.md` | Missing `/auth/google`, `/auth/logout(-all)`, `/users/me*`, avatar, career, block, reports, admin, `/feed/home`, all of the connections additions; says `/search` also returns communities (it returns `people` only). |
| `docs/DATABASE.md` | Stops at V14; phone-based `otp_codes`; no `user_settings` section; old one-row-per-direction `connections`; none of V15-V40. See [06](06-database.md). |
| `docs/FRONTEND.md`, `frontend/README.md` | `BASE_URL=.../api`, "Clean Architecture" label, missing `WS_URL`/`CDN_URL`; `docs/FRONTEND.md` presents the three feed endpoints as live (UNVERIFIED comparison). |
| `docs/PRODUCT_GAP_REPORT.md`, `docs/PERFORMANCE.md`, `docs/QA_AUDIT_REPORT.md` | Partly outdated (environments now exist in config; feed endpoints optimised but unused; upload and pin limits missing). |
| `CLAUDE.md` | Mentions `RegisterUserRequest` (no such class; registration merged into the OTP flow; `UpdateProfileRequest` is validated). Onboarding order says Profile -> Verify -> Schools -> Socials; in code verification is the login screen and alumni get an extra After-school step. The global C# rules (log4net etc.) do not apply to this Java API (it uses SLF4J/Logback). |
| Media domain | App default `CDN_URL` is `cdn.apsbrat.in`; docs use `media.apsbrats.com`. |

## 11. Open questions (UNVERIFIED)

Where qa/prod actually run, DNS/CDN, Neon/Upstash use; how the first ADMIN is created; how production loads the school list and whether the V14 demo data was cleaned; whether a production proxy is inside the trusted forwarded-for range; whether more than one API instance runs; how production scrapes metrics (denied to everyone in qa/prod); whether Firebase credentials are mounted in qa/prod; whether banned users' open sockets are closed; which layer sets `created_at` on chat tables; root causes of 11 of the 18 failing Flutter tests; Android emulator cleartext behaviour.
