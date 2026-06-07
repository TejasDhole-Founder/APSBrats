# APSBrats — Environments & Naming Conventions

Three environments, one consistent naming scheme so it's always obvious which
env you're touching. Read with `DEPLOYMENT.md`.

## Why this subdomain style
We use a **prefix** style (`dev-api`, `qa-api`, `api`) — all **single-level**
subdomains of `apsbrats.com`. Reason: Cloudflare's free Universal SSL covers
`apsbrats.com` and `*.apsbrats.com` (one level only). Nested names like
`api.dev.apsbrats.com` would need paid Advanced Certificate Manager. Prefixing
keeps every environment on free TLS.

## The map

| Concern | DEV | QA / Staging | PROD |
|---|---|---|---|
| Web / landing | `dev.apsbrats.com` | `qa.apsbrats.com` | `apsbrats.com` + `www.apsbrats.com` |
| API | `dev-api.apsbrats.com` | `qa-api.apsbrats.com` | `api.apsbrats.com` |
| Admin (future) | `dev-admin.apsbrats.com` | `qa-admin.apsbrats.com` | `admin.apsbrats.com` |
| Spring profile (`SPRING_PROFILES_ACTIVE`) | `dev` | `qa` | `prod` |
| Database name | `apsbrats_dev` | `apsbrats_qa` | `apsbrats_prod` |
| Redis (logical) | `apsbrats-redis-dev` | `apsbrats-redis-qa` | `apsbrats-redis-prod` |
| Host / service name | `apsbrats-api-dev` | `apsbrats-api-qa` | `apsbrats-api-prod` |
| Docker image tag | `apsbrats-api:dev-<sha>` | `apsbrats-api:qa-<sha>` | `apsbrats-api:<version>` (e.g. `1.2.0`) |
| Git branch → env | `develop` | `release/*` | `main` (tagged) |
| App flavor (Flutter) | `dev` | `staging` | `prod` |
| App bundle id | `com.apsbrats.app.dev` | `com.apsbrats.app.qa` | `com.apsbrats.app` |
| App display name | `APS Brats (Dev)` | `APS Brats (QA)` | `APS Brats` |
| Master OTP (`OTP_MASTER`) | `000000` | **blank** | **blank** |

## General resource convention
`apsbrats-<component>-<env>` — e.g. `apsbrats-api-qa`, `apsbrats-db-prod`,
`apsbrats-redis-dev`. Lowercase, hyphenated. Env is always the **last** token so
it sorts/greps cleanly.

## Promotion flow
```
code → DEV (auto-deploy from develop) → QA (deploy release/* ; test) → PROD (tag on main ; approve → deploy)
```
- Never test in prod. Never point a dev app at the prod API.
- Each env has its **own** database, Redis, secrets — never shared. A dev mistake
  must not be able to touch prod data.

## Secrets per env
Same variable **names**, different **values**, stored separately (Render env
groups / Cloudflare / a secret manager):
`DATABASE_URL, DB_USER, DB_PASSWORD, SPRING_DATA_REDIS_HOST, JWT_SECRET, OTP_MASTER`.
Generate a **unique** `JWT_SECRET` per env (`openssl rand -base64 48`). `OTP_MASTER`
is set only in dev.

## Flutter: build per env
```bash
# DEV
flutter run --dart-define=BASE_URL=https://dev-api.apsbrats.com/api -t lib/main_dev.dart
# QA
flutter build apk --release --dart-define=BASE_URL=https://qa-api.apsbrats.com/api -t lib/main_staging.dart
# PROD
flutter build appbundle --release --dart-define=BASE_URL=https://api.apsbrats.com/api -t lib/main_prod.dart
```
Use the bundle-id suffixes above so all three can be installed side-by-side on one phone, each with an env badge on the icon.

## Cloudflare DNS records to create (single level → free SSL)
```
apsbrats.com        -> landing (prod)        proxied
www                 -> landing (prod)        proxied
api                 -> apsbrats-api-prod      proxied
qa                  -> landing (qa)          proxied
qa-api              -> apsbrats-api-qa        proxied
dev                 -> landing (dev)          proxied
dev-api             -> apsbrats-api-dev       proxied
```
(Start with just `api` for prod-staging; add `qa-*`/`dev-*` when you split envs.)

## Rollout order (practical)
1. Stand up **one** environment now using `api.apsbrats.com` for private testing.
2. When you add CI/CD, introduce **QA** (`qa-api`) as the auto-deploy target and
   reserve `api` (prod) for tagged releases.
3. Add **DEV** (`dev-api`) only if you want a always-on integration sandbox
   separate from local Docker.
