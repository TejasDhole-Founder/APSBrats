# Auth and Sessions

Sign-in (email OTP or Google), account creation, onboarding gating, token lifecycle, and logout. There is no separate registration endpoint: sign-in creates a bare account and onboarding fills it in.

Last verified: 2026-11-16 against commit 168d987 (working tree has uncommitted changes)

All API paths are under `/api/v1` (the app's `Env.baseUrl` supplies the prefix; frontend paths in `frontend/lib/core/constants/api_endpoints.dart`).

## Implemented

### Core model (read this first)
- Identity is the **email**. `users.email` is NOT NULL + UNIQUE. Phone and password are legacy (`users.phone`, `users.password_hash`), never used for login.
- `AuthService.findOrCreateByEmail` creates a bare `users` row (email only, `role=USER`, `current_status=STUDENT`) on first successful OTP or Google verify. Why: one flow for login and signup, no way to tell "does this email exist" from the OTP step.
- "Onboarded" = `User.isOnboarded()`: `fullName` (>= 2 chars) and `username` set. Schools, career, socials are optional.
- Tokens: access JWT (type `access`, claims `sub`, `email`, `role`) and refresh JWT (type `refresh`, `jti`). Expiry: access 900000 ms (15 min), refresh 2592000000 ms (30 days), in all three profiles of `application.yml`. Signing key is derived from env `JWT_SECRET` (SHA-256); qa/prod refuse to start with a weak secret (`JwtService.validateSecret`).
- Refresh tokens are server-tracked in Redis: `rt:<jti>` -> userId (TTL = refresh expiry), and `rtu:<userId>` -> set of jtis (for logout-all). Access tokens are stateless; revocation is a Redis marker `revoked:<userId>` (timestamp) checked by `JwtAuthFilter`.

### 1. Request OTP
1. User action: types email on the login screen, taps "Send code".
2. Frontend: `features/auth/presentation/screens/login_screen.dart` `_sendCode()` (regex pre-check, snackbar "Enter a valid email address") -> `AuthController.requestOtp` (`features/auth/presentation/providers/auth_provider.dart`) -> `AuthRepository.requestOtp` (`features/auth/data/auth_repository.dart`).
3. State: `authControllerProvider` (`StateNotifier<AuthState>`): `loading=true`, then `otpSent=true`. Not optimistic. The screen starts a resend countdown timer.
4. API: `POST /auth/request-otp` body `{email}`; response `ApiResponse<Void>` "OTP sent".
5. Backend: `AuthController.requestOtp` -> `AuthService.requestOtp`: normalize (trim, lowercase) -> `enforceRequestLimits` (60 s resend cooldown key `otp:cd:<email>`; max 5 per email per hour `otp:rq`; max 15 per IP per hour `otp:ip`) -> generate 6-digit code with `SecureRandom` -> save `OtpCode` (10 min TTL) -> in non-prod log the code via log4j/slf4j.
6. DB: `otp_codes` insert (email, code, expires_at, consumed). Redis counters above.
7. Response handling: success flips `otpSent`; any exception shows "Could not send the code. Try again." (the real server message, e.g. rate-limit text, is NOT surfaced).
8. UI: switches to the 6-box OTP entry, focuses first box, countdown for resend.
9. Other users: n/a.
10. Failure: `dio_client.dart` never retries `/auth/` calls (a re-sent request would hit the cooldown). 429 -> generic error text. Offline -> `networkOfflineProvider=true` (connection banner).
11. Concurrency: cooldown key is set after the counters are incremented, so two simultaneous requests can both pass the cooldown check (counters still cap abuse). Per-IP limit uses `request.getRemoteAddr()` (Tomcat `RemoteIpValve` via `server.forward-headers-strategy: native`) so clients cannot spoof it.
12. Security: bean validation `@Email @NotBlank`; route is `permitAll` (`/api/v1/auth/**`); global `RateLimitFilter` (60 req/min per IP when anonymous) sits on top.

### 2. Verify OTP (login or signup)
1. User action: enters the 6 digits.
2. Frontend: `login_screen.dart` `_verify()` -> `AuthController.verifyOtp` -> `AuthRepository.verifyOtp` -> `_storeAndReturn`.
3. State: `AuthState.user` set. Tokens and flags go to `FlutterSecureStorage`: `access_token`, `refresh_token`, `user_id`, `onboarding_done` ("1" or "" from `AuthUser.needsOnboarding`, i.e. `username` empty).
4. API: `POST /auth/verify-otp` `{email, code}` -> `ApiResponse<AuthTokens{accessToken, refreshToken, user: UserDto}>`.
5. Backend: `AuthService.verifyOtp`: check lockout `otp:lock:<email>` (429) -> unless master OTP matches (non-prod only, `app.otp.master` from env `OTP_MASTER`) load latest unconsumed OTP (`findTopByEmailAndConsumedFalseOrderByCreatedAtDesc`) -> expired? 400 -> `constantTimeEquals` -> on mismatch `registerFailedAttempt` (5 fails in 15 min locks the email for 15 min) -> mark consumed -> clear attempt counter -> `findOrCreateByEmail` -> `ensureNotBannedOrSuspended` (403) -> `isVerified=true` -> `issueTokens` (store `rt:<jti>`, add to `rtu:<userId>`).
6. DB: `otp_codes.consumed=true`; `users` insert (new) or update `is_verified`.
7. Response handling: `verifyOtp` returns true -> `_continue()`: if `user.needsOnboarding` -> `resumeOnboardingRoute` (reads the saved draft step) -> `context.go('/onboarding...')`; else `context.go('/home')`. Any error shows "Incorrect or expired code." (a ban/suspend 403 message is also hidden behind this text).
8. UI: lands on onboarding step or Home.
9. Other users: none.
10. Failure: same as above; no retry on auth calls. If Redis is down, `RedisConnectionFailureException` maps to 503 "temporary problem" (`GlobalExceptionHandler.handleRedisDown`); the app shows the generic error.
11. Concurrency: two parallel verifies of the same code can both read the OTP as unconsumed before either commits (no row lock or `UPDATE ... WHERE consumed=false`); both get tokens. Low impact (same person, same email). Two first-time verifies racing `findOrCreateByEmail` hit the `users.email` unique key -> `DataIntegrityViolation` -> 409 "conflicts with existing data" (second attempt succeeds).
12. Security: constant-time compare, lockout, one-time use, 10 min expiry, banned/suspended blocked at login. Master OTP disabled when profile `prod` is active; dev profile defaults to a fixed code defined in `application.yml` (`application.yml` line ~123), qa/prod default empty.

Variation: dev shortcut. `AuthController.devSkipLogin` (`auth_provider.dart`) requests an OTP for a seeded demo email and verifies with the master code. Button is rendered only under `kDebugMode` (`login_screen.dart:303`). Comment says "remove before release".

### 3. Google sign-in
1. User action: taps "Continue with Google".
2. Frontend: `login_screen.dart` `_google()` -> `AuthController.signInWithGoogle` -> `AuthRepository.signInWithGoogle`: `GoogleSignIn(scopes:['email']).signIn()` -> `FirebaseAuth.signInWithCredential` -> `getIdToken()` -> POST to backend.
3. State: as OTP verify; returns false (no state change) if the user cancels the picker.
4. API: `POST /auth/google` `{idToken}` -> `AuthTokens`.
5. Backend: `AuthService.signInWithGoogle` -> `FirebaseAuthVerifier.verify` (Firebase Admin SDK; lazy init from file path in `app.firebase.credentials-path`; requires verified email, else 400; failures -> 401; unconfigured -> 503) -> `findOrCreateByEmail(email, name, pictureUrl)` (name and Google picture seed a NEW account only) -> ban/suspend check -> `issueTokens`.
6. DB: same as verify. Google picture URL is stored in `users.profile_pic_url` for new accounts (external URL, not copied to our storage).
7-8. Same routing as OTP. Error text: "Could not sign in with Google. Try again."
9. Other users: none.
10. Failure: not retried (path contains `/auth/`). If the server has no Firebase credentials file the user always sees the generic error (503 message not surfaced). UNVERIFIED whether qa/prod have the credentials mounted.
11. Concurrency: same email unique-key race as above.
12. Security: token verified server-side by Firebase; `emailVerified` required; email is lowercased so a Google account and an OTP user with the same email merge into one account (intended).

### 4. Onboarding gating and completion
- Router: `frontend/lib/core/routes/app_router.dart` `redirect`. Any `/onboarding*` URL requires a stored `user_id`, else redirect to `/login?mode=signup`, and it hydrates the draft (`onboardingFlowProvider.notifier.hydrate()`).
- Steps per `CLAUDE.md`: Profile -> Verify -> Schools -> Socials. In the real code the verify step is the login screen itself (email already verified before onboarding starts); alumni get an extra "After school" step. Routes: `/onboarding` (identity), `/onboarding/schools`, `/onboarding/schools/after-school`, `.../socials`.
- Draft persistence: `OnboardingDraftStore` (`features/onboarding/data/services/onboarding_draft_store.dart`) saves `OnboardingFlowState` JSON in secure storage under `onboarding_draft` keyed by userId (dropped if the userId differs). Survives app restart; wiped by logout. No password field exists anywhere.
- Nothing is sent to the server until the last step: `OnboardingSocialsScreen._finish()` runs, in order: `PUT /users/me` (name, username, dob, city, profession, gender, `currentStatus` STUDENT/ALUMNI) -> `POST /users/{id}/school-history/bulk` -> `PUT/DELETE /users/{id}/social-links/{platform}` -> `POST /career` per finished card (best effort) -> `markOnboardingDone()` -> `reset()` draft -> `context.go('/home')`. Details of each call: see `profile-career-schools.md`.
- Failure/partial state: the sequence is not transactional. If `PUT /users/me` succeeds but school save fails, the user is already "onboarded" server-side (name + username set) so the gate opens, while the app still shows an error and keeps the draft. Retrying re-runs everything (all idempotent: replace/upsert/delete).
- Backend gate: `user/OnboardingGate.java` (a `HandlerInterceptor`) throws 403 "Finish setting up your profile first" for an un-onboarded account on `/communities/**, /posts/**, /comments/**, /events/**, /community-messages/**, /conversations/**, /connections/**, /reports, /people/**, /search/**, /feed/**, /users/me/circle/**, /profiles/**, /users/*/block`. Allowed before onboarding: auth, `/users/me`, `/users/username-available`, school-history, social-links, career, avatar, `GET /schools`. Cost: one `findById` per gated request (no cache).
- Username rules (`UserService.usernameProblem`): `^[a-zA-Z][a-zA-Z0-9_]{2,19}$`, reserved words, profanity terms; unique case-insensitively (index from V34). Live check: `GET /users/username-available`. Age: 13..120 from `dob`.

### 5. Token refresh (automatic)
1. User action: none; happens on any 401.
2. Frontend: `core/network/dio_client.dart` `onError` interceptor -> `refreshAccessToken()` using a separate `refreshDio` (so refresh cannot recurse).
3. State: single-flight `refreshInFlight` future: concurrent 401s share one refresh. New tokens written to secure storage. Failed call is retried once (`__retried__` flag) with the new bearer.
4. API: `POST /auth/refresh` `{refreshToken}` -> `AuthTokens`.
5. Backend: `AuthService.refresh`: must be a refresh-type JWT (else 400) -> `redis.delete(rt:<jti>)` must return true (this is the rotation: a refresh token works exactly once) -> load user -> ban/suspend check -> `issueTokens` (new pair).
6. DB: users read; Redis only.
7. Response handling: if refresh fails (`newToken == null`) -> `clearSession()` deletes the three keys and sets `sessionExpiredProvider=true`.
8. UI: `app.dart` listens to `sessionExpiredProvider`, calls `authRepository.clearLocal()` and `AppRoot.restart(context)` -> app returns to the welcome screen. No message is shown to the user.
9. Other users: none.
10. Failure: any `DioException` during refresh (including a plain network error or 5xx) is treated as "session dead" and logs the user out. See Risks.
11. Concurrency: the Redis `DELETE` is atomic so a replayed refresh token (stolen copy) fails; but the legitimate client and the thief race. The client-side single-flight avoids the self-inflicted double refresh.
12. Security: refresh tokens are one-use and server-revocable; access token type is checked in `JwtService.parseAccess` so a refresh token cannot be used as a bearer.

### 6. Authenticated request path
`JwtAuthFilter` (before `UsernamePasswordAuthenticationFilter`): parse bearer -> `isRevoked(userId, issuedAt)` (Redis `revoked:<userId>`; fails OPEN if Redis is down) -> set `Authentication` with principal = userId (UUID) and authority `ROLE_<role>` (role is read from the token, not the DB) -> best-effort `PresenceService.touch` (Redis `active:<id>` throttle then `UPDATE users SET last_active_at`, at most once a minute). Expired/invalid tokens leave the context empty so protected routes return 401 via `RestAuthEntryPoint`. `/api/v1/admin/**` requires `ROLE_ADMIN` or `ROLE_MODERATOR` (`SecurityConfig`). CORS applies to browsers only.

### 7. Session persistence across restarts
- Cold start: `appRouterProvider.redirect` runs only on the first navigation to `/`. It reads `user_id` and `onboarding_done` from secure storage (no network call): present + done -> `/home`; present + not done -> `resumeOnboardingRoute`; absent -> welcome (`SplashScreen`). Storage read errors are treated as logged out.
- The first API call then carries the stored access token; an expired one triggers the refresh flow above.
- `meProvider` and other "my data" providers are local-first (`localFirst` in `profile_repository.dart`): cached JSON in secure storage under `cache_<name>_<userId>`, refreshed in the background. `logout` wipes it via `deleteAll`.
- Gap: `onboarding_done` is only a local flag. If the user finishes onboarding on a device and signs in on another, `UserDto` has a username so `needsOnboarding=false` and it is set correctly at login; fine. If the flag is lost while the server says onboarded, the user is sent to onboarding with an empty draft (UNVERIFIED path, not exercised).

### 8. Logout (this device)
1. User action: Profile tab -> Settings sheet -> "Log out" -> confirm dialog (`feed/presentation/widgets/profile_tab.dart` `_SettingsSheetState._logout`).
2. Frontend: `AuthController.logout` -> `AuthRepository.logout()`: `POST /auth/logout` with a 5 s timeout, errors swallowed -> `clearLocal()` (Google sign-out, Firebase sign-out, `FlutterSecureStorage.deleteAll`) -> `chatSocketProvider.disconnect()` -> `AuthState()` reset -> `AppRoot.restart` (new `ProviderScope`, so every cached provider is dropped).
3. API: `POST /auth/logout` `{refreshToken}`.
4. Backend: `AuthService.logout`: refresh-type check (400) -> delete `rt:<jti>`, remove jti from `rtu:<userId>`. The access token stays valid until it expires (no revoke marker for single logout).
5. DB: Redis only.
6. Failure: offline logout still clears the device but leaves the server refresh token alive until its TTL. Accepted trade-off (documented in the repository method).
7. Concurrency/Security: endpoint is `permitAll` but needs a valid refresh token; `parse` errors map to 401.

### 9. Logout everywhere
1. User action: Settings -> "Log out of all devices" -> confirm.
2. Frontend: `AuthController.logoutEverywhere`: `POST /auth/logout-all` -> `clearLocal()` -> disconnect socket -> restart. Errors are NOT swallowed here: a failed server call shows a snackbar and keeps the user logged in (so they are not told it worked when it did not).
3. API: `POST /auth/logout-all` (authenticated, no body).
4. Backend: `AuthService.revokeAllFor(userId)`: delete every `rt:<jti>` in `rtu:<userId>`, delete the set, set `revoked:<userId>` = now with TTL = access expiry + 60 s. The filter then rejects any access token issued at or before that instant.
5. Same `revokeAllFor` is called by: suspend, ban, role change (`AdminService`), and account delete (`AccountService`). Reinstate does not clear it; tokens issued after the revoke instant work.
6. Concurrency: a token issued in the same millisecond as the revoke is treated as revoked (`issuedAt <= revokedAt`); JWT `iat` has second precision, so a user who logs in again within the same second as logout-all can be rejected once and must retry. UNVERIFIED in practice.

### 10. Account deletion and data export (entry points)
- Both live in the same Settings sheet (`profile_tab.dart` `_export()`, `_deleteAccount()`), call `features/settings/data/account_repository.dart`, hit `GET /users/me/export` and `DELETE /users/me`. After a successful delete the app calls `logout()` and restarts. Full 12-point detail: `profile-career-schools.md`.
- Login after deletion: the row's email is rewritten to `deleted+<id>@deleted.invalid`, so the same real email signs up as a brand-new account.

## Not implemented (verified by search)
- (Was missing until 2026-11-20) Sending the OTP by email is now done through Brevo; see [07 section 2.1](../07-authentication-security.md) and [09](../09-integrations.md). Live configuration is not yet confirmed.
- Password login, password change, forgot-password: removed from the flow (`users.password_hash` column and a `BCryptPasswordEncoder` bean remain unused).
- Phone login/verification (`users.phone` is a legacy column).
- Email change (`UserService.updateMe` rejects it).
- Device/session list (only "all or this one").
- Refresh-token reuse detection (a replay just fails; the family is not revoked).
- Multi-step "Verify" onboarding screen (the `CLAUDE.md` step list says Verify is step 2; in code verification happens on the login screen before onboarding).

## Risks, bugs, tech debt
- OTP email depends on `BREVO_API_KEY` and `EMAIL_SENDER_ADDRESS` on the host; without them prod returns 503 for code requests. Highest-priority item to confirm for prod.
- `AuthService.java:88` / `application.yml:~123`: dev profile defaults `OTP_MASTER` to a fixed code; safe only because `masterOtpMatches` is gated on non-prod and qa/prod default to empty. If qa is exposed publicly with `OTP_MASTER` set, anyone can log in as anyone.
- `AuthService.java:144` `refresh` is `@Transactional(readOnly = true)` yet writes Redis; harmless, but misleading.
- `AuthService.java:167` logout removes the jti from `rtu:` but `refresh` (rotation) never removes the old jti from the set; the set grows until TTL and logout-all deletes already-gone keys (harmless).
- `dio_client.dart` `refreshAccessToken` catches every `DioException` as "unrecoverable", so a transient network blip or 5xx during refresh signs the user out. Only a 401/400 from `/auth/refresh` should do that.
- `AuthController` (Flutter) maps every error to a fixed string, hiding server messages such as "temporarily suspended" and 429 cooldowns.
- `JwtAuthFilter.isRevoked` fails open on Redis outage (documented, bounded by access TTL). Role comes from the JWT, so a demoted moderator keeps `ROLE_MODERATOR` until tokens are revoked; `setRole` does call `revokeAllFor`, so this is covered. `AdminService.requireAdmin` re-reads the DB role.
- OTP verify has no atomic consume (see 2.11).
- WebSocket (`/ws/**` is `permitAll`; auth is in `StompAuthChannelInterceptor`): STOMP CONNECT rejects access tokens covered by the `revoked:<userId>` marker (`StompAuthChannelInterceptor.java:33`). It does not check ban or suspend directly, so enforcement relies on `revokeAllFor` having been called, and like the HTTP filter it fails open on a Redis outage.

## Discrepancies with existing docs
- `docs/API.md` / `docs/BACKEND.md`: describe `POST /users` registration, `RegisterUserRequest`, password endpoints and "phone must already belong to a registered user". None exist: `RegisterUserRequest` is not in the code, `PUT /users/{id}/password` is gone, login is by email, and registration is log-in-or-create. `CLAUDE.md` still says "`RegisterUserRequest` has no validation annotations"; the live request is `UpdateProfileRequest` and it DOES have validation annotations.
- `docs/API.md`: paths shown as `/api/...`; real prefix is `/api/v1`. Missing `POST /auth/google`, `POST /auth/logout`, `POST /auth/logout-all`.
- `docs/DATABASE.md`: `otp_codes` documented as keyed by phone; V23 `email_primary_login` and V24 `widen_otp_email` moved it to email.
- `docs/BACKEND.md:180` "No FCM push wiring yet" is still true (see `notifications-and-moderation.md`).
