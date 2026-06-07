# APSBrats — Performance Review (query efficiency)

A functionality-by-functionality pass over the API for slow paths — mainly **N+1
queries**, unbounded result sets, and missing indexes. ✅ = fixed in this pass,
⚠️ = recommended next.

> Method: traced every service method to the repository calls it makes, counted
> queries as a function of result size *N*, and checked the DB indexes backing each query.

---

## Summary of what was slow

The root issue was `PersonService.toPerson(user)` — it ran **one school-history query (plus a lazy school load) per person**, and it was called inside loops everywhere a list of people is returned. A feed of 20, a community with 5 avatars, an inbox of 15 chats each multiplied DB round-trips.

**Fix:** added `PersonService.toPeople(List<User>)` — **one** query (`findAllWithSchoolByUserIds`, with `JOIN FETCH h.school`) builds the whole list. All list endpoints now use it.

---

## Functionality-by-functionality

| # | Endpoint | Before | After | Change |
|---|----------|--------|-------|--------|
| 1 | `GET /feed/recent-joins` | 1 + N×(history) | 1 + 1 | ✅ batched `toPeople` |
| 2 | `GET /feed/activity` | 1 + N×(history) | 1 + 1 | ✅ batched actor people |
| 3 | `GET /feed/banner` | 1 | 1 | already fine |
| 4 | `GET /connections` (batchmates) | 1 + N×(history) | 1 + 1 | ✅ batched |
| 5 | `GET /connections/pending` | 1 + N×(history) | 1 + 1 | ✅ batched |
| 6 | `GET /connections/{id}/status` | 2 point queries | **1** | ✅ single `findBetween` |
| 7 | `POST /connections/{id}` (request) | 2 dup-check queries (+2 user loads +1 notif) | 1 dup-check | ✅ single `findBetween` |
| 8 | `GET /search?q=` | 1 + N×(history) + M×(count) | 1 + 1 + M | ✅ people batched (+ trigram index) |
| 9 | `GET /communities/{id}/messages` | 1 + N×(history per message) | 1 + 1 | ✅ batched senders |
| 10 | community **avatars** (in every community DTO) | loaded **all** members + 5×(history) | top-5 query + 1 | ✅ `findTop5...` + batched |
| 11 | `GET /conversations` (inbox) | per chat: 2 + history | per chat: 2; people batched once | ✅ people batched (see ⚠️ A) |
| 12 | `GET /profiles/{username}` | 4 queries, fixed | 4 | fine (not per-N) |
| 13 | `GET /communities` (mine) | per community: ~4 + 5×history | per community: ~4 + 1 | ✅ avatars batched (see ⚠️ B) |

---

## Indexes added (migration V15)

- `users(created_at DESC)` — backs `recent-joins` ordering and the "joined today" banner (was a full scan + sort).
- **pg_trgm GIN** indexes on `LOWER(full_name)`, `LOWER(city)`, `LOWER(username)`, `LOWER(communities.name)` — search used `LOWER(col) LIKE '%term%'`, which can't use a normal btree and was a sequential scan. Trigram indexes on the `LOWER(...)` expression match the generated SQL.
- Partial index `chat_messages(conversation_id) WHERE read_at IS NULL` — speeds the unread-count query.

(Existing indexes already cover `community_members`, `community_messages`, `feed_events.created_at`, and the connection FKs.)

---

## ⚠️ Still recommended (not done — higher risk / needs product input)

**A. DM inbox still issues 2 queries per conversation** (`GET /conversations`): last-message + unread-count. For a large inbox this is the next bottleneck. Options:
- Denormalize `last_message_body` / `last_message_at` onto `conversations` (write on send) → 0 extra queries for the preview.
- Compute unread counts for all conversations in one grouped query (`GROUP BY conversation_id`).

**B. `GET /communities` does ~4 queries per community** (count, last message, unread, avatars). Fine while a user is in a handful of communities; if that grows, batch the per-community aggregates with `GROUP BY` queries.

**C. Message lists are unbounded** — `GET /communities/{id}/messages` and `GET /conversations/{id}/messages` return **every** message. Add keyset/`Pageable` pagination (e.g. `?before=<id>&limit=50`) before any thread gets large. This is the most important remaining item for real data.

**D. `lastSender`/`lastMessage`** trigger a lazy `sender` load per community in the list. Minor; folds into (B) if batched.

**E. Caching** — `PersonDto` and community metadata are read-heavy and change rarely; a short-lived cache (Redis is already wired) would cut repeat work. Defer until measured.

**F. `getReferenceById` in `ChatService.findOrCreate`** is already optimal (no extra select to create a conversation) — noted as intentional.

---

## Net effect

List endpoints went from **O(N) database round-trips to O(1)** for person data, the
two hottest search paths are now index-backed, and connection status/dup-checks halved
their queries. The remaining items (A–C, especially **message pagination**) are the
next things to address as data volume grows.
