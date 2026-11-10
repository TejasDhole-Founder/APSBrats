# Communities — Plan and Hands-On Course

Two kinds of community:
- **School communities**: one per APS school, created automatically. Your schools are **suggested**; you join if you want. Only people with that school in their history can join.
- **Interest communities**: created by users ("Software Developers", "Lawyers", "NDA Aspirants"). **Open** ones anyone can join; **Private** ones need the owner's approval.

Members post text, like (♥) and comment. Home shows the newest posts from all your communities.

Written 2026-10-02; rewritten 2026-10-04 after the old community chat was deleted (V25), the career timeline was added (V26), and Tejas chose interest communities, text-only v1 and a newest-first Home.

---

## Part 0 — Tutor rules (for any AI agent guiding Tejas)

1. **Backend (`apsbrat-api/`) is copy-paste only.** Never edit it. Give the file path, an anchor, the code, and a beginner-friendly explanation directly under **every** code block. Tejas pastes it. Read-only checks are fine (`mvn -o test`, curl, `psql`).
2. **Before handing over the next step, compile it together with every earlier step in a scratch copy** (`mvn -o test`, and boot the app if entities changed). Never hand over code that hasn't been compiled.
3. **Frontend (`frontend/`) the tutor may edit directly**, but must narrate what changed and why.
4. One step at a time. Wait for "done". Teach the idea first, then the code.
5. Read the real code before each step; this plan may drift.
6. Every chapter ends with a **Checkpoint** (prove it works) and **Check yourself** questions.
7. **Never edit an applied Flyway migration.** V25 and V26 are taken; this course starts at `V27`.
8. Update the Progress Tracker at the bottom after each checkpoint.
9. Test tokens: `POST /api/v1/auth/verify-otp` with `{"email":"arjun.singh@example.com","code":"000000"}` (dev master OTP).

---

## Part 1 — The plan

### 1.1 Decisions

| # | Decision | Choice |
|---|---|---|
| D1 | Kinds | **SCHOOL** (one per school, automatic) and **INTEREST** (user-created). No school+batch groups. |
| D2 | School membership | **Opt-in (changed 2026-10-04).** Your schools are suggested with a Join button; joining requires that school in your history. Leave anytime. Removing a school from your history also removes you from its community. |
| D3 | School visibility | **Open, but only for that school's students** (stored as `visibility='OPEN'`). Students with the school in their history can see it, read posts and join instantly (no owner, so no approvals). Everyone else gets 404 (not 403), so existence isn't leaked. |
| D4 | Interest visibility | **OPEN**: anyone can read and join instantly. **PRIVATE**: name + description visible in search; posts members-only; joining sends a request the owner approves. |
| D5 | Creating | Any user, **max 5** interest communities each. Names unique (case/punctuation-insensitive, reusing `NameKeys`). |
| D6 | Roles | `OWNER` (creator) and `MEMBER`. Owner approves requests, removes members, deletes posts. App `ADMIN`/`MODERATOR` can do everything everywhere. |
| D7 | Posts in v1 | **Text only** (max 2,000 characters). Photos later. |
| D8 | Engagement | Instagram-style: a heart (Like) and flat comments. Nothing else. |
| D9 | Reports | Reasons: `SPAM`, `INAPPROPRIATE`, `NOT_RELEVANT`, `HARASSMENT`, `PRIVACY`, `OTHER`. **3 different reporters auto-hide** a post until reviewed. |
| D10 | Home tab | **Newest first** across all my communities. No ranking in v1. |
| D12 | Visibility wording | Code and database say `OPEN` / `PRIVATE`; the app always shows **"Public"** / **"Private"** (translate `OPEN` → "Public" in Flutter). |
| D11 | Where in the app | A new **Communities** bottom tab: My communities, Discover, Create. |

### 1.2 What already exists (reuse it)

| Need | Already there |
|---|---|
| Schools | `schools` table (138 rows). |
| School history | `UserSchoolHistoryService.replaceSchoolHistory(userId, request)` — **deletes and rewrites all entries**, so membership is recalculated from the full list each time. |
| Duplicate-proof names | `career/NameKeys.of(name)` — lowercases, strips punctuation and "Pvt Ltd". |
| Cursor paging | `CursorSupport` (used by chat). |
| Reports | `Report` + `ReportTargetType {USER, MESSAGE}`, `AdminService.resolveReport`. |
| Blocks | `BlockService` / `UserBlockRepository`. |
| Notifications | `NotificationService.create(...)`. |
| People DTOs in bulk | `PersonService.toPeople(users)` (avoids N+1). |

### 1.3 Data model (migration `V27`)

```
communities              id, type ('SCHOOL'|'INTEREST'), school_id UNIQUE NULL, name, name_key,
                         description, visibility ('OPEN'|'PRIVATE'), created_by, member_count, created_at
                         CHECK: SCHOOL rows have school_id, INTEREST rows don't
                         UNIQUE (name_key) for INTEREST rows
community_members        community_id, user_id, role ('OWNER'|'MEMBER'), joined_at
                         PRIMARY KEY (community_id, user_id)
community_join_requests  community_id, user_id, created_at           PRIMARY KEY (community_id, user_id)
posts                    id, community_id, author_id, body, status ('ACTIVE'|'HIDDEN'|'REMOVED'),
                         like_count, comment_count, created_at, version
post_likes               post_id, user_id, created_at                PRIMARY KEY (post_id, user_id)
comments                 id, post_id, author_id, body, status, created_at
```

- One community row is inserted for each of the 138 schools by the migration itself.
- Counters (`member_count`, `like_count`, `comment_count`) live on the row and change with `UPDATE ... SET x = x + 1`, so screens never `COUNT(*)` big tables.
- A join request is deleted when approved (a member row is added) or rejected. No history table in v1.

### 1.4 API

| Method | Path | Who | Notes |
|---|---|---|---|
| GET | `/communities/mine` | me | Communities I've joined, plus `suggested`: my schools' communities I haven't joined yet. |
| GET | `/communities/discover?q=` | anyone | Interest communities (open and private) by name; my membership state on each. |
| POST | `/communities` | anyone | Create interest community `{name, description, visibility}`. Max 5. |
| GET | `/communities/{id}` | see 1.5 | Header info + my role / request state. |
| POST | `/communities/{id}/join` | non-member | SCHOOL → member now if the school is in my history (else 404). OPEN → member now. PRIVATE → request created. |
| DELETE | `/communities/{id}/members/me` | member | Leave. Owner can't leave (delete instead). |
| GET | `/communities/{id}/requests` | owner | Pending requests. |
| POST | `/communities/{id}/requests/{userId}/approve` / `reject` | owner | |
| DELETE | `/communities/{id}/members/{userId}` | owner | Remove a member. |
| GET | `/communities/{id}/posts?cursor` | can read | Newest first, cursor-paged. |
| POST | `/communities/{id}/posts` | member | `{body}`. Rate-limited. |
| DELETE | `/posts/{id}` | author, owner, admin | |
| PUT / DELETE | `/posts/{id}/like` | member | Repeating changes nothing. |
| GET / POST | `/posts/{id}/comments` | read / member | |
| DELETE | `/comments/{id}` | author, owner, admin | |
| POST | `/reports` | anyone | New target types `POST`, `COMMENT`. |
| GET | `/feed/home?cursor` | me | Newest posts across all my communities. |

### 1.5 Authorization rules (check every endpoint against this table)

| Action | SCHOOL | INTEREST · OPEN | INTEREST · PRIVATE |
|---|---|---|---|
| See it exists | that school's students | everyone | everyone |
| Read posts | that school's students | everyone | members |
| Join | instant, only if the school is in my history | instant | request → owner approves |
| Post / like / comment | members | members | members |
| Delete any post | admins | owner, admins | owner, admins |

Never trust the client for `authorId`, membership, roles or counters. Hidden/removed posts and posts by people I blocked never appear.

### 1.6 Screens (Flutter)

| Screen | What it shows |
|---|---|
| **Communities tab** | "Your schools" suggestions with Join · "My communities" · "Discover" search · "+ Create". |
| **Community page** | Name, type, member count, Join / Requested / Joined button, post list (newest first), compose box for members. Owner sees "Requests (n)". |
| **Post card** | Author, time, text, ♥ with count, 💬 with count, "..." menu (Report, Delete). |
| **Post detail** | Post, comments, comment box. |
| **Create community** | Name, description, Open/Private switch. |
| **Requests (owner)** | Pending people with Approve / Reject. |
| **Home tab** | Newest posts across my communities. |

Empty states (no communities yet, no posts yet) use the shared illustration: `EmptyState(image: kEmptyInboxImage, ...)` from `feed_shared.dart` (asset `assets/images/inbox_empty.webp`), same as the empty Messages screen.

---

## Part 2 — Chapters

### Chapter 1 — Read the domain (no code)
**Teach:** the two kinds; opt-in membership with a school-history eligibility check; the authorization table in 1.5; counters vs counting.
**Checkpoint:** explain in your own words why a non-member gets 404 rather than 403, and why `member_count` is stored instead of counted.

### Chapter 2 — Migration `V27`
**Teach:** CHECK constraints across columns, partial unique index, `INSERT ... SELECT` backfill, composite primary keys.
**Steps:** create the six tables; insert one SCHOOL community per school. **Nobody is auto-joined** (D2).
**Checkpoint:** `select type, count(*), sum(member_count) from communities group by type` → `SCHOOL | 138 | 0`.

### Chapter 3 — Entities and repositories
**Teach:** composite keys with `@IdClass`; plain id columns vs `@ManyToOne`.
**Steps:** enums (`CommunityType`, `CommunityVisibility`, `MemberRole`, `ContentStatus`); `Community`, `CommunityMember`, `JoinRequest`, `Post`, `PostLike`, `Comment`; one repository each. Queries and DTOs are added in the chapter that first needs them (`CommunityDto` in 4, `PostDto` built in bulk in 6).
**Checkpoint:** the app boots (Hibernate validates every entity against V27).
**Check yourself:** where would an N+1 hide in a list of 30 posts?

### Chapter 4 — School communities: suggest, join, auto-remove
**Teach:** eligibility checks; keeping derived rules consistent inside one transaction.
**Steps:** `GET /communities/mine` (joined + `suggested`), `GET /communities/{id}`, `POST /{id}/join` (written for all kinds: SCHOOL if eligible, OPEN instantly, PRIVATE creates a request), `DELETE /{id}/members/me`; at the end of `replaceSchoolHistory`, remove me from school communities whose school I no longer list. `member_count` changes with an atomic `UPDATE`.
**Checkpoint:** Arjun sees his 3 schools as suggestions; joins one → member; another user without that school gets 404; Arjun removes the school from his history → he's out.

### Chapter 5 — Interest communities: create, discover, join, leave, requests
**Steps:** create (limit 5, unique name via `NameKeys`, creator becomes OWNER), discover search, owner approves/rejects requests and removes members. (Join and leave already exist from Chapter 4.)
**Checkpoint (curl, two users):** private join creates a request; owner approves → member; second user can now read.

### Chapter 6 — Text posts
**Steps:** `PostService.create` (member check, trim, 2,000 cap, rate limit), list newest-first with cursor, delete (author/owner/admin).
**Checkpoint:** member posts → appears; non-member of a private community gets **403** (the community itself is public, so its existence isn't secret); page 2 via `nextCursor`.

### Chapter 7 — Likes and comments
**Teach:** idempotent toggles with a composite key; atomic counters; why not read-modify-write.
**Checkpoint:** like twice → 1; two users at once → 2; delete a comment → count drops.

### Chapter 8 — Reports, auto-hide, blocks
**Steps:** `POST`/`COMMENT` report targets; 3 distinct reporters → `HIDDEN`; admin resolve; filter blocked users' posts.
**Checkpoint:** three users report → gone for everyone; one user reporting three times → still visible.

### Chapter 9 — Home feed
**Steps:** `/feed/home`: newest `ACTIVE` posts where `community_id` is in my communities, cursor-paged, blocked users filtered.
**Checkpoint:** two users in different communities see different Home feeds.

### Chapter 10 — Flutter: Communities tab, community page, create, discover
The bottom tab already exists (added 2026-10-04) as a "coming soon" placeholder: `lib/features/community/presentation/communities_tab.dart`. This chapter replaces its body.
### Chapter 11 — Flutter: posts, likes, comments, report, owner requests
### Chapter 12 — Flutter: Home feed + notifications

### Later (not v1)
Photos and video; ranking and Trending; link interest communities to Journey job functions ("suggested for you"); community moderators besides the owner; pinned posts; polls; "on this day".

---

## Progress Tracker

| # | Chapter | Status |
|---|---|---|
| 1 | Read the domain | ✅ |
| 2 | Migration V27 | ✅ 2026-10-04 |
| 3 | Entities and DTOs | ✅ 2026-10-04 |
| 4 | School communities: suggest + join | ✅ 2026-10-04 |
| 5 | Interest communities | ✅ 2026-10-04 |
| 6 | Text posts | ✅ 2026-10-04 |
| 7 | Likes + comments | ✅ 2026-10-04 |
| 8 | Reports + blocks | ✅ 2026-10-04 |
| 9 | Home feed | ✅ 2026-10-04 |
| 10 | Flutter: tab, page, create, discover | ✅ 2026-10-04 |
| 11 | Flutter: posts, likes, comments, requests | ✅ 2026-10-04 |
| 12 | Flutter: Home + notifications | ✅ 2026-10-04 |

**Built 2026-10-04.** Chapters 5–12 were applied directly at Tejas's request (see Part 0 rule 1), each verified with compile + tests + a live run against the dev database. Re-run the checks any time with the scripts in [`e2e/`](e2e/README.md).
