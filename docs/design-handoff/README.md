# APS Brats — Design Handoff Pack

Alumni app for Army Public School "brats". Flutter (Material 3) app, phone-first (design at **390 × 844**).
Source of truth is the code in `frontend/lib`; this pack was written from it.

| File | Use it for |
|---|---|
| `DESIGN_TOKENS.md` | Colours, radii, type, spacing → Figma variables/styles |
| `COMPONENTS.md` | Reusable pieces → Figma components |
| `SCREENS.md` | Every screen, its states and copy → Figma frames |
| `FLOWS.md` | Navigation and user journeys (Mermaid) → FigJam |
| `SCREEN_CHECKLIST.csv` | Tracking sheet: one row per frame |

## Product in one paragraph
Sign in with email + 6-digit code (or Google) → basic onboarding (name, username, birthday, student/alumni) → optional schools, career, socials → 5-tab app: **Home, Batchmates, Communities, Messages, Profile**. Communities have a feed, chat, events (RSVP + photos) and members; school communities also have school memories.

## Rules a designer must keep
- Theme stays crimson + gold on cream. Do not restyle; redesign layout only where asked.
- Users cannot enter the app until name + username are saved. Schools/socials are optional.
- Email cannot be changed after signup.
- Deleted users keep their name on old posts; their profile shows "Unknown user" with blank info.
- Events need a start AND end date/time. Upcoming list = not yet ended, soonest first.

## Not built (do not design as live)
Search page (stub), Classroom page (stub), batch/class groups, video posts, voice/video calls.

## Open items / uncertain from code
- Home tab still contains sample activity cards (Priya Khanna, Rohit Singh…) that look like hard-coded placeholder content; confirm with product before designing them as real.
- Edit profile still shows the old hint "Your phone is your login and cannot be changed here" — login is email now; copy needs fixing.
- Profile tab settings still labels a field "Phone · used to log in" (legacy).
- No custom font; no final logo file (assets are skyline + two empty-state illustrations).
- Dark mode: none designed. Tablet/web: not targeted.
