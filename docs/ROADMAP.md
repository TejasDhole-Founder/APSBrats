# APSBrats — What's left to build (prioritised)

Audit of the current repo. ✅ done · 🟡 partial · ❌ missing.

## Snapshot
- Backend modules (auth, users, schools, connections, feed, communities, chat, notifications, search, profile): ✅ built
- Flutter data layer (models/repos/providers) + login: ✅ built
- Marketing site + brand/logo/icons: ✅ built
- Docs (API, DB, backend, frontend, performance): ✅ built
- **Posts (user-generated content): ❌ still a placeholder**
- **Realtime chat: ❌ REST-only (no WebSocket)**
- **Push notifications (FCM): ❌ token field exists, nothing sends**
- **Image/profile-pic upload: ❌ `profilePicUrl` exists, no upload endpoint/storage**
- **Privacy settings: ❌ UI toggles exist, no backend (`user_settings`)**
- Infra (Docker, CI, health, API docs, metrics): ❌ none
- Tests: 🟡 only the two generated stubs
- Redis: 🟡 configured but unused

---

## P0 — Make the app work end-to-end
1. **Wire Flutter widgets to the providers** — screens still read `dummy_data.dart`; connect home/batch/messages/profile/communities/search/notifications and delete the dummy file. Add loading/empty/error states (FRONTEND.md §10).
2. **Realtime chat** — add Spring WebSocket/STOMP (starter already in pom) so DMs + community messages push live instead of polling. Client lib `socket_io_client` is already in pubspec.
3. **Push notifications** — wire FCM: register `fcm_token` on login, send on new message / connection request / batchmate join.
4. **Image upload** — `POST /api/users/{id}/avatar` to object storage (S3/GCS/Cloudinary) → set `profile_pic_url`. Needed for real profiles.
5. **Posts** (only if the product wants user-generated posts beyond the system feed) — implement the `post` module: entity, create/list/like, feed integration.

## P1 — Production readiness (system design)
1. **Containerise** — `Dockerfile` for the API + `docker-compose.yml` (api + postgres + redis) for one-command local/prod parity.
2. **CI/CD** — GitHub Actions: build + test on PR, image build/publish, optional deploy.
3. **API docs** — add `springdoc-openapi` → Swagger UI at `/swagger-ui` so the contract is self-documenting.
4. **Observability** — Spring Boot Actuator (`/health`, `/metrics`), structured JSON logging, Micrometer→Prometheus/Grafana, error tracking (Sentry/GlitchTip).
5. **Use Redis for real** — it's wired but idle. Move OTP storage + rate-limit counters + refresh-token blacklist + `PersonDto`/community caching into it.
6. **Config/secrets** — externalise `JWT_SECRET`, DB creds; confirm `app.otp.master` is empty in prod; add a `.env`/secret-manager story.

## P2 — Security hardening
1. **OTP abuse protection** — per-phone rate limit, max attempts + lockout, resend cooldown (Redis-backed). Today OTP can be brute-forced.
2. **Refresh-token rotation + revocation** — rotate on use, blacklist on logout; currently a refresh token is valid until expiry.
3. **Privacy enforcement** — back the Settings toggles (show phone, profile visibility "batchmates only", profile-view tracking) with a `user_settings` table and enforce in profile/search responses.
4. **Message content safety** — sanitise/escape message bodies (stored XSS), basic spam/abuse checks.
5. **Transport & headers** — enforce HTTPS, lock CORS to prod origins, add security headers.

## P3 — Data & scale (see PERFORMANCE.md)
1. **Paginate message lists** — `/conversations/{id}/messages` and community messages currently return everything. Most important data fix.
2. **DM inbox** — denormalise last-message + batch unread counts (PERFORMANCE.md A/B).
3. **Search** — move from `LIKE`/trigram to Postgres full-text (`tsvector`) or a search index as data grows.
4. **Backups + pooling** — automated DB backups, Hikari tuning, read replica path for later.

## P4 — Testing & quality
1. Backend: unit + integration tests with **Testcontainers** (real Postgres), controller + security tests. Right now there's effectively no coverage.
2. Flutter: widget/unit tests for repositories and key screens; golden tests for the brand UI.
3. Contract tests so FE/BE DTOs can't drift.

## P5 — AI / RAG opportunities (optional, value-add — do after P0–P2)
RAG isn't core to an alumni network, but a few AI features fit well and reuse the existing Postgres:
1. **Semantic people/community search** (highest value) — add `pgvector`, embed profiles (name, schools, city, profession, bio) and support natural-language queries like *"someone from my Pune batch now in tech in Bangalore."* This is mostly embeddings + retrieval, not heavy generation.
2. **Alumni assistant (true RAG)** — retrieve over the user's network + the 137-school directory and answer *"who from 12A is in Bengaluru?"* or app-help questions, with an LLM and strict scoping to what the user is allowed to see.
3. **Auto-generated "memory" nudges** — the nostalgia cards ("you left APS Patiala 3 years ago") are hard-coded; generate personalised, varied prompts.
4. **Moderation** — LLM/classifier to flag spam/abuse in DMs and community chat before it spreads.
5. **Connection suggestions** — embeddings + school-history overlap to recommend likely batchmates.

Prereqs for any of these: `pgvector` on the existing DB, an inference provider, privacy guardrails (never retrieve beyond a user's visibility), and cost/rate controls. Start with #1 — it's the most defensible and the least "chatbot gimmick."

---

## Suggested order
P0 (usable app) → P1 (shippable/operable) → P2 (safe) → P3 (scales) → P4 (trustworthy) → P5 (smart).
