# APSBrats — Developer Documentation

APSBrats is an alumni network for Army Public School "brats": find batchmates, join
your section/school communities, chat, and keep a profile of the schools you attended.

This `docs/` folder is the starting point for any new developer.

---

## 📚 Document map

| Doc | Read it when you need to… |
|-----|---------------------------|
| **[README.md](./README.md)** (this file) | Get oriented, set up, run, troubleshoot |
| **[BACKEND.md](./BACKEND.md)** | Understand the Spring Boot architecture & add features |
| **[FRONTEND.md](./FRONTEND.md)** | Understand the Flutter app & wire screens to data |
| **[API.md](./API.md)** | Call any endpoint (paths, bodies, responses) |
| **[DATABASE.md](./DATABASE.md)** | Understand the schema, tables, enums, migrations |
| `../BACKEND_NOTES.md` | Quick one-page build summary |

Suggested reading order: **README → BACKEND → API → DATABASE** (backend devs),
or **README → FRONTEND → API** (frontend devs).

---

## 🏗 System overview

```
┌──────────────────┐      HTTPS / JSON       ┌──────────────────────┐      JDBC      ┌────────────┐
│  Flutter client  │  ───────────────────▶   │  Spring Boot API     │  ───────────▶  │ PostgreSQL │
│  (Riverpod, dio) │   Bearer JWT in header  │  /api/**             │                │  (Flyway)  │
└──────────────────┘                         │  JWT + OTP auth      │                └────────────┘
                                             └──────────────────────┘
                                                        │ (Redis available, not yet used)
```
- **Auth**: phone OTP → JWT access/refresh tokens.
- **Data**: every screen is backed by a REST endpoint; demo data is seeded by Flyway.
- Two codebases in this repo: `apsbrat-api/` (backend) and `frontend/` (Flutter).

---

## 🚀 Quickstart

### Prerequisites
- Java 17, Maven (wrapper included)
- PostgreSQL with a database `apsbrat_db` (user `aps_user` / `aps_pass`, or set `DB_USER`/`DB_PASSWORD`)
- Redis on `:6379`
- Flutter SDK (Dart 3)

### 1. Backend
```
cd apsbrat-api
./mvnw spring-boot:run
```
Flyway runs migrations and seeds demo data on first boot. API at `http://localhost:8080/api`.

### 2. Frontend
```
cd frontend
flutter pub get
flutter run -t lib/main_dev.dart
```

### 3. Log in (demo)
Phone **`919999000001`**, OTP **`000000`** → you are "Arjun Singh".
(Any seeded phone `919999000002`…`011` works; see DATABASE.md §6.)

### Smoke-test the API without the app
```
curl -X POST localhost:8080/api/auth/request-otp -H 'Content-Type: application/json' -d '{"phone":"919999000001"}'
curl -X POST localhost:8080/api/auth/verify-otp  -H 'Content-Type: application/json' -d '{"phone":"919999000001","code":"000000"}'
# copy data.accessToken, then:
curl localhost:8080/api/feed/activity -H "Authorization: Bearer <accessToken>"
```

---

## 📁 Repository layout

```
APSBrats/
├── apsbrat-api/        # Spring Boot backend  → see BACKEND.md
│   └── src/main/
│       ├── java/com/apsconnect/api/...
│       └── resources/db/migration/   # Flyway V1..V14
├── frontend/           # Flutter app          → see FRONTEND.md
│   └── lib/...
├── docs/               # this documentation
├── BACKEND_NOTES.md    # one-page summary
└── seed_schools.sql    # full 135-school directory (optional bulk import)
```

---

## 📐 Conventions cheat-sheet (`CLAUDE.md`)

Backend:
- DTOs & request bodies are Java `record`s; controllers stay thin and return `ApiResponse`.
- Errors via `throw new AppException(msg, HttpStatus)` — never hand-build error JSON.
- Get the caller with `SecurityUtils.currentUserId()`; never trust a userId in the URL for "me".
- `ddl-auto: validate` → schema changes need a Flyway migration (guarded with `IF [NOT] EXISTS`; enums via `DO $$` block).
- `RegisterUserRequest` has no validation annotations — intentional.
- Timezone is `Asia/Kolkata` throughout.

Frontend:
- State via Riverpod (`ConsumerWidget` / `StateNotifier`); navigate with `context.go()` only.
- `withValues(alpha:)` not `withOpacity()`; `initialValue:` not `value:` on dropdowns.
- No mock data in new code — use the providers in each feature's `data/` folder.
- Colours via `AppColors` (crimson / gold palette).

---

## 🧭 Glossary

| Term | Meaning |
|------|---------|
| **Brat** | child of an Army officer; here, an APS alumnus/student |
| **Batchmate** | someone you have an accepted *connection* with |
| **Section community** | auto-joined group for your exact class+section+year (e.g. `12A · APS Patiala · 2022`) |
| **School community** | group for everyone from one school across years |
| **Primary school history** | the `is_primary` row used to build a person's headline (school + `detail` like `12A · Class 2022`) |
| **Person card / `PersonDto`** | the shared shape shown wherever a user appears (feed, avatars, chat) |
| **Discover community** | a large group (`ALL_YEARS` / `GLOBAL`) you can browse and join |

---

## 🛠 Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| App won't compile (backend) | Needs **Java 17** (Spring Boot 3). Check `java -version`. |
| `Flyway ... validate failed` / migration checksum | Don't edit an applied migration — add a new `V##`. Existing DBs are baselined at V4. |
| Startup fails on enum/column mismatch | Hibernate `validate` — entity `@Column`/enum doesn't match the migration. Align names. |
| `401` on every feature call | Missing/expired `Authorization: Bearer` token. Re-run verify-otp / refresh. |
| OTP "incorrect" in dev | Use master `000000`, or read the real code from the server console log. |
| CORS error from web | `SecurityConfig` allows `localhost`/`127.0.0.1` only — add your origin there. |
| Flutter can't reach API on a device | Pass `--dart-define=BASE_URL=http://<host-ip>:8080/api` (not `localhost`). |
| Screens still show old fake data | Those widgets still read `dummy_data.dart`; wire them to providers (FRONTEND.md §10). |

---

## ✅ Status & roadmap

**Done:** auth (JWT+OTP), users/schools/onboarding, connections, feed, communities, chat (REST),
notifications, search, profiles; full Flutter data layer + working login; demo seed.

**Next:**
1. Wire feature widgets to providers, remove `dummy_data.dart` (FRONTEND.md §10).
2. Realtime chat (WebSocket) — starters already in `pom.xml` / pubspec.
3. FCM push notifications (`users.fcm_token` ready).
4. Profile-pic upload endpoint; true "shared-batch" batchmate count.
