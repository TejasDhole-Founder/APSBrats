# Design Tokens

## Brand colours
| Token | Hex | Use |
|---|---|---|
| crimson | #7B1414 | Primary brand, headers, active nav icon |
| crimsonDark | #5C0F0F | Primary buttons, onboarding |
| crimsonMuted | #B44040 | Secondary accents |
| crimsonMed (kCrimsonMed) | #9B1C1C | Links, badges |
| crimsonLight | #FEF3F3 | Tinted chips/backgrounds |
| gold | #D4A84A | Accent, active nav bar, highlights |
| goldDark | #C48C28 | Pressed gold |
| goldDeep (welcome) | #C9962E | Splash accents |
| goldLight (welcome) | #E8C06A | Splash text accent |
| goldTint | #FEF9EE | Gold chip background |
| goldText | #A07010 | Text on gold tint |
| cream | #F4F0E2 | App background (legacy screens) |
| card | #FDFAF0 | Cards on cream |
| communityBg | #FBF8F6 | Community screens background |
| tint | #F3ECEC | Neutral tinted fill |
| cardLine | #EADCDC | Card borders (community) |
| mud | #3A2C08 | Dark brown text |

## Text / neutral
| Token | Hex |
|---|---|
| txt | #1A0606 |
| txt2 | #5A1414 |
| txt3 | #9A7070 |
| border | rgba(123,20,20,0.12) |
| border2 | rgba(123,20,20,0.22) |
| input border | #E2DDD5 |
| hint | #BBB4A8 |
| nav inactive | #AAAAAA |
| online dot | #22C55E |
| error | Material redAccent |

## Splash (dark) palette
card #5C1010, cardDeep #4A0C0C, muted text #D9C7B8.

## Chat
maroon #8B1118 · wallpaper #F8F5ED · gold #E8B547 · time grey #8C6F70 · text #241B1C.

## Legacy green (global Material theme only)
g1 #1C3010, g2 #2E4D18 (app bar default), g3 #4E6B22 (Material primary), input dark fill #243018.
**Designer note:** green shows only on screens that fall back to the global theme; treat crimson as the real brand and tell dev if green appears.

## Radii
sm 9 · md 12 · phone 40 · buttons: stadium (fully round) · cards 12–16.

## Type
No custom font — default Material (Roboto on Android). Serif (system) only for pre-login headlines: 28 / 26 px, w600. Labels: uppercase, small, bold (`appFieldLabelStyle`). Buttons: 14 px w800, letter-spacing 0.5.
Suggested Figma styles: Display serif 28/26, Title 18–20 w700, Body 14, Caption 12, Label 11 caps w700.

## Layout
Gutter 17 px. Bottom nav 56 px, 5 tabs, active = crimson icon + 18×3 gold bar. CrimsonHeader: crimson with diagonal 6 % white stripes every 28 px.
