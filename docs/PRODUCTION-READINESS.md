# APSBrats — Production Readiness Review (PRR)

> Reviewer lens: senior architect / eng lead taking this to a go-live gate.
> Verdict today: **NOT production-ready.** Functionally it's a strong prototype,
> but it is missing the safety, security, compliance, operability and quality
> controls required to put real users — including minors and military families —
> on it. Below is everything from code → UX → security → ops → legal, with
> severity: 🔴 launch blocker · 🟠 high · 🟡 medium · 🟢 later.

---

## 0. Executive summary — the blockers

You cannot launch until these are done:

1. 🔴 **Child-safety & minors.** APS is a *school*; the network will contain users under 18. With DMs + photo uploads that triggers legal duties: age-gating, verifiable parental consent (DPDP Act 2023 §9), CSAM detection/reporting (POCSO/IT Rules 2021), and minor-specific privacy. None exist.
2. 🔴 **No real OTP delivery + no rate limiting.** OTP only logs to console; there's no SMS gateway and no TRAI DLT registration (mandatory in India for transactional SMS). With no rate limit, "OTP bombing" is both an abuse vector and a direct cost attack.
3. 🔴 **Account takeover / weak auth lifecycle.** Default JWT secret `change-me`, no refresh-token rotation/revocation, no logout invalidation, OTP brute-forceable (no attempt lockout).
4. 🔴 **No account deletion or data export** (DPDP "right to erasure"/access). There are zero `DELETE` endpoints.
5. 🔴 **No Trust & Safety surface** — no block, report, mute, leave-community, or moderation. Unsafe for a social app, doubly so with minors.
6. 🔴 **Privacy controls are fake** — the Settings toggles (show phone, "batchmates only") have no backend; profiles/search currently expose PII (phone, city, profession) regardless.
7. 🔴 **Not operable** — no Docker, CI/CD, health checks, logging, metrics, alerting, or backups. You can't safely deploy, observe, or recover it.
8. 🔴 **No automated tests** — effectively zero coverage; every change is a blind change.
9. 🟠 **App not wired end-to-end** — Flutter screens still render `dummy_data.dart`, not the live API.

Special context that raises the bar: **military-family data** (schools, postings, cities, real names, phone) is OPSEC-sensitive — privacy must be default-deny, never publicly indexable.

---

## 1. Backend — code & architecture
- 🔴 **GlobalExceptionHandler is dangerous**: it catches `Exception` and returns a generic 500 while **logging nothing** (`Exception ignored`). You'll be blind in prod, and legitimate 4xx cases get masked as 500. Add: per-exception mapping, structured log with stack + correlation id, never leak internals to clients.
- 🔴 **OTP-before-account ordering** — registration creates a user with no proof of phone ownership; verification happens only at login. Spam/fake-account farm risk. Verify OTP → then create/activate.
- 🟠 **No optimistic locking (`@Version`)** — concurrent writes (accept connection, mark-read, profile edit) can silently clobber each other.
- 🟠 **No soft-delete / audit columns** (`deleted_at`, `created_by/updated_by`). No recovery, no "who did what", no moderation trail.
- 🟠 **`RegisterUserRequest` has no validation** (intentional per CLAUDE.md, but prod needs server-side checks): E.164 phone format, username policy + profanity/impersonation block, email format, DOB/age.
- 🟠 **Idempotency** — send-message / send-connection / register have no idempotency keys; double taps or retries create duplicates.
- 🟡 **Placeholders still shipped** (`PostModulePlaceholder`, `FollowModulePlaceholder`, etc.) — decide: implement Posts or delete the stubs.
- 🟡 **DTO/response consistency** — confirm timestamps are ISO-8601 UTC with offset; document null semantics.
- 🟡 **Service boundaries** — `PersonService` is a shared hot path; keep it cache-friendly (see Perf).
- 🟢 Package-by-feature, records, `ApiResponse` envelope, Flyway, enum mapping — all good foundations; keep.

## 2. Frontend (Flutter) — code & architecture
- 🟠 **Screens not wired** to providers (`dummy_data.dart` still used) — top functional gap.
- 🔴 **No 401/refresh handling** — access token expires in 15 min and the Dio client has no refresh-on-401 interceptor → users get silently logged out / see errors. Add token-refresh + retry + global logout.
- 🟠 **No global error/maintenance handling** — network errors, 5xx, offline, and "force update" aren't surfaced.
- 🟠 **State after mutations** — providers aren't invalidated after send/accept/join; no optimistic updates → stale UI.
- 🟠 **No crash reporting** — `firebase_core`/`messaging` present but no Crashlytics/Sentry.
- 🟡 **No offline cache / connectivity awareness**; no skeleton loaders or empty states.
- 🟡 **No deep-link routing** from notifications (open a chat/profile from a push).
- 🟡 **Secrets/log hygiene** — good (pretty logger hides bodies); verify no token logging in release.
- 🟡 **Env handling** — base URL via `--dart-define`; ensure prod build uses prod flavor and HTTPS only.

## 3. API design
- 🟠 **Versioning** — no `/v1` prefix; add before public clients ship (breaking changes later are painful).
- 🔴 **Pagination** — list/message endpoints return everything; standardise cursor pagination (`?cursor&limit`) with a documented envelope.
- 🟠 **Consistent error codes** — return machine-readable `code` + message, not just a string, so the app can react (e.g., `OTP_EXPIRED`, `RATE_LIMITED`).
- 🟠 **OpenAPI/Swagger** — add `springdoc-openapi`; generate the contract, drive client models from it.
- 🟡 **Rate-limit headers**, request size limits, and consistent 429s.
- 🟡 **Idempotency-Key header** support on mutating POSTs.

## 4. Data / persistence
- 🔴 **Backups + PITR** — no backup/restore strategy. Managed Postgres with automated backups + tested restore before launch.
- 🟠 **Migrations discipline** — never edit applied migrations; add a CI check; keep `target/classes` copies out of git.
- 🟠 **Retention policy** — OTP codes, notifications, deleted users, chat logs need TTL/retention rules (and legal retention limits).
- 🟠 **PII classification** — tag phone/email/DOB/location as PII; encrypt-at-rest (managed), restrict in logs and analytics.
- 🟡 **Indexing review under real data**; connection pool (Hikari) sizing; statement timeouts.
- 🟡 **Full-text search** — `LIKE`/trigram won't scale; move to Postgres FTS (`tsvector`) or a search service.

## 5. Security (auth, authz, OWASP)
- 🔴 **Secrets management** — `JWT_SECRET` must be a strong, rotated secret from a vault/secret manager; fail startup if default. Remove dev `app.otp.master` from any prod path.
- 🔴 **OTP hardening** — per-phone + per-IP rate limit, max attempts → lockout, single-use, short TTL, resend cooldown, constant-time compare. (Redis-backed.)
- 🔴 **Refresh-token rotation + revocation** — rotate on use, store/blacklist (Redis), revoke on logout/compromise; today a leaked refresh token is valid for 30 days.
- 🟠 **Authorization audit** — verify every endpoint checks ownership/membership (some do via `SecurityUtils`); add tests that prove a user can't read others' DMs, accept others' requests, post to communities they're not in.
- 🟠 **Input validation & output encoding** — validate all inputs; treat message bodies as untrusted (stored-XSS sink in web/admin views); strip control chars.
- 🟠 **Transport & headers** — enforce HTTPS/HSTS, lock CORS to prod origins, add security headers (CSP for the web/admin, X-Content-Type-Options, etc.).
- 🟠 **Dependency & container scanning** — Dependabot/Snyk + image scan in CI; pin versions.
- 🟡 **Brute-force/enumeration** — don't reveal whether a phone is registered; uniform responses + rate limits.
- 🟡 **Abuse/DoS** — body size caps, query cost limits, WAF in front.

## 6. Privacy & compliance (India-first)
- 🔴 **DPDP Act 2023** — you're a Data Fiduciary: lawful consent capture, purpose limitation, **right to access + erasure**, breach notification, a published grievance/DPO contact. None implemented.
- 🔴 **Minors** — verifiable parental consent + no behavioural tracking/targeted content for under-18 (DPDP §9). Requires age determination at signup.
- 🔴 **TRAI DLT** — register sender header + OTP templates with the DLT platform before any SMS; otherwise OTP won't deliver.
- 🟠 **App store privacy** — Google Play **Data Safety** form + Apple **Privacy Nutrition Labels**; both required and audited.
- 🟠 **Privacy policy + ToS** — published, linked in app + website + stores; consent screen at onboarding.
- 🟡 **Data localization / residency** — keep Indian user data per DPDP guidance; choose region accordingly.
- 🟡 **Cookie/analytics consent** on the marketing site if you add analytics.

## 7. Trust & Safety / moderation
- 🔴 **Block / report / mute** users and messages; **leave community / remove member**.
- 🔴 **CSAM handling** — with photos + minors this is legally mandatory: hash-matching (PhotoDNA-equivalent), automated takedown, and reporting to authorities; preserve evidence.
- 🟠 **Admin/moderation console** — review reports, suspend/ban, audit actions, community moderators/roles.
- 🟠 **Automated abuse detection** — spam, harassment keywords, link/scam filtering, message rate limits per user.
- 🟡 **Impersonation controls** — school/identity verification flow (the app implies "verified"); define what "verified" means and how it's earned.

## 8. Realtime / chat
- 🟠 **WebSocket/STOMP** — chat is REST-only; add realtime delivery, with **Redis pub/sub** so it works across multiple instances (sticky sessions alone won't scale).
- 🟡 Presence (online/last-seen — currently faked), typing indicators, delivery/read receipts, message ordering + dedupe, edit/delete, attachments.
- 🟡 Offline queue + resend; push fallback when socket is down.

## 9. Notifications (push / email / SMS)
- 🔴 **SMS (OTP)** provider + DLT (see Compliance) + failover provider + cost caps.
- 🟠 **FCM push** — register/refresh `fcm_token`, send on message/connection/join, deep-link payloads, respect per-type preferences and quiet hours.
- 🟡 **Email** (optional) for receipts/security alerts; verified sender domain (SPF/DKIM/DMARC).
- 🟡 Notification preferences must be honoured server-side (ties to Settings backend).

## 10. Media / file handling
- 🔴 **Upload pipeline** — profile pics need object storage (S3/GCS) + CDN, signed URLs, size/type limits, image re-encoding (strip EXIF/GPS — OPSEC!), and **virus/CSAM scanning** before serving.
- 🟡 Thumbnailing, lazy loading, cache headers.

## 11. UI/UX (every state, a11y, polish)
- 🟠 **All async states** — loading (skeletons), empty ("no batchmates yet"), error + retry, offline, end-of-list. Currently optimistic-only mockups.
- 🟠 **Forms** — phone input masking + country code, inline validation, server-error mapping, disabled/submitting states, success feedback.
- 🟠 **Accessibility** — semantic labels for screen readers, min 44px tap targets, dynamic font scaling, 4.5:1 contrast (verify crimson/gold combos), focus order, reduced-motion.
- 🟡 **Onboarding** — progress save/resume, back navigation, edit-before-submit, verify step actually verifies.
- 🟡 **Localization** — `intl` is only used for dates; decide on Hindi/regional support; externalise strings.
- 🟡 **Consistency** — design tokens, spacing scale, component library; dark mode decision; haptics/micro-interactions.
- 🟡 **Edge content** — long names, emoji, RTL safety, huge communities, very long messages.

## 12. Mobile app specifics
- 🟠 **Force-update / min-version gate** (server-driven) so you can retire broken clients.
- 🟠 **Crash + ANR reporting** (Crashlytics/Sentry), with release symbol upload.
- 🟠 **Permissions** — runtime prompts (notifications, photos) with rationale; graceful denial paths.
- 🟡 **Deep links / universal links** (open profile/chat from push/web).
- 🟡 **App store readiness** — icons (done), screenshots, descriptions, privacy forms, content rating (esp. with minors), signing keys + Play App Signing, staged rollout.
- 🟡 **Build flavors** — confirm dev/staging/prod, no debug toggles in release, obfuscation (`--obfuscate`).

## 13. Infrastructure / DevOps
- 🔴 **Containerize** — `Dockerfile` (multi-stage) + `docker-compose` (api/postgres/redis) for parity.
- 🔴 **Environments** — separate dev / staging / prod with isolated data + secrets.
- 🔴 **CI/CD** — build, test, scan, image publish, migrate, deploy; protected `main`, PR checks.
- 🟠 **Managed services** — managed Postgres + Redis (backups, HA) rather than self-run.
- 🟠 **Secrets** — vault/secret manager, not yaml defaults; rotation.
- 🟠 **Edge** — TLS, load balancer, CDN, WAF, DNS, rate limiting at the edge.
- 🟡 **IaC** (Terraform), autoscaling, blue-green/canary deploys.

## 14. Observability
- 🔴 **Health/readiness/liveness** (Actuator) for orchestrators + LB.
- 🔴 **Structured logging** with correlation/request IDs; ship to a log store; no PII in logs.
- 🟠 **Metrics** (Micrometer→Prometheus) + dashboards (Grafana): latency, error rate, throughput, DB, OTP send/verify, push success.
- 🟠 **Error tracking** (Sentry) for API + app.
- 🟠 **Alerting + on-call** — SLOs (e.g., 99.9% API, p95 latency), alert routing, runbooks.
- 🟡 **Distributed tracing** (OpenTelemetry); **uptime/synthetic** checks; **audit log** for sensitive actions.

## 15. Performance / scalability
- 🔴 **Pagination** (repeat: messages, search, lists).
- 🟠 **Use Redis** for OTP, rate limits, token blacklist, and caching `PersonDto`/community aggregates (it's wired but idle).
- 🟠 **Load testing** (k6/Gatling) to find breakpoints; set capacity targets.
- 🟡 Resolve remaining N+1s (PERFORMANCE.md A/B), denormalise DM inbox, statement timeouts, async work via a queue (notifications, image processing).

## 16. Reliability / availability / DR
- 🟠 **Graceful shutdown**, DB connection retry/backoff, sensible timeouts.
- 🟠 **Circuit breakers / retries** around SMS, FCM, storage (Resilience4j).
- 🟠 **Backup + tested restore**; documented RPO/RTO; DR runbook.
- 🟡 Multi-AZ; idempotent consumers; dead-letter queues.

## 17. Testing / QA
- 🔴 **Backend**: unit + integration with **Testcontainers** (real Postgres/Redis), controller + **authz/security** tests, contract tests.
- 🟠 **Mobile**: widget/unit tests, `integration_test`/Patrol e2e, golden tests, device matrix (low-end Android).
- 🟠 **Coverage gate** in CI; **load** + **security** (ZAP/Burp) + **a11y** testing.
- 🟡 Manual QA scripts, beta channel (internal testing / TestFlight), bug triage process.

## 18. Release management
- 🟠 Semver + changelog; **feature flags**; staged rollout (Play % rollout); fast rollback; release checklist.

## 19. Cost / capacity
- 🟠 **SMS is the cost risk** — per-OTP cost + bombing exposure; cap + alert on spend.
- 🟡 Storage/CDN/compute/managed-DB budgeting; per-MAU cost model.

## 20. Analytics / product
- 🟡 Event instrumentation (signup funnel, activation = first connection/message, retention), privacy-respecting; dashboards; (minors: no behavioural targeting).

## 21. Documentation / support / ops
- 🟡 Runbooks (incident, on-call, restore), architecture decision records, support inbox/flow (the contact form is mailto-only today — fine for now), status page.

---

## Launch gate — phased plan
- **Alpha (internal)**: P0 functional wiring + Docker + health + logging + basic tests. Closed group, no minors.
- **Private beta**: real OTP (DLT), rate limiting, token rotation, account deletion, block/report, privacy settings enforced, crash reporting, monitoring + alerts, backups, privacy policy/ToS, app store privacy forms. Invite-only, 18+.
- **Public GA**: minors flow + parental consent + CSAM scanning, moderation console, load-tested + autoscaling, staged rollout, on-call + SLOs, DR tested.

## Rough sequencing (not a commitment)
1. Operability & safety net: Docker/CI, health/logging/metrics, tests harness, error-handler fix.
2. Auth/security hardening + real OTP/DLT + rate limiting + token rotation.
3. Privacy/compliance: settings backend, account deletion/export, policies, consent, app-store forms.
4. Trust & safety: block/report/moderation + (for minors) CSAM scanning.
5. End-to-end wiring + UX states + realtime + push + media.
6. Scale & reliability: pagination/caching, load test, DR, autoscale.
7. Analytics, feature flags, staged GA rollout.

> Bottom line: the build is a credible MVP, but "live production with real users" is gated on **safety (minors/CSAM), security (auth/OTP/secrets), privacy/compliance (DPDP/DLT/erasure), operability (deploy/observe/backup), and quality (tests)** — in that order of risk.
