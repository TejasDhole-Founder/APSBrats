# Engineering Wiki Index

Where to find what. Start with [00](00-project-overview.md) for the big picture and [CURRENT-STATE.md](CURRENT-STATE.md) for where things stand today.

## Core documents

| Doc | What it answers |
|---|---|
| [README.md](README.md) | What this wiki is and the rules for keeping it correct |
| [CURRENT-STATE.md](CURRENT-STATE.md) | What is committed, migrated, tested and risky right now |
| [CHANGELOG.md](CHANGELOG.md) | Important technical and architectural changes over time |
| [00-project-overview.md](00-project-overview.md) | What the app does, features and status, stack, architecture diagram, repo map |
| [01-system-architecture.md](01-system-architecture.md) | Responsibilities, component communication, request lifecycle, data flows, infrastructure |
| [02-technology-stack.md](02-technology-stack.md) | Every major library and service: where used, what it does |
| [03-features/](03-features/README.md) | End-to-end flow of every user action, per feature |
| [04-backend-engineering.md](04-backend-engineering.md) | Spring Boot layers, filters, data access, caching, jobs, errors, logging, "where to look for X" |
| [05-frontend-engineering.md](05-frontend-engineering.md) | Flutter structure, routing, state, Dio and token refresh, storage, realtime, widgets, tests |
| [06-database.md](06-database.md) | Tables, keys, indexes, relationships, lifecycle, migrations, time zones |
| [07-authentication-security.md](07-authentication-security.md) | Login flows, JWT, roles, API protection, rate limits, validation, security gaps |
| [08-infrastructure-deployment.md](08-infrastructure-deployment.md) | Hosting evidence, environments and env vars, CI, deployment, monitoring, limits |
| [09-integrations.md](09-integrations.md) | Firebase, Google sign-in, R2, Geoapify, Redis, push state |
| [10-development-guide.md](10-development-guide.md) | Setup, running, seeding, tests, build, troubleshooting |
| [11-technical-decisions.md](11-technical-decisions.md) | Decisions with reasons, alternatives, trade-offs, when to reconsider |
| [12-current-status-technical-debt.md](12-current-status-technical-debt.md) | Known bugs, limits, risks, debt, documentation drift, open questions |
| [testing.md](testing.md) | Test architecture, what exists, what fails, what is not covered |

## Feature files

[auth-and-sessions](03-features/auth-and-sessions.md) · [profile-career-schools](03-features/profile-career-schools.md) · [posts-comments-likes](03-features/posts-comments-likes.md) · [communities](03-features/communities.md) · [feed-search-discovery](03-features/feed-search-discovery.md) · [connections-and-blocking](03-features/connections-and-blocking.md) · [messaging](03-features/messaging.md) · [notifications-and-moderation](03-features/notifications-and-moderation.md)

## "I want to..." shortcuts

| I want to | Go to |
|---|---|
| Understand what happens when a user taps something | the feature file, then [04](04-backend-engineering.md) section 11 for code locations |
| Run the project locally | [10](10-development-guide.md) |
| Change the schema | [06](06-database.md) (migration rules), then add a CHANGELOG entry |
| Know whether a feature exists | [00 section 2](00-project-overview.md) and the "Not implemented" list in [12](12-current-status-technical-debt.md) |
| Know why something was built that way | [11](11-technical-decisions.md) |
| See what could go wrong in production | [12 section 1](12-current-status-technical-debt.md) |

## Older documents (not part of the wiki, partly stale)

`docs/API.md`, `docs/BACKEND.md`, `docs/DATABASE.md`, `docs/FRONTEND.md`, `docs/DEPLOYMENT.md`, `docs/ENVIRONMENTS.md`, `docs/RUNBOOK.md`, `docs/PERFORMANCE.md`, `docs/PRODUCTION-READINESS.md`, `docs/PRODUCT_GAP_REPORT.md`, `docs/QA_AUDIT_REPORT.md`, `docs/ROADMAP.md`, `docs/auth-course/`, `docs/chat-course/`, `docs/communities-course/`, `docs/conventions/error-handling.md` (still the error-handling rule), `docs/design-handoff/`, `BACKEND_NOTES.md`, `apsbrat-api/README.md`, `frontend/README.md`. Where they disagree with the code, the code and this wiki win; the discrepancies are listed in [12 section 10](12-current-status-technical-debt.md).
