# 02 - Technology Stack
What each major technology is, where it is used, and what it is responsible for.
Versions come from `frontend/pubspec.yaml` and `apsbrat-api/pom.xml`. "Reason not recorded" means no code or doc states why it was chosen.

Last verified: 2026-11-16 against commit 168d987 (working tree has uncommitted changes)

## 1. Mobile app (Flutter)

| Technology | Version | Where used | Responsibility | Why |
|---|---|---|---|---|
| Flutter / Dart | SDK `^3.10.8`; local toolchain Flutter 3.38.9 | `frontend/` (`android/`, `ios/`, `web/` folders exist) | UI, one codebase | Reason not recorded |
| flutter_riverpod | ^2.5.1 | `frontend/lib/features/**` providers, `ConsumerWidget`s | State management | Project rule in `CLAUDE.md` |
| riverpod_annotation, riverpod_generator, build_runner | ^2.3.5 / ^2.4.0 / ^2.4.9 | Declared only. No `package:riverpod_annotation` import in `frontend/lib` | Code generation | Declared but unused |
| go_router | ^12.1.3 | `frontend/lib/core/routes/app_router.dart` | Navigation, launch redirects (`context.go()` only) | Project rule |
| dio | ^5.4.3+1 | `frontend/lib/core/network/dio_client.dart` | HTTP client, auth header, retry with backoff (500 ms * 2^n) | Reason not recorded |
| pretty_dio_logger | ^1.4.0 | `dio_client.dart` | Debug HTTP logging, only in non-release builds; request headers/body off | Comment: avoid leaking tokens |
| flutter_secure_storage | ^9.2.2 | `dio_client.dart`, `features/auth/data/auth_repository.dart`, `features/chat/data/chat_socket.dart` | Stores tokens | Reason not recorded |
| shared_preferences | ^2.2.3 | `features/community/presentation/community_screen.dart` only | Small local flags | Reason not recorded |
| stomp_dart_client | ^2.0.0 | `features/chat/data/chat_socket.dart` | STOMP over WebSocket client for chat | Matches backend STOMP |
| firebase_core, firebase_auth, google_sign_in | ^2.31.1 / ^4.17.4 / ^6.2.1 | `lib/main.dart`, `features/auth/data/auth_repository.dart` | Google sign-in; sends Firebase ID token to the API | See 09-integrations.md |
| firebase_messaging, flutter_local_notifications | ^14.9.4 / ^19.4.2 | Declared only. No import in `frontend/lib` | Push notifications | Prepared, not wired |
| cached_network_image | ^3.3.1 | `core/media/photos.dart`, `core/app_root.dart`, feed widgets | Image caching | Reason not recorded |
| image_picker | ^1.1.2 | `core/media/photos.dart`, chat and community chat screens | Pick photos | Reason not recorded |
| geolocator | ^12.0.0 | `core/location/location_service.dart` | "Use my location" for city lookup | Feeds the places API |
| share_plus | ^10.0.0 | `community_screen.dart`, `post_card.dart`, `profile_tab.dart` | Native share sheet | Reason not recorded |
| hugeicons | ^4.4.0 | `app.dart`, `core/media/photos.dart`, `core/routes/app_router.dart` and others | Icon set | Reason not recorded |
| google_fonts | ^6.2.1 | 9 files: auth, onboarding, career and `features/feed/presentation/widgets/messages_tab.dart` | Fonts. `assets/fonts/` is empty, so fonts are fetched at runtime (UNVERIFIED: offline behaviour) | Reason not recorded |
| emoji_picker_flutter | ^2.2.0 | `chat_screen.dart` | Emoji picker | |
| country_picker | ^2.0.28 | `app.dart`, `onboarding_socials_screen.dart` | Phone country code | |
| font_awesome_flutter | ^11.0.0 | `onboarding_socials_screen.dart` only | Social brand icons | |
| intl | ^0.18.1 | chat, event, profile screens | Date formatting | |
| video_player, chewie, shimmer, reactive_forms, url_launcher, flutter_image_compress | various | No `package:` import found in `frontend/lib` | Dead dependencies (no import under `frontend/lib`, grep-verified) | n/a |
| flutter_lints | ^6.0.0 | `frontend/analysis_options.yaml`; CI runs `flutter analyze` | Lint rules | |

## 2. Backend (Spring Boot)

Java 17, Spring Boot parent 3.2.5, artifact `api` 0.0.1-SNAPSHOT (`apsbrat-api/pom.xml`). Base package `com.apsconnect.api`.

| Technology | Version | Where used | Responsibility | Why |
|---|---|---|---|---|
| spring-boot-starter-web | 3.2.5 (managed) | all `*Controller` classes | REST API under `/api/v1` | |
| spring-boot-starter-data-jpa (Hibernate) | managed | entities and `*Repository` per feature package | Persistence. `ddl-auto: validate` in every profile, so Flyway owns the schema | Schema safety |
| Flyway (`flyway-core`) | managed | `apsbrat-api/src/main/resources/db/migration` (V1..V40) | Versioned migrations on startup | |
| PostgreSQL JDBC driver | managed | datasource config | DB access | |
| spring-boot-starter-security | managed | `common/config/SecurityConfig.java`, `auth/JwtService.java` | Stateless JWT auth, CORS, route rules, roles ADMIN/MODERATOR | |
| jjwt (api, impl, jackson) | 0.12.6 | `auth/JwtService.java` | Sign/verify access (15 min) and refresh (30 day) tokens | |
| spring-boot-starter-data-redis | managed | `auth/AuthService`, `common/web/RateLimitFilter`, `IdempotencyFilter`, `circle/CircleCache`, `user/PresenceService`, `community/PostService`, `community/CommunityChatService`, `media/ImageUploadService` | OTP limits/lockout, rate limits, idempotency results, caches, presence | |
| spring-boot-starter-websocket | managed | `chat/WebSocketConfig.java` (endpoint `/ws`, in-memory simple broker on `/queue`), `chat/StompAuthChannelInterceptor.java` | Real-time chat | In-memory broker, so single instance only |
| spring-boot-starter-validation | managed | request records (`@Valid` on most controller bodies; see 12 for the exceptions) | Bean validation | |
| spring-boot-starter-actuator + micrometer-registry-prometheus | managed | `application.yml` `management.*` | Health, info, metrics, prometheus | |
| AWS SDK v2 `s3` | 2.29.52 | `media/R2StorageService.java` | Talks to Cloudflare R2 over the S3 API | R2 is S3-compatible |
| firebase-admin | 9.3.0 | `auth/FirebaseAuthVerifier.java` | Verifies Google/Firebase ID tokens | |
| springdoc-openapi-starter-webmvc-ui | 2.5.0 | on in dev; off in qa/prod (`application.yml`) | Swagger UI, `/v3/api-docs` | |
| Lombok | `${lombok.version}` | entities/DTOs | Boilerplate | |
| Spring `RestClient` | managed | `places/PlacesService.java` | Calls Geoapify | |
| logback | managed | `src/main/resources/logback-spring.xml` | Log pattern with requestId/userId; rolling file in qa/prod | |
| Testcontainers (junit-jupiter, postgresql) | managed by Boot BOM | `ApiApplicationTests`, `ConnectionFlowTest`, `ConnectionMigrationTest` | Real Postgres 16 + Redis 7 in tests | |
| spring-boot-starter-test (JUnit 5, Mockito) | managed | `src/test/**` | Unit tests | |

## 3. Data and infrastructure

| Technology | Version | Where | Responsibility |
|---|---|---|---|
| PostgreSQL | 16 (compose); tests use `postgres:16-alpine` | `docker-compose.yml` service `db` | System of record |
| PG extensions | `uuid-ossp` (V1), `pg_trgm` (V15, V21) | `db/migration/V1__create_users.sql`, `V15__add_performance_indexes.sql`, `V21__people_search_indexes.sql` | UUID defaults, fuzzy people search |
| Redis | 7 (compose); `redis:7-alpine` (tests) | `docker-compose.yml` service `redis`, 256 MB `volatile-lru` | Shared state (section 2) |
| Docker | n/a | `apsbrat-api/Dockerfile` (multi-stage: `maven:3.9-eclipse-temurin-17` build, `eclipse-temurin:17-jre` runtime), `docker-compose.yml` | Container image and local stack. No Dockerfile for the Flutter app |
| Make | n/a | `Makefile` (`up down logs rebuild psql`) | Compose shortcuts |
| GitHub Actions | checkout@v4, setup-java@v4, subosito/flutter-action@v2 | `.github/workflows/ci.yml` | CI only (no CD in repo) |
| Cloudflare R2 | n/a | `media/R2StorageService.java` | Media storage when `STORAGE_TYPE=r2` |
| Geoapify | HTTP API | `places/PlacesService.java` | City autocomplete and reverse geocode |
| Static site | plain HTML | `website/index.html`, `website/brand/` | Landing page. Hosting (Cloudflare Pages) is stated only in `docs/DEPLOYMENT.md`: UNVERIFIED |
| Python 3 (stdlib only) | n/a | `tools/api_dashboard.py` | Local dev analytics dashboard |
| k6 | n/a | `apsbrat-api/load/k6-load.js` | Load-test scenarios: baseline, normal, stress, spike, login, chat |

## 4. Notes
- Time zone is fixed to Asia/Kolkata everywhere: `jackson.time-zone`, Hibernate `jdbc.time_zone`, Hikari `connection-init-sql: SET TIME ZONE '+05:30'`, Dockerfile `JAVA_OPTS`, `spring-boot-maven-plugin` `jvmArguments`.
- Redis is required at runtime (rate-limit filter; readiness group includes `redis`).
- Image processing library for `media/ImageProcessor` was not checked: UNVERIFIED.
