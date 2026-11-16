# 09 - Integrations
Every external service the system talks to: purpose, where it is wired, config, and whether it is actually working or only prepared.
Env var names only, never values.

Last verified: 2026-11-16 against commit 168d987 (working tree has uncommitted changes)

## Summary

| Service | State | Required to run? |
|---|---|---|
| PostgreSQL | Wired | Yes |
| Redis | Wired | Yes |
| Cloudflare R2 | Wired (optional, local disk is the default) | Only for qa/prod media |
| Firebase Auth / Google sign-in | Wired in code; needs server credentials file and client Firebase config | No (email OTP works without it) |
| Email / OTP delivery | NOT wired: the code is never sent by email | Gap |
| Geoapify places | Wired; needs API key | No (city search returns 503 without it) |
| FCM push notifications | NOT wired (packages declared only) | No |
| Prometheus / Grafana | Prometheus format exposed in dev only; no scraper or Grafana config in repo | No |
| Upstash | Not referenced in code; only in `docs/DEPLOYMENT.md` as a suggested Redis host | No |

## PostgreSQL
- Purpose: system of record. Flyway migrations V1..V40 in `apsbrat-api/src/main/resources/db/migration`.
- Communication: JDBC through Hikari (pool 10).
- Config: `DATABASE_URL` (qa/prod), `SPRING_DATASOURCE_URL`, `DB_USER`, `DB_PASSWORD`, `DB_POOL_SIZE`.
- Extensions: `uuid-ossp`, `pg_trgm`. The DB role must be allowed to create them (Flyway runs `CREATE EXTENSION IF NOT EXISTS`). UNVERIFIED on managed hosts.

## Redis
- Purpose: OTP request limits and lockout (`auth/AuthService.java`), global rate limiting (`common/web/RateLimitFilter.java`), idempotency keys (`IdempotencyFilter.java`), circle cache (`circle/CircleCache.java`), presence (`user/PresenceService.java`), post and community chat counters (`community/PostService.java`, `CommunityChatService.java`), upload limits (`media/ImageUploadService.java`).
- Communication: Spring Data Redis (`StringRedisTemplate`).
- Config: `SPRING_DATA_REDIS_HOST`, `SPRING_DATA_REDIS_PORT`, `SPRING_DATA_REDIS_PASSWORD`, `SPRING_DATA_REDIS_SSL_ENABLED` (SSL default true in qa/prod, false in dev).
- Limitation: if Redis is down, readiness fails. `RateLimitFilter` fails open on a Redis outage (`RateLimitFilterTest.redisOutageLetsRequestsThrough`); other uses were not checked: UNVERIFIED.

## Cloudflare R2 (object storage)
- Purpose: store uploaded photos (profile, posts, chat).
- Where: `media/R2StorageService.java` (AWS SDK v2 `s3`), selected by `STORAGE_TYPE=r2`. Local alternative: `media/LocalStorageService.java`. Upload pipeline: `media/ImageUploadService.java`.
- Communication: S3 API to the R2 account endpoint. Clients read through the public base URL.
- Config: `STORAGE_TYPE`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `MEDIA_BASE_URL` (must be a full URL for R2).
- Test: `src/test/.../media/R2StorageServiceTest.java`.
- Limitation: the public domain (`media.apsbrats.com` in docs) is UNVERIFIED. The Flutter `CDN_URL` default (`https://cdn.apsbrat.in`) does not match it; how the app resolves photo URLs is in `frontend/lib/core/media/photos.dart` (relative paths get the API origin prepended).

## Firebase Auth and Google sign-in
- Purpose: let users sign in with Google without an OTP.
- Flow: app signs in with Google on the device (`google_sign_in` + `firebase_auth`, `frontend/lib/features/auth/data/auth_repository.dart`), then POSTs the Firebase ID token to `POST /api/v1/auth/google` (`auth/AuthController.java`). `auth/FirebaseAuthVerifier.java` verifies it with firebase-admin and `AuthService.signInWithGoogle` finds or creates the user by email.
- Config server side: `FIREBASE_CREDENTIALS_PATH` (service-account JSON file path). Not set means HTTP 503 "Google sign-in is not configured yet on this server".
- Config client side: `Firebase.initializeApp()` in `frontend/lib/main.dart` with no options. No `google-services.json`, `GoogleService-Info.plist` or `firebase_options.dart` is in the repo, so on a clean checkout Firebase init fails and the app logs "Firebase not configured yet"; everything except Google sign-in keeps working. Whether the maintainer has these files locally: UNVERIFIED.
- Firebase is used for authentication only.

## Email / OTP delivery
- Login is email plus 6-digit OTP (`auth/AuthService.requestOtp`, `POST /api/v1/auth/request-otp`, `/verify-otp`).
- The code is stored in `otp_codes` and, outside prod, written to the application log. There is a `TODO` to send the code by email in qa/prod: no email or SMS provider is integrated (no mail dependency in `pom.xml`).
- Consequence: in prod a real user cannot receive a code. Only Google sign-in works for real users, or the master OTP (do not enable in prod).
- Dev: `OTP_MASTER` (universal code, dev and compose have a default; blank disables it). Constant-time comparison. Master OTP is also disabled if blank.
- Protections that exist: per-email request limits, cooldown, attempt counter and lockout in Redis keys `otp:*`.

## Geoapify (places)
- Purpose: city autocomplete and "use my location" reverse lookup in onboarding/profile.
- Where: `places/PlacesService.java`, `places/PlacesController.java` (`GET /api/v1/places/cities`, `GET /api/v1/places/reverse`). Client: `frontend/lib/core/location/location_service.dart` (geolocator) and the places repository.
- Communication: server calls `https://api.geoapify.com` with `RestClient`. The key never goes to the app.
- Config: `GEOAPIFY_API_KEY`. Unset means 503 "City search is not configured".
- Limitations: no timeout, caching or rate limit specific to this call found: UNVERIFIED. Subject to Geoapify quota (not recorded).

## Push notifications (FCM)
- State: NOT wired. `firebase_messaging` and `flutter_local_notifications` are in `frontend/pubspec.yaml` but nothing imports them, and the backend has no FCM sender (firebase-admin is used only for ID token verification).
- What exists instead: in-app notifications stored in the database and served by `apsbrat-api/src/main/java/com/apsconnect/api/notification/` (`NotificationController`, `NotificationService`, `V13__create_notifications.sql`, `V22__circle_notifications_and_sections.sql`) and shown by `frontend/lib/features/notifications/`. There is no device-token table, but the `users.fcm_token` column exists (V1, `User.fcmToken`); nothing sends FCM and the code only ever sets it to null (`AccountService`).

## Prometheus / Grafana
- The API exposes `/actuator/prometheus` and `/actuator/metrics`. Public only in the dev profile (`app.actuator.public-metrics=true`); in qa/prod access is denied. See `08-infrastructure-deployment.md`.
- `tools/api_dashboard.py` is the only consumer in the repo (local, dev only). No Prometheus config or Grafana dashboards exist.

## WebSocket / STOMP (internal, not external)
- Endpoint `/ws`, simple in-memory broker (`chat/WebSocketConfig.java`), auth through `chat/StompAuthChannelInterceptor.java`. Not an external service, but constrains hosting to one instance. Client: `stomp_dart_client`.

## Upstash
- No reference in code or yml comments except a comment in `application.yml` ("Upstash needs both" password and TLS). `docs/DEPLOYMENT.md` suggests it as a Redis host and includes a real-looking hostname: consider removing it from the doc.
