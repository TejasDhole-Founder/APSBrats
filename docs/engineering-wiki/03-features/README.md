# 03 - Features and Business Logic

One file per feature area. Each action is traced end to end: user action, frontend (widget/provider/repository), state update, API, backend call order, tables, response handling, UI update, effect on other users, failure handling, concurrency and security. Each file ends with what is NOT implemented and the risks found.

| File | Covers |
|---|---|
| [auth-and-sessions.md](auth-and-sessions.md) | Email OTP, Google sign-in, onboarding gate, token refresh, logout, session persistence |
| [profile-career-schools.md](profile-career-schools.md) | Profile edit, avatar, school history, social links, career, privacy settings, export, account deletion, blocked-users screen |
| [posts-comments-likes.md](posts-comments-likes.md) | Create/delete/pin posts, photo upload, likes, comments, share, post detail |
| [communities.md](communities.md) | School vs interest communities, discover, create, join/leave, owner actions, members, events/RSVP, memories, Social tab screens |
| [feed-search-discovery.md](feed-search-discovery.md) | Home feed, activity endpoints (unused), circle, global and people search, places |
| [connections-and-blocking.md](connections-and-blocking.md) | Requests, accept/decline/withdraw/remove, mutual connections, history, blocking and where it is enforced |
| [messaging.md](messaging.md) | Direct messages, community group chat, STOMP push, read marks, presence |
| [notifications-and-moderation.md](notifications-and-moderation.md) | Notification creation and display, reports, auto-hide, admin actions, push state |

Conventions: paths are relative to the repo root; "Not implemented (verified by search)" lists are deliberate, so do not assume a common social feature exists. Update the matching file whenever a flow changes.
