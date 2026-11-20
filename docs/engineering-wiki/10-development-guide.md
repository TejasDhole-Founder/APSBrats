# 10 - Development Guide
How to set up a machine, run the stack, seed data, run tests and fix common problems.
Everything here comes from repo files; items not confirmed by code are marked UNVERIFIED. No credentials are listed.

Last verified: 2026-11-16 against commit 168d987 (working tree has uncommitted changes)

## 1. Prerequisites

| Tool | Version | Evidence |
|---|---|---|
| JDK | 17 (Temurin in CI and Dockerfile) | `apsbrat-api/pom.xml` `java.version`, `.github/workflows/ci.yml` |
| Maven | 3.9+ on PATH. There is no `mvnw` wrapper in the repo (so `BACKEND_NOTES.md` `./mvnw` is stale) | `apsbrat-api/` has no `mvnw` |
| Flutter | stable channel; SDK constraint Dart `^3.10.8`. Local machine uses Flutter 3.38.9 | `frontend/pubspec.yaml` |
| Docker Desktop (or Docker Engine) with Compose v2 | any recent | `docker-compose.yml`; needed for Postgres, Redis, Testcontainers |
| Android Studio / Xcode | only for device or emulator builds | `frontend/android`, `frontend/ios` |
| Python 3 | only for `tools/api_dashboard.py` (stdlib only) | script header |
| k6 | optional, load tests | `apsbrat-api/load/k6-load.js` |

## 2. Start Postgres and Redis

Full stack (db + redis + api container), from repo root:
```
make up            # docker compose up --build -d
make logs          # follow API logs
make psql          # psql into the db container
make down
```
Only the databases (to run the API from your IDE):
```
docker compose up -d db redis
```
- Postgres 16 on `localhost:5432`, database `apsbrat_db`, user/password from `DB_USER`/`DB_PASSWORD` (compose has defaults, see `docker-compose.yml`; `.env.example` is the template, `.env` is gitignored).
- Redis 7 on `localhost:6379`, no password.
- Compose passes `SPRING_FLYWAY_BASELINE_ON_MIGRATE=false` to the api container, so a fresh container DB runs every migration from V1.

## 3. Migrations (Flyway)
Run automatically at API start (`spring.flyway.enabled: true`, scripts in `apsbrat-api/src/main/resources/db/migration`, V1..V40). There is no separate migrate command.
- dev profile default is `baseline-on-migrate: true` with baseline version 4. That is meant for an old local DB that already had tables. Flyway only baselines a non-empty schema that has no Flyway history table, so a brand-new empty DB migrates V1..V40 normally. The risk is the opposite: an existing database without a history table is assumed to contain V1..V4 and those scripts never run. Set `SPRING_FLYWAY_BASELINE_ON_MIGRATE=false` to turn baselining off (compose does).
- Hibernate does not change the schema (`ddl-auto: validate`). New schema change = new `V41__...sql` with `IF [NOT] EXISTS` guards (project rule).
- Do not edit an applied migration (checksum error, see section 10).

## 4. Run the API
From `apsbrat-api/`:
```
mvn spring-boot:run
```
- Profile: `dev` by default. The pom sets `-Duser.timezone=Asia/Kolkata` for `spring-boot:run`. If you run from IntelliJ, add `-Duser.timezone=Asia/Kolkata` to the VM options (Postgres 16 rejects the legacy zone name `Asia/Calcutta`, see section 10).
- Listens on `:8080`, REST under `/api/v1`. Swagger UI on in dev: `/swagger-ui.html`. Health: `/actuator/health`.
- Env vars (names only): `DB_USER`, `DB_PASSWORD`, `JWT_SECRET`, `OTP_MASTER`, `SPRING_DATA_REDIS_HOST`, `STORAGE_TYPE`, `GEOAPIFY_API_KEY`, `FIREBASE_CREDENTIALS_PATH`, `BREVO_API_KEY`, `EMAIL_SENDER_ADDRESS`, `EMAIL_SENDER_NAME`. Dev has defaults for DB, JWT and OTP master, so nothing is needed for a basic run. Full table in `08-infrastructure-deployment.md`.
- Without `GEOAPIFY_API_KEY` city search returns 503. Without `FIREBASE_CREDENTIALS_PATH` Google sign-in returns 503. Neither blocks the rest.
- Media: with `STORAGE_TYPE` unset, uploads go to `apsbrat-api/media/` (gitignored) and are served at `/media/**`.

## 5. Run the Flutter app
From `frontend/`:
```
flutter pub get
flutter run
```
API base URL is NOT chosen per platform. It is a compile-time define with one default (`frontend/lib/core/constants/env.dart`):

| dart-define | Default | Purpose |
|---|---|---|
| `BASE_URL` | `http://localhost:8080/api/v1` | REST base |
| `WS_URL` | `ws://localhost:8080/ws` | STOMP WebSocket |
| `CDN_URL` | `https://cdn.apsbrat.in` | CDN base (usage: check `core/media/photos.dart`) |

Per target:
- iOS simulator, desktop, web: the default works.
- Android emulator: `localhost` is the emulator itself. Use `flutter run --dart-define=BASE_URL=http://10.0.2.2:8080/api/v1 --dart-define=WS_URL=ws://10.0.2.2:8080/ws`. UNVERIFIED: whether Android allows plain HTTP in debug (no `usesCleartextTraffic` or network-security config found in `frontend/android/app/src/main/AndroidManifest.xml`; only `INTERNET` permission).
- Physical phone: use your PC LAN IP, same pattern, and allow port 8080 through the firewall.
- Google sign-in needs Firebase client config files that are not in the repo (see `09-integrations.md`). Without them the app starts and only Google sign-in fails.

## 6. Seed data and test accounts

| File | What it does |
|---|---|
| `V14__seed_demo_data.sql` (a Flyway migration, runs everywhere) | Demo schools/users/feed data from the early UI. Contains phone-era demo users. Runs in all profiles including prod |
| `seed_schools.sql` (repo root, 953 lines) | Inserts the 135 APS schools from the AWES directory into `schools`. Run manually after the schema exists |
| `seed_test_users.sql` (repo root, 135 lines) | Deletes users with username `seed.%`, then creates 100 test users spread across all schools, with school history and social links. Re-runnable. Run AFTER `seed_schools.sql` |
| `local_dump.sql`, `clean_dump.sql` | pg_dump files. Names only noted; contents are personal data and must not be committed or shared. Untracked in git and NOT in `.gitignore`, so `git add .` could commit them |

Load a seed file:
```
docker compose exec -T db psql -U <DB_USER> -d apsbrat_db < seed_schools.sql
docker compose exec -T db psql -U <DB_USER> -d apsbrat_db < seed_test_users.sql
```
Test login mechanism: the dev "master OTP". When `OTP_MASTER` is non-blank and the profile is not `prod` (so also `qa`), `verify-otp` accepts that value for any email (`auth/AuthService.masterOtpMatches`). The default is defined in `application.yml` (dev) and `docker-compose.yml`. Alternatively request a real OTP: in non-prod the generated code is written to the API log (`OTP for <email> is ...`). In qa/prod `OTP_MASTER` must be blank. The seed comments mention a phone flow; login is now email-based (V23), so check the seeded users have emails before relying on them (UNVERIFIED).

## 7. Run tests

Frontend (`frontend/`): `flutter test` (about 15 s). Current result: 88 pass, 18 fail (see `testing.md`).

Backend (`apsbrat-api/`):
```
mvn -B verify          # what CI runs
mvn test               # tests only
mvn -Dtest=ConnectionFlowTest test   # one class
```
Unit tests need no Docker. `ApiApplicationTests`, `ConnectionFlowTest`, `ConnectionMigrationTest` use Testcontainers (Postgres 16 and Redis 7) and need a running Docker daemon. `ApiApplicationTests` is `@Testcontainers(disabledWithoutDocker = true)`, so without Docker it is skipped silently (the last surefire report shows it skipped). `ConnectionFlowTest` and `ConnectionMigrationTest` carry the same annotation, so they skip too.

Windows + Docker Desktop settings that worked for this team (not in the pom; passed per run). Set before running Maven (Git Bash syntax):
```
export DOCKER_HOST=npipe:////./pipe/dockerDesktopLinuxEngine
export TESTCONTAINERS_RYUK_DISABLED=true
mvn test -Dapi.version=1.44 -DargLine="-Duser.timezone=Asia/Kolkata -Dapi.version=1.44"
```
- `DOCKER_HOST`: points Testcontainers at the Docker Desktop Linux engine pipe.
- `TESTCONTAINERS_RYUK_DISABLED=true`: skips the Ryuk cleanup container (it often fails to start on Windows). Leftover containers must then be removed by hand.
- `api.version=1.44`: pins the Docker API version for the docker-java client when Docker Desktop rejects the library's default. Set it as a system property for the forked test JVM (through `argLine`), because surefire forks a JVM and `-D` on the Maven command line alone does not always reach it (UNVERIFIED which of the two placements is required; both are shown for safety).
- `-Duser.timezone=Asia/Kolkata` through surefire `argLine`: the pom has no surefire config, so the test JVM otherwise uses the OS zone. A zone Postgres 16 does not accept (for example `Asia/Calcutta`) makes the connection fail.
These flags come from the earlier work notes for this wiki, not from a file in the repo: UNVERIFIED in this pass (not re-run).

## 8. Build commands

| Goal | Command |
|---|---|
| API jar | `cd apsbrat-api && mvn -B clean package` (add `-DskipTests` to skip tests) |
| API image | `docker build -t apsbrat-api ./apsbrat-api` or `make rebuild` |
| Flutter analyze | `cd frontend && flutter analyze` |
| Android APK | `cd frontend && flutter build apk --dart-define=BASE_URL=<url> --dart-define=WS_URL=<url>` (UNVERIFIED: no release signing or flavor config reviewed) |
| iOS | `flutter build ios` on macOS (UNVERIFIED) |
| WebSocket load test | Start the API on a throwaway database with `RATE_LIMIT_IP_PER_MINUTE=100000` and `--spring.data.redis.database=1`, then `python tools/ws_load.py --community-id <id> --school-id <id> --users 1000`; dashboard at `http://localhost:8097` (header of the file explains the setup) |
| Load test | `k6 run -e SCENARIO=baseline -e COMMUNITY_ID=<id> -e SCHOOL_ID=<id> apsbrat-api/load/k6-load.js` (read the header of the file first: needs a throwaway DB and a high `RATE_LIMIT_IP_PER_MINUTE`) |

## 9. Local analytics dashboard (`tools/api_dashboard.py`)
Dev only. Reads `/actuator/prometheus` (public only in the dev profile) and shows per-endpoint latency (p50/p95/p99), repository call timings, Hikari pool, JVM stats and a "worth a look" list.
```
python tools/api_dashboard.py                          # reads http://localhost:8080
python tools/api_dashboard.py --target http://localhost:8090 --port 8099
python tools/api_dashboard.py --pg-container <postgres container> --pg-db apsbrat_db --pg-user <DB_USER>
```
Open `http://localhost:8099` (bound to 127.0.0.1). `--pg-container` adds read-only Postgres statistics through `docker exec ... psql`. Slow-statement view needs `pg_stat_statements` enabled (not enabled by `docker-compose.yml`).

## 10. Common problems

| Problem | Cause (evidence) | Fix |
|---|---|---|
| Port 8080 already in use | Compose `api` container and an IDE-run API both bind 8080 (`docker-compose.yml` `ports`) | Stop one: `make down` or stop the IDE run; or run with `SERVER_PORT=8081` / `--server.port=8081` (the k6 script defaults to 8081 for this reason) |
| Postgres rejects time zone `Asia/Calcutta` | JVM or OS reports the legacy name; the project pins `Asia/Kolkata` (`pom.xml` jvmArguments, `Dockerfile` `JAVA_OPTS`, Hikari `SET TIME ZONE '+05:30'`) | Run the JVM with `-Duser.timezone=Asia/Kolkata`; for tests pass it through surefire `argLine` (section 7) |
| Flyway: "Validate failed ... checksum mismatch" | An already-applied `Vn__*.sql` was edited | Never edit applied migrations; add a new version. For a throwaway local DB drop the volume (`docker compose down -v`) |
| Flyway: "Found non-empty schema(s) without schema history" / V1..V4 skipped on a fresh DB | dev profile baselines at V4 (`baseline-on-migrate: true`, `baseline-version: 4`) | Start with `SPRING_FLYWAY_BASELINE_ON_MIGRATE=false` on an empty DB |
| API container exits immediately in Docker with no profile | `DevProfileGuard` refuses dev defaults in a container without `SPRING_PROFILES_ACTIVE` | Set `SPRING_PROFILES_ACTIVE` (compose already sets `dev`) |
| qa/prod start fails: unresolved `DATABASE_URL` / `JWT_SECRET` / `SPRING_DATA_REDIS_HOST` | Those have no default in qa/prod (`application.yml`) | Set the env vars |
| Connection refused on Redis at startup or 503 on readiness | Redis not running; readiness includes `redis` | `docker compose up -d redis` |
| Google sign-in returns 503 | `FIREBASE_CREDENTIALS_PATH` unset (`FirebaseAuthVerifier`) | Provide the service-account file path, or use email OTP |
| City search returns 503 | `GEOAPIFY_API_KEY` unset (`PlacesService.requireKey`) | Set the key |
| Sign-in code request returns 503 in prod ("couldn't send your code") | `BREVO_API_KEY` or `EMAIL_SENDER_ADDRESS` unset, key rejected, sender not verified, or Brevo blocked the host's IP | `GET /api/v1/admin/email/health` (ADMIN) names the cause; fix per `docs/DEPLOYMENT.md` "Email (Brevo)" |
| Android emulator cannot reach API | `localhost` default in `env.dart` | Use `10.0.2.2` via `--dart-define` (section 5) |
| Rate limited (429) during repeated logins from one machine | IP limit 60/min (`RateLimitFilter`) | Raise `RATE_LIMIT_IP_PER_MINUTE` locally |
| Photos upload but do not display with R2 | `MEDIA_BASE_URL` must be the full public bucket URL (`ImageUploadService` checks it) | Set it exactly |
| Tests with Testcontainers fail or hang on Windows | Docker pipe / API version / Ryuk (section 7) | Use the flags in section 7 |
| 18 Flutter tests fail on a clean checkout | Tests out of date with the code, see `testing.md` | Not an environment problem |
