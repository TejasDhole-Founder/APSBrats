# APSBrats — Deployment Guide (dev + live staging)

You have: a **Cloudflare account**, the domain **apsbrats.com**, and the landing
site already live at **www.apsbrats.com**. This guide takes you from there to a
running backend + app, step by step.

> ⚠️ Keep this a **private/staging** launch (you + trusted testers, no real or
> under-18 users) until the 🔴 blockers in `PRODUCTION-READINESS.md` are closed.

---

## Target architecture

```
                    Cloudflare (DNS + TLS + WAF + cache)
  apsbrats.com / www  ─────────────▶  Landing site  (Cloudflare Pages)
  api.apsbrats.com    ─────────────▶  Spring Boot API  (Render / VPS)
                                          │
                                   Postgres + Redis (managed or compose)
  Flutter app  ──────── HTTPS ─────▶  https://api.apsbrats.com/api
```

Subdomains follow the env naming convention in `ENVIRONMENTS.md` (single-level
so Cloudflare's free `*.apsbrats.com` SSL covers them):
- `apsbrats.com` + `www.apsbrats.com` → landing (prod, already live)
- `api.apsbrats.com` → prod API · `qa-api.apsbrats.com` → QA · `dev-api.apsbrats.com` → dev
- (future) `admin.apsbrats.com` / `qa-admin.apsbrats.com`

Start with **`api.apsbrats.com`** for your first private environment; add the
`qa-*` / `dev-*` records when you split environments (see `ENVIRONMENTS.md`).

---

## Part A — Run everything locally (do this first)

Prereqs: Docker Desktop.

```bash
cp .env.example .env          # then edit values (set a strong JWT_SECRET)
docker compose up --build      # or: make up
```
- API → http://localhost:8080/api  (try `GET /api/schools`)
- Postgres → localhost:5432, Redis → localhost:6379
- Flyway runs all migrations + seeds demo data on first boot.
- Demo login: phone `919999000001`, OTP `000000`.

`make logs` to tail, `make down` to stop, `make psql` for a DB shell.
This is your dev environment for "everything" — backend, DB, cache, in one command.

---

## Part B — Put the backend live

Pick ONE. **Option 1 (Render) is the fastest for now.**

### Option 1 — Render (managed, recommended for staging)
1. Push the repo to GitHub (see `aps-brats-website/PUSH-TO-GITHUB.md` pattern; for the API push the whole `apsbrat-api` project).
2. On render.com → **New → Postgres** (free/cheap). Note its Internal Database URL.
3. **New → Key Value (Redis)**. Note its host.
4. **New → Web Service** → connect the repo → root = `apsbrat-api` → it auto-detects the `Dockerfile`.
5. Set environment variables on the service:
   - `SPRING_PROFILES_ACTIVE=prod`
   - `DATABASE_URL` = the Postgres connection string (Render gives `postgresql://...`; Spring needs `jdbc:postgresql://...` — prefix with `jdbc:`)
   - `DB_USER`, `DB_PASSWORD` = from the Render DB
   - `SPRING_DATA_REDIS_HOST`, `SPRING_DATA_REDIS_PORT` = from Render Redis
   - `JWT_SECRET` = `openssl rand -base64 48`
   - `OTP_MASTER` = (leave blank — disables the dev master OTP)
   - `SPRING_FLYWAY_BASELINE_ON_MIGRATE=false`  (fresh DB → run all migrations)
6. Deploy. Confirm the Render URL responds at `/api/schools`.
7. (Until real SMS is wired, OTP is printed in the service **Logs** — use that to log in during testing.)

### Option 2 — Your own VPS + Cloudflare Tunnel (more control, cheap)
Good if you want one box running the `docker-compose.yml`, with **no open ports**.
1. Get a small VPS (Hetzner/DigitalOcean, 2 GB+). Install Docker + Compose.
2. `git clone` the repo, `cp .env.example .env`, set strong secrets, **remove `OTP_MASTER`**.
3. `docker compose up -d --build`.
4. Install `cloudflared`, then:
   ```bash
   cloudflared tunnel login
   cloudflared tunnel create apsbrats
   # route the hostname to the local API:
   cloudflared tunnel route dns apsbrats api.apsbrats.com
   ```
   Config (`~/.cloudflared/config.yml`):
   ```yaml
   tunnel: <tunnel-id>
   credentials-file: /root/.cloudflared/<tunnel-id>.json
   ingress:
     - hostname: api.apsbrats.com
       service: http://localhost:8080
     - service: http_status:404
   ```
   `cloudflared tunnel run apsbrats` (install as a service to keep it up).
   Tunnel handles TLS + DNS; you never expose port 8080 publicly.

---

## Part C — Cloudflare configuration

### DNS
- Dashboard → **apsbrats.com → DNS → Records**.
- Landing (already live): `apsbrats.com` + `www` → your Pages project (Pages adds these automatically when you add the custom domain).
- API:
  - **Render**: add `CNAME  api  →  your-service.onrender.com`, **Proxied (orange cloud)**.
  - **Tunnel**: the `route dns` command already created the `api` record.

### SSL/TLS
- **SSL/TLS → Overview → Full (strict)**. (Render and Tunnel both present valid certs; "Flexible" is insecure — don't use it.)
- Enable **Always Use HTTPS** and **HSTS** (after you confirm HTTPS works).

### Don't cache the API
- **Rules → Cache Rules**: for `api.apsbrats.com/*` → **Bypass cache**. (Caching API JSON will break auth/responses.)

### Protect the API at the edge (cheap wins)
- **Security → WAF**: enable Managed Rules.
- **Security → Rate limiting**: add a rule on `api.apsbrats.com/api/auth/*` (e.g., 5 requests/min/IP) — your first line against OTP abuse until app-level limits exist.
- **Bots**: turn on Bot Fight Mode.

### Landing site (tidy-up)
- If not already: connect the `aps-brats-website` GitHub repo to **Cloudflare Pages** for auto-deploy on push.
- Add a redirect so the apex and www agree (e.g., `apsbrats.com` → `https://www.apsbrats.com`).

---

## Part D — Point the app + landing at the API

### Flutter app
Build against the live API:
```bash
flutter run   --dart-define=BASE_URL=https://api.apsbrats.com/api -t lib/main_dev.dart
# release build for internal testing:
flutter build apk --release --dart-define=BASE_URL=https://api.apsbrats.com/api -t lib/main_prod.dart
```
Distribute via **Play Console → Internal testing** and **TestFlight** — NOT a public store release yet (see the safety gate).

### Landing site
The "Get the app" buttons currently link to `#get`. Once you have store/testing links, update them in `index.html`. The contact form already emails `tejasdhole.work@gmail.com`.

---

## Part E — Before you let anyone real in

These are the minimum operational guardrails even for a private staging:
- [ ] Strong `JWT_SECRET` set; `OTP_MASTER` blank in prod.
- [ ] Managed Postgres with **automated backups** on (Render does this; on VPS add `pg_dump` cron + offsite copy).
- [ ] Cloudflare **rate limit** on `/api/auth/*` (cost + abuse).
- [ ] HTTPS everywhere, Full (strict).
- [ ] Basic uptime check (Cloudflare Health Checks or UptimeRobot on `/api/schools`).
- [ ] A real **SMS/OTP provider + TRAI DLT** registration before any non-tester signs up.
- [ ] Keep it invite-only and **18+** until minors/privacy/safety blockers are done.

---

## Quick reference
```bash
# local
make up            # build + run everything
make logs          # tail API logs (read OTP codes here)
make down

# secrets
openssl rand -base64 48     # JWT_SECRET

# health
curl https://api.apsbrats.com/api/schools
```

## Recommended next step
Do **Part A** (local compose) today, then **Option 1 (Render)** + **Part C** to get
`api.apsbrats.com` live and private. That gives you a real dev/staging environment
to build the remaining roadmap against, without exposing real users yet.
