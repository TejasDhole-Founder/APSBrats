# APS Brats

A social network for alumni and students of Army Public Schools: sign in, add the schools and years you attended, then find classmates and schoolmates, join school communities, share photo posts, go to events, and chat.

- **App:** Flutter (`frontend/`), Riverpod, go_router, Dio.
- **API:** Spring Boot 3.2.5 on Java 17 (`apsbrat-api/`), PostgreSQL 16 with Flyway, Redis, STOMP WebSocket for chat push, media on Cloudflare R2 or local disk.

## Documentation

All technical documentation lives in the engineering wiki:

- Start here: [docs/engineering-wiki/INDEX.md](docs/engineering-wiki/INDEX.md)
- Run it locally: [docs/engineering-wiki/10-development-guide.md](docs/engineering-wiki/10-development-guide.md)
- What exists and what is risky today: [docs/engineering-wiki/CURRENT-STATE.md](docs/engineering-wiki/CURRENT-STATE.md)

Project rules for contributors and the AI assistant are in `CLAUDE.md`. Older files under `docs/` are partly stale; the wiki is the source of truth.
