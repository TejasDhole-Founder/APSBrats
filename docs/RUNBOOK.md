# APSBrats API — Operations Runbook

What to check, in what order, when something is wrong. Written against the code as of 2026-11-10.

## 1. Severity

| Level | Meaning | Examples | Response |
|---|---|---|---|
| **SEV1** | App unusable for most users, or data at risk | API down, DB down, everyone logged out, data loss | Drop everything; fix or roll back now |
| **SEV2** | A core feature broken for many users | Can't post / chat / sign in; 5xx rate > 5% | Same day |
| **SEV3** | Degraded or one feature for some users | Slow feed, one screen erroring, push delays | Next working day |
| **SEV4** | Cosmetic | Wrong label, layout glitch | Backlog |

## 2. First five minutes

1. **Is it up?** `GET /actuator/health` → `{"status":"UP"}`. Readiness includes DB and Redis: `GET /actuator/health/readiness`.
2. **Which build is running?** `GET /actuator/info` → `build.version`, `build.time`. Compare with the last deploy; if the problem started with that deploy, **roll back first, debug second**.
3. **What are users seeing?** Every error body has `requestId`; every response has `X-Request-Id`. Ask the reporter for it (it's in the "ref:" of the app's error message).
4. **Find the request in the logs.** Each line: `time LEVEL [requestId] [userId] logger - message`.
   - qa/prod logs: stdout **and** `$LOG_DIR/api.log` (rotated daily / 50 MB, 30 days kept). `LOG_DIR` must be a mounted volume or the file dies with the container.
   - `grep <requestId> api.log` → the whole request. `grep <userId> api.log` → everything that user did.
5. **Write down** the start time, the symptom, and the requestIds. That becomes the incident note.

## 3. Known failure modes

| Symptom | Likely cause | What the app does | Fix |
|---|---|---|---|
| Many `503 SERVICE_UNAVAILABLE` "temporary problem" | **Redis down** | Reads keep working (token-revocation check and global rate limit fail open; circle cache recomputes). Sign-in, refresh, posting, chat, uploads (they need Redis) return 503 | Restart Redis. Log line: `Redis unavailable` / `Rate limit check skipped` / `Revocation check skipped` |
| Requests hang ~10 s then 500 `Connection is not available` | **DB pool exhausted** | HikariCP waits `connection-timeout` (10 s) | Check `Apparent connection leak` warnings (leak detection at 20 s) and `org.hibernate.SQL_SLOW` lines (queries > 100 ms). Raise `DB_POOL_SIZE` only after ruling out a leak |
| Users get `429 Too many requests` | Global limit (300/min per user, 60/min per IP before sign-in) or a per-action limit | Expected behaviour | If legitimate traffic: raise `RATE_LIMIT_USER_PER_MINUTE` / `RATE_LIMIT_IP_PER_MINUTE`. If **every** anonymous user is limited together, the proxy's IP isn't trusted (see §5) |
| Chat messages arrive only after refresh | WebSocket broker | One API instance holds all STOMP sessions | **Never run more than one API instance** until the RabbitMQ relay exists (QA report 3.7). Check the app shows "Reconnecting to chat…" |
| Users suddenly logged out | Refresh failing (Redis) or `revokeAllFor` | App clears the session when refresh is rejected | Check Redis; check for `logout-all` / account deletion in logs |
| `Rejected access token` warnings in bulk | Tampered/forged tokens, or a deploy changed `JWT_SECRET` | 401, app tries refresh | If after a deploy: secret changed → everyone must log in again (expected). Otherwise treat as an attack: check the IPs |
| Google sign-in returns 503 | `FIREBASE_CREDENTIALS_PATH` missing or wrong | Lazy init fails on first Google sign-in | Mount the service-account JSON and set the path |
| OTP never arrives | Email delivery not implemented (QA report 11.14) | Code only in server log (non-prod) | Known gap |

## 4. Routine jobs

- **Nightly 03:30 IST** (`MaintenanceJobs`): deletes OTP codes expired > 1 day and **read** notifications > 180 days. Log line: `Maintenance: removed …`. Override the time with `app.maintenance.cron`.
- **Account deletions** are recorded in `account_deletions` (user id, time, request id; no personal data).

## 5. Configuration that bites

| Setting | Default | Why it matters |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | dev | Must be `qa`/`prod` in containers (`DevProfileGuard` refuses to start otherwise). dev accepts OTP `000000` |
| `server.forward-headers-strategy` | native | Client IP comes from `X-Forwarded-For` **only** via a private-network proxy. Behind a public-IP proxy (e.g. Cloudflare), set `server.tomcat.remoteip.internal-proxies` to its ranges, or all users share one IP for rate limits |
| `DB_POOL_SIZE` | 10 | Enough for 1 000 concurrent users in the load test |
| Redis `maxmemory-policy` | volatile-lru (docker-compose) | Never use `allkeys-lru`: it can evict token-revocation markers |
| `SLOW_QUERY_MS` | 100 | Threshold for `org.hibernate.SQL_SLOW` log lines |

## 6. Releases

- Every build stamps `build.version` / `build.time` on `/actuator/info`.
- Flyway migrations run on start; current version: `select max(installed_rank), version from flyway_schema_history group by version order by 1 desc limit 1`.
- **Rollback:** redeploy the previous image. Flyway migrations are forward-only. If the bad release added a migration, the old code must still work with the new schema (all migrations so far only add things).

## 7. After an incident

Within two working days, add a short note to the QA report's known-issues list: what happened, when, impact (users, duration), cause, fix, and what stops it happening again.

## Not covered yet (needs outside services)

Monitoring dashboard and alerting (QA 18.1/18.2), crash reporting (5.10), DB backups and restore (4.19/15), log aggregation (5.13). Until they exist, someone has to look: health endpoint, `api.log`, user reports.
