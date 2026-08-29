# APSBrats — Project Rules

## Stack
Flutter (Dart) · Spring Boot 3.2.5 · PostgreSQL · Riverpod · go_router

## Flutter conventions
- State: Riverpod — `ConsumerStatefulWidget` / `ConsumerWidget` / `StateNotifier`
- Navigation: go_router — `context.go()` only, never `Navigator.push`
- Deprecations to avoid: `withOpacity()` → `withValues(alpha:)` · `DropdownButtonFormField value:` → `initialValue:`
- No mock data — all screens hit the real API

## Color palette (memorize — do not look up)
```
AppColors.crimson      = Color(0xFF7B1414)
AppColors.crimsonDark  = Color(0xFF5C0F0F)
AppColors.crimsonMuted = Color(0xFFB44040)
AppColors.gold         = Color(0xFFD4A84A)
AppColors.cream        = background
```

## Onboarding flow
Steps: **Profile (1) → Verify (2) → Schools (3) → Socials (4)**

Every onboarding screen uses `OnboardingFrame`:
```dart
OnboardingFrame(
  step: N,
  title: '...',        // last word renders gold automatically
  subtitle: '...',
  headerAction: ...,   // optional — appears top-right of logo row
  child: ...,          // content below header
  footer: ...,         // pinned below child
)
```

Provider: `onboardingFlowProvider` (`OnboardingFlowState`)
Fields: `firstName, lastName, username, phone, email, dob, city, profession, gender, isStudent, schoolHistory, instagram, linkedin, whatsapp, twitter, customLabel, customHandle`
**No password field** — removed entirely from the flow.

## Backend rules
- `RegisterUserRequest` has **no validation annotations** — intentional, do not re-add
- Flyway migrations: always use `IF NOT EXISTS` / `IF EXISTS` guards
- Timezone: JVM = `Asia/Kolkata`, DB init = `SET TIME ZONE '+05:30'`

## Response rules
- No trailing summary of what you just did
- No comments explaining what code does
- No intermediate planning docs
- No error handling for cases that cannot happen
- Fix lint warnings shown in `<ide_diagnostics>` only when severity is `error` or `warning` — ignore `Information`

## Backend error handling (MANDATORY — see docs/conventions/error-handling.md)
- Never catch-and-swallow. No empty `catch`, no `Exception ignored`. The catch-all `@ExceptionHandler(Exception.class)` MUST `log.error("...", ex)` with the full stack.
- Map exceptions to the correct HTTP status; a 4xx (bad input, not found, conflict, auth) must never fall through to 500.
- Never leak internals to clients: no stack traces, SQL, class names, or framework messages in `error`. 5xx returns a generic message + the `requestId` only.
- Throw `AppException(message, HttpStatus, ErrorCode)` from services for expected errors. Never throw raw `RuntimeException` for control flow; never hand-build error envelopes in controllers.
- Every error response includes a machine-readable `code` (ErrorCode enum) and a `requestId` (`X-Request-Id`, propagated via MDC by `RequestIdFilter`).
- Log levels: 4xx = WARN (no stack), 5xx = ERROR (with stack). Never log PII (phone, email, OTP, JWT, message bodies).
- When touching error handling, add/extend tests covering 400 (validation), 404, 409, and a forced 500 (assert generic body + requestId + that it was logged).
