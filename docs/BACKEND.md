# APSBrats Backend Guide

Spring Boot REST API. Read alongside [`API.md`](./API.md) (endpoints) and [`DATABASE.md`](./DATABASE.md) (schema).

---

## 1. Tech stack
| Concern | Choice |
|---------|--------|
| Language / runtime | Java 17 |
| Framework | Spring Boot 3.2.5 (Web, Data JPA, Security, Validation, WebSocket, Data Redis) |
| DB | PostgreSQL + Flyway migrations |
| Auth | JWT (jjwt 0.12.6) + phone OTP |
| Boilerplate | Lombok |
| Build | Maven (`./mvnw`) |

Entry point: `com.apsconnect.api.ApiApplication`.

---

## 2. Project structure — package by feature

```
com.apsconnect.api
├── ApiApplication.java
├── common/
│   ├── config/SecurityConfig.java        # security filter chain, CORS, PasswordEncoder
│   ├── exception/AppException.java        # throw new AppException(msg, HttpStatus)
│   ├── exception/GlobalExceptionHandler.java
│   ├── response/ApiResponse.java          # the universal envelope
│   └── security/SecurityUtils.java        # SecurityUtils.currentUserId()
├── auth/         # JWT + OTP login          (JwtService, JwtAuthFilter, AuthService, ...)
├── user/         # users, + history/ + social/ + PersonDto/PersonService
├── school/       # schools
├── connection/   # batchmate links
├── feed/         # activity feed
├── community/    # communities, members, messages
├── chat/         # 1-1 conversations + messages
├── notification/ # notifications
├── search/       # cross-entity search
└── profile/      # public profile aggregate
```
Each feature package is self-contained. Empty `*ModulePlaceholder.java` files are legacy stubs (harmless, kept because the mount blocks deletion).

---

## 3. Anatomy of a module

Every feature follows the same five-layer shape (look at `connection/` as the cleanest example):

| File | Role |
|------|------|
| `Xxx.java` | `@Entity` — JPA-mapped table row |
| `XxxRepository.java` | `JpaRepository<Xxx, UUID>` — queries (derived names or `@Query`) |
| `XxxService.java` | `@Service` — business logic, `@Transactional`, throws `AppException` |
| `XxxController.java` | `@RestController` — thin; maps HTTP → service, wraps in `ApiResponse` |
| `XxxDto.java` / `XxxRequest.java` | `record`s — output / validated input |

### Request lifecycle
```
HTTP request
  → JwtAuthFilter            (reads Bearer token, sets UUID principal in SecurityContext)
  → SecurityConfig rules     (permit or require auth)
  → Controller               (SecurityUtils.currentUserId(); @Valid @RequestBody)
  → Service (@Transactional) (logic; loads entities; throws AppException on errors)
  → Repository → PostgreSQL
  → map Entity → DTO record
  → ApiResponse.success(dto) → JSON { success, data, ... }
```
Any thrown `AppException` (or validation error) is converted to the error envelope by `GlobalExceptionHandler`.

---

## 4. Cross-cutting building blocks

### Response envelope — `ApiResponse<T>`
```java
return ResponseEntity.ok(ApiResponse.success(dto));            // {success:true, data:dto}
return ResponseEntity.ok(ApiResponse.success(null, "Saved"));  // with message
// errors are produced centrally; don't build error envelopes by hand
```

### Errors — `AppException` + `GlobalExceptionHandler`
```java
throw new AppException("Community not found", HttpStatus.NOT_FOUND);
```
Handled globally → `{ success:false, error:"Community not found" }` with the right status.
Bean-validation failures (`@Valid`) → `400` with `"field: message"`.

### Identity — never trust the URL for "me"
Feature endpoints get the caller from the token:
```java
UUID me = SecurityUtils.currentUserId();
```
`{userId}` in a path is always *another* user (e.g. who to connect with), never the caller.

### Enums ↔ PostgreSQL enum types
DB enum types are real (`CREATE TYPE ...`). Map them like:
```java
@Enumerated(EnumType.STRING)
@JdbcType(PostgreSQLEnumJdbcType.class)
@Column(nullable = false, columnDefinition = "connection_status")
private ConnectionStatus status;
```
Java constant names **must exactly match** the labels in the migration's `CREATE TYPE`.

### Transactions
Services annotate read paths `@Transactional(readOnly = true)` and writes `@Transactional`. Lazy associations (`@ManyToOne(fetch = LAZY)`) are resolved inside these boundaries (e.g. `PersonService` reading school history).

---

## 5. Authentication internals

Flow: **`POST /auth/request-otp` → `POST /auth/verify-otp` → JWT pair → send `Authorization: Bearer` on every call**.

| Component | Responsibility |
|-----------|----------------|
| `AuthService.requestOtp` | generate 6-digit code, store in `otp_codes` (10-min TTL), log it (no SMS gateway) |
| `AuthService.verifyOtp` | validate code (or dev master `000000`), mark consumed, mark user verified, issue tokens |
| `AuthService.refresh` | validate a refresh token, issue a new pair |
| `JwtService` | sign/parse HS256 tokens; key = SHA-256 of `app.jwt.secret` (so any secret length works); access vs refresh via a `type` claim; subject = user UUID |
| `JwtAuthFilter` | `OncePerRequestFilter`; on a valid Bearer token sets a `UUID` principal; invalid tokens are ignored (protected routes then 401) |
| `SecurityConfig` | stateless; permits `/auth/**`, `GET /schools/**`, registration + onboarding sub-resources; everything else `authenticated()` |

> OTP is **not** required to *register* (onboarding is public); it's the *login* mechanism. Password endpoints still exist but the login flow has no password.

---

## 6. Configuration (`application.yml`)

Three YAML profiles: base, `dev` (active by default), `prod`.

| Key | Dev default | Notes |
|-----|-------------|-------|
| `spring.datasource.url` | `jdbc:postgresql://localhost:5432/apsbrat_db` | user `aps_user` / `aps_pass` (env-overridable) |
| `spring.jpa.hibernate.ddl-auto` | `validate` | **never** auto-DDL → migrations required |
| `spring.flyway.baseline-version` | 4 | existing DBs are baselined at V4 |
| `app.jwt.secret` | `change-me` (`JWT_SECRET`) | set a real secret in prod |
| `app.jwt.access-token-expiry` | 900000 (15 min) | |
| `app.jwt.refresh-token-expiry` | 2592000000 (30 d) | |
| `app.otp.master` | `000000` (`OTP_MASTER`) | **dev only** — universal OTP; empty in prod |
| timezone | `Asia/Kolkata` / `+05:30` | JVM, Hikari init SQL, Jackson |

---

## 7. Project conventions (from `CLAUDE.md`)
- `RegisterUserRequest` intentionally has **no** validation annotations — don't add them.
- Flyway: always guard with `IF NOT EXISTS` / `IF EXISTS`; new enums use a `DO $$ ... EXCEPTION WHEN duplicate_object ... $$;` block.
- Timezone is `Asia/Kolkata` everywhere.
- DTOs and request bodies are Java `record`s.

---

## 8. Adding a new feature module (checklist)
1. **Migration** `V15__create_thing.sql` (guarded DDL; enum via `DO $$` block).
2. **Entity** with matching `@Column` names + enum mapping if needed.
3. **Repository** extending `JpaRepository<Thing, UUID>`.
4. **Service** (`@Transactional`), use `SecurityUtils.currentUserId()`, throw `AppException`.
5. **DTO / Request** `record`s (`@Valid` constraints on requests).
6. **Controller** under `/api/...`, return `ApiResponse`.
7. Document it in `API.md` + `DATABASE.md`.
8. Restart → Flyway migrates, Hibernate `validate` confirms entity↔table alignment.

---

## 9. Build & run
```
cd apsbrat-api
./mvnw clean verify          # compile + tests
./mvnw spring-boot:run       # run (needs Java 17, Postgres, Redis)
```
Prereqs: Java 17, PostgreSQL DB `apsbrat_db`, Redis on :6379. On boot, Flyway applies V5–V14 (V1–V4 baselined) and the demo seed (V14) populates data.

---

## 10. Known limitations / TODO
- Chat & community messaging are **REST only** — no realtime push yet (WebSocket starter & `socket_io_client` are present for a future upgrade).
- `Person.online`, `community.online_count`, and `member_count_override` are demo/denormalised display values, not live data.
- `ProfileDto.batchmatesCount` mirrors `connectedCount` (true shared-batch count is a TODO).
- No FCM push wiring yet (`users.fcm_token` column exists for it).
- OTP delivery logs to console (plug in an SMS provider in `AuthService.requestOtp`).
