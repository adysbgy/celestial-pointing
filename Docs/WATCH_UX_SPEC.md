# Watch UX spec v1 (ADR-010, 2026-10-09)

**Principle:** a tiny window into the sky. One screen, one job: point →
see the name → "Yes, that's it". Everything technical lives in Settings.

## Home (root)

**Layout.** A `NavigationStack` with a single toolbar button, the settings
gear at top leading. The content is a vertical stack, top to bottom:

1. **Stop bar.** Only while a slew might be in progress (ADR-009 rule
   unchanged).
2. **Hero, one of:**

   | Outcome | Hero |
   |---|---|
   | idle | scope icon · "Point at the sky" · "Raise your arm toward what you see" |
   | moving | hand icon · "Hold still…" |
   | one answer | object visual (44 pt) · **name** (title2, bold) · "Planet · Bright" · green **"Yes, that's it"** button (Double Tap) |
   | possible matches | "Could be one of these" · up to 3 rows (name + type), each a confirm button |
   | not sure | "Not sure yet" + the engine's real reason (e.g. sun icon · "The sky is still bright — stars are not visible yet") or "Point more precisely, then hold still" |
   | no sensor | "Motion sensor unavailable" |

3. **Approximate location.** One caption, only if the location is a
   fallback.

**Fit.** No scrolling is needed for any state on 40, 42 or 49 mm (see
`Docs/watch-ux/after/`).

## Result (after confirming)

- Visual, name, "Kind · Brightness".
- Two plain facts: "72° above the horizon", "Toward the south".
- iPhone status, as icon + text: sent / saved (iPhone not reachable) /
  failed.
- Telescope section: state, and GoTo when allowed (ADR-009).
- **Point again** (a bordered button). There's no back chevron, so the
  result can't be dismissed by accident.

## Settings

- **Toggles:** Night mode (red), Sound when found.
- **Links:** Calibrate, Sky & location.
- **iPhone connection** status.
- **Developer:**
  - Technical details: the old full screen, as a sheet
  - Pointing Lab
  - the σ line with PROVISIONAL

## Copy rules

- Plain words, one idea per line. No σ, °/s, RA/Dec or frame names outside
  Developer.
- Indonesian is the source; English comes from the catalog. Examples:
  "Tunjuk ke langit", "Tahan diam…", "Mungkin salah satu ini",
  "Ya, itu dia", "45° di atas cakrawala", "Arah selatan".

## Accessibility

- Every state is an SF Symbol plus text. Never colour only.
- The Confirm button's VoiceOver label is "Confirm <name>".
- Possible matches is a header.
- Hold still is marked `updatesFrequently`.
- Green button with black text (~11:1).
- Reduce Motion and Always-On reuse the existing `NightAwareContainer` /
  `ReducedLuminanceView`.
