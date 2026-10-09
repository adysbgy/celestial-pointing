# Watch UX review (2026-10-09)

Screenshots: `Docs/watch-ux/before/` (Series 11 42 mm simulator, watchOS 26.5,
the same size class as Ady's Series 10, Watch7,8).

## What the old main screen asked the user to process

On one scrolling screen, in order:

1. **Top bar.** Four toolbar icons: sky info, calibration warning, night mode,
   sound. Plus the clipped app title, until it was removed.
2. **Status card.** A coloured heading ("Locked / Not certain / Searching /
   Aiming"), a sentence of explanation, and a raw rate such as "0°/s" or
   "46°/s".
3. **Identify panel.**
   - The "Confirm X" button
   - "σ 10.0° PROVISIONAL"
   - telescope state
4. **Object card.** Visual, name, type, confidence badge, "mag 1.4",
   "RA … Dec …".
5. **Diagnostics.**
   - the slew-verdict banner
   - "This device does not provide device motion" (red)
   - "Location: Jakarta (default)"
   - "iPhone connected · 1 failed"
6. **Developer link.** The "Pointing Lab" button.

## Problems against Apple's watchOS HIG

| # | Problem | Why it matters on a wrist |
|---|---|---|
| 1 | Seven or more blocks; the answer and Confirm compete with diagnostics | A watch interaction should take 1–2 s with **one primary action** |
| 2 | Technical numbers in the main flow (σ, PROVISIONAL, °/s, RA/Dec, magnitude) | Meaningless to a curious stargazer, and reads as "broken" |
| 3 | Four toolbar icons, two of them state toggles | Hidden meaning, small targets |
| 4 | The status heading and the identify panel say the same thing twice ("Locked" + "Confirm") | Redundant, and doubles the reading |
| 5 | Red warnings that are normal on a simulator or in daylight | Alarming without telling the user what to do |
| 6 | "Not sure — point more precisely" shown in **daylight** | Wrong advice: the real reason is that the sky is bright |
| 7 | The Lab, link counters and fallback location sit in the main scroll | Developer tools leaking into the product |
| 8 | The answer often sits below the fold | The wrist is raised; scrolling with the pointing arm defeats the gesture |

## What was already right (kept)

- One honest answer, possible matches, or not sure (ADR-007).
- Stop always reachable (ADR-009).
- Night (red) palette, Always-On reduced view, Reduce Motion gating.
- Localization (en/id), VoiceOver labels.
