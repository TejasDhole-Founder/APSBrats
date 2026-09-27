# Authorization & JWT in APS Brat — A Hands-On Course

A book in 10 chapters, taught on **your real code**: `JwtService`, `JwtAuthFilter`, `SecurityConfig`, `AuthService`, `AdminService`, `ChatService`. Every chapter either explains something already running in the app, or fixes a real gap in it.

**Two real bugs are fixed as part of this course, not as made-up exercises:**
- **Chapter 4:** a *refresh* token (30 days) is also accepted as an *access* token on every API call and on the WebSocket.
- **Chapter 7:** a user you've **blocked** can still open a chat with you and message you.

---

## Part 0 — Instructions for the tutor agent (read this first)

Same rules as `docs/chat-course/CHAT_COURSE.md`:

1. **Backend (`apsbrat-api/`) is copy-paste only.** Never edit it yourself. Give the file path, a clear anchor, and the code. Tejas pastes it. Read-only checks are fine (`mvn -o -q compile`, `mvn -o test`, curl).
2. One step at a time. Wait for "done".
3. Format: file path + new/edit, then the code block, then the plain-language explanation **directly under it**.
4. Read the real code before each step. This course was written against the codebase on 2026-09-27. Adapt if it has drifted, and say so.
5. Teach first, then code. End every chapter with its **Checkpoint** and **Check yourself** questions.
6. Update the Progress Tracker at the bottom when a chapter's checkpoint passes.
7. Keep it simple. No new libraries unless the chapter says so.

**Getting a token for testing:** `POST /api/v1/auth/verify-otp` with `{"email":"arjun.singh@example.com","code":"000000"}` (the dev master OTP). No `request-otp` call is needed. Arjun is `USER`. To test admin paths, promote a test user in Postgres: `docker exec apsbrats-db-1 psql -U aps_user -d apsbrat_db -c "update users set role='ADMIN' where email='rohit.singh@example.com';"`

---

## Part 1 — How it works today

### Chapter 1 — Authentication vs authorization: a request's journey

**Teach first:**
- **Authentication** = *who are you?* (proved by the JWT). **Authorization** = *are you allowed to do this?* (roles, ownership, relationships).
- Trace one request through the app, in order:
  1. `RequestIdFilter`: tags the request with an id for logs.
  2. `JwtAuthFilter`: reads `Authorization: Bearer …`, verifies the token, and puts the userId + `ROLE_x` into `SecurityContextHolder`. **An invalid token doesn't error here.** The request just stays anonymous.
  3. `SecurityConfig` URL rules: `permitAll` paths go through. `/api/v1/admin/**` needs `ADMIN`/`MODERATOR`. Everything else needs *some* authenticated user.
  4. Controller → `SecurityUtils.currentUserId()` → service.
  5. **Service-level checks**: "is this your conversation?" (`requireParticipant`), "is this your school entry?", "are you an admin?" (`AdminService.requireAdmin`).
- **401 vs 403:** 401 = "I don't know who you are" (`RestAuthEntryPoint`). 403 = "I know who you are, and you can't do this" (`RestAccessDeniedHandler`).

**Checkpoint (curl, no code):** 1) `GET /api/v1/conversations` with no token → 401. 2) With a garbage token → 401. 3) As Arjun (USER) `GET /api/v1/admin/reports` → 403. 4) As Arjun `GET /api/v1/conversations` → 200.

**Check yourself**
1. Why does `JwtAuthFilter` swallow a bad token instead of returning 401 itself?
2. Which layer produced each of the four responses above?

---

### Chapter 2 — Anatomy of your JWT

**Teach first:**
- A JWT is `header.payload.signature`, each part base64url-encoded. Paste a real Arjun token into a decoder (or `echo <part> | base64 -d`) and read it:
  - header: `{"alg":"HS256"}`
  - payload: `sub` (userId), `type` (`access`/`refresh`), `iat`, `exp`, `email`, `role`, and on refresh tokens a `jti`
  - signature: HMAC-SHA256 over `header.payload` with the server secret
- **Base64 is not encryption.** Anyone holding the token can read the payload, so never put secrets in it. The signature only proves nobody *changed* it.
- `JwtService.deriveKey` hashes `app.jwt.secret` with SHA-256 to get a 256-bit key. `validateSecret` refuses weak secrets in qa/prod.
- **HS256 vs RS256:** HS256 uses one shared secret, fine when a single backend both issues and checks tokens. RS256 uses a private key to sign and a public key to verify, which you'd need if *other* services had to verify your tokens without being able to mint them.

**Checkpoint (hands-on attack):**
1. Decode Arjun's access token and change `"role":"USER"` to `"role":"ADMIN"` in the payload, re-encode it, and keep the old signature.
2. Call `GET /api/v1/admin/reports` with it → **401**. Explain why, pointing to `JwtService.parse()` → `verifyWith(key)`.
3. Research the classic `alg: none` attack, and explain why jjwt's `verifyWith(key)` already blocks it.

**Check yourself**
1. If an attacker can *read* your payload, what's the harm? What should never go in it?
2. Why is the `role` claim safe to trust even though the client holds the token?

---

### Chapter 3 — Access vs refresh, rotation and reuse (recap + deepen)

**Teach first** (the code is `AuthService.issueTokens` / `refresh` / `logout` / `revokeAllFor`):
- Access token: 15 min, checked by signature only. **It can't be revoked.**
- Refresh token: 30 days, *and* its `jti` must exist in Redis (`rt:{jti}`). `refresh()` deletes it on use, so each one works exactly once (**rotation**).
- `rtu:{userId}` is a Redis set of every live `jti` for that user. `revokeAllFor` walks it. That's what ban/suspend/delete-account already call (`AdminService`, `AccountService`).
- **Reuse detection (concept):** if an *already-used* refresh token shows up again, someone stole a copy. Strict systems then revoke the whole family. We don't do this yet. Discuss whether it's worth it here.
- Client side: `dio_client.dart`'s 401 interceptor and its single-flight `refreshInFlight`.

**Checkpoint:** as Arjun, call `/auth/refresh` with a refresh token → success. Call it again with the **same** token → 401. Explain in your own words why.

**Check yourself**
1. Why does `refresh()` use `redis.delete(...)` as the check, instead of `hasKey` followed by a separate delete? (Hint: two requests at the same moment.)
2. After `revokeAllFor(userId)`, which of that user's tokens still work, and for how long?

---

## Part 2 — Fixing real gaps

### Chapter 4 — Token confusion: a refresh token works as an access token 🐞

**The bug:** `JwtAuthFilter` calls `parseUserId` and `parseRole` but **never checks `type`**. `StompAuthChannelInterceptor` doesn't either. So a 30-day refresh token can be sent as `Bearer …` and **authenticates as the user on every API call and on the socket.** That defeats the whole point of short-lived access tokens: a stolen refresh token gives 30 days of API access without ever calling `/refresh`, so rotation never gets a chance to catch it.

**Teach first:** a token's `type` (or `aud`/`scope`) claim exists so one kind of token can't be replayed where another is expected. This is called *token confusion*.

**Steps**
1. `JwtService`: add `isAccessToken(String token)` → `"access".equals(parse(token).get("type", String.class))`.
2. `JwtAuthFilter`: only authenticate when `jwtService.isAccessToken(token)`. Otherwise leave the request anonymous, exactly like a bad token.
3. `StompAuthChannelInterceptor`: on CONNECT, reject tokens that aren't access tokens.
4. `JwtServiceTest`: add one test proving a refresh token isn't an access token.

**Checkpoint:** *before* the fix, `GET /api/v1/conversations` with Arjun's **refresh** token → 200 (prove the bug exists). *After* the fix → 401. The access token still gets 200. `mvn -o test` passes.

**Check yourself**
1. What exactly could someone do with a stolen refresh token before this fix? And after?
2. Why must the WebSocket interceptor get the same fix?

---

### Chapter 5 — Method-level security with `@PreAuthorize`

**Teach first:**
- URL rules (`SecurityConfig`) are coarse. `AdminService.requireAdmin` is a hand-written `if (role != ADMIN) throw` that every admin method has to remember to call.
- `@EnableMethodSecurity` + `@PreAuthorize("hasRole('ADMIN')")` puts the rule **on the method itself**. Spring checks it through a proxy before your code runs, so you can't forget it.
- Recall the "called internally by Spring" idea from the chat course: `@PreAuthorize` works through the same proxy mechanism as `@Transactional`. A method calling *itself* inside the same class skips the check.
- `hasRole('ADMIN')` matches the authority `ROLE_ADMIN`, which is exactly what `JwtAuthFilter` builds from the `role` claim.

**Steps**
1. Add `@EnableMethodSecurity` to `SecurityConfig`.
2. In `AdminService` (or `AdminController`), replace `requireAdmin(actorId)` calls with `@PreAuthorize("hasRole('ADMIN')")` on the methods that are admin-only. Keep moderator-allowed ones as `hasAnyRole('ADMIN','MODERATOR')`. **The tutor reads `AdminService` first to see which methods are admin-only today, and keeps that exact behaviour.**
3. Delete `requireAdmin` once nothing calls it.

**Checkpoint:** as a MODERATOR, call an admin-only endpoint (e.g. change role) → 403. As ADMIN → works. As USER, a moderator endpoint → 403.

**Check yourself**
1. What's the difference between the URL rule for `/api/v1/admin/**` and `@PreAuthorize`? Why keep both?
2. Why would `@PreAuthorize` silently not apply if one method in the same class calls another?

---

### Chapter 6 — Ownership rules ("you can only edit your own …")

**Teach first:**
- Three hand-rolled ownership checks exist today: `UserSchoolHistoryController` (line ~45), `UserSocialLinkController` (line ~39), and `ChatService.requireParticipant`.
- SpEL in `@PreAuthorize` can read method arguments and the logged-in principal: `@PreAuthorize("#userId == authentication.principal")`. Your principal *is* the userId `UUID` (see `JwtAuthFilter`), so this comparison works directly.
- **Where ownership belongs:** when the rule is "path id must be me," an annotation reads cleanly. When it needs a database lookup ("is this conversation mine?"), keep it in the service, like `requireParticipant`. Don't force everything into annotations.
- **403 vs 404 (recap from chat):** for *edits to your own profile*, 403 is fine because the resource's existence isn't a secret. For *private conversations*, 404, so nothing leaks.

**Steps**
1. Replace the manual check in `UserSchoolHistoryController` and `UserSocialLinkController` with `@PreAuthorize("#userId == authentication.principal")` on the write methods.
2. Leave `requireParticipant` as it is, and explain why.

**Checkpoint:** as Arjun, try to edit Rohit's social links via `PUT /api/v1/users/{rohitId}/social-links/INSTAGRAM` → 403. Your own → works.

---

### Chapter 7 — Relationship rules: blocking must reach chat 🐞

**The bug:** blocking is enforced in `ConnectionService`, `ProfileService` and `SearchService`, but **`ChatService` never checks it.** Someone you've blocked can still call `POST /conversations/with/{you}` and message you, and their messages get pushed live to your socket.

**Teach first:** authorization isn't only roles and ownership. *Relationships* (blocked, connected, private profile) are rules too. Your LinkedIn-style message cap is already one of these (the `relations()` check in `sendMessage`). A rule enforced in 3 places out of 4 is a hole, so the fix belongs in one shared check.

**Steps**
1. The tutor reads `UserBlockRepository` / `BlockService` for an existing "is there a block either way between A and B" method, and reuses it. Only if none exists, add one (e.g. `existsByBlocker_IdAndBlocked_Id` checked in both directions).
2. `ChatService.openWith`: if either user has blocked the other → 403 (or 404, discuss which leaks less).
3. `ChatService.sendMessage`: same check, since a conversation may predate the block.

**Checkpoint:** Rohit blocks Arjun (`POST` the block endpoint as Rohit). Arjun sends to their existing conversation → rejected. Arjun's `openWith(Rohit)` → rejected. Unblock → works again.

**Check yourself**
1. Should the error tell Arjun he's been blocked? What's the privacy argument each way?
2. Why check in `sendMessage` and not only in `openWith`?

---

### Chapter 8 — Stale claims: a banned user keeps access for 15 minutes

**The gap:** `revokeAllFor` kills refresh tokens, but an **access token already issued keeps working until it expires** (up to 15 min), because `JwtAuthFilter` trusts the signature alone. The same goes for a demoted admin: their token still says `role: ADMIN` until it expires.

**Teach first — the three standard answers:**
- (a) Accept it: keep access tokens short. Many apps stop here.
- (b) Look up the user on every request: always correct, but costs a DB hit per request.
- (c) **"Revoked-before" timestamp in Redis (what we'll build):** when revoking, set `revoked-at:{userId} = now`. In `JwtAuthFilter`, reject any token whose `iat` is earlier than that. It costs one Redis lookup per request, and a key only exists for users who were actually revoked, so it's cheap.

**Steps**
1. `AuthService.revokeAllFor`: also set `revoked-at:{userId}` to the current epoch seconds, with a TTL equal to the access token lifetime. After that, every old access token has expired anyway, so the key can safely disappear.
2. `JwtService`: expose `parseIssuedAt(token)`.
3. `JwtAuthFilter` (and the STOMP interceptor): if `revoked-at:{userId}` exists and the token's `iat` is earlier → stay anonymous.
4. Also call `revokeAllFor` when an admin changes someone's role, so the new role takes effect straight away.

**Checkpoint:** log in as a test user and keep their access token. Ban them as ADMIN. Immediately reuse the old access token → 401 (it gave 200 before this chapter).

**Check yourself**
1. Why a TTL on `revoked-at`, and why exactly the access token lifetime?
2. What does option (c) cost per request compared with (b)?

---

### Chapter 9 — "Log out of all devices"

**Teach first:** users want this after losing a phone. Everything it needs already exists after Chapter 8.

**Steps**
1. `AuthController`: `POST /api/v1/auth/logout-all`, authenticated, which calls `authService.revokeAllFor(SecurityUtils.currentUserId())`.
2. Frontend (the tutor may edit `frontend/` directly, per the course rules): a "Log out of all devices" row in the Profile settings sheet that calls it, then runs the normal logout.

**Checkpoint:** log in as Arjun in two browser sessions. Tap "log out all" in one. The other gets 401 on its next request, and then its refresh also fails, so it lands on the login screen.

---

### Chapter 10 — Where the client keeps tokens, and testing it all

**Teach first:**
- Mobile: `flutter_secure_storage` → Keychain (iOS) / Keystore (Android). Good.
- **Web:** secure storage falls back to browser storage, which any injected script can read (XSS). The alternative is HttpOnly cookies, which scripts can't read but which need CSRF protection. Discuss the tradeoff. No change is needed now.
- Why CSRF is disabled in `SecurityConfig`: bearer tokens aren't sent automatically by the browser, so CSRF doesn't apply. It *would* apply if you switched to cookies.

**Steps — lock the lessons in with tests** (`apsbrat-api/src/test/…`, following the existing `JwtServiceTest` style):
1. An expired token is rejected.
2. A token signed with a different secret is rejected.
3. A refresh token isn't accepted as an access token (Chapter 4).
4. A token issued before `revoked-at` is rejected (Chapter 8).

**Checkpoint:** `mvn -o test` passes, with the new tests included.

---

## Progress Tracker

| # | Chapter | Status | Notes |
|---|---|---|---|
| 1 | Request journey, 401 vs 403 | ⬜ | |
| 2 | JWT anatomy + tamper attack | ⬜ | |
| 3 | Access/refresh, rotation, reuse | ⬜ | |
| 4 | 🐞 Refresh token accepted as access | ⬜ | Real bug |
| 5 | `@PreAuthorize` method security | ⬜ | |
| 6 | Ownership rules | ⬜ | |
| 7 | 🐞 Blocking not enforced in chat | ⬜ | Real bug |
| 8 | Stale claims / revoked-at | ⬜ | |
| 9 | Log out of all devices | ⬜ | |
| 10 | Token storage + security tests | ⬜ | |
