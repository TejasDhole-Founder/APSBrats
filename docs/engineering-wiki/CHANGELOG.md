# Changelog

Important technical and architectural changes, newest first. One short entry per change. Add to this file whenever you change architecture, an API contract, the schema, or a significant behaviour (see [README.md](README.md)).

## Unreleased: work from the 2026-11-14 to 2026-11-16 sessions (not committed yet)

Also found uncommitted in the working tree (origin not recorded in this wiki): V38 (`users.state`, `country`, `latitude`, `longitude`, `place_id`), the `places` package (Geoapify city autocomplete and reverse geocode), the onboarding location lookup and DOB picker (`frontend/lib/core/location/`, `dob_picker_sheet.dart`), a login/splash/app-icon refresh with new brand assets, the actuator and Prometheus dependencies, and a rewritten `docs/DEPLOYMENT.md`.

Backend (`apsbrat-api`)
- **Connections redesigned (V39):** one row per user pair (`user_low_id`/`user_high_id`), `requested_at`, `connection_events` history, advisory lock per pair in every state change, reverse request auto-accepts, `created_at` is no longer reset on re-request, `BlockService` now ends connections through `ConnectionService.endForBlock`. V39 backfills pairs and history from old rows, merges any pair stored twice (keeps the accepted/latest row, moves history and notification links), drops `uq_connection` and the single-column connection indexes. **Not backward compatible with the previous app version.** [06](06-database.md), [connections](03-features/connections-and-blocking.md), decision D8.
- **Read side split:** `ConnectionQueryService` (lists, status, mutual, history). New endpoints: `GET /connections/page`, `/connections/pending/page`, `/connections/sent/page`, `/connections/{id}/mutual/count`, `/mutual/page`, `/history`. `POST /connections/{id}` now returns `{status: PENDING|ACCEPTED}`. Existing endpoints unchanged (the app still uses the legacy list endpoints).
- **V40:** partial indexes for pending requests (`idx_conn_pending_incoming`, `idx_conn_pending_outgoing`); 36.8 ms -> 0.43 ms for 6,000 waiting requests in a local 2M-row test. Decision D10.
- **Connection lists** load both users in one query (fixes N+1 in the legacy lists).
- **Communities:** `GET /communities/mine/chats` (last message and unread per joined community) and `requested` list in `MyCommunitiesDto` (for the Requested filter).
- **Profile:** removed `batchmatesCount` from `ProfileDto` (it was just the connected count).
- **Dev-only metrics:** `app.actuator.public-metrics` opens `/actuator/prometheus` and `/actuator/metrics` in the dev profile only; dev also records latency histograms. Decision D18.

Frontend (`frontend`)
- **Social tab:** Messages and Communities merged into one "Social" tab with a segmented control; unified chat list (All, Direct, Groups, Unread), quick row with online friends.
- **Communities UI:** new school cards and Discover list, "Your Communities" screen (All/Joined/Requested/Owned, menu with Open/Leave), APS Patiala banner as the school cover, round badge removed from school views.
- **Community page header:** verified check, meta line (kind | members), avatar stack with "+N members", tabs with icons, share prompt with image/video/article icons, Latest/Popular toggle styling. The online count was removed from the header.
- **Icons:** all Material icons replaced by `hugeicons` (`AppIconData` typedef). Decision D17. Liked/unliked heart now differs only by colour.
- **Profile:** removed the Batchmates stat and the "mutual batchmates" row and sheet.
- **Tests:** icon finders now use `test/hugeicon_finder.dart`; added `connection_contract_test.dart` with fixtures recorded from a real server run (`test/fixtures/connections/`).

Web app (2026-11-17)
- **Clean URLs:** `usePathUrlStrategy()` in `main.dart` (`flutter_web_plugins` added). `frontend/web/_redirects` sends every path to `index.html`; `frontend/web/_headers` sets cache and security headers.
- **Login guard:** any `/home...` path without a stored user id redirects to `/login?from=<path>`; after sign-in the app goes to `from` (only `/home` paths are followed). `LoginScreen` has a new `from` parameter. Logged-out use of other routes is unchanged.
- **Google sign-in button is hidden on the web** (no web client ID or Firebase web config yet): email code only. Chat reconnect on resume already existed (`chatSocketProvider`).
- `web/index.html`: `viewport-fit=cover`, `theme-color`, real description, `apple-mobile-web-app-capable`. `web/manifest.json`: `id`, `scope`, `start_url` `/`, crimson theme colour.
- **Memory safety:** `Dockerfile` `JAVA_OPTS` adds `-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError`; `docker-compose.yml` api gets `mem_limit` (default 1g), `restart: unless-stopped` and `CORS_ALLOWED_ORIGINS`. Addresses the heap part of risk 12 in [12](12-current-status-technical-debt.md); the socket cap and bounded outbound queue are still open. Steps for the web host and Cloud Run: `docs/DEPLOYMENT.md` (Part D).
- Verified: `flutter build web --release` succeeds; the 3 changed Dart files analyze clean. The test suite has 18 failing tests with or without these changes (88 pass); they look for old welcome-screen text. Not tested on a real iPhone or Android phone, and the guard and `from` redirect were not run in a browser.

Icon sizes (2026-11-20)
- Fixed oversized icons from the Hugeicons switch. Cause: `HugeIcon` fills its box and ignores the surrounding icon size, and an `InputDecoration` icon slot forces at least 48 px, so field icons (calendar, building, search, ID card, location, chevrons) rendered at 48 px on the registration, career, school, event and profile screens. New `fieldIconSlot` (`core/theme/app_inputs.dart`) keeps the size; used in `appInputDecoration` and the identity, career and school field decorations and two `prefixIcon` uses. Set explicit sizes on inline chevrons (18) and list-row icons (20 to 22). Found by rendering the four registration steps to images. Test: `field_icon_size_test.dart` (3). 112 Flutter tests pass.

Batchmates tab (2026-11-20)
- Removed the Friends segment from Batchmates: friends are on the Social tab. The tab opens on Classmates. Removed its list, empty state, long-press remove and the Message button on those rows. Tests updated; 109 Flutter tests pass.

Email sign-in codes via Brevo (2026-11-20)
- New `email/` package: `EmailProperties` (`app.email.*`: `BREVO_API_KEY`, `EMAIL_SENDER_ADDRESS`, `EMAIL_SENDER_NAME`), `BrevoEmailClient` (Brevo REST, short timeouts, readable failure reasons), `EmailService` (what to send, reserved test domains skipped, prod 503 when not configured or Brevo fails), `EmailAdminController`.
- `AuthService.requestOtp` now emails the code. It is no longer one transaction (the email is sent without holding a database connection); a failed send deletes the code and the resend cooldown key. Behaviour change in prod: code requests answer 503 until Brevo is configured (before: they succeeded and nothing arrived).
- New ADMIN-only endpoints: `GET /api/v1/admin/email/health` (checks the key and sender with Brevo, sends nothing) and `POST /api/v1/admin/email/test` (5 an hour per admin; provider problems come back as `sent:false` with a reason). `SecurityConfig` lists `/api/v1/admin/email/**` as ADMIN before the ADMIN/MODERATOR rule.
- Verified: 30 new unit tests; full backend run 126 ran, 0 failed; the real API started against a throwaway database (401 without a token, 403 for a normal user, 200 for an admin); the real Brevo API answered 401 to a made-up key and the health, test and sign-in paths reported it correctly. NOT verified: a real key, a verified sender, or a delivered email (those are on the live host).
- Sender: `app.email.sender-address` now defaults to `verify@apsbrats.com` (verified in Brevo); `EMAIL_SENDER_ADDRESS` overrides it. Only `BREVO_API_KEY` is required.
- Docs: `docs/DEPLOYMENT.md` "Email (Brevo)", `.env.example`, `docker-compose.yml`, wiki pages 00, 01, 07, 09, 10, 12.

Web sanity pass (2026-11-20)
- **Flavor by build flag:** `Env.flavor` reads `--dart-define=FLAVOR=` (default `dev`). One startup path, `frontend/lib/bootstrap.dart`, serves `main.dart` and `main_dev/staging/prod.dart` (clean URLs, error reporting and Firebase were missing from the three flavor mains). The prod flavor shows no corner banner. CI builds the web app with `FLAVOR=prod`; before this the live site showed the DEV banner.
- **Back button:** a signed-in user who finished onboarding is redirected from `/` and `/login` to `/home` on every navigation, not only at launch, so browser/system back from Home no longer lands on the code screen. Unfinished registrations keep the old behaviour (resume on launch, welcome screen reachable).
- **Fewer calls:** `accessTokenTimeLeft` reads the token's expiry locally. The Dio client refreshes a token that has under 30 s left before sending the request (one shared refresh) instead of sending it, getting 401 and retrying. The chat socket no longer calls `GET /users/me` on every (re)connect: only when the token has under 60 s left.
- **Dev login on the live site:** not possible by design. The live API runs the prod profile, which always refuses the universal OTP, and `DEV_LOGIN` is off in CI. Real login on prod needs email OTP delivery (still missing).
- Tests: 110 pass (`token_expiry_test`, a redirect test in `launch_redirect_test`).

Web app connection and CI (2026-11-20)
- Live API refused the web app origin (403 "Invalid CORS request"): the qa/prod `app.cors.allowed-origins` default was empty. It now defaults to the web app address; `CORS_ALLOWED_ORIGINS` still replaces it. Takes effect when the API is redeployed.
- One workflow, `APS Brats CI/CD` (`.github/workflows/ci.yml`): jobs "API - build and test", "App - analyze and test", "Web - build and deploy to Cloudflare Pages"; runs on one branch no longer overlap (main is never cancelled mid-deploy). The deleted `deploy-web.yml` can still be listed in the Actions sidebar until its old runs are deleted.

Dev login flag (2026-11-20)
- `Env.devLogin` (`--dart-define=DEV_LOGIN=true`) shows "Skip login (dev)" in release builds; default off. It needs an API with the universal OTP `000000` (dev, or qa with `OTP_MASTER`); prod refuses it. See `docs/DEPLOYMENT.md` Part D.

Frontend tests and CI (2026-11-20)
- Fixed the 18 failing Flutter tests (stale expectations after the welcome, onboarding, school-year, username and Social-tab changes); suite is 106 passed. Details: [testing](testing.md) section 4.
- Fixed two narrow-phone overflows: gender chip on the identity screen, Messages/Communities segment control on the Social tab.
- `ci.yml`: `flutter analyze --no-fatal-infos`. Fixed 3 analyzer warnings (unawaited return in the launch redirect, unused `_HintCard`, unused test import). Removed my duplicate `deploy-web.yml`; the `web-deploy` job in `ci.yml` deploys to the `aps-brats-web` Pages project.

Tests (backend)
- Added `ConnectionFlowTest` (29 tests including races across threads), `ConnectionMigrationTest` (V39 on old-style data, including duplicate pairs), `UserPairTest`. Also verified two separate API instances on one Postgres (not part of the suite): opposite requests, double accept, accept vs withdraw, request vs block: all consistent.

Tooling
- `tools/api_dashboard.py`: local dashboard for request counts, latency percentiles, database call timings, pool, memory and optional Postgres statistics.
- This engineering wiki (`docs/engineering-wiki/`).
- `tools/ws_load.py`: 1000-socket community chat load test with a live dashboard (connections, push latency, delivery, other-API latency, heap, CPU, DB pool). `apsbrat-api/load/ws_chat_soak.py`: single-socket direct-message soak test (not run). Results and the memory finding: [12](12-current-status-technical-debt.md) risk 12 and section 7.

## Recent commits (from git; not the full history)

| Date | Commit | Change |
|---|---|---|
| 2026-11-10 | `168d987` | Untrack local-disk test uploads, gitignore `media/` |
| 2026-11-10 | `7f7cfdb` | Community events and chat, career history, security and performance hardening pass |
| 2026-09-27 | `f979c8a` | Chat rebuilt on REST + STOMP WebSocket, email and Google login, UI refresh |
| 2026-09-04 | `d6cda9b`, `7b8a000` | Auth and profile page changes |
| 2026-08-29 | `9de5e77`, `7bd3ede`, `8e4269b` | Android fix, merge of PR 1, early work |
