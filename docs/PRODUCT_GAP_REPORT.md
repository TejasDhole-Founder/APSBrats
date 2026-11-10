# APS Brat — Product Gap Report

Written 2026-10-02 from the code as it is today (frontend `frontend/lib`, backend `apsbrat-api`), not from the older docs.
`docs/ROADMAP.md` and `docs/PRODUCTION-READINESS.md` are **out of date**: they still list WebSocket chat, OTP rate limiting, refresh-token rotation, block/report endpoints, account export, pagination, API versioning, Docker and CI as missing. All of those exist now. Update or retire them.

Legend: ✅ working with real data · 🟡 partly working · ❌ missing or placeholder · 🐞 bug

---

## 1. The honest picture in one table

| Area | Backend | Frontend | Verdict |
|---|---|---|---|
| Login (email OTP + Google) | ✅ | ✅ | Works, but the OTP email is never actually sent |
| Onboarding | ✅ | ✅ | Works; no terms, no age check |
| Home tab (activity feed) | ✅ `FeedController` | ❌ shows demo/empty only | **Built on the server, never connected** |
| Batchmates tab | ✅ | ✅ | Strongest screen; a few rough edges |
| Direct messages + chat | ✅ | ✅ | Live and real-time; missing the extras |
| Communities | ✅ full CRUD + messages | ❌ still `dummyCommunities` | **Built on the server, never connected** |
| Profile tab | ✅ | ✅ | Works; labels out of date, no photo upload UI |
| Other person's profile | ✅ | 🟡 | No Message button |
| Notifications | 🟡 | 🟡 | New chat messages never create a notification |
| Search screen (`/home/search`) | ✅ | ❌ empty stub, nothing links to it | Dead route |
| Classroom (`/home/classroom/:id`) | ❌ no backend | ❌ stub | Dead route |
| Safety (block/report/delete) | ✅ endpoints | ❌ no UI at all | **Launch blocker** |
| Push notifications | ❌ | ❌ | Missing |
| Photo upload | ✅ `AvatarController` | ❌ no picker wired | Missing in the app |

---

## 2. Screen by screen

### A. Welcome / Login / Onboarding
Sub-screens: Splash → Welcome → Login (email code, Google) → Onboarding identity → Schools → Socials.

**Pending / must add**
- **Send the login code by email.** `AuthService.java:73` still says `TODO: send the code by email`. Today only the backend log shows the code, so no outside user can sign in.
- **Terms and privacy consent screen** before the account is created. Nothing like it exists.
- **Age / date-of-birth gate.** APS students are minors; DPDP Act §9 needs parental consent under 18. No age is collected during onboarding.
- Remove the **"Skip login (dev)"** button before any release build.

**Upgrade**
- Resend-code timer and an "edit email" link on the code step (the backend already enforces a 60 s cooldown, so show it).
- Save onboarding progress so closing the app mid-way resumes at the same step (the router already resumes at `/onboarding`; confirm it restores the half-filled schools).
- Tell users *why* each step is asked ("so we can find your batchmates").

### B. Home tab
Sub-screens: Home feed, Notifications, (bell).

**Pending / must add**
- **Wire the activity feed.** `feed_repository.dart` and `GET /feed/activity`, `/feed/recent-joins`, `/feed/banner` exist, but `home_tab.dart` reads `dummyRecentJoins` and shows "Nothing in your feed yet" forever. This is the first screen every user sees, so right now it looks empty.
- **Chat messages should create a notification.** `NotificationType.MESSAGE` exists, but `ChatService` never creates one, so the bell never reflects new messages.
- Notification tap should open the right place: chat for a message, requests for a connection request (today it only opens a profile).

**Upgrade**
- Pull-to-refresh and skeleton loaders on the feed.
- An empty state with a next action ("Find your batchmates", "Complete your schools") instead of a dead end.
- Show an unread count on the bell.

### C. Batchmates tab (Friends · Classmates · Batchmates)
Sub-screens: segments, search + filters, requests, someone's profile, edit schools.

**Pending / must add**
- **Fix the "Batchmates: 14" stat on your profile.** It currently shows your connection count (same number as "Connected"), not real batchmates.
- Make the profile **"Connected" count tappable** → opens the Friends list (it is plain text today).
- **Message button on another person's profile** (`profile_screen.dart` has none), plus Connect / Pending / Accept states if not already there.
- **Block and Report** in the profile's "…" menu.

**Upgrade**
- Explain the three segments once ("Classmates = same section and years. Batchmates = same school"), e.g. a small info sheet.
- "People you may know" ordering is already ranked by mutual friends; show *why* ("4 mutual · same 12A").
- Remove or finish the unused `/home/search` stub and `_HintCard`.

### D. Messages tab
Sub-screens: Direct messages list, Chat screen, Communities list, Community chat.

**Direct messages**
- ✅ Real list, search, live updates, unread badges.
- **Pending:** online presence (the green dot never lights, `online` is never set to true), typing indicator, "seen" receipts, photo messages, **push notification when the app is closed**.
- 🐞 **Blocked users can still message you** (`ChatService` never checks blocks).
- The filter button beside search does nothing yet; make it "Unread only / Sort".
- A "New message" button (the pencil in the header) opens nothing: it should open a picker of your friends.
- Message long-press: copy, delete for me, report.

**Communities**
- ❌ **Frontend is entirely demo data.** The backend already has joins, leave, discover, unread counts and messages.
- Needs: communities list from the API, Discover/Join, a community chat screen, member list, leave.
- Note: when we removed the old realtime layer, community messages lost their live push. Rebuilding that (a STOMP topic per community) is a good learning task.

### E. Profile tab
Sub-screens: About, Schools, Socials, Settings sheet, Edit profile, Edit schools.

**Pending / must add**
- **Photo upload.** Edit profile promises "Name, photo, bio" but there is no photo picker; the repository's `uploadAvatar` is never called. Web also needs bytes upload, not a file path.
- **Fix stale labels:** "Phone · used to log in" with a green Verified badge, while email shows "Not verified". Login is email now: mark email as the login identity and verified, make phone an optional plain field.
- **Delete account** and **Download my data**: the backend endpoints exist, there is no button (DPDP right to erasure and access).
- Settings → **Help & FAQ** and **Report a problem** do nothing (`onTap: () {}`).
- **Blocked users** list with Unblock.

**Upgrade**
- Show how complete the profile is ("80% complete, add a photo") with a nudge.
- Privacy toggle explanation ("Private hides your phone and socials; your name and schools stay visible").
- "Log out of all devices" (see the auth course, Chapter 9).

### F. Cross-cutting
- **Safety:** block, report, mute, report-a-message UI. Admin/moderation console (endpoints exist: `AdminController`, reports, suspend/ban).
- **Push notifications (FCM):** the `fcm_token` column exists, nothing registers or sends. This is what brings people back.
- **Offline / slow network:** no local cache anywhere (`shared_preferences` is unused). Cache the last conversations and feed and show them while refreshing (stale-while-revalidate).
- **Photo and media safety:** strip EXIF/GPS from uploads (military-family privacy), size limits, scanning.
- **Security bugs from the auth course:** a refresh token works as an access token (Ch. 4); blocking not enforced in chat (Ch. 7); banned users keep access up to 15 min (Ch. 8).
- **Ops:** `Dockerfile` and `.github/workflows/ci.yml` exist. Still missing: staging/prod environments, secrets, backups, monitoring/alerts, crash reporting.
- **Tests:** 14 test files. Add integration tests with Testcontainers for chat, auth and connections.

---

## 3. What to build, in order

**P0, before any real user**
1. Email delivery for the login code.
2. Terms/privacy consent + age gate.
3. Block / Report / Delete-account UI, and make chat respect blocks.
4. Fix the refresh-token-as-access-token bug.
5. Wire the Home feed and Communities (two main areas that are empty today).

**P1, makes people stay**
6. Push notifications (chat, connection requests, joins) and notification-per-message.
7. Profile photo upload + show photos in avatars (the avatar widget already supports it).
8. Message button on profiles; tappable counts; fix "Batchmates" stat and stale phone/email labels.
9. Presence, typing and seen receipts.
10. Local cache for Messages and Home.

**P2, gives a reason to open the app**
11. **Reunions / Events** (create, RSVP, "who's going", reminder the day before).
12. Memory nudges ("you left APS Patiala 3 years ago") instead of hard-coded text.
13. Semantic people search (pgvector) from the old roadmap's AI section.
14. Photo messages and photo albums per batch.

---

## 4. Easy workflow: small changes with a big effect
- Every list gets: pull-to-refresh, skeleton loader, an empty state with one clear next action, and an error state with Retry.
- One "Message" button everywhere a person appears (profile, friend row, search result).
- Notifications deep-link to the exact screen.
- The "…" menu on a person is the one place for Block, Report and Mute.
- Show counts that mean what they say, and make them tappable.
- Delete the dead routes (`/home/search`, `/home/classroom/:id`) and the leftover demo overlays (`ChatOverlay`, `BatchmateOverlay`) so nothing misleading is reachable.
- Keep header style consistent: crimson on the 4 main tabs, plain app bar on drill-in screens.
