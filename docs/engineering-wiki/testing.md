# Testing
What tests exist for the backend and the Flutter app, how they run, what fails today, and what is not covered.
Counts are from the last surefire reports in `apsbrat-api/target/surefire-reports` (dated 2026-11-15) and one `flutter test` run on 2026-11-16.

Last verified: 2026-11-16 against commit 168d987 (working tree has uncommitted changes)

## 1. Architecture

| Layer | Tooling | Needs | In CI |
|---|---|---|---|
| Backend unit tests | JUnit 5, Mockito, `MockHttpServletRequest` style tests | nothing | yes (`mvn -B verify`) |
| Backend integration | `@SpringBootTest` or plain JDBC + Testcontainers Postgres 16 (`postgres:16-alpine`) and Redis 7 (`redis:7-alpine`) | Docker daemon. `@Testcontainers(disabledWithoutDocker = true)`: skipped silently without Docker | yes (Ubuntu runner has Docker) |
| Frontend unit/widget tests | `flutter_test` (no `integration_test` package, no mocks library) | nothing | yes (`flutter test`) |
| End-to-end / device tests | none | | no |
| Load tests | k6 `apsbrat-api/load/k6-load.js` (manual, throwaway DB) | k6, running API | no |
| WebSocket load test | `tools/ws_load.py` (1000 sockets, live dashboard on port 8097; manual, throwaway DB); `apsbrat-api/load/ws_chat_soak.py` (one socket, direct messages; not run) | `pip install websockets`, running dev API | no |

Backend test code has no `src/test/resources` (no test yml, no fixtures). Surefire has no custom config in `apsbrat-api/pom.xml` (no `argLine`, no timezone, no parallelism). Setup flags for Windows are in `10-development-guide.md` section 7.

## 2. Backend tests (`apsbrat-api/src/test/java/com/apsconnect/api`)

Last report: 96 tests ran, 0 failures, 0 errors, 1 skipped (`ApiApplicationTests`, Docker was not available for that run).

| Test class | Tests | Purpose |
|---|---|---|
| `ApiApplicationTests` | 1 (skipped) | Full Spring context loads against real Postgres + Redis, runs all Flyway migrations from V1 |
| `auth/JwtServiceTest` | 5 | Token issue/parse behaviour of `JwtService` |
| `career/NameKeysTest` | 2 | Name normalisation keys for career history |
| `circle/CircleRankingTest` | 4 | Ordering of the "circle" suggestions |
| `common/exception/GlobalExceptionHandlerTest` | 6 | AppException status/code mapping, validation 400, missing param, 405, 409 does not leak internals, unexpected error is generic |
| `common/util/CursorSupportTest` | 4 | Cursor pagination encode/decode |
| `common/web/IdempotencyFilterTest` | 5 | First request stored, retry replayed, concurrent duplicate 409, failure forgotten, no key passes through |
| `common/web/RateLimitFilterTest` | 4 | Per-user and per-IP limits, Redis outage lets requests through, media/health not counted |
| `connection/ConnectionFlowTest` | 29 | Connection request/accept/decline/withdraw lifecycle on a real DB (largest suite, about 47 s) |
| `connection/ConnectionMigrationTest` | 1 | Migration V39 turns old rows into pairs + history |
| `connection/UserPairTest` | 3 | Canonical ordering of a user pair |
| `connection/ConnectionServiceTestHook` | helper | Test hook, not a test class |
| `media/ImageProcessorTest` | 3 | Image processing |
| `media/ImageUploadServiceTest` | 6 | Upload folders per kind and user, ownership checks, kind validation |
| `media/R2StorageServiceTest` | 1 | SDK failure wrapped as AppException |
| `search/PeopleSearchTokensTest` | 3 | Search tokenising |
| `user/PresenceVisibilityTest` | 4 | Who can see online presence |
| `user/RegistrationValidationTest` | 7 | Registration field rules |
| `user/history/SchoolHistoryOverlapTest` | 8 | School history year overlap rules |

Note: `GlobalExceptionHandlerTest` covers 400 and 409 and a generic 500 body. `CLAUDE.md` also asks for a 404 case and an assertion that the 500 was logged with a requestId: UNVERIFIED that these are asserted (test names do not show them).

## 3. Frontend tests (`frontend/test`)

21 test files, 106 test cases (counted by `flutter test`: 88 pass, 18 fail).

| File | Cases | Area |
|---|---|---|
| `account_safety_test.dart` | 4 | Account safety screens |
| `back_nav_test.dart` | 1 | System back from login |
| `batch_tab_test.dart` | 2 | Batchmates tab |
| `career_test.dart` | 13 | Career history and onboarding steps |
| `chat_screen_test.dart` | 5 | Chat screen |
| `communities_tab_test.dart` | 1 | Five tabs fit a phone |
| `community_ui_test.dart` | 18 | Communities UI |
| `connection_contract_test.dart` | 11 | Connection API contract using `test/fixtures/connections` |
| `dob_format_test.dart` | 3 | Date of birth format |
| `empty_state_test.dart` | 1 | Empty state widget |
| `launch_redirect_test.dart` | 2 | Router redirect on launch |
| `login_mode_test.dart` | 3 | Login vs create-account wording |
| `onboarding_draft_test.dart` | 13 | Draft save/restore |
| `onboarding_steps_test.dart` | 2 | Step flow |
| `photos_test.dart` | 4 | Photo URL helper |
| `profile_cache_test.dart` | 3 | Profile cache |
| `profile_photo_test.dart` | 3 | Profile photo |
| `school_overlap_test.dart` | 6 | School overlap rules |
| `school_years_test.dart` | 7 | Year joined/left auto-fill |
| `username_input_test.dart` | 3 | Username input formatter |
| `widget_test.dart` | 1 | Splash route renders |

Per-file case counts come from `testWidgets(` / `test(` occurrences; failure marks come from the run.

## 4. Frontend test status (2026-11-20, `flutter test` in `frontend/`)

All 110 frontend cases pass (106 after the 2026-11-20 fixes, plus 4 added for token expiry and the signed-in redirect). The 18 that failed on 2026-11-16 were stale expectations, not code bugs, and were updated to the current screens:

- Welcome screen: the button is "Join APS Brats" (was "Get Started - It's Free"). Affects `widget_test`, `back_nav_test`, `login_mode_test`, `launch_redirect_test`.
- Onboarding titles render in capitals ("TELL US ABOUT...", "WHICH APS SCHOOLS DID YOU CALL HOME?"); the stepper reads "Socials" and "After school"; the last button is "Finish setup  ->" and the after-school button is "Continue  ->". Affects `career_test`, `onboarding_draft_test`, `launch_redirect_test`. The after-school page is taller than the test screen on wide layouts, so tests scroll to the buttons first.
- Usernames: the app drops periods and caps at 20 characters (matches the server rule). `username_input_test` now asserts that.
- School years: the year fields are read-only and open a year wheel, so `school_years_test` taps the field and "Done" instead of typing.
- Communities: four tabs (Home, Batchmates, Social, Profile); Messages and Communities are segments of Social. "Your Schools" heading; the joined card shows the member count only; the create action is the add icon.
- `onboarding_draft_test` lets a pending request time out before closing the app (otherwise it fired after the providers were disposed).

Two layout overflows found by these tests were fixed in the app: the gender chip row on the identity screen and the Messages/Communities segment control on narrow phones (labels now shrink with an ellipsis).

CI: `.github/workflows/ci.yml` runs `flutter analyze --no-fatal-infos` then `flutter test`. Analyze exits 0 (39 info hints, no warnings or errors) on the local Flutter version; CI uses the latest stable and reports more `deprecated_member_use` hints, which no longer fail the build.

Backend: no known failures; ApiApplicationTests was skipped in the last report, so context-load plus all 40 migrations on a fresh DB has not been confirmed by that report. `ConnectionMigrationTest` and `ConnectionFlowTest` did run, which means Docker worked for those at that time.

## 5. Coverage gaps
No coverage tool is configured (no JaCoCo in `pom.xml`, no `--coverage` in CI). Qualitative gaps from the test list:

Backend with no test class found:
- `auth/AuthService` (OTP request, verify, lockout, master OTP, Google login), `FirebaseAuthVerifier`
- `SecurityConfig` rules (public vs authenticated routes, actuator exposure, admin role)
- Controllers (no MockMvc/`@WebMvcTest` tests at all)
- `community` (posts, events, chat, memory posts), `chat` (WebSocket/STOMP, `StompAuthChannelInterceptor`), `notification`, `profile`, `search` service logic beyond tokens, `safety` (blocks, reports), `admin`, `places/PlacesService`, `LocalStorageService`, `PresenceService` Redis behaviour
- Flyway migrations as a set (only V39 has a dedicated test; `ApiApplicationTests` covers all of them only when Docker runs it)
- Account deletion flow (V37 audit table)

Frontend:
- No tests for `auth_repository`, token refresh in `dio_client.dart`, `chat_socket.dart`, feed, search, notifications, settings, profile editing screens, router guard beyond launch redirect
- No integration or golden tests

Process gaps:
- No test for `DevProfileGuard` or profile-specific config (qa/prod yml never loaded in tests)
- No Testcontainers setup shared between classes (each class starts its own containers; ConnectionFlowTest alone takes about 47 s)
- Load tests are manual
