# Current State

A snapshot of the project right now. Refresh this file whenever the state changes materially (a release, a migration applied, a risk fixed). Detail lives in [12](12-current-status-technical-debt.md).

Snapshot date: 2026-11-16 (commit 168d987 from 2026-11-10, plus uncommitted work)

## Code and version control

- Last commit: `168d987` (2026-11-10). All work from the 2026-11-14 to 2026-11-16 sessions is **uncommitted**: see the "Unreleased" entry in [CHANGELOG.md](CHANGELOG.md).
- Untracked files that tracked code already depends on: migrations V38, V39, V40; `ConnectionQueryService`, `UserPair`, `ConnectionEvent*`; the `places/` package; `frontend/lib/core/location/`, `core/theme/app_icons.dart`, `my_communities_screen.dart`, `dob_picker_sheet.dart`; new image assets. A checkout of `168d987` does not compile or start. Also untracked: the new tests, `tools/`, the root `README.md` and this wiki.
- Uncommitted edits to existing files include `docs/DEPLOYMENT.md` (contains an Upstash hostname: replace it with a placeholder before committing) and `.claude/settings.local.json`.
- Untracked files that must not be committed: `local_dump.sql`, `clean_dump.sql` (database dumps; not in `.gitignore`).
- Old docs under `docs/` and `BACKEND_NOTES.md` are partly stale (list in [12 section 10](12-current-status-technical-debt.md)).

## Database

- Migrations in the repo: V1 to V40 (Flyway, `apsbrat-api/src/main/resources/db/migration`).
- Local dev database (docker container `apsbrats-db-1`): applied up to **V38** as of 2026-11-15. V39 and V40 have been applied only to throwaway databases and tested there (including against a copy of the local data); they apply on the next backend start. Back up first: V39 merges and deletes duplicate connection rows and locks `connections` while it runs.
- qa and prod: UNVERIFIED (no deployment evidence in the repo).

## Tests (last known)

| Suite | Result | Notes |
|---|---|---|
| Backend (`mvn test`, Docker tests enabled, `ApiApplicationTests` excluded) | 95 passed, 0 failed | `ApiApplicationTests` needs `postgres:16-alpine`/`redis:7-alpine` images and is skipped when Docker is not set up. Windows flags: [10 section 7](10-development-guide.md) |
| Flutter (`flutter test`) | 88 passed, 18 failed | The 18 were already failing before the recent work (stale expectations); see [testing.md](testing.md). CI's frontend job would fail on them |

## What exists

Feature status table: [00 section 2](00-project-overview.md). Short version: auth (Google works, email OTP delivery missing), onboarding, profile and career, communities with events and memories, posts with photos, likes and comments, Home feed, connections with history and blocking, DMs and group chat with push, people search, in-app notifications, moderation API. No push notifications, no admin UI, no post editing. The Flutter app also builds for the web (clean URLs, login guard, email-code sign-in only; deploy steps in `docs/DEPLOYMENT.md` Part D); not yet deployed or tried on a real phone.

## Local tooling

`tools/api_dashboard.py`: live API and database analytics for a locally running dev API ([10](10-development-guide.md)). `tools/ws_load.py`: 1000-socket chat load test with its own live dashboard. The dev profile exposes `/actuator/metrics` and `/actuator/prometheus` and records latency histograms (`app.actuator.public-metrics`, dev only).

## Highest-priority open items

1. Email OTP delivery and removal/guarding of the demo seed before any real deployment.
2. `reinstateUser` admin check; block/discoverable/ban checks on remaining read paths.
3. Account deletion completeness.
4. Decide Redis failure policy; guard `IdempotencyFilter`.
5. Fix the failing Flutter tests so CI is a real gate; commit V38 to V40 (after review) and keep dumps out of git.

Full prioritised list with file references: [12](12-current-status-technical-debt.md).
