# Watch ↔ iPhone sync: analysis and design (ADR-020)

Ady: "It's satisfying when the user knows the watch is connected to the iPhone
and connecting feels good … it looks like there's no data sync, I don't
understand the current one."

## What already ran, but wasn't visible

| Data | Channel | Problem |
|---|---|---|
| Live confirmation ("Yes, that's it") | `sendMessage` + reply (ADR-006) | Only the **last** one was kept on the iPhone. Confirmations made while the iPhone was away arrived through the queue, but went nowhere visible. |
| Pointing state | `updateApplicationContext` | Only visible on the developer screen (Link). |
| Telescope status | context every 2 s | Watch only. |
| Stellarium mirror | `sendMessage` ≤ 4 Hz | Only when Stellarium is on. |
| Settings (dark sky, hot–cold) | **none** | Changing them on the iPhone didn't change the watch, and vice versa. |
| Connection status | `isReachable` | Only on the developer screen. Users had **no way** of knowing whether the watch was connected. |

The infrastructure was correct (WCSession is active from launch), but users
never saw it work.

## How good Apple apps do it (Workout, Activity, Maps for watch)

1. **One clear status, always visible:**
   - live: green;
   - connected but the watch app isn't open: yellow;
   - not ready: grey, with the next step written out.
2. **Three channels for three kinds of data:**
   - `sendMessage`: live, when reachable. It feels instant.
   - `updateApplicationContext`: the latest state, which the receiving app
     reads when it opens (settings, status).
   - `transferUserInfo`: events that **must not be lost** (confirmations),
     queued until the other side is available.
3. **Optimistic UI.** The watch shows the result immediately. The iPhone later
   shows "From Apple Watch" without asking the user to do anything.
4. **Two-way settings, last writer wins** (by timestamp).

## Decision (implemented)

- **`WatchConnectionState` (PointingKit, tested).**
  - States: not paired / app not installed / standby (+ when the last data
    arrived) / live.
  - Shown as a **pill at the top of the Sky tab** (watch ⇄ iPhone icon with a
    pulsing signal when live). Tapping it opens a **detail sheet**:
    - a checklist (paired, app installed, app open, last data);
    - "What syncs";
    - "How to connect".
  - The same row is in Settings.
- **Journal syncs automatically.** Every confirmation (live **or** from the
  queue) is saved with the "From Apple Watch" label, deduplicated by the
  watch's message id.
- **`SyncedSettings`: dark sky + hot–cold haptics, both directions.**
  - iPhone → watch: context (persistent) + `sendMessage`.
  - Watch → iPhone: `sendMessage` when reachable + `transferUserInfo` as a
    guarantee.
  - On activation, both sides exchange their versions so they converge.
  - Changes coming from the other device are not sent back, so there is no
    ping-pong.
- **Watch:** the calm screen shows "iPhone connected" or "iPhone away: data
  sent later"; Settings shows the same.

## Evidence (paired simulators, iPhone 17 ↔ Ultra 3)

- **iPhone → watch:** "Dark sky" changed on the iPhone shows up on the watch
  with the same timestamp.
- **Watch → iPhone:** "Hot–cold" turned off on the watch shows up on the
  iPhone with the same timestamp. A queued transfer alone stalled in the
  simulator, which is why `sendMessage` + queue is used.
- **Journal:** Saturn confirmed on the watch appears in the iPhone Journal as
  "From Apple Watch".
- **Status:** the pill shows "Connected · live" with all checks ticked.

Screenshots: `Docs/design/sync-*.png`.
