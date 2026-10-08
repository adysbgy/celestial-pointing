# Validation log & field protocol

Measured device results go here, with device model and OS version. Nothing in
this file is a result until a dated entry with real data says so.

## Environment (2026-10-08)

- Mac: Xcode 27.0 (27A266a); simulator runtimes iOS 26.5 and watchOS 26.5 only.
- iPhone: "AJs iPhone", iPhone 17 (iPhone18,3), iOS 27.0.1. Paired, not
  connected during the audit.
- Apple Watch: **not visible to Xcode yet.** Model and watchOS unknown.
- Simulator: both apps build. The Watch app installs and launches on the
  Apple Watch Ultra 3 simulator. Simulator motion does **not** validate
  pointing.

## Open questions the Pointing Lab answers (ADR-002, ADR-004)

1. **Convention check.** Is `gravityMismatchMedianDeg` near 0° in every trial?
   If it's large in tilted poses, the quaternion convention in ADR-002 is
   transposed and must be fixed before anything else.
2. **Axis sign.** For each wear setting (left/right wrist × crown left/right),
   does `.screenRight` or `.screenLeft` have the smaller `errorVsTruthDeg`?
   This tells us whether watchOS flips the sensor frame with the crown setting.
3. **Best ray.** Forearm ±X versus +Y and +Z, and the fitted device axis
   (`AxisSelection.fittedDeviceAxis`).
4. **Frames.** True-north versus arbitrary-corrected-plus-yaw-calibration.
   Also: does a second `CMMotionManager` lower the delivered rate (`observedHz`
   per frame, dual versus single stream)?
5. **Runtime.** Does `extendedRuntime` stay `running` while the arm is raised
   and the screen dims?

## Field protocol v1 — daytime terrestrial targets

Goal: a first error distribution without needing night sky or the telescope.

**Preparation**

- Choose 4–6 landmarks 50 m to 2 km away, for example a tower top, a building
  corner or a mast. Spread their bearings around the compass, with elevations
  from about 0° to 30°. Add one high target if possible (rooftop edge from
  close, about 45–60°).
- Get each landmark's **true-north bearing** and **elevation** independently:
  map bearing from your exact standing spot (satellite view), and elevation
  from `atan(height difference / distance)` or a clinometer app on a phone
  held against a straight edge. Write the method in the target name or note.
- Stand on a marked spot in an open field, at least 10 m from cars, metal
  fences and the telescope (environment = `open-field`).
- iPhone → Lab tab: enter each target (name, bearing, elevation) → **Send
  targets to Watch**. Allow location on both devices.

**Step 0 — 30-second sensor-stream check (always first)**

Apple recommends a single `CMMotionManager` per app, and the Lab can run two.
Before any pointing trial:

- In the Lab, for each **Sensor streams** mode (`dual`, `singleNorth`,
  `singleArbitrary`): rest the watch arm still for about 30 s, watching the
  per-frame Hz lines, then Mark 3 trials at any target.
- **Pass:** every active stream shows a steady rate near the request (50 Hz),
  and each trial's frames have `deliveredInWindow = true`.
- **If `dual` drops either stream's rate by more than 20 %, or a stream stops
  delivering:** run the rest of the protocol in `singleNorth` and note it.
- `Tools/analyze_pointing.py` reports delivered Hz per mode, so this check is
  in the data too.

**Trials**

- Watch → scroll to the bottom → **Lab Pointing**. Pick participant (P01…)
  and environment.
- For each target: pick it, point naturally with the **watch arm**, extended
  as you would to show a friend, hold still, then **Mark** with Double Tap or
  the button. Lower the arm fully between trials.
- **10 trials per target, per arm.** Do the left wrist first (watch on the
  left wrist, as worn), then move the watch to the right wrist. Change the
  watchOS wrist setting accordingly (Settings → General → Orientation) and
  repeat. Then, if possible, repeat one arm with the crown setting flipped
  (question 2).
- Repeat one target block in `singleArbitrary` mode (question 4).
- Repeat one target block standing about 1 m from the telescope or tripod
  (environment = `near-telescope`).
- At the end, **Send to iPhone**. On the iPhone Lab tab, check the file shows
  `n=` with the expected count, then Export (AirDrop) the `.jsonl` to the Mac
  into `ResearchLogs/` (git-ignored).

**Then night targets (protocol v2, after v1 is analysed):** Moon, bright
planets, and 3–4 bright isolated stars across 15–80° altitude, chosen from the
catalog list in the Lab picker. Same 10 × per arm.

## Results

_No device data yet._

## Live channel latency (device session, before any telescope test)

The 3 s GoTo staleness window (ADR-006) and the 4 s watch reply timeout are
**provisional**. In the simulator a watch→iPhone `sendMessage` round trip took
about 3.5 s.

**Procedure.**

1. Pair the iPhone and Watch (Debug build). Keep the iPhone app in the
   foreground, unlocked, within 1 m of the watch.
2. Run 20 confirms: Point → Confirm → note the result → Point again. For each
   one, record the watch-side delay from tap to "Sent to iPhone" (screen
   recording, or the device log timestamps for `sendMessage` and
   `handleResponse` in the WatchConnectivity log).
3. Repeat 10 confirms with the iPhone **locked** in a pocket, and 10 with the
   iPhone about 10 m away.

**Record.** p50 and p95 round trip, the number of `.noReply` timeouts, and
the number of "Saved — iPhone not reachable" results.

**Decide.**

- If p95 is over 2 s with the phone awake, raise the GoTo window and the
  reply timeout together, keeping timeout > window.
- If p95 is over 3 s, GoTo from the watch needs a different interaction, for
  example confirming the GoTo on the iPhone, before any motion test.

## GoTo / Stop latency (device session, after the live-channel step)

Do this only outdoors with clearance, after the live-channel latency step.
Use the Alpaca bridge or the Debug mock telescope.

**GoTo.** Run 10 GoTos to a confirmed bright object and time:

- watch tap → "GoTo accepted"
- tap → the watch shows "Telescope moving"
- tap → the mount physically starts moving

**Stop.** Run 10 Stops mid-slew and time:

- watch tap → "Telescope stopped"
- tap → the mount physically stops (video both)

**Failure cases.** Repeat 3 of each with the iPhone locked and 10 m away. GoTo
must show "Phone not reachable" and send nothing. Stop must show its failure
and the "stop it on the iPhone" instruction.

**Pass.**

- Stop takes effect within ≤ 2 s at p95.
- No GoTo ever executes after the watch has shown a failure.

Record p50/p95 for each.

**Known simulator finding.** `applicationContext` delivery stalled for about
17 s, which is longer than the 10 s staleness limit, so the watch also asks for
telescope state over the live channel every 3 s. Check on device how often each
path actually delivers.

## Threshold hypotheses (to be replaced by field data)

The confidence policy is provisional:

- σ = 10°
- best-candidate limit 1σ = 10°
- ambiguity margin 2σ = 20°
- search cone 20°

These numbers decide how often the watch can give **one** answer. The
statements below are hypotheses that field protocol v1 and v2 test. None of
them is a measurement.

**H1 — The error budget is dominated by the wrist-to-intent offset, not by the
sensor.** The expected contributors, not measured:

| Contributor | Expected | Notes |
|---|---|---|
| Tilt / altitude from gravity | ~1–2° | Watch still |
| Heading, true/magnetic-north frame | several degrees in open field, much larger near metal or the telescope | Depends on magnetometer calibration state, which is logged per sample |
| Heading drift, arbitrary-corrected frame after yaw calibration | grows with time since calibration | |
| Forearm axis vs. intended ray | systematic, likely 5–15° and pose-dependent | |
| Human pointing repeatability | a few degrees | |

*Test:* compare raw error, error after one-point yaw calibration and error
after Wahba (analysis script, leave one target out), and the
`magneticAccuracy` / `near-telescope` splits.

**H2 — With σ = 10°, about half the stars can never be a single answer.**
Computed from the bundled catalog (25 bright stars + 18 DSOs) on
2026-10-08:

- The nearest-neighbour separation has a median of 13.8° for all objects and
  22.8° for stars only. The closest pairs are Alnitak–M42 (3.7°), M6–M7
  (3.9°) and Castor–Pollux (4.5°).
- How many of the 25 stars have no neighbour inside the ambiguity margin, and
  so can ever produce *one answer*:

  | σ | ambiguity margin | stars that can be one answer |
  |---|---|---|
  | 10° | 20° | 14/25 |
  | 7° | 14° | 17/25 |
  | 5° | 10° | 19/25 |
  | 3° | 6° | 23/25 |

  The rest will always end in *Possible matches*. That's honest, but it's the
  dominant UX outcome if σ stays at 10°.
- **Implication:** a measured σ of about 5° after calibration is the
  difference between "usually one answer" and "usually a list".

*Test:* replay the field trials through the resolver (analysis replay) and
count single / possible / not-sure per target.

**H3 — Visibility filtering, not geometry, separates most DSOs.** Most DSOs
are filtered out by twilight, the Moon and the magnitude limit, so near pairs
such as Alnitak–M42 rarely compete in practice. *Test:* log the candidate
count per trial at night (v2).

**H4 — 20° is too wide a search cone once σ is known.** The cone should be
about 2.5–3σ, so that "Not sure" happens when nothing is near rather than
matching something 18° away. *Test:* false-confident rate versus cone in the
replay.

**Decision rule.** After protocol v1 + v2, set σ to the P68 of
post-calibration error, keep ambiguity = 2σ and cone ≈ 3σ, then mark the
policy `measured`. The UI line changes from PROVISIONAL automatically. If P68
stays above about 8°, consider shrinking the catalog to well-separated objects
rather than showing lists most of the time.

## Analysis

```sh
python3 Tools/analyze_pointing.py ResearchLogs/*.jsonl > ResearchLogs/report.md
```

**What the report contains.** Stdlib only; numpy is optional.

- Error, repeatability and bias for every frame × axis × arm × target. Every
  axis is recomputed from each trial's mean quaternion, so the wrong-axis rows
  are there too: they're how question 2 is answered.
- Gravity-convention mismatch and delivered Hz per stream mode.
- Leave-one-target-out replays of one-point yaw, all-target yaw and Wahba
  calibration.

**Checks to read first.**

- The first line cross-checks Python's recomputed pointing against the Swift
  summary. A ❌ there means the two sides disagree on the frame convention.
- `PointingLabAnalysisContractTests` writes a synthetic file with a known
  bias (+2° alt, +3° az) through the app's own code path and runs this script
  on it. Schema or convention drift between Swift and the script turns the
  Swift test suite red. Set `CP_WRITE_LAB_FIXTURE=<path>` to keep that file.
