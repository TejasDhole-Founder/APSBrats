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
| `back_nav_test.dart` | 1 | System back from login (FAILS) |
| `batch_tab_test.dart` | 2 | Batchmates tab |
| `career_test.dart` | 13 | Career history and onboarding steps (4 FAIL) |
| `chat_screen_test.dart` | 5 | Chat screen |
| `communities_tab_test.dart` | 1 | Five tabs fit a phone (FAILS) |
| `community_ui_test.dart` | 18 | Communities UI (2 FAIL) |
| `connection_contract_test.dart` | 11 | Connection API contract using `test/fixtures/connections` |
| `dob_format_test.dart` | 3 | Date of birth format |
| `empty_state_test.dart` | 1 | Empty state widget |
| `launch_redirect_test.dart` | 2 | Router redirect on launch (1 FAILS) |
| `login_mode_test.dart` | 3 | Login vs create-account wording (1 FAILS) |
| `onboarding_draft_test.dart` | 13 | Draft save/restore (2 FAIL) |
| `onboarding_steps_test.dart` | 2 | Step flow |
| `photos_test.dart` | 4 | Photo URL helper |
| `profile_cache_test.dart` | 3 | Profile cache |
| `profile_photo_test.dart` | 3 | Profile photo |
| `school_overlap_test.dart` | 6 | School overlap rules |
| `school_years_test.dart` | 7 | Year joined/left auto-fill (3 FAIL) |
| `username_input_test.dart` | 3 | Username input formatter (2 FAIL) |
| `widget_test.dart` | 1 | Splash route renders (FAILS) |

Per-file case counts come from `testWidgets(` / `test(` occurrences; failure marks come from the run.

## 4. Known failures (2026-11-16, `flutter test` in `frontend/`)

18 failing frontend cases, all from tests that no longer match the code:

| Test | Observed cause |
|---|---|
| `username_input_test`: keeps letters, digits, periods... | Expected `tejas.dhole_99`, got `tejasdhole_99`: formatter now drops periods |
| `username_input_test`: stops at 30 characters | Expected 30, got 20: max length is now 20 |
| `widget_test`: renders splash screen route | Looks for text "Get Started" that is not found |
| `login_mode_test`: Get Started opens create-account wording | Same screen/text change (likely) |
| `back_nav_test`, `career_test` (4), `launch_redirect_test`, `onboarding_draft_test` (2), `school_years_test` (3), `communities_tab_test`, `community_ui_test` (2) | Not diagnosed individually. UNVERIFIED cause: likely stale expectations after the onboarding/communities UI changes (note `CLAUDE.md` says the flow is Profile, Verify, Schools, Socials) |

Only the first three causes were read from output. The rest are unconfirmed.

Consequences: CI job `frontend` runs `flutter test`, so it should fail on this commit (not checked on GitHub). Backend: no known failures; ApiApplicationTests was skipped in the last report, so context-load plus all 40 migrations on a fresh DB has not been confirmed by that report. `ConnectionMigrationTest` and `ConnectionFlowTest` did run, which means Docker worked for those at that time.

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
