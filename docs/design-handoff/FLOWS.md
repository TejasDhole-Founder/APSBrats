# Flows

## 1. Entry and onboarding
```mermaid
flowchart TD
  S[Splash] -->|Get Started| L[Login: email]
  S -->|Log In| L
  L -->|Send Code| C[Enter 6-digit code]
  L -->|Google| N
  C -->|Verify| N{Name + username saved?}
  N -->|No| I[Identity]
  N -->|Yes| H[Home]
  I --> SC[Schools - optional content]
  SC -->|Student| SO[Socials]
  SC -->|Alumni| AS[Life after school - skippable]
  AS --> SO
  SO --> H
```
Rule: Identity is mandatory; Schools/Career/Socials may be left empty. Until Identity is saved, community/post/chat/search APIs refuse (403), so no other screen is usable.

## 2. Main navigation
```mermaid
flowchart LR
  H[Home shell] --- T1[Home] & T2[Batchmates] & T3[Communities] & T4[Messages] & T5[Profile]
  T1 --> NOTI[Notifications] --> REQ[Requests]
  T2 --> UP[Other profile] --> CH[Chat]
  T3 --> CP[Community page] --> EV[Event] & PO[Post] & CCH[Chat] & JR[Join requests]
  T4 --> CH
  T5 --> EP[Edit profile] & ES[Edit schools] & BL[Blocked users]
```

## 3. Join a community
```mermaid
flowchart TD
  D[Discover] --> P{Public?}
  P -->|Yes| J[Join] --> M[Member: feed, chat, events]
  P -->|No| R[Request to join] --> W[Requested - waiting] -->|Owner approves| M
  W -->|Owner rejects| D
```

## 4. Event lifecycle
```mermaid
flowchart TD
  O[Create event: title, venue, start + end] --> U[Upcoming list, soonest first]
  U -->|RSVP Going / Interested| U
  U -->|Event starts| PH[Photos can be shared]
  PH -->|End time passes| PA[Past list]
  U -->|Owner cancels| X[Cancelled]
```

## 5. Connect and message
```mermaid
flowchart TD
  A[Profile or Batchmates card] -->|Connect| B[Requested]
  B -->|Other accepts| C[Connected]
  A -->|Message| CH[Chat]
  A -->|Block| BL[Hidden both ways; Blocked users, Unblock]
  A -->|Report| RP[Report sheet]
```

## 6. Delete account
Profile → Account → Delete account → confirm dialog → signed out. Others then see: name kept on posts, profile "Unknown user" with blank info, cannot message or connect.

## Back-button rules
Tab → Home tab first, then exit app. Pushed screens pop one level. Onboarding steps go back one step.
