# APS Brats Engineering Wiki

The project's technical memory: how it works, where the code is, why it was built that way, and what is still wrong. Written to be read after months away. Navigation: [INDEX.md](INDEX.md).

## Rules for this wiki

1. **Verified, not assumed.** Every statement was checked against the code (file paths, classes, endpoints, tables). Anything not confirmed is marked `UNVERIFIED:`. Implemented and planned are never mixed: missing features are listed under "Not implemented".
2. **Concise.** Explain why, not obvious programming. No source dumps. Diagrams (Mermaid) for complex flows.
3. **No secrets.** Environment variable names only, never values, keys, passwords or tokens.
4. **Every doc has a "Last verified" line** (date and commit). Update it when you re-check the file.
5. **Code wins.** If this wiki and the code disagree, fix the wiki in the same change.

## When to update what (part of the task, not optional)

| You changed | Update |
|---|---|
| A user flow, screen or business rule | the matching file in `03-features/`; [00 section 2](00-project-overview.md) if feature status changed |
| An endpoint, request/response or error behaviour | the feature file, [04](04-backend-engineering.md) or [05](05-frontend-engineering.md) |
| The schema or a migration | [06](06-database.md), the feature file, [CHANGELOG.md](CHANGELOG.md) |
| Auth, permissions, limits, validation | [07](07-authentication-security.md) |
| Architecture, a library or a service | [01](01-system-architecture.md), [02](02-technology-stack.md) or [09](09-integrations.md) |
| Environment, CI, deployment, hosting | [08](08-infrastructure-deployment.md), [10](10-development-guide.md) |
| A significant decision | add an entry to [11](11-technical-decisions.md) |
| A bug fixed or found, a limitation, a risk | [12](12-current-status-technical-debt.md) and [CURRENT-STATE.md](CURRENT-STATE.md) |
| Tests added, removed or failing | [testing.md](testing.md) |

Update only the affected sections. Always add a line to [CHANGELOG.md](CHANGELOG.md) for architectural or contract changes, and remove text that is no longer true.

## Conventions

- Paths are relative to the repository root. Backend source root: `apsbrat-api/src/main/java/com/apsconnect/api/` (written `api/`).
- Tags in [12](12-current-status-technical-debt.md): `[re-verified]`, `[audit]`, `UNVERIFIED`, `measured`.
- Feature docs use a fixed 12-point template per action (user action, frontend, state, API, backend, database, response, UI, other users, failure handling, concurrency, security).
