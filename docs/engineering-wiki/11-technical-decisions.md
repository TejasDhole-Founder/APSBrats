# 11 - Technical Decisions and Trade-offs

A record of the decisions that shape the project: what, why, what else was possible, the cost, and what would make us revisit it. Add an entry whenever a significant decision is made.

How to read "Why": "Recorded" means a code comment, doc or an explicit decision in the development sessions states the reason. "Inferred" means the reason is deduced from the code and was never written down elsewhere, so treat it as a hypothesis.

Last verified: 2026-11-16 against commit 168d987 (working tree has uncommitted changes)

## Index
D1 Modular monolith, one jar · D2 Flyway owns the schema · D3 Stateless JWT + Redis-backed refresh · D4 Email OTP and Google sign-in, no passwords · D5 REST for writes, STOMP only for push · D6 Keyset pagination · D7 Server-side image processing, upload on pick · D8 One connection row per user pair + advisory lock · D9 No outbox · D10 Partial indexes for pending requests · D11 Redis failure behaviour · D12 Soft delete and anonymise · D13 Denormalised counters · D14 Idempotency keys on every POST · D15 Mutual connections computed in SQL · D16 Fixed Asia/Kolkata time zone · D17 Hugeicons stroke icons · D18 Dev-only metrics exposure and local dashboard · D19 Privacy by "not found"

---

### D1. Modular monolith, one deployable jar
- Decision: one Spring Boot service organised by feature package (`auth`, `community`, `connection`, ...), one Postgres, one Redis.
- Why: Inferred (small team, shared data, simplest to run). The code itself says "single instance" in several places (`MaintenanceJobs`, `WebSocketConfig`).
- Alternatives: microservices, separate chat service.
- Trade-offs: simple deploys and transactions; chat push and the nightly job assume one instance.
- Reconsider when: a second API instance is needed (see D5) or one feature needs independent scaling.

### D2. Flyway owns the schema, Hibernate only validates
- Decision: every schema change is a Flyway migration; `spring.jpa.hibernate.ddl-auto: validate`. Project rule: migrations use `IF NOT EXISTS` / `IF EXISTS` guards (`CLAUDE.md`).
- Why: Recorded (rule in `CLAUDE.md`); safe, reviewable, repeatable changes.
- Alternatives: `ddl-auto: update`, manual SQL.
- Trade-offs: a mapping/schema mismatch stops startup; migrations are forward-only; V39 is not backward compatible with the previous app version (see D8).
- Reconsider when: rollbacks without redeploy become a requirement (add expand/contract migrations).

### D3. Stateless JWT access token, Redis-backed refresh and revocation
- Decision: access token 15 min, refresh token 30 days with its id stored in Redis; logout-all writes a revocation marker (`AuthService`, `JwtAuthFilter`).
- Why: Inferred (mobile client, no server session state, ability to log out everywhere).
- Alternatives: server sessions, opaque tokens.
- Trade-offs: revocation depends on Redis and fails open if Redis is down (a banned or logged-out token keeps working until it expires, up to 15 min); refresh-token reuse is not detected.
- Reconsider when: banning must take effect instantly (check `banned_at` per request) or refresh theft becomes a concern.

### D4. Email OTP and Google sign-in, no passwords
- Decision: one "log in or create" flow keyed by email; `users.password_hash` and the `PasswordEncoder` bean are unused leftovers (V23 moved login from phone to email).
- Why: Inferred (no password reset flow to build, Google covers most users).
- Trade-offs: OTP is generated but there is no email sender, so only Google works in qa/prod; a master OTP exists for dev (`OTP_MASTER`).
- Reconsider when: before any real launch: add an `EmailSender` (the `TODO` in `AuthService.requestOtp`).

### D5. REST for writes, STOMP only for push, in-memory broker
- Decision: messages are sent with REST (so rate limits, validation and idempotency apply) and the server pushes the stored message over `/ws` after commit.
- Why: Recorded in code comments (push after commit so clients never see rolled-back messages) and `docs/chat-course`.
- Alternatives: send over the socket; external broker (RabbitMQ/Redis pub-sub).
- Trade-offs: in-memory `enableSimpleBroker("/queue")` means push only reaches users on the same instance; no replay after a dropped socket (client does not refetch on reconnect).
- Reconsider when: more than one API instance, or reliable delivery is required.

### D6. Keyset (cursor) pagination
- Decision: cursors on `createdAt` for posts/chat/comments, and on `(lower(name), id)` or `(requested_at, id)` for connection lists. Offset paging remains for popular posts and people search.
- Why: Recorded (`CursorSupport`; a `ponytail:` comment at `PostRepository.java:43` says offset paging can repeat or skip a post when scores move).
- Trade-offs: `createdAt`-only cursors can skip rows that share a timestamp at a page boundary; the connection cursors include an id tie-break.
- Reconsider when: timestamp ties show up in practice: add `(createdAt, id)`.

### D7. Server-side image processing, upload on pick
- Decision: every photo is sent to the API (`POST /media/images`), validated (type, 5 MB, decodable), re-encoded as JPEG with metadata stripped (max 1600 px for posts), stored in R2 or local disk, and the returned URL is attached to the post.
- Why: Recorded in `ImageUploadService` docs (no outside links, no one else's photos, strip EXIF/GPS).
- Alternatives: presigned direct-to-R2 upload; upload at Post time.
- Trade-offs: the API holds each file in memory (`file.getBytes()`); photos upload when picked, so abandoned drafts leave orphan files that are never deleted; 30 uploads per hour per user count even for abandoned posts.
- Reconsider when: upload volume grows (presigned URLs) or storage cost matters (cleanup job).

### D8. One connection row per user pair, serialised by an advisory lock, with an events table
- Decision (V39): `connections` has `user_low_id < user_high_id` (canonical pair), `requester_id/addressee_id` for the current request direction, unique key `uq_connection_pair`. Every change first takes `pg_advisory_xact_lock` on the pair (`ConnectionRepository.lock`, `ConnectionService`). History is in `connection_events`. A reverse request auto-accepts.
- Why: Recorded (requirement given in the development session): the old schema allowed A->B and B->A rows and raced.
- Alternatives considered: unique key only (leaves check-then-insert races to error handling); optimistic locking only (not safe across instances); Redis lock (extra dependency); full event sourcing (overkill).
- Trade-offs: the lock holds for the transaction only; Postgres-specific; UUID order must match Postgres byte order, so `UserPair` orders by canonical text (not `UUID.compareTo`). V39 is not backward compatible: old app code cannot insert connections because the new columns are NOT NULL, and the migration locks `connections` while it runs.
- Reconsider when: moving off Postgres or if the table gets large enough that the V39-style rewrite is a problem.

### D9. No transactional outbox
- Decision: notifications are rows inserted in the same transaction as the action (`NotificationService.create`). No outbox, queue or worker.
- Why: Recorded (explicitly: add an outbox only if existing infrastructure lacks a reliable mechanism; the same-transaction insert is reliable and atomic).
- Trade-offs: no asynchronous push delivery exists, so there is nothing to retry. If a failure in the notification insert occurs, the whole action rolls back.
- Reconsider when: push notifications (FCM) are implemented: add an outbox then.

### D10. Partial indexes for pending requests (V40)
- Decision: `idx_conn_pending_incoming` and `idx_conn_pending_outgoing` on `(user, requested_at DESC, id DESC) WHERE status = 'PENDING'`.
- Why: Recorded (the V40 header comment gives rough figures; these exact numbers come from a local `EXPLAIN ANALYZE` run on a throwaway 2M-row database: received requests 36.8 ms -> 0.43 ms, sent 9.8 ms -> 0.44 ms, deep pages too; about 10 MB each).
- Trade-offs: legacy full-list queries bind the status as a parameter and cannot use partial indexes.
- Reconsider when: pending volume per user stays tiny (indexes then add only write cost).

### D11. Redis failure behaviour is per feature
- Decision: global rate limit and token revocation fail open; OTP, per-action limits (posts, group chat, uploads) and refresh fail closed (503); keyed POSTs may return a raw 500 (`IdempotencyFilter` does not catch Redis errors).
- Why: Inferred; the global limiter documents "fail open". The rest was not decided as a whole.
- Trade-offs: a Redis outage degrades the app unevenly. Treat as technical debt (see 12), not a deliberate policy.
- Reconsider when: before production: pick one policy.

### D12. Soft delete of content, anonymise accounts
- Decision: content has `status` (`ACTIVE`/`REMOVED`) so mistakes can be undone; deleting an account anonymises the user row (`AccountService.deleteAccount`) instead of removing it.
- Why: Recorded in `PostService.delete` comment ("kept as REMOVED so a mistake can be undone").
- Trade-offs: much user data remains after deletion (career entries, memberships, connections, files), a data-protection gap; see 12.

### D13. Denormalised counters updated atomically
- Decision: `like_count`, `comment_count`, `member_count` live on the parent row and change with `UPDATE ... SET x = x + :delta`; likes use `INSERT ... ON CONFLICT DO NOTHING`.
- Why: Inferred (cheap feed reads, safe double taps).
- Trade-offs: counters can drift if a path forgets to update them (account deletion keeps `member_count` inflated).

### D14. Idempotency key on every POST
- Decision: the Flutter client adds `Idempotency-Key` to each POST and retries transient failures with the same key; `IdempotencyFilter` replays 2xx results for 24 h.
- Why: Recorded in code comments (safe retries on flaky mobile networks).
- Trade-offs: key is not tied to the request body; Redis outage breaks keyed POSTs (D11).

### D15. Mutual connections computed in SQL, never stored
- Decision: `INTERSECT` queries over accepted rows (`ConnectionRepository.countMutualBetween`, `findMutualPage`); no counter table.
- Why: Recorded (requirement given in the development session): mutual counts depend on both users and change with either's connections.
- Trade-offs: cost grows with the larger friend list; measured about 83-142 ms for two users with 25,000 connections each, a few ms for typical users.
- Reconsider when: very large networks or hot profile pages.

### D16. Fixed Asia/Kolkata time zone
- Decision: JVM (`JAVA_OPTS` in the Dockerfile), Jackson, Hibernate JDBC time zone and the DB session (`SET TIME ZONE '+05:30'`) are all pinned; timestamps are `LocalDateTime`.
- Why: Recorded (`CLAUDE.md` rules).
- Trade-offs: a laptop JVM that is not pinned can store different times (the Docker image pins it); event times are zone-less, so users outside IST are not handled.

### D17. Hugeicons (stroke, rounded) as the icon set
- Decision: all Material icons were replaced with `hugeicons` (`AppIconData` typedef in `frontend/lib/core/theme/app_icons.dart`).
- Why: Recorded (requested for a more modern look).
- Trade-offs: only the stroke-rounded set is free, so there are no filled variants; a liked heart differs from an unliked one only by colour; `semanticLabel` is not supported (accessibility labels were dropped on a few icons).

### D18. Metrics exposed only in dev, plus a local dashboard
- Decision: `/actuator/prometheus` and `/actuator/metrics` are public only when `app.actuator.public-metrics=true` (dev profile); latency histograms are on in dev; `tools/api_dashboard.py` reads them.
- Why: Recorded (local testing need); metrics can reveal internals so they stay closed elsewhere.
- Trade-offs: in qa/prod nothing can scrape metrics today.
- Reconsider when: production monitoring is set up: add a separate protected management port or a scraper path.

### D19. Privacy by "not found"
- Decision: where existence must not leak (blocked users, another school's community) the API returns 404 instead of 403.
- Why: Inferred from `ProfileService`, `CommunityService`, `ConnectionService` behaviour.
- Trade-offs: block, `discoverable` and ban checks are applied per query, not centrally, so some read paths miss them (listed in 12).
