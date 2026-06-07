# APSBrats API Reference

REST API for the APSBrats app (Spring Boot 3.2.5, Java 17, PostgreSQL).
Companion doc: [`DATABASE.md`](./DATABASE.md).

---

## 1. Conventions

### Base URL
| Env | Base |
|-----|------|
| Local dev | `http://localhost:8080/api` |
| Flutter `Env.baseUrl` | same (override with `--dart-define=BASE_URL=...`) |

Every path below is relative to `/api` (e.g. `POST /auth/verify-otp` → `http://localhost:8080/api/auth/verify-otp`).

### Response envelope
**Every** endpoint returns this wrapper (`ApiResponse<T>`):
```json
{ "success": true, "message": "optional text", "data": { ... }, "error": null }
```
On failure (`GlobalExceptionHandler`):
```json
{ "success": false, "message": null, "data": null, "error": "Human readable reason" }
```
Clients read the payload from `data`. Validation failures return `400` with `error` = `"field: message, field2: message2"`.

### Authentication
JWT bearer tokens. Send on every protected call:
```
Authorization: Bearer <accessToken>
```
- Access token TTL: 15 min (`app.jwt.access-token-expiry=900000`).
- Refresh token TTL: 30 days (`app.jwt.refresh-token-expiry=2592000000`).
- The token subject is the user's UUID; the filter (`JwtAuthFilter`) sets it as the security principal, read server-side via `SecurityUtils.currentUserId()`. **No `userId` is ever passed in feature URLs** — the server derives "me" from the token.

### Public (no token) routes
- `POST /auth/**`
- `GET /schools/**`
- `POST /users` (registration) and the onboarding sub-resources `/users/{id}/school-history/**`, `/users/{id}/social-links/**`
- `OPTIONS /**` (CORS preflight)

Everything else requires a valid bearer token → otherwise `401`.

### Common errors
| Status | When |
|--------|------|
| 400 | Bad request / validation / bad OTP |
| 401 | Missing/invalid/expired token |
| 403 | Authenticated but not allowed (e.g. not a member/participant) |
| 404 | Resource not found |
| 409 | Conflict (duplicate username/phone/email, duplicate connection) |

### Pagination
List endpoints that paginate use `?page=0&size=20` (`/schools`, `/users`). Feed uses `?limit=20`.

### Enums
```
UserStatus        : STUDENT | ALUMNI
SocialPlatform    : INSTAGRAM | LINKEDIN | WHATSAPP | TWITTER | CUSTOM
ConnectionStatus  : PENDING | ACCEPTED
FeedEventType     : JOIN | CONNECTED | GENERAL
CommunityType     : SECTION | SCHOOL | ALL_YEARS | GLOBAL
NotificationType  : JOIN | CONNECTION_REQUEST | CONNECTION_ACCEPTED | MESSAGE | GENERAL
```

### Shared object: `PersonDto`
Returned anywhere a "person card" is shown (feed, batchmates, community avatars, chat). Derived from the user + their **primary** school-history row.
```json
{
  "id": "uuid",
  "username": "priya.khanna",
  "initials": "PK",
  "name": "Priya Khanna",
  "school": "APS Patiala",
  "detail": "12A · Class 2022",
  "city": "Bengaluru",
  "job": "Software Engineer, Wipro",
  "currentStatus": "ALUMNI",
  "profilePicUrl": null,
  "online": false,
  "tags": ["12A Patiala", "Alumni"]
}
```
> `online` is currently always `false` (no presence service yet). `detail`/`tags` come from the primary `user_school_history` row; the `section` column stores the grade+section label (e.g. `12A`).

---

## 2. Auth  `/auth`  (public)

OTP login flow: **request-otp → verify-otp → receive tokens**. There is no password in the login flow.

> Dev convenience: `app.otp.master=000000` accepts `000000` as a universal code. `request-otp` also logs the real generated code to the server console (no SMS gateway is wired).

### POST /auth/request-otp
Generates a 6-digit code (10-min TTL) for a phone.
```json
// request
{ "phone": "919999000001" }
// 200 → data: null, message "OTP sent"
```

### POST /auth/verify-otp
Verifies the code and returns tokens + the user. The phone **must already belong to a registered user**.
```json
// request
{ "phone": "919999000001", "code": "000000" }
// 200 data:
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "user": { "id":"uuid","username":"arjun.singh","fullName":"Arjun Singh","phone":"919999000001","email":"...","city":"New Delhi","currentStatus":"ALUMNI" }
}
```
Errors: `400` no OTP requested / expired / incorrect; `404` no account for phone.

### POST /auth/refresh
Exchanges a refresh token for a fresh token pair.
```json
// request
{ "refreshToken": "eyJ..." }
// 200 data: same AuthTokens shape as verify-otp
```
Errors: `400` not a refresh token; `401` invalid/expired.

---

## 3. Users & onboarding  `/users`

(Existing module — documented for completeness.)

| Method | Path | Auth | Body | Returns |
|--------|------|------|------|---------|
| `GET` | `/users?page&size` | yes | – | `UserDto[]` |
| `POST` | `/users` | public | `RegisterUserRequest` | `UserDto` |
| `PUT` | `/users/{userId}/password` | yes | `ChangePasswordRequest` | – |
| `POST` | `/users/{userId}/school-history/bulk` | public | `{ "items": SaveSchoolHistoryItem[] }` | – (replaces all) |
| `GET` | `/users/{userId}/social-links` | public | – | `UserSocialLinkDto[]` |
| `PUT` | `/users/{userId}/social-links/{platform}` | public | `UpsertUserSocialLinkRequest` | `UserSocialLinkDto` |

`RegisterUserRequest`: `username, fullName, phone, email, dob (yyyy-MM-dd), city, profession, currentStatus, gender`.
`SaveSchoolHistoryItem`: `schoolId(uuid), classFrom(1-12), classTo(1-12), section, batchStart, batchEnd, isPrimary`.
`UpsertUserSocialLinkRequest`: `handle, label (required only for CUSTOM), isVisible`.

`UserDto`: `{ id, username, fullName, phone, email, city, currentStatus }`.

---

## 4. Schools  `/schools`  (public, GET)

| Method | Path | Returns |
|--------|------|---------|
| `GET` | `/schools?page&size` | `SchoolDto[]` |

`SchoolDto`: `{ id, name, city, state, cantonment, address, schoolCode, principalName, phone, email, website, isActive }`.

---

## 5. Feed  `/feed`

| Method | Path | Returns |
|--------|------|---------|
| `GET` | `/feed/activity?limit=20` | `FeedEventDto[]` (newest first) |
| `GET` | `/feed/recent-joins` | `PersonDto[]` (12 most-recent users, excl. me) |
| `GET` | `/feed/banner` | `BatchmateBannerDto` |

`FeedEventDto`:
```json
{ "id":"uuid", "person": PersonDto, "type":"JOIN", "typeLabel":"New join",
  "title":"Priya Khanna joined APS Brat", "body":"...", "meta":"APS Patiala 12A",
  "createdAt":"2026-06-05T10:00:00" }
```
`typeLabel`: JOIN→"New join", CONNECTED→"Connected", GENERAL→"Update".

`BatchmateBannerDto`: `{ "count": 3, "firstNames": ["Priya","Rohit","Vikram"], "message": "3 new batchmates joined today." }` — counts users created **today** (excl. me).

---

## 6. Connections  `/connections`

Symmetric "batchmate" relationships (request → accept).

| Method | Path | Body | Returns | Notes |
|--------|------|------|---------|-------|
| `GET` | `/connections` | – | `PersonDto[]` | my accepted batchmates |
| `GET` | `/connections/pending` | – | `PersonDto[]` | incoming pending requests |
| `GET` | `/connections/{userId}/status` | – | `{ "status": "..." }` | `NONE \| PENDING_OUT \| PENDING_IN \| CONNECTED` |
| `POST` | `/connections/{userId}` | – | – | send request (creates `CONNECTION_REQUEST` notification) |
| `PUT` | `/connections/{userId}/accept` | – | – | accept their request (creates `CONNECTION_ACCEPTED` notification) |

Errors: `400` self-connect; `409` already exists; `404` no pending request to accept.

---

## 7. Communities  `/communities`

| Method | Path | Body | Returns |
|--------|------|------|---------|
| `GET` | `/communities` | – | `CommunityDto[]` (mine) |
| `GET` | `/communities/discover` | – | `DiscoverCommunityDto[]` (ALL_YEARS/GLOBAL I'm not in) |
| `GET` | `/communities/{id}` | – | `CommunityDto` |
| `GET` | `/communities/{id}/messages` | – | `CommunityMessageDto[]` (oldest first) |
| `POST` | `/communities/{id}/messages` | `{ "body": "..." }` | `CommunityMessageDto` (members only) |
| `POST` | `/communities/{id}/join` | – | – |
| `POST` | `/communities/{id}/read` | – | – (sets my `last_read_at`) |

`CommunityDto`:
```json
{ "id":"uuid","name":"12A · APS Patiala · 2022","badge":"AUTO-JOINED","type":"SECTION",
  "members":6,"online":8,"lastSender":"Rohit","lastMessage":"...","time":"2026-06-05T...",
  "avatars":[PersonDto,...up to 5], "unreadCount":2,"autoJoinLabel":"AUTO-JOINED",
  "isYourSection":true,"isYourSchool":false }
```
- `members` = real member count, unless `member_count_override` is set (discover groups show 312 / 4200).
- `online` is a stored demo value (`online_count`) — not real presence.
- `unreadCount` = messages newer than my `last_read_at` (all if never read).

`DiscoverCommunityDto`: `{ id, name, memberCount: "312 members", subtitle }`.
`CommunityMessageDto`: `{ id, senderId, sender: PersonDto, body, mine, createdAt }`.

---

## 8. Direct messages  `/conversations`

1-to-1 chat (REST; client polls — no websocket yet).

| Method | Path | Body | Returns |
|--------|------|------|---------|
| `GET` | `/conversations` | – | `ConversationDto[]` (recent first) |
| `POST` | `/conversations/with/{userId}` | – | `ConversationDto` (get-or-create a thread with someone) |
| `GET` | `/conversations/{id}/messages` | – | `ChatMessageDto[]` (oldest first) |
| `POST` | `/conversations/{id}/messages` | `{ "body": "..." }` | `ChatMessageDto` |
| `POST` | `/conversations/{id}/read` | – | – (marks the other party's msgs read) |

`ConversationDto`: `{ id, person: PersonDto, preview, time, unread, unreadCount }` — `person` is the *other* participant.
`ChatMessageDto`: `{ id, senderId, body, mine, createdAt }` — `mine=true` if I sent it.
Errors: `403` not a participant; `404` conversation not found; `400` chat with self.

---

## 9. Notifications  `/notifications`

| Method | Path | Returns |
|--------|------|---------|
| `GET` | `/notifications` | `NotificationDto[]` (newest first) |
| `GET` | `/notifications/unread-count` | `{ "count": 3 }` |
| `POST` | `/notifications/{id}/read` | – |
| `POST` | `/notifications/read-all` | – |

`NotificationDto`: `{ id, type, title, body, read, createdAt }`.

---

## 10. Search  `/search`

| Method | Path | Returns |
|--------|------|---------|
| `GET` | `/search?q=term` | `SearchResultDto` |

Searches users (full name / username / city, excl. me) and community names.
`SearchResultDto`: `{ "people": PersonDto[], "communities": DiscoverCommunityDto[] }`. Empty `q` → empty result.

---

## 11. Profiles  `/profiles`

| Method | Path | Returns |
|--------|------|---------|
| `GET` | `/profiles/{username}` | `ProfileDto` |

`ProfileDto`:
```json
{ "id":"uuid","username":"arjun.singh","fullName":"Arjun Singh","bio":"...","city":"New Delhi",
  "profession":"NDA Cadet","profilePicUrl":null,"isVerified":true,"currentStatus":"ALUMNI",
  "schools":[ SchoolHistoryDto ... ],     // newest batch first
  "socials":[ UserSocialLinkDto ... ],    // visible links only
  "batchmatesCount":4, "schoolsCount":3, "connectedCount":4 }
```
`SchoolHistoryDto`: `{ id, schoolId, schoolName, classFrom, classTo, section, batchStart, batchEnd, isPrimary }`.
`UserSocialLinkDto`: `{ id, userId, platform, handle, label, isVisible, createdAt }`.
> `batchmatesCount` currently mirrors `connectedCount` (accepted connections); a true "shared-batch peers" count is a future enhancement.

---

## 12. Quick reference (all new endpoints)
```
POST   /auth/request-otp
POST   /auth/verify-otp
POST   /auth/refresh
GET    /feed/activity            GET /feed/recent-joins      GET /feed/banner
GET    /connections              GET /connections/pending    GET /connections/{id}/status
POST   /connections/{id}         PUT /connections/{id}/accept
GET    /communities              GET /communities/discover   GET /communities/{id}
GET    /communities/{id}/messages   POST /communities/{id}/messages
POST   /communities/{id}/join    POST /communities/{id}/read
GET    /conversations            POST /conversations/with/{userId}
GET    /conversations/{id}/messages  POST /conversations/{id}/messages  POST /conversations/{id}/read
GET    /notifications            GET /notifications/unread-count
POST   /notifications/{id}/read  POST /notifications/read-all
GET    /search?q=
GET    /profiles/{username}
```
