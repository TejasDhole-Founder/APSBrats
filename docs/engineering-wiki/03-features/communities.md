# Communities
School and interest communities: discover, create, join/leave, owner tools, members, events, memories, and the Social tab that hosts them.
Group chat inside communities has its own doc; this file covers it only where it touches the community screen.

Last verified: 2026-11-16 against commit 168d987 (working tree has uncommitted changes)

## 1. Concepts and map

| Concept | Rule (code) |
|---|---|
| SCHOOL community | One per school, created by migration V27 (`INSERT ... SELECT FROM schools`, visibility `OPEN`, `school_id` UNIQUE). No owner (`created_by` NULL, nobody has role OWNER). Visible only to people who list that school in their school history; anyone else gets 404 (`CommunityService.visibleCommunity`). |
| INTEREST community | Created by any user (max 5 per user, `MAX_CREATED_PER_USER`). Creator becomes OWNER. Name unique (case/space-insensitive) via `name_key` + partial unique index `uq_interest_community_name`. Visibility `OPEN` (anyone joins, anyone reads) or `PRIVATE` (join needs owner approval, only members read posts). |
| Roles | `community_members.role` = `OWNER` or `MEMBER`. App-wide staff (ADMIN/MODERATOR in the JWT) can moderate posts/comments/events anywhere but cannot delete a community or manage requests (those need `requireOwner`). |

Backend (`apsbrat-api/src/main/java/com/apsconnect/api/community/`): `CommunityController` (`/api/v1/communities/...`), `CommunityService`, `CommunityEventController` + `CommunityEventService`, `PostController`/`PostService` (memories), entities `Community`, `CommunityMember` (composite key), `JoinRequest`, `CommunityEvent`, `EventRsvp`; repositories alongside.
Frontend (`frontend/lib/features/community/`): data `community_repository.dart` (`CommunityRepository` + providers), `community_models.dart`; UI `communities_tab.dart`, `my_communities_screen.dart`, `community_screen.dart`, `event_screen.dart`, `memories_screen.dart`, `community_ui.dart`. Social tab host: `frontend/lib/features/feed/presentation/widgets/messages_tab.dart`. Routes: `frontend/lib/core/routes/` (`communities`, `community/:id`, `community/:id/chat`, `event/:id`, `post/:id` under `/home`).

Tables (V27, V32, V33, V35): `communities`, `community_members` (PK community_id+user_id, role CHECK, `idx_community_members_user`), `community_join_requests` (PK community_id+user_id), `community_events`, `event_rsvps` (PK event_id+user_id, status CHECK GOING/INTERESTED), `posts` (memory columns). All child tables use `ON DELETE CASCADE` to `communities`/`users` (events set `posts.event_id` to NULL).

Common behaviour (see `posts-comments-likes.md` section 1 for the full list): JWT required on all endpoints; envelope `ApiResponse`; every POST gets a Dio `Idempotency-Key` and is replayed by `IdempotencyFilter`; errors surface through `friendlyError()`; no WebSocket events exist for community membership or events (REST only); `AppException` -> JSON error with `code` and `requestId`, race violations of unique keys become 409 (`GlobalExceptionHandler`).

Community DTO (`CommunityDto`): id, type, name, description, visibility, memberCount, myRole (null if not a member), requested (I have a pending join request). The Flutter `Community` model derives `isSchool`, `isPrivate`, `isMember`, `isOwner`, `requested` from it. `member_count` is a stored counter updated with a relative SQL update (`CommunityRepository.addToMemberCount`) on every add/remove, so concurrent joins both count.

---

## 2. Screens and navigation

- Social tab (bottom nav "Messages" slot): `messages_tab.dart` `MessagesTab` has a header "Social" and a segmented control `['Messages','Communities']` (`_SegmentedControl`). The segments live in an `IndexedStack`; the Communities segment (`CommunitiesTab`) is built lazily on first tap (`_communitiesVisited`) and then kept alive. Messages = DM list (chat doc).
- `CommunitiesTab` (`communities_tab.dart`): search box (300 ms debounce, `_onSearch`), "+" create button, sections "Your Schools" (joined school communities followed by `suggested` ones: schools in my history I have not joined), "Your Communities" (horizontal chips of joined interest communities, "See all" -> `/home/communities`), "Discover Communities" (results of `GET /communities/discover`, hiding ones I am in when the box is empty; with a query it shows everything that matches).
- "Your Communities" see-all (`MyCommunitiesScreen`, route `/home/communities`): reads the same `myCommunitiesProvider`, filter chips All / Joined / Requested / Owned with counts, local name filter, each row a `CommunityTile(menu: true)` with "Open" and (members who are not owners) "Leave community".
- `CommunityScreen` (`community_screen.dart`, route `/home/community/:id`): collapsing header + `TabBar`.
  - School community tabs: Feed, Events, Memories, Members. Chat opens from the header button (separate route).
  - Interest community tabs: Feed, Chat (embedded `CommunityChatScreen`, or "Join to chat" for non-members), Events, Members.
  - Private community and not a member: no tabs, "Members only" placeholder ("Ask to join..." or "You'll see the posts once the owner approves your request.").
  - Pull-to-refresh on the Feed tab invalidates `communityProvider`, `communityEventsProvider((id,false))` and reloads the post feed. Other tabs have their own providers.
  - App bar: Share (text only: "Join <name> on APS Brats..."), and for owners an `_OwnerMenu` (Join requests - private only, Delete community).

---

## 3. Discover and search communities
1. **User action**: types in the search box on the Communities segment, or just opens it.
2. **Frontend**: `_CommunitiesTabState._onSearch` (debounce 300 ms) sets `_query`; the list watches `discoverProvider(_query)` (autoDispose `FutureProvider.family<List<Community>,String>`) -> `CommunityRepository.discover`.
3. **State**: the query string is widget state; each distinct query is a separate cached provider entry. No optimistic updates; `RefreshIndicator` calls `_refresh` (invalidates `myCommunitiesProvider` and `discoverProvider`).
4. **API**: `GET /communities/discover?q=<text>` -> `List<CommunityDto>` with `myRole` and `requested` filled for the caller.
5. **Backend**: `CommunityService.discover` loads my memberships and join requests, then `CommunityRepository.findTop20ByTypeAndNameKeyContainingOrderByMemberCountDescNameAsc(INTEREST, NameKeys.of(q))` (`career/NameKeys.java` lower-cases and strips spaces/punctuation; blank q matches everything).
6. **Database**: `communities` (index `idx_communities_name_trgm` on `LOWER(name)`; note the query filters on `name_key`, so that trigram index is probably unused, UNVERIFIED), `community_members`, `community_join_requests`.
7. **Response**: list rendered in a card of `CommunityTile`s.
8. **UI**: tiles show name, kind label, member count and a pill: Owner / Joined / Requested / Join / Request.
9. **Other users**: n/a (read).
10. **Failure**: `_ErrorRow` with message and retry; empty search shows "Nothing found ... You could create it."
11. **Concurrency**: n/a.
12. **Security**: authenticated only; SCHOOL communities are never returned (type filter INTEREST). Private interest communities ARE listed (name, description, member count) so people can ask to join. Result capped at 20, no paging.

`GET /communities/mine` (`CommunityService.mine`) returns three lists: `joined` (schools first, then by name), `suggested` (school communities of my schools I am not in), `requested` (pending join requests). Used by the Social tab and the see-all screen.

---

## 4. Create an interest community
1. **Action**: "+" on the Communities segment -> bottom sheet "Create a community": name (3-60), optional description (<= 500), Private switch.
2. **Frontend**: `_CreateSheetState._create` (`communities_tab.dart`) -> `CommunityRepository.create` (visibility `PRIVATE`/`OPEN`).
3. **State**: sheet-local `_busy`/`_error` (inline red text). Not optimistic. Success invalidates `myCommunitiesProvider` and `discoverProvider`, closes the sheet and pushes the new community screen.
4. **API**: `POST /communities` body `{name, description?, visibility}` (`CreateCommunityRequest`; `@Size(3..60)`, `@NotNull visibility`) -> `CommunityDto`.
5. **Backend** (`CommunityService.create`, transactional): trim; `NameKeys.of(name)` must be >= 3 chars (400); `countByCreatedByAndType(user, INTEREST) >= 5` -> 400; `existsByTypeAndNameKey` -> 409 "A community with this name already exists"; save `Community` (type INTEREST, createdBy me); `addMember(OWNER)` (insert member + `member_count + 1`); return `get()`.
6. **Database**: INSERT `communities`, INSERT `community_members`. Constraints: `chk_community_type`, `chk_community_visibility`, `chk_community_school` (SCHOOL iff school_id set), unique `uq_interest_community_name` (partial, `WHERE type='INTEREST'`).
7-8. Sheet closes, new community opens with the creator as Owner.
9. **Other users**: appear in Discover on their next load; no notification.
10. **Failure**: error text in the sheet (409 name taken, 400 limit). Dio retries keyed POST on transient errors; the idempotency filter prevents a duplicate.
11. **Concurrency**: the 5-limit and name checks are check-then-insert. Two simultaneous creates of the same name: the unique index rejects one (`DataIntegrityViolationException` -> 409 generic "This action conflicts with existing data"). Two simultaneous creates by one user could exceed 5 (no lock). Low risk.
12. **Security**: any authenticated user; limits enforced server-side only. No profanity/impersonation filter (UNVERIFIED), and names such as a school's name are allowed because uniqueness applies to INTEREST names only.

---

## 5. Join and leave

### 5.1 Join (open / school) and request to join (private)
1. **Action**: taps Join / Request on a tile (`CommunityTile`, `_joinCommunity`) or on the community header (`_HeaderState._join`).
2. **Frontend**: `CommunityRepository.join(id)`. After success: tile path invalidates `myCommunitiesProvider` + `discoverProvider`; header path (`_run`) also invalidates `communityProvider(id)`, `postFeedProvider('')` (Home) and `postFeedProvider(id)`.
3. **State**: not optimistic; header buttons use `_busy`. Server answer decides: `updated.requested` true -> snackbar "Request sent. The owner will review it."
4. **API**: `POST /communities/{id}/join`, no body -> `CommunityDto` with `myRole` set (joined) or `requested=true`.
5. **Backend** (`CommunityService.join`, transactional): `visibleCommunity` (404 if SCHOOL and I do not list that school); if not already a member: PRIVATE -> insert `JoinRequest` unless one exists; OPEN/SCHOOL -> `addMember(MEMBER)` + `member_count + 1`; return `get()`. Calling it twice changes nothing (idempotent by the `existsById` checks).
6. **Database**: `community_members` or `community_join_requests`; `communities.member_count`.
7-8. Button flips to Joined / Requested; for open communities the feed and tabs unlock.
9. **Other users**: owner is NOT notified of a new request (no `NotificationService` call in `CommunityService`, verified by grep); they must open "Join requests". The requester is also not notified of approve/reject.
10. **Failure**: snackbar via `friendlyError`; 404 for ineligible school community.
11. **Concurrency**: two simultaneous joins can both pass `existsById`; the PK `(community_id,user_id)` rejects the second with a 409. Count uses relative SQL update.
12. **Security**: eligibility via school history for school communities; private join cannot bypass approval because `join` never adds a member to a PRIVATE community. No per-action rate limit beyond the global 300/min.

### 5.2 Leave
1. **Action**: header "Leave" (confirm dialog; wording differs for private communities) or tile menu "Leave community" (`CommunityTile._leave`, plain dialog).
2. **Frontend**: `CommunityRepository.leave(id)` -> `DELETE /communities/{id}/members/me`. Header path invalidates community, my-communities, discover, Home feed; the tile path invalidates my-communities, `myCommunityChatsProvider`, discover (it does NOT invalidate the Home feed, so posts from the left community can stay on Home until it is rebuilt).
3. **State**: not optimistic.
4. **API**: `DELETE /communities/{id}/members/me` -> message "Left the community".
5. **Backend** (`CommunityService.leave`): membership must exist (404) ; OWNER cannot leave (400 "Owners can't leave their own community"); delete member row; `member_count - 1`.
6. **Database**: `community_members` delete; own posts/comments/likes stay.
9. **Other users**: member count changes on their next fetch. After leaving a private community the user needs approval again.
10-12. Errors as snackbar; second leave -> 404; owner restriction is server-side.
Also: `CommunityService.dropSchoolsNoLongerListed` removes school-community memberships when a user edits their school history and no longer lists that school.

---

## 6. Owner actions

### 6.1 Join requests: list, approve, reject (private communities)
1. **Action**: owner menu "Join requests" (shown only for private) -> `JoinRequestsScreen` (`/home/community/:id/requests`); approve/reject one or several (`_decide(userIds, approve:)`).
2. **Frontend**: `joinRequestsProvider(id)` -> `CommunityRepository.requests`; decide -> `decide(id, userId, approve:)`. After: invalidate `joinRequestsProvider(id)` and `communityProvider(id)` (member count).
3. **State**: not optimistic; list refetched.
4. **API**: `GET /communities/{id}/requests` -> `JoinRequestDto[] {person, createdAt}`; `POST /communities/{id}/requests/{userId}/approve|reject` -> message.
5. **Backend**: `requireOwner` (membership role OWNER else 403) in every method; `requests` builds all person cards in one batch (`PersonService.toPeople`); `approve` deletes the request then `addMember(MEMBER)`; `reject` deletes the request (404 if the request does not exist).
6. **DB**: `community_join_requests` delete, `community_members` insert, `member_count + 1`.
9. **Other users**: the requester is not notified; they see Joined the next time they load.
10. **Failure**: snackbar; approving twice -> 404.
11. **Concurrency**: delete + insert in one transaction; PK prevents duplicate member rows.
12. **Security**: owner only. Blocked users are not filtered out of the request list (UNVERIFIED).

### 6.2 Remove a member
- `DELETE /communities/{id}/members/{userId}` -> `CommunityService.removeMemberAsOwner`: `requireOwner`; cannot remove yourself (400 "delete the community instead"); target must be a member (404); delete row, `member_count - 1`.
- Frontend: `CommunityRepository.removeMember` exists but nothing in `frontend/lib` calls it (grep verified), so owners cannot remove a member from the app today; the endpoint is API-only. No notification to the removed user; no ban list, so they can rejoin an OPEN community immediately (a PRIVATE one needs a new request).

### 6.3 Delete community
1. **Action**: owner menu -> "Delete community" -> confirm "All its posts and members go with it. This can't be undone."
2. **Frontend**: `_OwnerMenu._delete` -> `CommunityRepository.delete` -> invalidates `myCommunitiesProvider`, `discoverProvider`, `postFeedProvider('')`, then `router.go('/home')`.
4. **API**: `DELETE /communities/{id}` -> "Community deleted".
5. **Backend**: `requireOwner` then `communityRepository.delete` (hard delete).
6. **DB**: `ON DELETE CASCADE` removes members, join requests, posts (then their likes/comments), events (then RSVPs), and community chat rows (UNVERIFIED for chat tables, see V31). Stored photos are not deleted.
9. **Other users**: community disappears from their lists on next fetch; open screens get 404 "Community not found".
11. **Concurrency**: n/a. 12. **Security**: owner only; school communities have no owner so nobody (not even staff) can delete one through this API.

### 6.4 Owner moderation of content
Owners can delete any post/comment in their community and pin up to 3 posts (`PostService.canModerate`, `setPinned`), see `posts-comments-likes.md`.

---

## 7. Members directory
1. **Action**: Members tab; search by name, optional batch (passing-out year) filter, "show more".
2. **Frontend**: `_MembersTab` (`community_screen.dart`) watches `communityMembersProvider((communityId,q,batch,page))` for each loaded page (`_pages` grows by one); search is debounced; actions per person (message / connect / accept) call the chat or connection repositories and invalidate `communityMembersProvider`.
4. **API**: `GET /communities/{id}/members?q&batch&page&size` (size default 30, max 50) -> `PersonDto[]`.
5. **Backend** (`CommunityController.members`): `requireReadable` (private + non-member -> 403), then `PeopleSearchService.search(..., communityId=id, ...)`: same SQL as people search (`UserRepository.searchPeople`) with an `EXISTS` on `community_members`. In a school community `batch` is matched against `batch_end` of that school only. Excludes deleted, banned, non-discoverable users, me, and blocked pairs (details in `feed-search-discovery.md`).
10-12. Errors show retry; a user who set `discoverable = false` is hidden from the directory even though they are a member (privacy choice wins).
- Header avatars use the same endpoint (first page, empty query).

---

## 8. Events

Rules in `CommunityEventService` (all endpoints `/api/v1`): list `GET /communities/{id}/events?when=upcoming|past` (upcoming limit 50, past limit 30, no paging) returns `{events, canCreate}`; `GET /events/{id}`; create `POST /communities/{id}/events`; edit `PUT /events/{id}`; cancel `POST /events/{id}/cancel`; RSVP `PUT /events/{id}/rsvp {status}` and `DELETE /events/{id}/rsvp`; attendees `GET /events/{id}/attendees` -> `{GOING:[..], INTERESTED:[..]}`; event posts `GET /events/{id}/posts`.

### 8.1 Create / edit event
1. **Action**: owner (or staff) taps create on the Events tab, or edit on the event screen; form `_EventForm` (`event_screen.dart`, `showEventForm`) with title, venue, start/end date-time, details, optional cover photo.
2. **Frontend**: `_EventFormState._save` validates first (title >= 3, venue, start, end after start, end in the future) then `CommunityRepository.saveEvent` (POST when new, PUT when `eventId` set). Cover: `_pickCover` -> `uploadPhoto(kind: UploadKind.event)` immediately. After save: invalidate `communityEventsProvider` (upcoming and past) and `eventProvider(id)`.
3. **State**: form-local (`_busy`, `_error`); not optimistic.
4. **API**: body `{title, venue, startsAt, endsAt, description?, coverUrl?}` (`SaveEventRequest`; ISO local date-time with no zone) -> `EventDto` (counts of GOING/INTERESTED, photo count, my RSVP, `canManage`, organizer).
5. **Backend**: `requireReadable` + `requireManager` (community OWNER or staff, else 403 "Only the community owner can manage events"); `apply()` rules: title >= 3, end after start (400), a new/changed end must be in the future, start <= 3 years ahead, duration <= 30 days; cover must be one of my own uploads (`requireOwnUpload`, unchanged cover is kept). Edit refuses cancelled events. If start, end or venue changed, `notifyRsvps` creates a `GENERAL` notification for every RSVP'd user except the editor (`NotificationService.createAll`, ref EVENT).
6. **DB**: `community_events` (`title<=120`, `description<=2000`, `venue<=200`, `starts_at`, `ends_at NOT NULL` since V35, `chk_event_times`, `cancelled`), `notifications`.
9. **Other users**: members see the event after their next fetch; RSVP'd users get an in-app notification on time/venue change (no push).
10. **Failure**: inline error in the form.
11. **Concurrency**: `CommunityEvent` has no `@Version` visible in the code reviewed (UNVERIFIED); two owners editing at once is last-write-wins.
12. **Security**: manager-only; school communities have no owner, so only staff can create events there; `canCreate` in the list response drives the UI button.
- Time zones: `LocalDateTime` is sent without a zone and interpreted in the server zone (JVM `Asia/Kolkata`); a phone in another zone shows/sends wall-clock times (UNVERIFIED for non-IST users).

### 8.2 Cancel event
`POST /events/{id}/cancel` -> `CommunityEventService.cancel` (manager only) sets `cancelled=true` once and notifies RSVP'd users ("Event cancelled"). Frontend `_EventScreenState._cancel` invalidates event + both lists. Cancelled events cannot be edited, RSVP'd (for new status) or tagged by posts. Not reversible in the API.

### 8.3 RSVP
1. **Action**: Going / Interested buttons; tapping my current answer clears it.
2. **Frontend**: `setEventRsvp` (`event_screen.dart`) -> `CommunityRepository.setRsvp(id, status|null)`; invalidates `eventProvider`, `eventAttendeesProvider`, upcoming `communityEventsProvider`.
3. **State**: not optimistic and no in-flight guard (the decision is made from the stale `e.myRsvp`).
4. **API**: `PUT /events/{id}/rsvp {status: GOING|INTERESTED}` or `DELETE /events/{id}/rsvp` -> `EventDto`.
5. **Backend** (`rsvp`): `readableEvent`; `requireMember`; clear = delete row; set requires not cancelled (400) and not over (`endsAt` before now, 400); upsert `EventRsvp` by key.
6. **DB**: `event_rsvps` PK `(event_id,user_id)`, CHECK status.
9. **Other users**: counts and attendee list update on next fetch; the organizer is not notified of RSVPs.
11. **Concurrency**: find-then-save; the PK stops duplicates (a lost race gives 409).
12. **Security**: members only (non-members can read events of OPEN/SCHOOL communities but not RSVP).

### 8.4 Attendees
`GET /events/{id}/attendees` (`attendees`): readable event, drops RSVPs of users blocked in either direction, groups by status in answer order. Shown on the event screen.

### 8.5 Event photos
Members share photos from a started, uncancelled event through the composer (see posts doc 2.3); `EventDto.photoCount` counts ACTIVE posts via `PostRepository.countByEvent`.

---

## 9. Memories gallery (school communities)
- Tab `MemoriesTab` (`memories_screen.dart`): year chips from `memoryYearsProvider(communityId)` (`GET /communities/{id}/memories/years` = distinct years, newest first) and category chips; grid via `memoriesProvider(MemoriesQuery{communityId, year, category})` (`PostFeedNotifier`, `GET /communities/{id}/memories?year&category&cursor&limit=30`). A prompt card opens the composer in memory mode (`asMemory: true`).
- Backend `PostService.memories`: `requireReadable`; page-number cursor; `PostRepository.findMemoryPage` orders by `memory_year DESC, created_at DESC, id`, only `ACTIVE`, blocked authors excluded; index `idx_posts_memories`. Invalid cursor -> 400.
- Interest communities have no Memories tab and the server rejects memory posts there.
- Created by memory posts only (see posts doc 2.2). Deleting a memory from its post screen invalidates `memoriesProvider`.

---

## 10. Not implemented / not found (verified by search)
- Remove member from the UI: backend endpoint exists, no screen calls `removeMember`.
- Promote/demote moderators or transfer ownership: roles are only OWNER/MEMBER; no endpoint changes them.
- Edit community name/description/visibility: no `PUT /communities/{id}` (the controller has no update method).
- Ban / block a member from a community, or invite links / invitations: none. Share is plain text.
- Notifications for join requests, approvals, rejections, removal, or RSVPs: none (only event time/venue change and cancellation notify RSVP'd users, and comments notify post authors).
- Real-time (WebSocket) updates for membership or events: none; only chat uses STOMP.
- Paging for discover (top 20) and for events (50 upcoming / 30 past): none.
- Event reminders, recurring events, event comments: none found.
- Per-community search of posts: none.

## 11. Risks and findings
- Account deletion (`user/AccountService.java:62` `deleteAccount`) soft-deletes the user but does not remove community memberships, so `member_count` stays inflated and a deleted owner leaves an ownerless community that nobody can moderate except staff. Memberships also survive `deleteAllByUser_Id` of school history (school-community members stay in after deleting their account).
- Owner is not notified of join requests (`CommunityService.join`) so private communities rely on the owner opening the requests screen.
- `CommunityTile._leave` (`communities_tab.dart` ~line 567) does not invalidate the Home feed, unlike the header path.
- Check-then-insert limits (5 communities per user, name uniqueness) rely on DB constraints only for the name.
- Discover includes private communities' descriptions and member counts to everyone (design choice, verify product intent).
- No pagination on `GET /communities/{id}/requests` (can be large for a popular private community).
