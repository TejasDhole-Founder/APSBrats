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
