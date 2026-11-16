# Profile, Career, Schools and Privacy

Everything about a person's profile: viewing, editing, avatar, school history, social links, career timeline, privacy settings, data export, account deletion, and the blocked-users list.

Last verified: 2026-11-16 against commit 168d987 (working tree has uncommitted changes)

API paths are under `/api/v1`. Frontend endpoint constants: `frontend/lib/core/constants/api_endpoints.dart`. Backend packages: `profile/`, `user/` (+ `user/history`, `user/social`, `user/settings`), `career/`, `media/`, `safety/` under `apsbrat-api/src/main/java/com/apsconnect/api`.

## Shared patterns

- **Local-first "my data" providers.** `localFirst()` in `frontend/lib/features/profile/data/profile_repository.dart` backs `meProvider`, `mySocialLinksProvider`, `mySchoolHistoryProvider` and `myCareerProvider` (`features/career/data/career_repository.dart`). First read of an app session returns the JSON cached in secure storage (`cache_<name>_<userId>`) instantly, then refetches in the background and replaces the state. Any later rebuild (after `ref.invalidate`) goes straight to the server, so a user never sees old data after saving. Logout wipes it (`deleteAll`).
- **Other people's data** use plain `FutureProvider.family` keyed by user id (`profileProvider(userId)`, `careerProvider(userId)`); no cache.
- **Error text.** Screens read `payload['error']` from the `ApiResponse` envelope (`friendlyError` in `features/community/data/community_repository.dart`, or inline equivalents) and show a snackbar or an inline error. Offline shows "Couldn't connect".
- **Transport.** `dio_client.dart`: 15 s connect/receive timeouts; 401 -> single-flight refresh; GET and idempotency-keyed JSON POST retried up to 2 times on connection errors / 502-504 with 500 ms and 1 s backoff. PUT and DELETE are not auto-retried. FormData (avatar) POSTs are never retried. Every POST carries an `Idempotency-Key`; `IdempotencyFilter` replays a stored 2xx for 24 h.
- **Global guards.** `RateLimitFilter` (300 req/min per user, 60 per IP anonymous, fails open without Redis), `OnboardingGate` (see auth doc), JWT auth. Validation errors are returned as 400 with an `error` message; DB unique-key and `@Version` conflicts are returned as 409 "This action conflicts with existing data" (`GlobalExceptionHandler.handleConflict`).
- `users` has `@Version` (optimistic locking): two concurrent profile saves for one user make the second fail with 409.

## 1. View a profile

1. User action: opens own profile tab or another person's profile (`/home/profile/:id`).
2. Frontend: `features/profile/presentation/screens/profile_screen.dart` (others) and `features/feed/presentation/widgets/profile_tab.dart` (own tab). Data: `profileProvider(userId)` -> `ProfileRepository.byId`.
3. State: `FutureProvider.family<Profile,String>`; loading/error/data via `.when`. Not optimistic. Invalidated by `refreshConnections` and `refreshAfterBlock`.
4. API: `GET /profiles/{userId}` -> `ProfileDto` (id, username, fullName, bio, city, profession, phone, profilePicUrl, isVerified, currentStatus, schools[], socials[], schoolsCount, connectedCount, mutualCount, isPrivate, lastActiveAt, deleted). Profiles are addressed by user id, never username, so handles are not leaked and accounts cannot be enumerated by guessing names.
5. Backend: `ProfileController.getById` -> `ProfileService.getById`: load user (404) -> if `deletedAt != null` return a stub with only `fullName` and `deleted=true` -> if not self and a block exists in either direction (`UserBlockRepository.existsBetween`) return 404 (so a blocked person cannot tell they are blocked) -> read `UserSettingsService.get` -> `hideContact = !self && isPrivate` -> counts (`ConnectionRepository.countAcceptedForUser`), mutual count (`PersonService.mutualCounts`), schools (`UserSchoolHistoryService.getSchoolHistory`) -> socials filtered to `isVisible=true` and omitted when `hideContact` -> phone omitted when `hideContact` -> `PresenceService.visibleLastActive`.
6. DB: reads `users`, `user_settings`, `user_blocks`, `connections`, `user_school_history` (+ `schools`), `user_social_links`.
7. Response handling: `Profile.fromJson`; `deleted=true` renders as "Unknown user".
8. UI: header, schools, socials, mutuals, Journey tab (career, section 7). Last-active shows only when both sides allow.
9. Other users: they see changes on their next load (no push). Block state changes call `refreshAfterBlock`.
10. Failure: 404 (blocked or missing) and network errors show the screen's error/empty state. GET is retried automatically.
11. Concurrency: read only.
12. Security: authenticated and gated by `OnboardingGate` (`/profiles/**`). Visibility rules above are enforced server-side, not in the app.

## 2. Edit profile

1. User action: Profile tab -> Edit profile -> Save.
2. Frontend: `features/profile/presentation/screens/edit_profile_screen.dart` `_save()`: form validation -> `_usernameCheck.passes()` (debounced `GET /users/username-available` through `OnboardingRegistrationService.usernameAvailability`) -> `ProfileRepository.updateMe`.
3. State: local widget state (`_saving`, `_error`); on success `ref.invalidate(meProvider)`. Not optimistic.
4. API: `PUT /users/me` body `{fullName, username, city, profession, gender, dob(yyyy-MM-dd), bio, currentStatus}` -> `UserDto`. (The server also accepts an optional `email`, but the app does not send it.)
5. Backend: `UserController.updateMe` -> `UserService.updateMe` (transaction): load live user -> if `email` is sent and differs -> 400 "Email can't be changed" -> `validateProfileFields` (name >= 2 chars, username regex `^[a-zA-Z][a-zA-Z0-9_]{2,19}$`, reserved words, profanity list, DOB required, not future, age 13..120) -> username uniqueness (`existsByUsernameIgnoreCase`) -> 409 "Username already exists" -> set fields (blank -> null) -> JPA flush on commit.
6. DB: `users` update; unique index on `lower(username)` (V34) is the real guard; `@Version` bumps.
7. Response handling: snackbar "Profile updated", `context.pop()`. `DioException` shows the server `error` text inline.
8. UI: previous screen now shows new values after `meProvider` refetch.
9. Other users: see it on next profile/people load; no push.
10. Failure: server message shown; no rollback needed (nothing was changed locally). PUT is not auto-retried.
11. Concurrency: username race (check, then write) is closed by the unique index (second saver gets 409). Concurrent edits from two devices: `@Version` conflict -> 409.
12. Security: path is always "me" (no user id taken from the client). Validation is server-side; the age rule exists for child-safety/DPDP reasons. `OnboardingGate` does NOT cover `/users/me` on purpose, because onboarding itself calls it.

Variation: onboarding calls the same endpoint once at the end (see `auth-and-sessions.md` section 4). Its first save is what flips `isOnboarded()` to true.

## 3. Upload avatar

1. User action: taps the circular photo (onboarding, Profile tab, Edit profile).
2. Frontend: `features/profile/presentation/widgets/profile_photo.dart` `changeProfilePhoto()` -> `pickPhoto` (`core/media/photos.dart`) -> `ProfileRepository.uploadAvatar` (multipart, bytes not path, so it works on web).
3. State: `ProfilePhotoButton._uploading` spinner. On success `invalidate(meProvider)` then `invalidate(profileProvider(me.id))`. Not optimistic.
4. API: `POST /users/me/avatar` multipart field `file` -> `{profilePicUrl}`.
5. Backend: `AvatarController` -> `AvatarService.updateAvatar`: non-empty check (400) -> load live user (404) -> `ImageProcessor.toSanitizedJpeg` (<= 5 MB else 413, only JPEG/PNG else 415, decodes and re-encodes to JPEG, scaled to a max dimension; strips metadata and any non-image payload) -> store at key `profile/<userId>/<uuid>.jpg` via `StorageService` (local disk in dev, R2 in qa/prod) -> set `users.profile_pic_url` -> return URL.
6. DB: `users.profile_pic_url`. Object store gets a new file each time.
7. Response handling: returns true/false; failure shows the server `error` string or "Couldn't update your photo".
8. UI: new photo via `CachedNetworkImage` (`mediaUrl()`).
9. Other users: next load of anything showing the avatar.
10. Failure: not auto-retried (FormData). Multipart limits are 5 MB file and 6 MB request (`application.yml`).
11. Concurrency: last write wins. The previous object is never deleted (orphans accumulate in storage).
12. Security: server re-encodes the image (no trust of client content type beyond an allow-list), random key, owner-only (path is "me"). Rate: global limiter only (UNVERIFIED whether upload-specific limits exist; the filter docs mention "uploads" limits elsewhere).

## 4. School history (bulk replace)

1. User action: Profile -> Edit schools -> Save (or the Schools step in onboarding).
2. Frontend: `edit_schools_screen.dart` `_save()` -> local validation `schoolDraftsProblem` (same rules as server: needs at least one school, overlap check in `onboarding_flow_provider.dart`) -> `ProfileRepository.replaceSchoolHistory(userId, items)`.
3. State: widget-local drafts; on success `invalidate(mySchoolHistoryProvider)`. Not optimistic.
4. API: `POST /users/{userId}/school-history/bulk` body `{items:[{schoolId, classFrom, classTo, section?, batchStart, batchEnd, stream?, isPrimary?}]}`; response `ApiResponse<Void>`. Read: `GET /users/{userId}/school-history` (any signed-in user).
5. Backend: `UserSchoolHistoryController.replaceSchoolHistory` -> `requireSelf` (403 if path id != caller) -> `UserSchoolHistoryService.replaceSchoolHistory` (transaction): load user -> `overlapProblem` (no shared class range, no overlapping years, lower classes must be in earlier years; sessions run April to March so a year boundary may touch) -> per item `validate` (classTo >= classFrom, batchEnd >= batchStart, stream required if classTo >= 11 and forbidden below) and `schoolRepository.findById` (400 if unknown) -> `deleteAllByUser_Id` then `saveAll` -> `CommunityService.dropSchoolsNoLongerListed` (leaves communities of schools no longer listed) -> `CircleCache.evictUser`.
6. DB: `user_school_history` delete + insert in one transaction (all-or-nothing); `community_members` rows removed for dropped schools; Redis circle cache evicted. Bean validation on each item (`@Min/@Max`, section `^[A-Za-z]{1,2}$`).
7. Response handling: snackbar "Schools updated", `context.pop()`; DioException shows server message.
8. UI: updated school timeline and profile counts.
9. Other users: the person's batchmates/classmates lists and search results change on next load (the circle cache is evicted so it recomputes). No push.
10. Failure: transaction rolls back on any validation error, leaving the old list. POST here is retried on transient errors thanks to the idempotency key.
11. Concurrency: delete-then-insert inside one transaction; two concurrent replaces serialize on the rows, last commit wins. No unique key on (user, school, class) UNVERIFIED.
12. Security: owner-only write; reading is allowed for any signed-in user even if the owner has blocked the viewer or is Private (see Risks).

## 5. Social links (create, update, delete)

1. User action: Profile tab -> tap a platform -> edit sheet -> Save (`profile_tab.dart` `_edit` -> `_EditSocialSheet`); during onboarding, the Socials step saves all of them.
2. Frontend: `ProfileRepository.saveSocialLink` / `deleteSocialLink`; platform constants in `core/constants/social_platforms.dart`.
3. State: after save `ref.invalidate(mySocialLinksProvider)`; snackbar "<platform> saved". Not optimistic.
4. API: `PUT /users/{userId}/social-links/{platform}` `{handle, label?, isVisible?}` -> `UserSocialLinkDto`; `DELETE /users/{userId}/social-links/{platform}`; `GET /users/{userId}/social-links`. Platforms: INSTAGRAM, LINKEDIN, WHATSAPP, TWITTER, CUSTOM.
5. Backend: `UserSocialLinkController` (owner-only on PUT/DELETE, 403 otherwise) -> `UserSocialLinkService.upsertLink`: load user -> CUSTOM requires `label` -> `validateHandle` with a per-platform regex (WhatsApp needs `+<country code>`; LinkedIn must be a `/in/` or `/company/` link; CUSTOM must look like a domain) -> find by (user, platform) or new -> set handle, label (CUSTOM only), `isVisible` (default TRUE when omitted). `deleteLink` is idempotent. `getLinks`: owner sees all; others see nothing if the owner is Private and only `isVisible=true` rows otherwise; 404 if either side blocked the other.
6. DB: `user_social_links`, unique `(user_id, platform)` (`uq_user_platform`, V5).
7. Response handling: sheet closes with `saved=true`.
8. UI: link chip updates.
9. Other users: only visible links, only when owner not Private; next load.
10. Failure: 400 messages are specific ("Enter a valid Instagram username or profile link"); shown in the sheet.
11. Concurrency: unique key stops duplicates; a double-submit race gives 409.
12. Security: owner-only writes; handle regexes prevent arbitrary text/links; Private flag and per-link `isVisible` enforced in `ProfileService` and `UserSocialLinkService`.

Important behaviour: the Profile-tab edit sheet does NOT send `isVisible`, and the service treats a missing value as TRUE, so editing a link silently turns a previously hidden link visible (bug, see Risks).

## 6. Privacy and visibility settings

Table `user_settings` (PK `user_id`; defaults when no row: private=false, discoverable=true, showActivity=true). API: `GET /users/me/settings`, `PUT /users/me/settings` with any subset of `{isPrivate, discoverable, showActivity}` (`UserSettingsService.update` creates the row on first write; null fields are ignored).

| Setting | UI | Enforced where |
|---|---|---|
| `isPrivate` | Settings sheet "Private profile" (`profile_tab.dart` `_PrivacyRow`, calls `setPrivate`) | `ProfileService.getById` hides `phone` and `socials` from non-owners; `UserSocialLinkService.getLinks` returns empty for non-owners. Name, bio, city, profession, schools, career (non-hidden) stay visible by design. |
| `discoverable` | NO UI toggle (model field only in `profile_models.dart`) | `UserRepository.searchPeople` (`NOT EXISTS ... discoverable = FALSE`) and `SearchService.search`. Hides from search only; still visible in communities, circle and direct profile URL. |
| `showActivity` | Settings sheet "Show my activity" (`_ActivityRow`) | `PresenceService.visibleLastActive` (needs BOTH viewer and subject to allow, so turning it off also hides everyone else's), `CommunityChatService` online count (line ~121), `CommunityMemberRepository.countActiveSince` (excluded from counts). |

Flow (both toggles): `_Toggle.onChanged` -> `ProfileRepository.setPrivate/setShowActivity` -> `PUT` -> `ref.invalidate(mySettingsProvider)`. Not optimistic: the switch reflects the server value after the refetch; on error a snackbar "Could not save. Try again." (no rollback needed). Last write wins; no locking. Other users see the effect on their next profile load.

## 7. Career / timeline entries

1. User action: Profile -> Journey tab -> add/edit/delete a job or college (`features/career/presentation/career_form.dart`, `journey_timeline.dart`); alumni also add during onboarding ("After school" step).
2. Frontend: `CareerRepository.save(draft)` (POST when `draft.id == null`, else PUT), `delete(id)`; org autocomplete `searchOrganizations` (min 2 chars). `_run()` wraps calls: sets `_busy`, on success `invalidate(myCareerProvider)` and pops the sheet; on `DioException` shows the server message or "Couldn't save. Check your connection and try again."
3. State: `myCareerProvider` (local-first) for self, `careerProvider(userId)` for others. Not optimistic.
4. API: `GET /organizations/search?type=COMPANY|INSTITUTION&q=`, `GET /users/{userId}/career`, `POST /career`, `PUT /career/{id}`, `DELETE /career/{id}`. \1}` (also accepts optional `location` and `description`).
5. Backend: `CareerController` -> `CareerService`: `apply()` rejects end before start; maps `kind` to `OrgType` (WORK -> COMPANY, EDUCATION -> INSTITUTION); `resolveOrganization`: picked id must exist and match the type, otherwise typed name is normalized with `NameKeys.of` and reused or created as an UNVERIFIED `Organization`; WORK titles link to a known `JobTitle` when one matches. `update`/`delete` use `ownedEntry` (404 missing, 403 not owner). `list` hides `isHidden` entries from non-owners.
6. DB: `career_entries`, `organizations` (unique `(type, name_key)`, `uq_org_type_key`), `job_titles` (V26).
7-8. Entry appears in the Journey timeline; hidden entries show to the owner only.
9. Other users: see non-hidden entries on next load.
10. Failure: server error text in the sheet; onboarding saves career best-effort and tells the user to add it later from the Journey tab if it failed.
11. Concurrency: two users adding the same new organization at the same instant can hit the unique key once (documented in code, user retries; 409).
12. Security: owner checks on mutate; `isHidden` filter on read. There is NO block check, Private check or deleted-account check on `GET /users/{id}/career` (see Risks).

## 8. Data export

1. User action: Settings -> "Download my data".
2. Frontend: `profile_tab.dart` `_export()` -> `AccountRepository.exportMyData` (`features/settings/data/account_repository.dart`) -> `Share.share(JSON pretty-printed, subject: "My APS Brats data")`.
3. State: `_exporting` flag only.
4. API: `GET /users/me/export` -> `AccountExportDto` (format label, timestamp, profile, schools, social links, settings).
5. Backend: `UserController.exportMyData` -> `AccountService.export` (read-only transaction): live user (404 if deleted) -> `UserSchoolHistoryService.getSchoolHistory`, `UserSocialLinkRepository.findAllByUser_IdOrderByCreatedAtDesc` (including hidden links), `UserSettingsService.get`.
6. DB: reads only.
7-8. OS share sheet opens with the JSON text.
9. Other users: none.
10. Failure: snackbar "Couldn't prepare your data. Try again." GET is auto-retried on transient errors.
11. Concurrency: read-only.
12. Security: owner-only by construction ("me"). Does NOT include career entries, posts, messages, connections, blocks, reports or notifications (see Risks; relevant to the DPDP right of access the code comment cites).

## 9. Delete account

1. User action: Settings -> "Delete account" -> confirm dialog ("can't be undone").
2. Frontend: `_deleteAccount()` -> `AccountRepository.deleteMyAccount` -> on success `AuthController.logout()` then `AppRoot.restart`. On failure `_deleting=false`, snackbar with server text.
3. State: `_deleting`; entire provider scope is dropped by the restart.
4. API: `DELETE /users/me`.
5. Backend: `AccountService.deleteAccount` (one transaction): live user -> delete `user_school_history` and `user_social_links` rows -> soft-delete and anonymize: `deletedAt=now`, username `deleted_<id>`, phone = id, email `deleted+<id>@deleted.invalid`, null out bio, city, profession, gender, dob, avatar, website, `fcmToken`, `passwordHash`, `isVerified=false`. Name is kept on purpose so old posts and messages still show an author. Insert `account_deletions (user_id, request_id)` via `JdbcTemplate` in the same transaction (audit row exists iff deletion happened) -> `AuthService.revokeAllFor` (all sessions die; note this Redis call is inside the DB transaction, so a later rollback would leave sessions revoked) -> log.
6. DB: `users` update, `user_school_history` and `user_social_links` deletes, `account_deletions` insert (no FK, ids/times only). NOT touched: `career_entries`, `user_settings`, `user_blocks`, `connections`, `notifications`, community memberships, posts, comments, chat messages, uploaded avatar files in storage.
7-8. App restarts to the welcome screen.
9. Other users: profile opens as "Unknown user" (`ProfileService` stub); posts and messages remain under the retained full name. `UserRepository` "live" queries exclude deleted users from lists/search.
10. Failure: confirmed error shown, nothing local changed. Server success but local logout failure is handled by `logout()` best-effort plus `clearLocal`.
11. Concurrency: `activeUser` check then write inside a transaction with `@Version`; a double-tap is blocked by the `_deleting` flag; a second call returns 404 "Account not found".
12. Security: owner only; irreversible by design (no grace period or restore). Tokens revoked; re-login with the same email creates a new account.

## 10. Blocked-users list, block and unblock

Block entry points: profile screen menu (`profile_screen.dart` `_SafetyMenu._block`) after a confirm dialog. List and unblock: Settings -> "Blocked users" -> `/home/blocked` (`features/settings/presentation/blocked_users_screen.dart`).

1. User action: block a person from their profile; open Blocked users; tap unblock.
2. Frontend: `features/settings/data/block_repository.dart`: `block`, `unblock`, `blocked`; providers `blockedUsersProvider` (autoDispose). `refreshAfterBlock` invalidates connections, community members, people search, conversations, that profile, and the blocked list.
3. State: after success the screen invalidates and refetches; not optimistic. Block also pops the profile route and shows "<name> is blocked". Unblock errors show `friendlyError`; the list screen has a Retry button on load failure.
4. API: `POST /users/{userId}/block`, `DELETE /users/{userId}/block`, `GET /users/me/blocks` -> `PersonDto[]`.
5. Backend: `BlockController` -> `BlockService.block` (transaction): self-block -> 400; already blocked -> silent return (idempotent); target must exist (404) -> insert `UserBlock` -> `ConnectionService.endForBlock` (ends any live connection or request and records history) -> evict circle cache for both users. `unblock` deletes the row (idempotent). `myBlocks` returns blocked users newest first via `PersonService.toPeople`.
6. DB: `user_blocks` unique `(blocker_id, blocked_id)` (`uq_user_blocks`), index on `blocked_id`; `connections` and `connection_events` updated.
7-8. Blocked person disappears from search, communities member list, chat list, and the profile returns 404 for both directions.
9. Other users: the blocked person gets no notification; they simply stop seeing the blocker (profile 404, hidden in search via `findBlockedIdsInvolving`, hidden-author filters in post feeds).
10. Failure: snackbar. Block POST is retried on transient errors (idempotency key plus the server's idempotent insert).
11. Concurrency: the unique key plus the pre-check make parallel blocks safe; a race throws a unique violation -> 409, harmless.
12. Security: blocker id comes from the token; `/users/*/block` is behind `OnboardingGate`; `GET /users/me/blocks` is NOT in the gate list (an un-onboarded user has none anyway).

## Not implemented (verified by search)
- Change email, change phone, change password.
- UI toggle for `discoverable` (backend enforces it, no screen sets it).
- Per-field privacy or "batchmates only" visibility (V16 created `show_phone` and `batchmates_only`, but V19 dropped both columns and replaced them with a single `is_private`).
- Removing the avatar (only replace) and deleting old avatar files.
- Account deletion grace period / undo; deletion of career entries, posts, messages (by design they stay or are simply not deleted).
- Export of career, posts, messages, connections.
- Admin screen to view users (see moderation doc).

## Risks, bugs, tech debt (file refs)
- `UserSocialLinkService.java` `upsertLink` (line ~62, `isVisible` default TRUE) + `profile_tab.dart:717`: editing a social link resets a hidden link to visible. Privacy bug. Fix: keep the existing value when `isVisible` is null on update.
- `CareerService.java:34` `list` and `CareerController.java` `GET /users/{userId}/career`: no deleted-account, block, or Private checks and not covered by `OnboardingGate`; career entries survive account deletion (`AccountService.java:65-66` only deletes schools and socials) and remain readable by any signed-in user. DPDP erasure gap.
- `UserSchoolHistoryService.java:35` `getSchoolHistory` / `GET /users/{id}/school-history`: only `existsById`; no block check (profile and social-links endpoints have one), so a blocked user can still read that person's schools.
- `AccountService.java:41-92` export omits career, and delete leaves `user_settings`, `notifications`, `user_blocks`, `connections`, memberships and avatar files. Decide whether these need erasure/export under the stated DPDP intent.
- `AccountService.java:~88` `authService.revokeAllFor` (Redis) runs inside the DB transaction; if the commit fails afterwards the user is logged out but not deleted. Minor.
- `UserSchoolHistoryService.replaceSchoolHistory` loads the user without a deleted check (`AvatarService` and `UserService` do filter `deletedAt`), and `UserSocialLinkService.upsertLink` likewise. A deleted account whose token still works for up to 15 min (revoke marker covers it) could write; low.
- `AvatarService.java` never removes the previous object; storage grows.
- `edit_profile_screen.dart` does not send `email` so the server's email check is only defensive; fine. `UpdateProfileRequest.java:11` Javadoc still says "Phone is the login credential"; stale.
- `ProfileRepository.setPrivate` etc. are PUT without auto-retry: a transient failure shows a snackbar and the toggle snaps back after refetch (acceptable).
- Settings are "last write wins" (no version); fine for three booleans.
- `CareerController` organization autocomplete has no per-user rate limit beyond the global one; a user can seed many UNVERIFIED organizations (`CareerService.resolveOrganization`). Moderation of `organizations.status` not implemented in the app.

## Discrepancies with existing docs
- `CLAUDE.md` mentions `RegisterUserRequest`; code has `UpdateProfileRequest` (with validation annotations) and no register endpoint.
- `docs/API.md` lists `POST /users` register and `PUT /users/{id}/password`; neither exists. Missing from docs: `PUT /users/me`, `GET/PUT /users/me/settings` (`showActivity` and `isPrivate`), `GET /users/me/export`, `DELETE /users/me`, `POST /users/me/avatar`, career endpoints, block endpoints.
- `docs/DATABASE.md` does not document `user_settings` at all (the V16 table and the V19 and V31 changes are missing); the live entity uses `is_private`, `discoverable`, `show_activity`.
- Existing privacy docs that mention three visibility levels are stale; only Public/Private exists.
