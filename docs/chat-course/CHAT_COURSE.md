# Building Real-Time Chat for APS Brat — A Hands-On Course

A book in 14 chapters. By the end, two people can open APS Brat on two devices and chat live over WebSocket, with every message saved in Postgres.

**The student (Tejas) writes every line.** This document tells the tutor (any AI agent, or you reading it alone) what each chapter builds, why, and how to check it works.

---

## Part 0 — Instructions for the tutor agent (read this first)

If you are an AI agent guiding Tejas through this course, follow these rules exactly:

1. **Never edit project files yourself.** No Write/Edit on anything under `apsbrat-api/` or `frontend/`. Tejas pastes every change. You may read files, grep, and run read-only checks (`mvn -o -q compile`, `mvn -o test`, `flutter analyze`, `flutter test`) *after* Tejas says they have pasted a step.
2. **One step at a time.** Give one step (usually one file), then stop and wait for "done" / "next". Don't dump a whole chapter.
3. **Format for every step:**
   - The file path, and whether it is a **new file** or an **edit** (for edits, give a clear anchor like "inside `sendMessage`, after the `save` line").
   - The code block.
   - **Directly under the code block**: a plain-language explanation — what this code does, why we need it, and what would break without it. Explain new annotations and keywords the first time they come up.
4. **Read the real code before writing a step.** This course was written against the codebase on 2026-09-26. Files may have changed since. Check the current code, and change the step to fit if needed. Say so when you do.
5. **Start each chapter by teaching.** Explain the chapter's concept in a few short paragraphs before any code. End each chapter with its **Checkpoint** (prove it works) and **Check yourself** questions. Ask Tejas to answer them in his own words, and correct gently.
6. **Update the Progress Tracker** (bottom of this file) when a chapter is finished. Editing this course file is allowed. Project code is not.
7. Keep it simple. No extra abstractions, no "for later" scaffolding. If Tejas asks for something outside the chapter, finish or pause the current step first.
8. When a step has a **Decision** box, ask Tejas to choose. Don't pick for him.

---

## Part 1 — The big picture

### What we are building

```
 Flutter app (sender)                 Spring Boot (apsbrat-api)                Flutter app (recipient)
 ───────────────────                  ─────────────────────────                ───────────────────────
 types "hi", taps send
        │  POST /conversations/{id}/messages  (REST, with JWT)
        └──────────────────────────────►  ChatController
                                           └► ChatService.sendMessage
                                               1. check you're in this conversation
                                               2. INSERT into chat_messages   ◄── Postgres = source of truth
                                               3. update conversations.last_message_at
                                               4. after the DB commit:
                                                  push over WebSocket ──────────────► /user/queue/messages
        ◄──────── 200 OK + saved message                                             message appears live
```

### Core ideas (the tutor should keep coming back to these)

- **Postgres is the source of truth. WebSocket is only a doorbell.** Every message is saved first. The socket push only means "something new arrived, show it now". If the push is lost (phone offline, app closed), nothing is lost. The app fetches history over REST when it opens.
- **Send over REST, receive over WebSocket.** Sending over REST gives a clear success or failure for each message, reuses the JWT auth you already have, and the saved message comes back in the response. The socket is used only for server → client pushes.
- **STOMP on top of WebSocket.** Raw WebSocket is just a pipe of bytes. STOMP adds a simple message format with destinations (like `/user/queue/messages`), subscribe, and connect-with-headers. Spring and the Flutter package `stomp_dart_client` both speak it.
- **One backend.** Chat lives in `apsbrat-api`, next to users and connections, because it needs them for almost every response.

### What already exists (don't rebuild it)

| Thing | Where | State |
|---|---|---|
| DB tables `conversations`, `chat_messages` | `V12__create_conversations.sql` | Already applied. **Never edit this migration.** |
| `Conversation`, `ChatMessage` entities | `apsbrat-api/.../chat/` | **Done** (Chapter 1) |
| Flutter API client for chat | `frontend/lib/features/chat/data/chat_repository.dart` | Exists. Defines the REST contract the backend must match |
| Flutter chat models | `frontend/lib/features/chat/data/chat_models.dart` | Exists; gets one new field in Ch 9 |
| Endpoint paths | `frontend/lib/core/constants/api_endpoints.dart` | Exists |
| Route `chat/:conversationId` → `ChatScreen` | `frontend/lib/core/routes/app_router.dart` | Exists; the screen is a placeholder |
| `ChatOverlay` (fake chat UI with auto-replies) | `frontend/lib/features/feed/presentation/widgets/chat_overlay.dart` | Dummy. Its look gets reused, then it is deleted (Ch 10–11) |
| `spring-boot-starter-websocket` | `apsbrat-api/pom.xml` | Already a dependency |
| `/ws/**` permitAll | `SecurityConfig.java` | Already present (explained in Ch 6) |
| Reference pattern | `community/CommunityService.java` | Cursor pagination, PersonDto building; copy its style |

### The API contract (fixed by the existing Flutter repository)

All under `/api/v1`, all need `Authorization: Bearer <accessToken>`, all wrapped in the usual `ApiResponse`.

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/conversations` | – | `List<ConversationDto>` (only conversations that have at least one message, newest first) |
| POST | `/conversations/with/{userId}` | – | `ConversationDto` (find-or-create the 1:1 conversation) |
| GET | `/conversations/{id}/messages?cursor=&limit=30` | – | `CursorPage<ChatMessageDto>` (oldest→newest inside the page) |
| POST | `/conversations/{id}/messages` | `{ "body": "hi" }` | `ChatMessageDto` |
| POST | `/conversations/{id}/read` | – | `null` data |

`ConversationDto`: `id, person (PersonDto of the OTHER user), preview (last message body or null), time (last message time or created time), unread (bool), unreadCount (long)`

`ChatMessageDto`: `id, conversationId, senderId, body, mine (bool, from the viewer's side), createdAt`

WebSocket: connect to `ws://localhost:8080/ws` (plain WebSocket, STOMP). Send `Authorization: Bearer <token>` as a STOMP CONNECT header. Subscribe to `/user/queue/messages`. Each frame is a `ChatMessageDto` JSON with `mine = false`.

---

## Part 2 — Backend (Spring Boot)

### Chapter 1 — Entities ✅ (done)

**Built:** `chat/Conversation.java`, `chat/ChatMessage.java`. These are JPA entities that map the existing V12 tables.

**Concepts to know:** `@Entity`/`@Table`, `@Id @GeneratedValue` UUIDs, `@ManyToOne(fetch = LAZY)` + `@JoinColumn`, `@PrePersist`.

**Check yourself**
1. Why do `userA`/`userB` hold a `User` object instead of a raw `UUID`?
2. What does `FetchType.LAZY` save us, and when does the actual query run?
3. The DB has `UNIQUE(user_a_id, user_b_id)`. Why is that not enough on its own to stop duplicate conversations between the same two people?

---

### Chapter 2 — Repositories: asking the database questions

**Goal:** `ConversationRepository` and `ChatMessageRepository`.

**Teach first:**
- Spring Data turns a method *name* into SQL (`findByConversation_IdOrderByCreatedAtDesc`). The `_` walks into a related entity (`conversation.id`).
- When a name gets too long or can't express the query, write it with `@Query` (JPQL: queries on entities, not tables).
- Writes that change many rows at once need `@Modifying` + `@Query("update ...")`, run inside a transaction.

**Important:** An earlier version of this step used `countByConversation_IdAndCreatedAtAfter` for unread counts. That is the Community approach, which stores a `lastReadAt` for each member. Our table works differently: it has `read_at` **on each message**. Use the methods below instead.

**Steps**
1. `ConversationRepository` (new):
   - `Optional<Conversation> findByUserA_IdAndUserB_Id(UUID a, UUID b)` finds the one conversation for a pair of people.
   - A `@Query` method `findActiveFor(UUID userId)`: conversations where `userA.id = :userId or userB.id = :userId` **and `lastMessageAt is not null`**, ordered by `lastMessageAt desc`.
     *Why the not-null filter:* Postgres sorts NULLs **first** in `DESC` order. Without the filter, empty conversations (someone tapped "Message" and never typed) would sit at the top of the list. Hiding them is also what WhatsApp does.
2. `ChatMessageRepository` (new):
   - `findByConversation_IdOrderByCreatedAtDesc(UUID, Pageable)` for the first page.
   - `findByConversation_IdAndCreatedAtLessThanOrderByCreatedAtDesc(UUID, LocalDateTime, Pageable)` for older pages (cursor).
   - `Optional<ChatMessage> findTopByConversation_IdOrderByCreatedAtDesc(UUID)` for the preview line.
   - `long countByConversation_IdAndSender_IdNotAndReadAtIsNull(UUID conversationId, UUID me)` counts unread messages: sent by the other person and not read yet.
   - `@Modifying @Query("update ChatMessage m set m.readAt = :now where m.conversation.id = :cid and m.sender.id <> :me and m.readAt is null") int markRead(...)` marks messages read in one statement.

**Checkpoint:** `mvn -o -q compile` passes. Spring checks derived-query method names when the app **starts**, so also run the app once (or `mvn -o test`) and confirm there is no `No property ... found` error.

**Check yourself**
1. Why is unread = "sender is not me AND read_at is null", and not just "read_at is null"?
2. Why one `update` statement instead of loading every message and calling `setReadAt` in a loop?
3. What would the conversations list look like without the `lastMessageAt is not null` filter?

---

### Chapter 3 — DTOs: what leaves the server

**Goal:** `ConversationDto`, `ChatMessageDto`, `SendChatMessageRequest` (Java `record`s).

**Teach first:**
- Never return entities from controllers. Entities contain lazy proxies, and whole `User` rows with email, role and so on. They also tie your API to your DB layout. A DTO is the exact shape the app needs.
- `record` = immutable data class. The constructor, getters, `equals` and `toString` come free.
- Validation lives on the request DTO (`@NotBlank`, `@Size(max = 4000)`). Copy `community/SendCommunityMessageRequest.java`. The controller's `@Valid` turns violations into a 400 through the existing `GlobalExceptionHandler`.

**Steps:** three records with exactly the fields in the API contract above. `ChatMessageDto` includes `conversationId`. The Community DTO doesn't have it, but the socket client needs it to know which open chat a pushed message belongs to.

**Checkpoint:** compiles.

**Check yourself**
1. Why is `mine` computed on the server and not stored in the DB?
2. Why does `ConversationDto.person` hold the *other* user and not both users?

---

### Chapter 4 — ChatService part 1: find-or-create a conversation (the pair invariant)

**Goal:** `ChatService` with `openWith(me, otherUserId)` and a private `toConversationDto(...)`.

**Teach first:**
- **An invariant** is a rule that is always true in your data. Ours: *for any two people there is at most one conversation row, and the smaller UUID is always stored in `user_a_id`.* If we always sort the pair before saving and before looking up, one query finds the conversation, whoever started it.
- **Race condition:** two people tap "Message" on each other at the same moment. Both look up, both find nothing, both insert. The DB's `UNIQUE` constraint rejects the second insert with a `DataIntegrityViolationException`. The fix: catch that exception and look the row up again. The DB constraint is the real safety net. The Java check just makes the normal case fast.
- **Business rule. Decision (ask Tejas):** who may start a chat?
  - (a) only people you're **CONNECTED** with (recommended; stops spam from strangers), using `personService.relations(me, List.of(other))`
  - (b) anyone in the app
  Also reject messaging yourself (400). The DB `CHECK` would stop it anyway, but a clear error message is better.

**Steps**
1. `ChatService` class: `@Service @RequiredArgsConstructor`, with the repositories, `UserRepository`, `PersonService`.
2. `openWith`: validate (not self, other user exists → 404, decision rule → 403), sort the pair (`a.compareTo(b) < 0`), find or create, handle the race, return the DTO.
3. `toConversationDto(conversation, me)`: pick the other user, build their `PersonDto`, load the preview (`findTop...`) and unread count.
   *Known ceiling:* on the list screen this runs 2 queries per conversation (an N+1 query problem). Fine for dozens of chats. Leave a `// ponytail: N+1 per conversation, batch with one grouped query if the list gets slow` comment.

**Checkpoint:** compiles. Tejas explains the pair invariant in his own words before moving on.

**Check yourself**
1. Without sorting, what would happen if A messages B first, then B later opens chat with A?
2. Why catch `DataIntegrityViolationException` instead of adding `synchronized` to the method? (Hint: two server instances.)

---

### Chapter 5 — ChatService part 2: list, history, send, mark read + the controller

**Goal:** a full REST chat that works end to end with curl. There is no real-time yet, and that's on purpose: get the data right first.

**Teach first:**
- **Participant check = security.** Every method that takes a `conversationId` must check that the caller is `userA` or `userB`. Without it, anyone who guesses or leaks an id can read someone else's private messages. Return **404** (not 403) for "not yours", so an attacker can't even learn the conversation exists. Put this in one private `requireParticipant(conversationId, me)` helper that every method calls.
- **Cursor pagination** (copy `CommunityService.messages`): fetch `limit + 1` rows newest-first. If you got the extra row, there's more. The cursor is the `createdAt` of the last row. Reverse before returning so the UI gets oldest→newest.
- **`@Transactional`**: `sendMessage` inserts a message *and* updates `conversation.lastMessageAt`. Both happen or neither happens.

**Steps**
1. `listConversations(me)` → `findActiveFor` → map with `toConversationDto`.
2. `messages(me, conversationId, cursor, limit)`: `requireParticipant`, then the Community pagination pattern, then `mine = sender == me`.
3. `sendMessage(me, conversationId, body)`: `requireParticipant`, trim the body, save the message, set `lastMessageAt = message.createdAt`, return the DTO with `mine = true`.
4. `markRead(me, conversationId)`: `requireParticipant`, then `markRead(...)` on the repository.
5. `ChatController` at `/api/v1/conversations`, shaped like `CommunityController`, with the 5 endpoints from the contract. Use `SecurityUtils.currentUserId()`.

**Checkpoint: manual test with two users** (Swagger at `http://localhost:8080/swagger-ui.html`, or curl):
1. Log in as user A: `POST /api/v1/auth/request-otp`, then read the OTP from the **backend console log** (`OTP for ... is ...`), then `POST /api/v1/auth/verify-otp` and copy the `accessToken`. Do the same for user B (`seed_test_users.sql` has test users; make sure A and B are connected if you chose rule (a)).
2. A: `POST /conversations/with/{B's id}`, save the conversation id.
3. A: send 3 messages. B: `GET /conversations` shows it with `unreadCount: 3`.
4. B: `GET /conversations/{id}/messages`: 3 messages, oldest first, `mine: false`.
5. B: `POST /read`, and `unreadCount` drops to 0.
6. **Security test:** log in as a third user C and call `GET /conversations/{id}/messages`. It must return **404**.

Add one small unit test for the pair-sorting logic if you pulled it into a static method (like `SchoolHistoryOverlapTest` does for its logic).

**Check yourself**
1. What exactly could user C do if `requireParticipant` were missing?
2. Why fetch `limit + 1` rows?
3. If the `lastMessageAt` update failed after the message was saved, what would the user see, and how does `@Transactional` prevent that?

---

### Chapter 6 — WebSocket + STOMP: opening the pipe

**Goal:** `WebSocketConfig` so clients can connect to `/ws` and subscribe.

**Teach first:**
- **HTTP vs WebSocket.** HTTP is ask → answer → done, so the server can never start a conversation. A WebSocket starts life as an HTTP request with `Upgrade: websocket`. After that the TCP connection stays open and *either side* can send at any time. This is the only way (besides polling) for the server to tell the phone "new message".
- **Why not polling?** Asking "anything new?" every 3 seconds wastes battery and data, still feels 0–3 s laggy, and multiplies server load by the number of open apps.
- **STOMP basics:** frames look like `COMMAND\nheader:value\n\nbody\0`. The commands used here are `CONNECT`, `SUBSCRIBE`, `MESSAGE`, `DISCONNECT`.
- **Simple broker + user destinations:** `enableSimpleBroker("/queue")` is an in-memory message router inside the app. `setUserDestinationPrefix("/user")` makes `/user/queue/messages` private: when the server calls `convertAndSendToUser("<userId>", "/queue/messages", dto)`, Spring delivers it only to that user's connected sessions (all their devices).
- **No SockJS.** SockJS is a fallback for very old browsers. Flutter (mobile and web) supports real WebSocket, so it would only add moving parts.
- **Why `/ws/**` is `permitAll` in `SecurityConfig`:** the WebSocket handshake is an HTTP request, and **browsers can't attach an `Authorization` header to it**. So Spring Security lets the handshake through, and we authenticate the STOMP `CONNECT` frame instead (Chapter 7). Until Chapter 7 is done the socket accepts anyone. Don't deploy between Ch 6 and Ch 7.

**Steps**
1. `chat/WebSocketConfig.java` (or `common/websocket/` if Tejas prefers; ask): `@Configuration @EnableWebSocketMessageBroker implements WebSocketMessageBrokerConfigurer`.
   - `registerStompEndpoints`: `addEndpoint("/ws").setAllowedOriginPatterns("http://localhost:*", "http://127.0.0.1:*")` (same origins as the CORS config).
   - `configureMessageBroker`: `enableSimpleBroker("/queue")` and `setUserDestinationPrefix("/user")`. No `/app` prefix, because clients never send over the socket in this design.
2. *Optional, recommended:* heartbeats (`.setHeartbeatValue(new long[]{10000, 10000})` plus a `ThreadPoolTaskScheduler`) so dead connections (phone lost signal) are noticed within about 20 s instead of never.

**Checkpoint:** the app starts, and the startup log mentions the STOMP broker. Real connect testing happens in Ch 8.

**Check yourself**
1. Why can't the server push over plain HTTP?
2. What does the `/user` prefix give us that a shared `/topic/chat` would not?

---

### Chapter 7 — Securing the socket: JWT on STOMP CONNECT

**Goal:** only logged-in users can connect, and each connection knows *which* user it is.

**Teach first:**
- A `ChannelInterceptor` on the **client inbound channel** sees every frame the client sends before Spring handles it. On `CONNECT` we read the `Authorization` native header, check it with the existing `JwtService.parseUserId`, and attach a `Principal` whose name is the userId string. This is the socket version of what `JwtAuthFilter` does for REST.
- `convertAndSendToUser(userId.toString(), ...)` matches on `Principal.getName()`. That's why the name must be the userId.
- **Reject bad subscriptions:** on `SUBSCRIBE`, only allow destinations starting with `/user/queue/`. Nothing else exists, and allowing everything is how data leaks start later.
- **Token expiry:** access tokens last 15 minutes. The token is only checked at CONNECT. An open socket stays open after expiry, which is normal and fine. Reconnects must use a fresh token (Ch 12 handles that on the client).

**Steps**
1. `StompAuthChannelInterceptor` (`@Component`, implements `ChannelInterceptor`): in `preSend`, get the `StompHeaderAccessor` with `MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class)`.
   - `CONNECT`: missing or invalid token → throw (Spring sends an `ERROR` frame and closes the connection). Valid → `accessor.setUser(() -> userId.toString())`. A lambda works because `Principal` has one abstract method.
   - `SUBSCRIBE`: destination doesn't start with `/user/queue/` → throw.
2. In `WebSocketConfig`: override `configureClientInboundChannel(registration)` → `registration.interceptors(stompAuthChannelInterceptor)`.

**Checkpoint:** compiles and starts. Tested for real in Ch 8.

**Check yourself**
1. Why don't we authenticate the WebSocket handshake with `JwtAuthFilter` like REST?
2. What would a user without the SUBSCRIBE check be able to try?

---

### Chapter 8 — Push after commit: making it real-time

**Goal:** when a message is saved, the recipient gets it instantly.

**Teach first:**
- `SimpMessagingTemplate` (Spring creates it for you) sends to a destination: `convertAndSendToUser(recipientId.toString(), "/queue/messages", dto)`. It turns the DTO into JSON the same way REST does.
- **Push only after the DB commit.** If we push inside the transaction and the commit then fails, the recipient sees a message that doesn't exist. Or they get pushed, fetch history, and don't find it yet. Fix: inside `sendMessage`, register a callback:
  ```java
  TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override public void afterCommit() { messagingTemplate.convertAndSendToUser(...); }
  });
  ```
  This is "save first, ring the doorbell second" in code.
- The pushed DTO has `mine = false`, because it goes to the recipient. The sender already has their copy from the REST response. *Known ceiling:* the sender's **other** devices won't see their own message live until they refresh. Fine for v1.
- If the recipient is offline, `convertAndSendToUser` just finds no session and does nothing. The message is still in Postgres. Offline alerts (push notifications) come in Chapter 14.

**Steps**
1. Inject `SimpMessagingTemplate` into `ChatService`.
2. In `sendMessage`, after saving: work out `recipientId` (the participant who isn't `me`), build the recipient's DTO (`mine = false`), and register the `afterCommit` push.

**Checkpoint: test the socket before touching Flutter.** The tutor gives Tejas a throwaway `ws-test.html` (saved **outside** the project, e.g. the Desktop). It loads `@stomp/stompjs` from `cdn.jsdelivr.net`, connects to `ws://localhost:8080/ws` with an `Authorization` header from a text box, subscribes to `/user/queue/messages`, and prints each frame.
1. Open it, paste **B's** token, connect.
2. Using Swagger/curl as **A**, send a message to the A–B conversation. It appears in B's page instantly.
3. Connect with a garbage token → the connection is refused.
4. Try subscribing to `/topic/anything` → an error frame.

If the page is served from `file://`, origin checks may need `http://localhost` instead. Serve it with `npx serve` or `python -m http.server`.

**Check yourself**
1. What goes wrong if we push *before* the commit?
2. B is offline when A sends. Walk through exactly what happens, and what B sees when they open the app.

🎉 **The backend is complete.** Run `mvn -o test`: everything should still pass.

---

## Part 3 — Frontend (Flutter)

### Chapter 9 — Models & repository: meet the existing code

**Goal:** make the existing `chat_models.dart` / `chat_repository.dart` match the backend exactly.

**Teach first:** read `chat_repository.dart` together, method by method, and map each one to the backend endpoint it calls. This code was written before the backend existed. Now it gets a real server.

**Steps**
1. `ChatMessage` model: add `conversationId` (from JSON). The socket handler needs it.
2. Check that `Conversation.fromJson` keys match `ConversationDto` exactly (`person`, `preview`, `time`, `unread`, `unreadCount`).
3. Add `static const wsUrl = String.fromEnvironment('WS_URL', defaultValue: 'ws://localhost:8080/ws');` to `core/constants/env.dart`. Note that it has **no** `/api/v1`, because `/ws` sits at the root.

**Checkpoint:** `flutter analyze` is clean.

---

### Chapter 10 — The chat screen, backed by REST

**Goal:** turn the placeholder `ChatScreen` (route `chat/:conversationId`) into a working chat that loads history and sends messages. No socket yet.

**Teach first:**
- **Why a `StateNotifier` and not only a `FutureProvider`:** a chat's message list *changes* (new sends, pushes arriving, older pages loaded). A `FutureProvider` loads once. A `StateNotifier` owns a list we can change and tells the UI to rebuild. Use `StateNotifierProvider.autoDispose.family<ChatController, ChatState, String>` keyed by conversationId, so each open chat has its own state, and it's thrown away when you leave the screen.
- **Optimistic send:** add the message to the list *immediately* with a temporary id and a "sending" flag, then call the API. On success, swap in the real message from the server. On failure, mark it "failed" and let the user tap to retry. This makes the app feel instant.
- **Reuse, don't redraw:** `ChatOverlay` already has the look (crimson header, bubbles, input bar). Move its widgets into `ChatScreen` and drop the fake `dummyChatHistory` / auto-reply parts.

**Steps**
1. `features/chat/presentation/chat_controller.dart`: `ChatState` (messages, loading, hasMore, nextCursor, other person) and `ChatController` with `load()`, `loadOlder()`, `send(text)`, `receive(ChatMessage)` (used in Ch 12; dedupe by id), and `markRead()`.
2. `ChatScreen` becomes a `ConsumerStatefulWidget` that watches the controller. It calls `markRead` on open, loads older messages when scrolled to the top, and scrolls to the bottom on new messages.
3. The header needs the other person: take it from the conversations list (or add `GET /conversations/{id}` if needed; ask before adding endpoints).

**Checkpoint:** navigate to the chat route with a real conversation id from Ch 5. History shows and sending works. Refreshing the page keeps the messages (they're in Postgres).

**Check yourself**
1. What does the user see if the network fails during an optimistic send?
2. Why `autoDispose`?

---

### Chapter 11 — Real entry points: Messages tab + "Message" button

**Goal:** remove the dummy chat paths and connect the real ones.

**Teach first:** right now `HomeScreen` opens `ChatOverlay` with an `AppPerson`. That's a dummy type with **no user id**, so it can never talk to the backend. Real screens use `Person` (`core/models/person.dart`), which has `id`. The dummy path gets replaced, not patched.

**Steps**
1. `messages_tab.dart` → `_DirectMessagesView` uses `ref.watch(conversationsProvider)` instead of `dummyMessages` (loading / error / empty states; the existing empty-state copy stays). Tapping a row → `context.push('<home prefix>/chat/${c.id}')`. The tutor checks the real route prefix in `app_router.dart`.
2. The "Message" button on connected-person cards (`batch_tab.dart`, around the `label: const Text('Message')` button) and on the profile screen, if it has one: `final c = await ref.read(chatRepositoryProvider).openWith(person.id);` then push the chat route.
3. Remove `ChatOverlay` from `home_screen.dart` (`_chatPerson`, `_openChat`, the overlay in the `Stack`) and delete `chat_overlay.dart` once nothing imports it. Remove `dummyChatHistory` / `dummyAutoReplies` / `dummyMessages` if unused.
4. After sending or reading, `ref.invalidate(conversationsProvider)` so the list preview and unread count stay fresh.

**Checkpoint:** from a fresh login, tap Message on a connected batchmate → type → go back → the Messages tab shows the conversation with a preview. Log in as the other user → the conversation shows as unread.

---

### Chapter 12 — The socket client: going live

**Goal:** incoming messages appear without refreshing.

**Teach first:**
- **Protocol mismatch:** `pubspec.yaml` has `socket_io_client`. Socket.IO is a *different protocol*, and it can't talk to a STOMP server. Replace it with `stomp_dart_client`.
- **One connection per app, not per screen.** Make a single `ChatSocket` (a Riverpod `Provider`) that connects when the user is logged in and exposes `Stream<ChatMessage> messages` (a broadcast `StreamController`). Screens *listen* to it. They don't open their own sockets.
- **Auth on connect:** in `StompConfig`, put `stompConnectHeaders: {'Authorization': 'Bearer $token'}`. Read the token from secure storage (`kAccessTokenKey`) **each time it connects**, using `beforeConnect`, so reconnects pick up refreshed tokens. If CONNECT fails because the token expired, make any authenticated REST call first (the Dio interceptor refreshes the token), then reconnect.
- **Lifecycle:** connect after login and on cold start if already logged in. Disconnect on logout (`auth_provider.dart` → `logout()`), otherwise the next user on that phone gets the previous user's messages.

**Steps**
1. `pubspec.yaml`: remove `socket_io_client`, add `stomp_dart_client`, run `flutter pub get`.
2. `features/chat/data/chat_socket.dart`: `ChatSocket` with `connect()`, `disconnect()`, and the `messages` stream. `onConnect` subscribes to `/user/queue/messages` and turns each frame body into a `ChatMessage`. Set `reconnectDelay` (e.g. 5 s).
3. Start and stop it from the auth state (the tutor checks how `auth_provider.dart` exposes logged-in state).
4. In `ChatController`: listen to the stream. If `msg.conversationId == this conversation`, call `receive(msg)` and `markRead()`, because the user is looking at it.
5. Anywhere: on any incoming message, `ref.invalidate(conversationsProvider)` so the Messages tab and unread count update live.

**Checkpoint: the real test.** Chrome = user A, a second Chrome profile, incognito window, or the Android emulator = user B.
1. Both open the same chat. A types, and it appears on B instantly with no refresh. Then reverse.
2. B on the Messages tab (not in the chat): A sends, and B's list shows the new preview and unread count live.
3. Log out B, log in as C on the same browser. C must **not** receive A→B messages.

**Check yourself**
1. Why one socket per app and not one per chat screen?
2. What happens if we forget to disconnect on logout?

---

### Chapter 13 — Reliability: when the network misbehaves

**Goal:** no lost or duplicated messages when the connection drops.

**Teach first:**
- While the socket is down (subway, app in the background), pushes are **gone**. The simple broker doesn't store them. This is fine *because Postgres is the source of truth*: after every reconnect, refetch the newest page of the open chat plus the conversations list, and merge by id.
- **Dedupe by message id.** The same message can reach you twice: the refetch plus a late push, or the REST response plus your own push if multi-device is added later. `receive()` ignores ids it already has.
- **App lifecycle:** mobile OSes kill background sockets. Use `AppLifecycleListener` (or `WidgetsBindingObserver`) to reconnect on resume.

**Steps**
1. `ChatSocket`: a `connected` stream/notifier. On every *re*connect (not the first connect), emit a "resync" event.
2. `ChatController`: on resync, fetch the first page again and merge. Conversations list: invalidate.
3. Reconnect on app resume.
4. *Optional UI:* a thin "Connecting…" bar when the socket is down.

**Checkpoint:** B has the chat open → B goes offline (turn off Wi-Fi, or background the app on mobile) → A sends 2 messages → B comes back online. The 2 messages appear once each, in order, with no manual refresh.

**Check yourself:** explain "the socket is a doorbell, Postgres is the mailbox" with this chapter's scenario.

---

### Chapter 14 — Shipping it & what comes next

**Deploying (tie into `docs/DEPLOYMENT.md`):**
- Production uses `wss://` (TLS). Set `WS_URL=wss://api.<domain>/ws` at build time (`--dart-define`).
- A reverse proxy (nginx/Caddy) must forward the upgrade headers (`Upgrade`, `Connection: upgrade`) and have a long read timeout, otherwise sockets die every 60 s.
- Add the production web origin to `setAllowedOriginPatterns` (and CORS).
- **More than one backend instance?** The simple broker is in-memory, so a user connected to instance 1 won't get pushes sent from instance 2. Options then: Redis pub/sub relay, or a full broker (RabbitMQ STOMP relay). Not needed on a single droplet.

**Future chapters (only when you actually want them):**
- Push notifications for offline users (FCM; `firebase_messaging` is already in `pubspec.yaml`).
- Read receipts ("seen") and typing indicators. These need an envelope `{type, payload}` on the socket instead of a bare message.
- Sender multi-device sync (push to the sender's other sessions too).
- Deleting/editing messages, images.
- Optional cleanup: `ChatScreen` route vs. overlay styling, and batching the N+1 query in the conversation list.

---

## Progress Tracker

The tutor updates this when a chapter's Checkpoint passes.

| # | Chapter | Status | Notes |
|---|---|---|---|
| 1 | Entities | ✅ Done | `Conversation.java`, `ChatMessage.java` |
| 2 | Repositories | ⬜ | |
| 3 | DTOs | ⬜ | |
| 4 | Find-or-create + pair invariant | ⬜ | Decision: who can message whom → ___ |
| 5 | Service + controller (REST) | ⬜ | |
| 6 | WebSocket config | ⬜ | |
| 7 | STOMP JWT auth | ⬜ | |
| 8 | Push after commit | ⬜ | |
| 9 | Flutter models/repo | ⬜ | |
| 10 | Chat screen (REST) | ⬜ | |
| 11 | Entry points, remove dummy | ⬜ | |
| 12 | Socket client | ⬜ | |
| 13 | Reliability | ⬜ | |
| 14 | Shipping | ⬜ | |
