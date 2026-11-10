# Screens (frame list)

Format: **Route** — purpose — key content — states to draw. Copy is exact from code.

## A. Pre-login
1. **Splash / Welcome** `/` — dark crimson, skyline image, serif headline "Your batchmates are already here.", stats pill "4,200+ APS brats across 137 schools", buttons "Get Started — It's Free" and "Already an APS brat? Log In", footer "ONCE AN APS BRAT, ALWAYS AN APS BRAT". States: default.
2. **Login – email** `/login` (or `?mode=signup`) — title "Welcome back, brat" / "Join us, brat"; "Enter your email to log in" / "Create your account with your email"; email field; **Send Code**; Google button; "New here? Create an account". States: empty, typing, invalid email, sending, error.
3. **Login – code** — "Enter the 6-digit code we sent you"; 6 boxes; **Verify & Continue**; resend countdown; wrong-code error. (Debug-only "skip login" is not a design.)

## B. Onboarding (blocking until step 4 is saved)
Frame has a step progress header (OnboardingFrame) and sticky footer.
4. **Identity** `/onboarding` — full name, username (live availability), date of birth, gender, I am a (Student/Alumni), city. States: validation errors, username taken/available, under-age error.
5. **Schools** `/onboarding/schools` — "Which APS schools did you call home?" / "Add every school you attended — even one year counts. Your batchmates are waiting." School editor cards: search "Search from APS schools...", From Class, To Class, Year Joined, Year Left, Section, Stream (chosen in Class 11). Add/remove card. Footer "Next — connect my socials" (student) or "Next — life after school" (alumni). Red error line above button.
6. **Life after school** (alumni only) `/onboarding/schools/after-school` — "Add the companies and colleges you've been to. Juniors look for this when they need guidance. You can skip it." Sections WORK / COLLEGE with CareerCards, "Add a company / Add another company", "Add a college / Add another college". Buttons Skip / Continue.
7. **Socials** `…/socials` — "Connect your socials", optional links. Finish → Home.

## C. Home shell `/home` (bottom nav)
8. **Home tab** — greeting "Good morning, Arjun.", memory card ("You left APS Patiala 3 years ago today."), "Recently joined" with Connect/Connected, "From your communities", activity feed, "Show more", "See all →". ⚠ sample content present; confirm real data sources.
9. **Batchmates tab** — Students/Alumni/Everyone filter; LOCATION (Everywhere), My schools / All APS Schools, My batch only; sections Classmates, Friends; person card with Message / View profile / Remove; invite link ("Invite message copied — paste it anywhere"); "Add your section to find classmates". States: empty, loading, "Could not load", "Could not search", filter sheet.
10. **Communities tab** — header "Communities"; search; "Your schools" (SchoolCommunityCard), "Your communities" (Joined/Owner), "Discover" (public/private, Request/Requested). **Create a community** sheet: name ≥3 chars, "WHAT IS IT ABOUT? (OPTIONAL)", Public/Private with helper text, "For a field, an exam or an interest. You can make up to 5.", Create/Creating…. States: "Nothing found", owner limit.
11. **Messages tab** — conversation list, search, unread badges, online dot; empty "No messages yet"; "No matches"; error "Could not load messages".
12. **Profile tab (me)** — avatar, name, @username, batch; Personal info (inline edit rows: Full name, Username, Email, Date of birth, Current city, I am a, What I do now), Schools, Privacy (Private profile, Show my activity), Account (Blocked users, Download my data, Log out, Delete account). Dialogs: "Log out?", "Delete your account?".

## D. Pushed screens (inside `/home`)
13. **Notifications** `/home/notifications` — rows with Accept/Decline; "Nothing yet"; error. (Shows first 30 only.)
14. **Connection requests** `/home/requests` — Accept/Decline list; "Could not load requests."
15. **Blocked users** `/home/blocked` — list with Unblock; helper "People you block can't…"
16. **Edit profile** `/home/edit-profile` — Change photo; FULL NAME, USERNAME ("Your unique handle — how others find you"; Checking availability… / Username is available), EMAIL (read-only), DATE OF BIRTH (DD / MM / YYYY), GENDER (Male/Female/Non-binary/Prefer not to say), I AM A, CURRENT CITY, WHAT ARE YOU UP TO NOW?, bio "A line or two about you"; Save changes; snackbar "Profile updated".
17. **Edit schools** `/home/edit-schools` — SchoolCards list, Save changes, "Schools updated".
18. **Career editor** (inside profile) — CareerForm: COMPANY/JOB TITLE or COLLEGE/DEGREE/FIELD OF STUDY, SINCE month/year, "I currently work/study here", "Hide from my profile / Only you will see it", Delete, Saving….
19. **Other user's profile** `/home/profile/:id` — header; Connect / Requested / Accept request / Connected / Message; sections About, Journey (timeline), Socials, mutual batchmates; ⋯ menu Block user / Report user. States: private ("Socials are private"), no socials ("No socials added"), **deleted** ("This account was deleted", "Unknown user", "Their posts and messages are still here, shown as an unknown user."), not loadable ("Profile not available").
20. **Chat (1:1)** `/home/chat/:conversationId` — header with avatar/online/last seen, bubbles, day dividers Today/Yesterday, empty "Say hi 👋 and start the conversation", message bar, emoji panel ("Search emoji", Keyboard toggle), attach sheet ("Send a photo", "Take a photo"), sending and failed states.

## E. Community
21. **Community page** `/home/community/:id` — collapsing crimson header (name, members, privacy, Join/Requested/Joined, chat icon for SCHOOL type).
    - **Interest community tabs:** Feed · Chat (embedded) · Events · Members.
    - **School community tabs:** Feed · Events · Memories · Members (chat from header).
    - Feed: Latest/Popular chips, pinned post, composer sheet "New post" ("Posting to the community", photos, "Posting…"); empty "No posts yet" / "Join and be the first to post." / "Nothing popular yet"; private non-member: "Members only" / "Ask to join to see what members are sharing."
    - Members: search, Owner badge, Connect state per row, "No members found", "No one else yet", "Active now".
    - Owner options sheet: Join requests, Delete community. Member: Leave community. Confirm dialogs for both.
22. **Join requests** `/home/community/:id/requests` — Approve/Reject; "No requests right now".
23. **Community chat (full)** `/home/community/:id/chat` — same chat UI as 20 with sender names; non-member: "Join this community to chat with its members."
24. **Events tab** — NextEventCard, Upcoming list, Past list; "Nothing planned yet. Plan a reunion or meetup."; "No past events yet."
25. **Event detail** `/home/event/:id` — cover, title, date/time range, venue, details, RSVP Going / Interested, attendees, Share, Manage event (Edit event / Cancel event), "Photos and memories" grid; before start: "Photos can be shared once the event starts."; empty "No photos yet. Were you there? Share yours."; cancelled: "This event was cancelled."
26. **Create / Edit event** (form) — TITLE ("Class of 2015 reunion"), WHERE ("APS Pune hall, or Online"), STARTS date + time, ENDS date + time (all required), DETAILS (OPTIONAL), Add a cover photo / Remove cover, Create event / Save changes. Errors: "Give it a title of at least 3 characters", "Pick the start date and time", "Pick the end date and time", "The event must end after it starts", "That end time has already passed. Pick a later one".
27. **Memories tab** (school only) — year filter ("Any year") + category; grid; empty "No memories yet", "Nothing for this filter"; prompt "Got an old school photo?" / "Share an old school photo and mark it as a school memory."; Add a memory sheet (photo required: "Add at least one photo to share a memory", year, category).
28. **Post detail** `/home/post/:id` — PostCard, Comments, "Add a comment", "No comments yet. Say something nice.", "Showing the first 50 comments.", "Delete this comment?", Report; deleted: "This post is gone".

## F. Cross-cutting states (design once)
Loading · offline/error with Retry ("Check your connection and try again.") · empty · permission ("Members only") · destructive confirm dialogs · snackbars · Report sheet · Block confirm.

## Stubs (do not design as final)
`/home/search` ("Search APS classmates, and schools"), `/home/classroom/:id`.

Approx size: 28 screens, ~90 frames including states.
