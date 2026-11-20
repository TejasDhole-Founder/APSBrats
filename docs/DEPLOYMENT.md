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
  api.apsbrats.com    ─────────────▶  Spring Boot API  (Cloud Run / Render / VPS)
  media.apsbrats.com  ─────────────▶  Cloudflare R2 (uploaded photos)
                                          │
                                   Neon Postgres + Upstash Redis (or managed/compose)
  Flutter app  ──────── HTTPS ─────▶  https://api.apsbrats.com/api
```

Subdomains follow the env naming convention in `ENVIRONMENTS.md` (single-level
so Cloudflare's free `*.apsbrats.com` SSL covers them):
- `apsbrats.com` + `www.apsbrats.com` → landing (prod, already live)
- `api.apsbrats.com` → prod API · `qa-api.apsbrats.com` → QA · `dev-api.apsbrats.com` → dev
- `media.apsbrats.com` → R2 bucket (already live, see Part B.5)
- (future) `admin.apsbrats.com` / `qa-admin.apsbrats.com`

Start with **`api.apsbrats.com`** for your first environment — not `dev-api` —
even though this is still-developing code. The dev/qa/prod subdomain split is
for when you have *multiple* environments running at once; with only one
environment, use the plain name so you don't have to migrate DNS, `BASE_URL`,
and CORS later. Add the `qa-*` / `dev-*` records when you actually split
environments (see `ENVIRONMENTS.md`).

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

## Part B.5 — Media storage (Cloudflare R2)

The app defaults to storing uploaded photos on local disk (`LocalStorageService`).
That's fine for Part A/B above, but **wrong for Cloud Run or any host without a
persistent disk** — the filesystem resets on every restart and every uploaded
photo silently disappears. Switch to R2 (S3-compatible, same account as your
`apsbrats.com` Cloudflare zone) before deploying anywhere stateless.

1. **Dashboard → R2 Object Storage → Create bucket.** Name it `apsbrats-media`
   (or set `R2_BUCKET` to match whatever you pick). Location: Automatic.
2. **Bucket → Settings → Public access → Custom Domains → Connect Domain.**
   Enter `media.apsbrats.com` (same zone you already manage). Cloudflare adds the
   DNS record and issues the cert — don't use the `pub-*.r2.dev` dev URL for
   anything beyond a quick test; Cloudflare explicitly says not to rely on it.
3. **R2 → Manage R2 API Tokens → Create API Token.** Permissions: **Object
   Read & Write**, scoped to the `apsbrats-media` bucket only (not account-wide).
   Copy the **Access Key ID** and **Secret Access Key** — shown once.
4. Note your **Account ID** (right side of the R2 overview page).
5. Set these on the API service (Render/Cloud Run/wherever), **not** in git:
   ```
   STORAGE_TYPE=r2
   R2_ACCOUNT_ID=<from step 4>
   R2_ACCESS_KEY_ID=<from step 3>
   R2_SECRET_ACCESS_KEY=<from step 3>
   R2_BUCKET=apsbrats-media
   MEDIA_BASE_URL=https://media.apsbrats.com
   ```
   `MEDIA_BASE_URL` must be the exact custom domain from step 2 — the app checks
   every photo a user attaches against this prefix, so a mismatch makes uploads
   unusable, not just unreachable.
6. Redeploy, then confirm: upload a photo in the app and open the returned URL
   directly — it should load from `media.apsbrats.com`, not `/media/...`.

Existing local-disk uploads (if any, from Part A testing) are **not** migrated
automatically — copy them into the bucket by hand if they need to survive, or
accept they're test data and move on.

## Part B.6 — Deploy to Google Cloud Run (recommended for production)

This is the **recommended path** for getting `api.apsbrats.com` live.
Cost at idle: ~$0 with min-instances=1 (you pay for the one always-on instance;
~$5–10/month for a 512 MB instance). Services used: Cloud Run + Secret Manager
(both have free tiers or very low cost), Neon Postgres (serverless, free tier),
Upstash Redis (free tier), R2 (already live from Part B.5).

> **WebSocket constraint**: the app uses an in-process STOMP broker. Cloud Run
> must run with `min-instances=1` AND `max-instances=1` — otherwise connection
> state lives in one container and clients may land on another. Set both before
> traffic hits the service.

### Step 1 — GCP project setup (do this once)

1. Go to [console.cloud.google.com](https://console.cloud.google.com) → create a new project, e.g. `apsbrats-prod`.
2. Enable billing on the project (required for Cloud Run even for free-tier usage).
3. Enable these APIs — search each in the Console and click **Enable**:
   - Cloud Run API
   - Cloud Build API
   - Secret Manager API
4. Install the `gcloud` CLI if you don't have it:
   ```bash
   # Windows: download installer from cloud.google.com/sdk/docs/install
   gcloud init   # authenticate + select your project
   ```

### Step 2 — Store secrets in Secret Manager

Never put real credentials in Cloud Run's plain env vars — use Secret Manager.
Run these in your terminal (replace values with your real credentials):

```bash
# Set your project once
gcloud config set project apsbrats-prod

# Database
echo -n "jdbc:postgresql://ep-old-mode-az9i4o6y.c-3.ap-southeast-1.aws.neon.tech/neondb?sslmode=require" \
  | gcloud secrets create DATABASE_URL --data-file=-
echo -n "neondb_owner" | gcloud secrets create DB_USER --data-file=-
echo -n "YOUR_NEON_PASSWORD" | gcloud secrets create DB_PASSWORD --data-file=-

# Redis (Upstash — TLS required, use rediss:// host)
echo -n "<your-redis-host>.upstash.io" | gcloud secrets create REDIS_HOST --data-file=-
echo -n "6379" | gcloud secrets create REDIS_PORT --data-file=-
echo -n "YOUR_UPSTASH_PASSWORD" | gcloud secrets create REDIS_PASSWORD --data-file=-

# R2 media storage
echo -n "r2" | gcloud secrets create STORAGE_TYPE --data-file=-
echo -n "7f961c1e4b4df15451865422915dd89e" | gcloud secrets create R2_ACCOUNT_ID --data-file=-
echo -n "YOUR_R2_ACCESS_KEY_ID" | gcloud secrets create R2_ACCESS_KEY_ID --data-file=-
echo -n "YOUR_R2_SECRET_ACCESS_KEY" | gcloud secrets create R2_SECRET_ACCESS_KEY --data-file=-
echo -n "apsbrats-media" | gcloud secrets create R2_BUCKET --data-file=-
echo -n "https://media.apsbrats.com" | gcloud secrets create MEDIA_BASE_URL --data-file=-

# App secrets — generate a fresh one for prod
echo -n "$(openssl rand -base64 48)" | gcloud secrets create JWT_SECRET --data-file=-
# OTP_MASTER intentionally left blank in prod (blank = disabled)
```

> Tip: the values in `.env` have a `CLOUDRUN_` prefix to avoid docker-compose
> confusion — strip the prefix when creating the secrets above. The real
> values are in `C:\APSBrats\.env` (gitignored, never commit it).

### Step 3 — Grant Cloud Run access to secrets

```bash
# Get the Cloud Run service account email (shown in Console under Cloud Run → service → Security)
# or construct it: PROJECT_NUMBER-compute@developer.gserviceaccount.com
PROJECT_NUMBER=$(gcloud projects describe apsbrats-prod --format="value(projectNumber)")
SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

# Grant Secret Manager accessor role to every secret
for SECRET in DATABASE_URL DB_USER DB_PASSWORD REDIS_HOST REDIS_PORT REDIS_PASSWORD \
              STORAGE_TYPE R2_ACCOUNT_ID R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY \
              R2_BUCKET MEDIA_BASE_URL JWT_SECRET; do
  gcloud secrets add-iam-policy-binding $SECRET \
    --member="serviceAccount:${SA}" \
    --role="roles/secretmanager.secretAccessor"
done
```

### Step 4 — Connect GitHub to Cloud Run (continuous deployment)

1. In Cloud Run Console → **Create Service**.
2. Source: **Continuously deploy from a repository** → Connect to GitHub.
   - Authorize GCP to access your repo `TejasDhole-Founder/APSBrats`.
   - Branch: `main` (or `release/*` if you follow the env-naming guide).
   - Build type: **Dockerfile** → build context `apsbrat-api/`.
3. Service name: `apsbrats-api-prod`. Region: `asia-southeast1` (Singapore, close to Neon's `ap-southeast-1`).
4. **Container settings**:
   - Memory: **512 MiB** (increase to 1 GiB if you see OOM errors under load).
   - CPU: **1** (always allocated — required so the WebSocket broker stays live).
   - Request timeout: **300s**.
   - Concurrency: **80** (default).
5. **Scaling** (critical for WebSocket):
   - Min instances: **1**
   - Max instances: **1**
6. **Authentication**: Allow unauthenticated invocations (your Spring Security handles auth).

### Step 5 — Wire secrets as environment variables

In the Cloud Run service → **Edit & deploy new revision → Variables & Secrets**
tab → **Reference a secret**. Add each one:

| Env var name | Secret | Version |
|---|---|---|
| `DATABASE_URL` | `DATABASE_URL` | latest |
| `DB_USER` | `DB_USER` | latest |
| `DB_PASSWORD` | `DB_PASSWORD` | latest |
| `SPRING_DATA_REDIS_HOST` | `REDIS_HOST` | latest |
| `SPRING_DATA_REDIS_PORT` | `REDIS_PORT` | latest |
| `SPRING_DATA_REDIS_PASSWORD` | `REDIS_PASSWORD` | latest |
| `STORAGE_TYPE` | `STORAGE_TYPE` | latest |
| `R2_ACCOUNT_ID` | `R2_ACCOUNT_ID` | latest |
| `R2_ACCESS_KEY_ID` | `R2_ACCESS_KEY_ID` | latest |
| `R2_SECRET_ACCESS_KEY` | `R2_SECRET_ACCESS_KEY` | latest |
| `R2_BUCKET` | `R2_BUCKET` | latest |
| `MEDIA_BASE_URL` | `MEDIA_BASE_URL` | latest |
| `JWT_SECRET` | `JWT_SECRET` | latest |

Add these as **plain** env vars (not secrets — they're not sensitive):

| Env var | Value |
|---|---|
| `SPRING_PROFILES_ACTIVE` | `prod` |
| `SPRING_DATA_REDIS_SSL_ENABLED` | `true` |
| `SPRING_FLYWAY_BASELINE_ON_MIGRATE` | `false` |
| `SERVER_PORT` | `8080` |

### Step 6 — Deploy and verify

Click **Deploy**. Cloud Run builds from your Dockerfile and deploys. Watch the build
logs in Console → Cloud Build → History.

Once green, hit the auto-assigned Cloud Run URL:
```bash
curl https://YOUR-SERVICE-URL.run.app/api/schools
```
You should get a JSON list of schools. If Flyway migrates successfully you're live.

To see logs: Console → Cloud Run → `apsbrats-api-prod` → **Logs** tab.
OTPs appear here until real SMS is wired.

### Step 7 — Map `api.apsbrats.com`

1. Cloud Run Console → `apsbrats-api-prod` → **Domain mappings** → **Add mapping**.
2. Enter `api.apsbrats.com`. GCP gives you DNS records to add.
3. In Cloudflare → DNS → add the `CNAME` record GCP specifies, **Proxied (orange cloud)**.
4. Wait ~5 minutes for cert provisioning. Then:
   ```bash
   curl https://api.apsbrats.com/api/schools
   ```

### On push deploys

Every push to `main` triggers a Cloud Build that rebuilds and redeploys. No
manual steps — just `git push origin main` and the service updates in ~3–4
minutes.

To roll back: Console → Cloud Run → **Revisions** → select a previous revision →
**Manage traffic** → send 100% to it.

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

### Web app (iPhone and Android browsers, installable from Safari / Chrome)
The same Flutter code builds a web app. Host it on its own Cloudflare Pages project at `app.apsbrats.com`; `apsbrats.com` stays the landing site.

1. Build: `flutter build web --release --dart-define=BASE_URL=https://api.apsbrats.com/api/v1 --dart-define=WS_URL=wss://api.apsbrats.com/ws` (run in `frontend/`). The URL strategy is clean paths, so the host must rewrite every path to `index.html`: `frontend/web/_redirects` does this on Cloudflare Pages, and `frontend/web/_headers` sets cache and security headers. Both are copied into `build/web`.
2. Deploy `frontend/build/web` to a new Pages project (direct upload or connect the repo with the build command above), then add the custom domain `app.apsbrats.com`.
3. The qa and prod API allow `https://app.apsbrats.com` by default (browser calls and the `/ws` socket). To allow other origins, set `CORS_ALLOWED_ORIGINS` (comma-separated) on the host (Render or Cloud Run); it replaces the default, so include the app address in it. Browser calls from any other origin get 403 "Invalid CORS request".
4. Sign-in on the web is the email code only: the Google button is hidden when `kIsWeb`. To enable it later you need a Firebase web app config in `main.dart` and a Google web client ID in `web/index.html`, then add `app.apsbrats.com` to Firebase Auth authorized domains.
5. Cloud Run: set memory to `1Gi` (`--memory 1Gi`). The image starts the JVM with `-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError`, so the heap follows the limit and an out-of-memory process exits and Cloud Run starts a new instance. `docker-compose.yml` has the same limit and `restart: unless-stopped` for local and VPS use.
6. Test builds with "Skip login (dev)": add `--dart-define=DEV_LOGIN=true` to the build. The button signs in as the seeded demo user with the universal OTP `000000`, so the API behind it must run the `dev` profile (or `qa` with `OTP_MASTER=000000`) and hold throwaway data only: anyone could log in as any account there. The `prod` API always refuses the universal OTP. Never set this flag on a build that points at real users.
7. Not done: web push notifications, a 180 px `apple-touch-icon` (the 192 px icon is used), and the Android Play Store listing.

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
