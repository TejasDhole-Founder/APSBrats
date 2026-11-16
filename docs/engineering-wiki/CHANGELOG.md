# Changelog

Important technical and architectural changes, newest first. One short entry per change. Add to this file whenever you change architecture, an API contract, the schema, or a significant behaviour (see [README.md](README.md)).

## Unreleased: work from the 2026-11-14 to 2026-11-16 sessions (not committed yet)

Also found uncommitted in the working tree (origin not recorded in this wiki): V38 (`users.state`, `country`, `latitude`, `longitude`, `place_id`), the `places` package (Geoapify city autocomplete and reverse geocode), the onboarding location lookup and DOB picker (`frontend/lib/core/location/`, `dob_picker_sheet.dart`), a login/splash/app-icon refresh with new brand assets, the actuator and Prometheus dependencies, and a rewritten `docs/DEPLOYMENT.md`.

Backend (`apsbrat-api`)
- **Connections redesigned (V39):** one row per user pair (`user_low_id`/`user_high_id`), `requested_at`, `connection_events` history, advisory lock per pair in every state change, reverse request auto-accepts, `created_at` is no longer reset on re-request, `BlockService` now ends connections through `ConnectionService.endForBlock`. V39 backfills pairs and history from old rows, merges any pair stored twice (keeps the accepted/latest row, moves history and notification links), drops `uq_connection` and the single-column connection indexes. **Not backward compatible with the previous app version.** [06](06-database.md), [connections](03-features/connections-and-blocking.md), decision D8.
- **Read side split:** `ConnectionQueryService` (lists, status, mutual, history). New endpoints: `GET /connections/page`, `/connections/pending/page`, `/connections/sent/page`, `/connections/{id}/mutual/count`, `/mutual/page`, `/history`. `POST /connections/{id}` now returns `{status: PENDING|ACCEPTED}`. Existing endpoints unchanged (the app still uses the legacy list endpoints).
- **V40:** partial indexes for pending requests (`idx_conn_pending_incoming`, `idx_conn_pending_outgoing`); 36.8 ms -> 0.43 ms for 6,000 waiting requests in a local 2M-row test. Decision D10.
- **Connection lists** load both users in one query (fixes N+1 in the legacy lists).
- **Communities:** `GET /communities/mine/chats` (last message and unread per joined community) and `requested` list in `MyCommunitiesDto` (for the Requested filter).
- **Profile:** removed `batchmatesCount` from `ProfileDto` (it was just the connected count).
- **Dev-only metrics:** `app.actuator.public-metrics` opens `/actuator/prometheus` and `/actuator/metrics` in the dev profile only; dev also records latency histograms. Decision D18.

Frontend (`frontend`)
- **Social tab:** Messages and Communities merged into one "Social" tab with a segmented control; unified chat list (All, Direct, Groups, Unread), quick row with online friends.
- **Communities UI:** new school cards and Discover list, "Your Communities" screen (All/Joined/Requested/Owned, menu with Open/Leave), APS Patiala banner as the school cover, round badge removed from school views.
- **Community page header:** verified check, meta line (kind | members), avatar stack with "+N members", tabs with icons, share prompt with image/video/article icons, Latest/Popular toggle styling. The online count was removed from the header.
- **Icons:** all Material icons replaced by `hugeicons` (`AppIconData` typedef). Decision D17. Liked/unliked heart now differs only by colour.
- **Profile:** removed the Batchmates stat and the "mutual batchmates" row and sheet.
- **Tests:** icon finders now use `test/hugeicon_finder.dart`; added `connection_contract_test.dart` with fixtures recorded from a real server run (`test/fixtures/connections/`).

Tests (backend)
- Added `ConnectionFlowTest` (29 tests including races across threads), `ConnectionMigrationTest` (V39 on old-style data, including duplicate pairs), `UserPairTest`. Also verified two separate API instances on one Postgres (not part of the suite): opposite requests, double accept, accept vs withdraw, request vs block: all consistent.

Tooling
- `tools/api_dashboard.py`: local dashboard for request counts, latency percentiles, database call timings, pool, memory and optional Postgres statistics.
- This engineering wiki (`docs/engineering-wiki/`).

## Recent commits (from git; not the full history)

| Date | Commit | Change |
|---|---|---|
| 2026-11-10 | `168d987` | Untrack local-disk test uploads, gitignore `media/` |
| 2026-11-10 | `7f7cfdb` | Community events and chat, career history, security and performance hardening pass |
| 2026-09-27 | `f979c8a` | Chat rebuilt on REST + STOMP WebSocket, email and Google login, UI refresh |
| 2026-09-04 | `d6cda9b`, `7b8a000` | Auth and profile page changes |
| 2026-08-29 | `9de5e77`, `7bd3ede`, `8e4269b` | Android fix, merge of PR 1, early work |
