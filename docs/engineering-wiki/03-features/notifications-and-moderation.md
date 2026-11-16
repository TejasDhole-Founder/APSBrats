# Notifications and Moderation

In-app notifications (what creates them, how the app lists and acts on them), user reports with auto-hide, and staff moderation actions. Also states what exists only in the API and what is missing (push, admin UI).

Last verified: 2026-11-16 against commit 168d987 (working tree has uncommitted changes)

API paths are under `/api/v1`. Backend: `notification/` and `safety/` packages in `apsbrat-api/src/main/java/com/apsconnect/api`. Frontend: `frontend/lib/features/notifications/`, `frontend/lib/features/community/presentation/post_card.dart` (report sheet).

## Part A: Notifications

### Model
- Table `notifications` (V13 + V22): `id, user_id (FK users, ON DELETE CASCADE), actor_id (FK, ON DELETE SET NULL), type (Postgres enum notification_type), title (<=200), body, ref_type (varchar), ref_id, group_key, is_read, created_at`. Indexes `(user_id, created_at DESC)` and a partial index on `(user_id, group_key)`.
- `NotificationType`: `JOIN, CONNECTION_REQUEST, CONNECTION_ACCEPTED, MESSAGE, GENERAL`. `NotificationRef`: `CONNECTION, USER, CONVERSATION, POST, EVENT` (ref_id points at connections.id / users.id / conversations.id / posts.id / community_events.id).
- Notifications are written in the same transaction as the action that causes them (`NotificationService.create` / `createAll`, both `@Transactional`, joined to the caller's transaction). If the action rolls back, so does the notification. There is no async queue.

### A1. Where notifications are created (complete list, verified by grep)

| Action | Code | Recipient | Type / ref | Title and body |
|---|---|---|---|---|
| Send connection request (new pair, or re-request after decline/withdraw/remove) | `ConnectionService.java:69` and `:96` via `notifyRequest` (line 189) | the addressee | `CONNECTION_REQUEST`, ref `CONNECTION` = connection id, actor = requester | "<name> wants to connect" |
| Accept a request, including the "reverse request = yes" case | `ConnectionService.accept` (line ~176) | the original requester | `CONNECTION_ACCEPTED`, ref `USER` = accepter id, actor = accepter | "<name> accepted your request" |
| Comment on a post (not own post) | `PostService.addComment` (line ~308) | the post author | `GENERAL`, ref `POST` = post id, actor = commenter | "New comment" / "<name> commented on your post" |
| Event start time, end time or venue edited, or event cancelled | `CommunityEventService.update` (line 101) / `cancel` (line 113) via `notifyRsvps` (line 227) -> `createAll` | everyone who RSVP'd, except the actor | `GENERAL`, ref `EVENT` = event id | "Event updated: <title>" / "Event cancelled" |

Nothing else creates a notification. In particular: no notification for direct chat or community chat messages, community join requests or approvals, likes, moderation actions (hide/ban/suspend), report outcomes, or being blocked. Types `JOIN` and `MESSAGE` exist in the enum and DB but no code writes them (the app still has icons for them in `_NotificationTile._iconFor`).

There is no de-duplication: `group_key` is a column and index but never set, so repeated actions create repeated rows (e.g. ten comments = ten notifications).

### A2. List notifications

1. User action: taps the bell on the Home tab (`feed/presentation/widgets/home_tab.dart:74` -> `context.go('/home/notifications')`).
2. Frontend: `notifications_screen.dart` `NotificationsScreen`. `initState` invalidates `notificationsProvider` and `unreadNotificationCountProvider` so the screen always shows fresh data. Pull-to-refresh invalidates again. Repository: `notification_repository.dart` `NotificationRepository.list`.
3. State: `notificationsProvider` (`FutureProvider<List<AppNotification>>`, page 0 only). Local `_answered` set hides Accept/Decline instantly (optimistic) after the user answers a request.
4. API: `GET /notifications?page=N` -> `NotificationDto[]` (id, type, title, body, read, createdAt, actorId, actorName, actorInitials, refType, refId, `actionable`). Page size is fixed at 30 (`NotificationService.PAGE_SIZE`).
5. Backend: `NotificationController.list` -> `NotificationService.list` (read-only): `findAllByUser_IdOrderByCreatedAtDesc` (entity graph loads actors in the same query) -> collect `CONNECTION` ref ids -> one `connectionRepository.findAllById` -> `actionable = type == CONNECTION_REQUEST && connection.status == PENDING`. Why: the request card must offer Accept/Decline only while the request is truly pending, so Home, the bell sheet and the profile button never disagree.
6. DB: reads `notifications`, `users` (actors), `connections`.
7. Response handling: `AppNotification.fromJson`; unknown type defaults to `GENERAL`.
8. UI: list of tiles (avatar initials, bold title when unread, body, relative time). Unread tiles have a tinted background. Pending requests get a gold highlight with Accept and Decline buttons. Empty state "Nothing yet". Load failure shows "Could not load notifications" with Retry. Header shows "N new" or "All caught up", computed locally from the loaded page.
9. Other users: n/a (refresh only; no WebSocket or push updates the list while it is open).
10. Failure: GET is auto-retried (dio retry interceptor); then error state with Retry.
11. Concurrency: read only. Race: a request accepted elsewhere between list and tap makes the tap fail (see A5).
12. Security: scoped to the caller's id from the token; `/notifications` is not behind `OnboardingGate` (an un-onboarded account has none).

### A3. Unread count

- API `GET /notifications/unread-count` -> `{count}` (`countByUser_IdAndReadFalse`); frontend `unreadNotificationCountProvider`.
- The provider is invalidated by `refreshConnections` and the notifications screen, but NO widget reads it. The bell icon on Home has no badge. So the endpoint works and is not shown to the user (verified: only `notifications_screen.dart` and `connection_repository.dart` reference the provider). The comment in `circle_repository.dart` ("the bell badge") suggests a badge was planned from the circle summary; UNVERIFIED whether any pending-request count is displayed elsewhere.

### A4. Mark read / mark all read

1. User action: "Mark all read" button in the notifications header (enabled only when the loaded page has unread items).
2. Frontend: `_markAllRead()` -> `NotificationRepository.markAllRead` -> invalidates both providers. Not optimistic; no error handling (an exception propagates unhandled from the `onPressed` future).
3. API: `POST /notifications/read-all`; single: `POST /notifications/{id}/read`.
4. Backend: `markAllRead` -> bulk `UPDATE notifications SET is_read = true WHERE user_id = :userId AND is_read = false` (marks every page, not only the visible one). `markRead` loads by id, 404 if missing, 403 "Not your notification" if owned by someone else, sets read.
5. DB: `notifications.is_read`.
6. UI: tiles lose bold/tint after refetch; header becomes "All caught up".
7. Idempotent, so double taps and retried POSTs are safe. Both are `POST`s, so the `Idempotency-Key` replay also applies.
8. Not implemented in the UI: marking a single notification read. `NotificationRepository.markRead` exists but is never called, and tapping a tile does NOT mark it read. The only way to clear unread state is "Mark all read".

### A5. Tap a notification, and answer a connection request

Tap (`_open` in `notifications_screen.dart`):
- `refType == USER` -> `context.go('/home/profile/<refId>')` (note `go`, not `push`: replaces the stack)
- `refType == POST` -> `context.push('/home/post/<refId>')`
- `refType == EVENT` -> `context.push('/home/event/<refId>')`
- otherwise, if there is an actor -> profile of the actor (this covers `CONNECTION` refs and the unhandled `CONVERSATION` ref; no screen opens a chat from a notification).

Accept / Decline on a pending request (`_respond`):
1. User action: Accept or Decline on a gold-highlighted request tile.
2. Frontend: adds the notification id to `_answered` (buttons vanish immediately), then `ConnectionRepository.accept(actorId)` (`PUT /connections/{userId}/accept`) or `end(actorId)` (`DELETE /connections/{userId}`, server decides decline/withdraw/remove from state). Then `refreshConnections` (invalidates batchmates, pending, sent, circle summary, classmates, schoolmates, people search, profile, notifications, unread count, status, mutuals).
3. Backend: `ConnectionService.acceptConnection` takes a pair lock (`connectionRepository.lock(pair)`), requires the caller to be the addressee (403 otherwise), is idempotent when already accepted (returns), 404 if no longer pending; accept writes status ACCEPTED, a `connection_events` row, a `CONNECTION_ACCEPTED` notification to the requester, and evicts the circle cache.
4. Failure/rollback: on any error the id is removed from `_answered` (buttons return) and a snackbar says "Could not update. Try again." Note the notification row is NOT deleted or rewritten after answering; it stays in the list with `actionable=false` on the next fetch.
5. Concurrency: the pair lock serializes concurrent accept/decline/withdraw/block; a request withdrawn by the sender while the tile is open makes accept return 404 and show the generic failure snackbar.
6. Other users: the requester receives `CONNECTION_ACCEPTED` on their next list load (no push).

### A6. Push notifications

State: NOT implemented. Verified:
- `users.fcm_token` exists (V1, `User.fcmToken`) and is only ever set to `null` (`AccountService.deleteAccount`). No endpoint, service or SQL writes a token (`grep -ri fcm` over `apsbrat-api/src` finds only those two references).
- Frontend `pubspec.yaml` lists `firebase_messaging: ^14.9.4`, but no Dart file imports it (no `getToken`, `onMessage`, or background handler). Firebase is used only for Google sign-in (`firebase_auth`, `google_sign_in`).
- Backend `FirebaseAuthVerifier` only verifies Google ID tokens; there is no FCM sender.
- Consequence: all notification delivery is pull. New notifications appear only when the user opens the notifications screen (and chat uses its own WebSocket, documented separately).

## Part B: Reporting

### B1. File a report

1. User action: overflow menu on a post ("Report"), a comment row, long-press on a community chat message, or the profile menu ("Report user").
2. Frontend: `showReportSheet(context, ref, targetType, targetId)` in `features/community/presentation/post_card.dart:357`: bottom sheet of six reasons (`kReportReasons` in `community_models.dart`: SPAM, INAPPROPRIATE, NOT_RELEVANT, HARASSMENT, PRIVACY, OTHER) -> `CommunityRepository.report` (`community_repository.dart:352`). Callers: `post_card.dart:202` (POST), `post_screen.dart:215` (COMMENT), `community_chat_screen.dart:261` (COMMUNITY_MESSAGE), `profile_screen.dart:382` (USER).
3. State: no provider; fire-and-forget with a snackbar. Not optimistic; the reported item is not hidden locally for the reporter.
4. API: `POST /reports` body `{targetType, targetId | targetUserId, reason, details?}`; for USER the app sends `targetUserId`, otherwise `targetId`. Response: the report id (`ApiResponse<UUID>`, "Report submitted"). The app has no free-text field, so `details` is never sent.
5. Backend: `ReportController.create` -> `ReportService.create` (transaction):
   - Content targets (POST, COMMENT, COMMUNITY_MESSAGE): `targetId` required (404 if null); `PostService.requireReportable` (comment must be ACTIVE; the reporter must be able to read the post; reporting your own post or comment -> 400) or `CommunityChatService.requireReportable` (message ACTIVE, reporter is a member of that community, not own message -> 400). Why: you cannot report what you cannot see, and the checks stop probing for hidden IDs.
   - Person targets (USER, and the unused MESSAGE type): `targetUserId` required (400), cannot be yourself (400).
   - Dedupe: `ReportRepository.findExisting(reporter, type, target)`; a repeat report returns the earlier id and writes nothing (so one person cannot inflate the count).
   - Insert `Report` (`status` defaults to `OPEN`; the target user must exist, else 404).
   - Auto-hide: for content targets, if `countDistinctReporters(type, targetId) >= 3` (`AUTO_HIDE_REPORTERS`), call `PostService.hidePost` / `hideComment` or `CommunityChatService.hide`, which set `status = HIDDEN` only if it was `ACTIVE`.
6. DB: `reports` insert (V16; unique index `uq_reports_once` on `(reporter_id, target_type, COALESCE(target_id, target_user_id))` from V34; indexes on status and target user). `posts`/`comments`/`community_messages.status` updated to HIDDEN.
7. Response handling: snackbar "Thanks. We'll take a look." Errors show the server message through `friendlyError` (e.g. "You can't report your own post").
8. UI: for the reporter, nothing changes. When the third distinct reporter files, the content disappears from lists for everyone (feeds filter `ACTIVE`). A hidden community message pushes a `removed=true` notice over the chat socket (`CommunityChatService.setStatus` -> `pushAfterCommit`), so open chats update live; hidden posts and comments disappear on the next load.
9. Other users: see the content vanish (see 8). The author is NOT notified that their content was hidden or why. Reporters are not told the outcome.
10. Failure: snackbar; POST is retried on transient errors, and the idempotency key plus the dedupe query make that safe.
11. Concurrency: duplicate-report race is closed by the unique index (second insert -> `DataIntegrityViolationException` -> 409, shown as an error though the first report counted). Two different reporters filing the 3rd report at the same instant can both see count 2 (READ COMMITTED) and neither hides; the next report hides it (hide is `ACTIVE`-guarded and idempotent).
12. Security: authenticated and `OnboardingGate`d (`/reports`); reason is capped at 50 chars, details 2000. The reason is a free string server-side (not validated against the six codes). Abuse risk: three throwaway accounts can hide any post (see Risks).

### B2. Staff review (API only)

`SecurityConfig` requires `ROLE_ADMIN` or `ROLE_MODERATOR` for `/api/v1/admin/**`. The role comes from the access token, so a role change takes effect when tokens are re-issued (`setRole` revokes all sessions to force that).

| Endpoint | Service | Who | Effect |
|---|---|---|---|
| `GET /admin/reports?status=` | `AdminService.listReports` | admin, moderator | newest first, optional status filter (uppercased) |
| `POST /admin/reports/{id}/resolve` `{status, reason}` | `resolveReport` | admin, moderator | sets `reports.status` (default `RESOLVED`; any string accepted), writes `moderation_actions` "REPORT_<STATUS>" |
| `POST /admin/posts/{id}/restore`, `/comments/{id}/restore`, `/community-messages/{id}/restore` | `PostService.restorePost/restoreComment`, `CommunityChatService.restore` | admin, moderator | status back to `ACTIVE` (also undoes a REMOVED state) |
| `POST /admin/users/{id}/suspend` `{days, reason}` | `suspendUser` | admin, moderator | `suspended_until = now + clamp(days,1,365)`; revokes all of that user's sessions; moderators cannot suspend staff (needs admin) |
| `POST /admin/users/{id}/ban` `{reason}` | `banUser` | admin only (`requireAdmin` reads role from DB) | `banned_at = now`; revokes sessions |
| `POST /admin/users/{id}/reinstate` | `reinstateUser` | admin, moderator | clears `banned_at` and `suspended_until` |
| `POST /admin/users/{id}/role` `{role}` | `setRole` | admin only | sets USER / MODERATOR / ADMIN; revokes sessions so the token re-issues with the new role |
| `GET /admin/actions?limit=` | `recentActions` | admin, moderator | audit trail, newest first, limit capped at 200 (default 50) |

Every account action and report resolution writes a `moderation_actions` row (actor, target user, action code such as `BAN`, `SUSPEND_7D`, `REINSTATE`, `SET_ROLE_ADMIN`, optional reason up to 500 chars, optional report id). That is the audit trail; it records who, not the before-state.

How enforcement reaches the banned/suspended user: `revokeAllFor` kills refresh tokens and marks older access tokens revoked (`JwtAuthFilter` rejects them -> 401, which makes the app refresh, fail, and drop to the login screen). `AuthService.verifyOtp`, `signInWithGoogle` and `refresh` call `ensureNotBannedOrSuspended` (403 "temporarily/permanently suspended"). Banned users are also excluded from people search (`banned_at IS NULL`). Suspension lifts by time (`isSuspended` compares to now); nothing needs to run.

### B3. What the app UI implements vs API only

| Capability | App UI | API |
|---|---|---|
| Report post / comment / community message / user | Yes (sheet above) | Yes |
| Report a direct chat message (`MESSAGE`) | No | Enum value only; treated as a "person" report, `targetId` unused |
| Block / unblock user | Yes (profile menu, Settings -> Blocked users) | Yes (see profile doc) |
| Delete own post/comment, community owner removing content | Yes (post card and comment menus; owner/staff checks in `PostService.canModerate`) | Yes |
| View reports queue, resolve reports | NO | Yes |
| Ban, suspend, reinstate, set role | NO | Yes |
| Restore hidden content | NO | Yes |
| View moderation audit log | NO | Yes |
| Tell the user they are banned/suspended | Partly: login shows the generic "Incorrect or expired code." (the 403 text is hidden by `AuthController`) | 403 with message |

There is no admin or moderator screen anywhere in `frontend/lib` (no `admin` route in `app_router.dart`, no `/admin/` endpoint constant in `api_endpoints.dart`). Staff must call the API directly (Swagger UI is permitted by `SecurityConfig`) with a token of an ADMIN/MODERATOR user. There is no endpoint or seed to create the first admin: UNVERIFIED how the first ADMIN is provisioned (likely a direct SQL update of `users.role`; check `docs/RUNBOOK.md`).

## Not implemented (verified by search)
- Push notifications (FCM) end to end: token capture, token endpoint, sender, client handlers.
- Unread badge on the bell (endpoint exists, nothing displays it).
- Single-notification mark-read from the UI, notification delete, pagination beyond page 0 in the UI.
- Notifications for chat messages, join requests/approvals, likes, moderation events, report outcomes, or "your content was hidden".
- Notification grouping (`group_key` unused), email/SMS notifications.
- Admin/moderator UI, appeal flow, report outcome feedback to the reporter, rate limit specific to reporting.
- Reporting of direct (1:1) chat messages.
- Auto-hide for user reports (users are never auto-actioned; only content is).

## Risks, bugs, tech debt
- `AdminService.java:73` `reinstateUser` has no `requireAdmin`: any moderator can un-ban a user an admin banned (ban is admin-only, so reinstate should be too) and can reinstate an admin or moderator. Inconsistent with `banUser` and with the staff-protection in `suspendUser`.
- `AdminService.java:38-41` `resolveReport` accepts any status string; a value longer than 20 chars overflows `reports.status varchar(20)` and surfaces as a 500. It also never un-hides content or acts on the target; resolving is bookkeeping only. `AdminRequests` records have no validation annotations.
- `AdminService.suspendUser` takes primitive `int days`: a missing field becomes 0, clamped to 1 day, silently.
- `ReportService.java:69` auto-hide trusts any 3 accounts: no weighting for account age or reporter reputation, so brigading is cheap (account creation is a free email OTP/Google sign-in). Authors get no notice or appeal.
- `ReportService.create` race on the third report (see B1.11) can delay hiding by one report. Unique-index violation returns a 409 error to a user whose report was in fact recorded.
- `notifications_screen.dart` `_markAllRead` has no try/catch; a failure throws from the button handler. `unreadNotificationCountProvider` is fetched in several places for nothing because no widget watches it.
- Tapping a notification never marks it read, so unread styling persists until "Mark all read".
- `CONVERSATION` refs would open the actor's profile, not the chat, if they were ever created.
- `MaintenanceJobs` deletes only READ notifications older than 180 days. Because tapping never marks single notifications read, unread rows are kept forever unless the user taps "Mark all read".
- Notifications are created in the caller's transaction: a failure creating one (e.g. recipient lookup 404 in `NotificationService.create`) rolls back the whole action (for example a comment). Acceptable for consistency; worth knowing.
- Notifications from or about a user you later block remain in your list (the list query does not filter by blocks).
- `JwtAuthFilter` takes the role from the token; moderators demoted by a direct DB edit (not through `setRole`) keep access until their access token expires (15 min).

## Discrepancies with existing docs
- `docs/API.md` section 9 documents `NotificationDto` as `{id, type, title, body, read, createdAt}`; live DTO also has `actorId, actorName, actorInitials, refType, refId, actionable`. It omits ref types `POST` and `EVENT` and the event/comment notification sources. `docs/DATABASE.md` says notifications are "created automatically on connection request/accept" only, and lacks V22 columns (`actor_id, ref_type, ref_id, group_key`).
- `docs/API.md` has no `/reports` or `/admin/**` section (verified by grep).
- `docs/BACKEND.md:180` "No FCM push wiring yet": accurate. `docs/PRODUCT_GAP_REPORT.md` and `ROADMAP.md` were not re-read for push status (UNVERIFIED).
