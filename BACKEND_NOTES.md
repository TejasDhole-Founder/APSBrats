# APSBrats — Backend build notes

All previously hard-coded screens are now backed by real REST endpoints + Postgres.
Auth is JWT + phone OTP. Demo data is seeded via Flyway (V14).

## Run
```
cd apsbrat-api
./mvnw spring-boot:run        # needs Java 17, Postgres (apsbrat_db), Redis
```
Frontend:
```
cd frontend
flutter pub get && flutter run
```

## Demo login (no SMS gateway wired)
Master OTP in dev = **000000** (app.otp.master). Log in as Arjun:
- phone: `919999000001`  → code: `000000`
Any seeded user works: 919999000002 (Priya) … 919999000011 (Riya).
`POST /api/auth/request-otp` also logs a real code to the console.

## New endpoints (all under /api, JWT required except auth/onboarding)
Auth:        POST /auth/request-otp · /auth/verify-otp · /auth/refresh
Feed:        GET  /feed/activity · /feed/recent-joins · /feed/banner
Connections: GET  /connections · /connections/pending · /connections/{id}/status
             POST /connections/{id}  · PUT /connections/{id}/accept
Communities: GET  /communities · /communities/discover · /communities/{id} · /{id}/messages
             POST /communities/{id}/messages · /{id}/join · /{id}/read
Chat (DMs):  GET  /conversations · /conversations/{id}/messages
             POST /conversations/with/{userId} · /conversations/{id}/messages · /{id}/read
Notifications: GET /notifications · /notifications/unread-count
             POST /notifications/{id}/read · /notifications/read-all
Search:      GET  /search?q=
Profiles:    GET  /profiles/{username}

## New migrations
V8 otp_codes · V9 connections · V10 feed_events · V11 communities (+members,+messages)
V12 conversations (+chat_messages) · V13 notifications · V14 seed demo data

## Remaining work (frontend UI wiring)
The data layer (models / repositories / Riverpod providers) is in place for every
feature, and login is wired. The feature WIDGETS still read the old
`features/feed/data/dummy_data.dart`. Next step is to swap each widget
(home_tab, batch_tab, messages_tab, profile_tab, chat_overlay, batchmate_overlay,
classroom/notifications/search/profile screens) to consume the new providers and
delete dummy_data.dart.
