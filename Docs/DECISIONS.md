# Architecture Decision Records

Short records of decisions that change architecture or overturn an earlier
assumption. Newest at the bottom. Each record says what was wrong, how it was
shown, and what replaced it.

---

## ADR-001 — Embed the Watch app at `Watch/`, not `PlugIns/` (2026-10-08)

**Context.** `project.yml` had a `postGenCommand` that rewrote the generated
"Embed Watch Content" phase from `dstSubfolderSpec = 16`,
`dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"` to `dstSubfolderSpec = 13`
(`PlugIns/`), justified as "Xcode 16+ requires it". The complication target
also had no `CURRENT_PROJECT_VERSION`, so its `CFBundleVersion` resolved to an
empty string.

**Evidence** (Xcode 27.0, iPhone 17 + Apple Watch Ultra 3 simulators, 26.5):

- With the app in `PlugIns/`, `simctl install` on the iPhone succeeds and the
  Watch app is silently ignored. No error is reported, and the build stays green.
- With the app moved to `Watch/`, installd validates the Watch bundle and
  rejects it: *"Appex bundle at …/Watch/PointAndKnowWatch.app/PlugIns/
  PointAndKnowWatchComplication.appex … does not have a CFBundleVersion key
  with a non-zero length string value"*. So `PlugIns/` was hiding that defect.
- With both fixes, the iPhone app installs, and the Watch app installs and
  launches on the watch simulator.

**Decision.**

- Remove the `postGenCommand`. XcodeGen 2.46.0 emits Xcode's standard
  `Watch/` phase on its own.
- Move `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` to project-level
  settings so all three targets inherit the same values.
- Add `CFBundleDisplayName` to the complication's `info.properties`, so
  `xcodegen generate` stops dropping it from the plist.

**Not yet proven.** Installation on physical devices. CI only builds and never
installs, which is why neither defect was caught. The complication's Debug
config still has `CODE_SIGNING_ALLOWED: NO`, which will block a signed device
install. That is left for the signing step.

---

## ADR-002 — Core Motion frame convention, explicit reference frame, forearm axis (2026-10-08)

**Context.** `DeviceAttitude.deviceToWorld` computed `rollMatrix · R(q)`,
where `rollMatrix` (at roll 0) sends reference-X to North, reference-Y to Up
and **reference-Z to East**. Its doc comment said: *"+Z (keluar layar) ->
Timur, +Y (atas layar) -> Zenith, +X (kanan layar) -> Utara"*. The suite
locked that in:

```swift
func testIdentityAttitudeMapsViewToEast() {
    let h = DeviceAttitude.identity.horizontalPointing(aim: .view)!
    XCTAssertEqual(h.altitudeDeg, 0, accuracy: eps)
    XCTAssertEqual(h.azimuthDeg, 90, accuracy: eps)
}
```

In every `CMAttitudeReferenceFrame`, Z is vertical, so identity attitude
means the device is **lying flat, screen up**. The old mapping read a screen
facing the zenith as "East, on the horizon". The claim in `MotionLogger` and
`Calibration.swift` that "altitude is already absolute" was therefore false
for real sensor data. Every synthetic test built its quaternions by inverting
the same wrong mapping (`Vector3(x: v.y, y: v.z, z: v.x)`, copied into 9 test
files), so all 896 green tests were self-consistent but never checked Apple's
convention. Two more problems:

- The pointing ray was the screen normal (`.view`), not the forearm.
- `wristLocation` and `crownOrientation` were never read.

**Decision.**

1. *Convention.* `v_ref = R(q) · v_device`, where `R(q)` is the standard
   active matrix of `CMAttitude.quaternion`. Reference to ENU is fixed for all
   four frames: `(E, N, U) = (−Y, X, Z)`. That follows from X = North (or
   arbitrary), Z = Up and right-handedness, which forces Y = West.
2. *The frame is explicit.* `DeviceAttitude.frame` and
   `PointingControllerConfig.frame` carry an `AttitudeReferenceFrame`.
   `MotionLogger` starts Core Motion with the controller's frame, so the
   quaternion and its interpretation can't drift apart. The default stays
   `xArbitraryZVertical` (yaw from calibration) until field data compares it
   with the north-referenced frames.
3. *Forearm axis.* The default aim is `.screenRight` (+X), the forearm for the
   default watchOS wear (left wrist, crown right). The watch app derives ±X
   from `WKInterfaceDevice` via `WearConfiguration.forearmAim`. The iPhone
   uses `.screenUp` (top edge). `.view` (+Z) stays as an experiment option.
4. *The sign is a hypothesis.* We don't know whether watchOS flips the sensor
   frame when the crown setting changes. `CalibrationSession` now keeps the
   raw attitude of each sample. `AxisSelection.evaluate` scores +X, −X, +Y,
   −Y and +Z, each with its own yaw fit, and returns all five so they can be
   logged. It **reports**; it does not switch the axis automatically yet.
5. *On-device convention check.* `DeviceAttitude.predictedGravity`
   (`−R(q)ᵀ ẑ`) against `CMDeviceMotion.gravity`. If the convention is right
   the mismatch is near 0°. If it's transposed, the mismatch is large at any
   non-yaw attitude (tested).

**How the new expectations were derived.** From Apple's frame definitions and
Apple's documented gravity readings, not from code output:

- flat face-up → +Z at alt 90°
- flat, +X North → az 0°
- yaw 90° CCW → +X West
- arm raised 45° (−45° about Y) → alt 45°
- flat gravity = (0, 0, −1)
- upright gravity = (0, −1, 0)

The old `FramesTests` cases were rewritten in place, each with a note on why
its expectation changed.

**Not yet proven.** All of this is verified against Apple's documented
definitions only. The sign of ±X per wear setting, the real gravity mismatch,
and whether the forearm is the best ray all need the Pointing Lab on a
physical watch (ADR-004, Docs/VALIDATION.md).

---

## ADR-003 — Calibration models as an experiment (2026-10-08)

- `yawOnly` (existing `CalibrationSolver`) stays the only model the user
  calibration flow applies. Its residual was already a great-circle (full 3D)
  error.
- `WahbaSolver` (Horn's quaternion method, Jacobi eigen-solver, pure Swift)
  fits a full rotation from at least two non-collinear references. It is
  available as `CalibrationModel.wahba` for offline comparison only.
- `AxisSelection.fittedDeviceAxis` estimates the best pointing ray in the
  device frame (mean of `R(q)ᵀ t`). It needs a north-referenced frame.

Which model ships is decided from the field data, not here.

---

## ADR-004 — Pointing Lab: measure before tuning (2026-10-08)

**Decision.** Add a research screen, separate from the product flow:

- On the watch: "Lab Pointing", at the bottom of the main scroll.
- On the iPhone: a "Lab" tab.

**What it records.** Each **Mark** (button, or Double Tap via
`handGestureShortcut(.primaryAction)`) captures a ±0.5 s window of raw
`CMDeviceMotion` from up to two simultaneous streams: a north-referenced frame
(true north if available, else magnetic) and arbitrary-corrected. Each sample
has the quaternion, gravity, rotation rate, user acceleration, magnetic field
and accuracy, and heading. Each trial also records:

- wear configuration and the active aim axis
- the target and its ground truth
- observer location, rounded to 0.01°
- environment
- extended-runtime state
- per-stream summaries: delivered Hz, mean pointing for every candidate axis,
  aim spread, gravity-convention mismatch, and error against truth in the
  north frame

**Storage and transfer.** Trials are appended as JSONL on the watch
(`Documents/PointingLab/`) and sent with `transferFile`. The iPhone moves the
file into its own `Documents/PointingLab/` inside the delegate callback and
offers a `ShareLink` export. Manual landmark targets go phone → watch with
`transferUserInfo`, under a key separate from `PointingLinkMessage`, so the
product protocol is untouched.

**Why two `CMMotionManager`s.** Apple recommends one instance per app because
extra instances can lower the delivered rate. The lab records the delivered
rate per stream, and dual-stream can be switched off, so the cost is
measured, not assumed. The product `MotionLogger` is stopped while the Lab is
open.

**`WKExtendedRuntimeSession`.** Uses `WKBackgroundModes = physical-therapy`
(partial `Apps/PointAndKnowWatch/Info.plist` merged with the generated keys),
so recording continues if the screen dims with the arm raised. Whether it
actually runs is logged per trial.

**Not verified.** The simulator has no device motion, and input injection
into the watch simulator didn't work, so the Lab screen was compiled and
launched but not exercised. First real run is on Ady's watch.

---

## ADR-005 — Signing through xcconfig; the developer only types a team ID (2026-10-08)

**Setup.**

- `Config/Base.xcconfig` (checked in) sets these for every target:
  - `CODE_SIGN_STYLE = Automatic`
  - an empty `DEVELOPMENT_TEAM`
  - `BUNDLE_ID_PREFIX = dev.celestial`
  - the two App Group entitlement paths
- It then optionally includes the git-ignored `Config/Local.xcconfig`.
  `Config/Local.xcconfig.example` documents what can go there.
- `project.yml` uses it as the project `configFiles`.

**Changes.**

- Bundle IDs, `WKCompanionAppBundleIdentifier`, the App Group in both
  entitlements files, and a new `CPAppGroupID` Info.plist key (read by
  `ComplicationStore`) all derive from `$(BUNDLE_ID_PREFIX)`.
- `CODE_SIGN_ENTITLEMENTS` goes through `$(CP_WATCH_ENTITLEMENTS)` and
  `$(CP_COMPLICATION_ENTITLEMENTS)`, so a team that can't use App Groups can
  blank them. The complication store already falls back to a private cache.
- The complication's `Debug: CODE_SIGNING_ALLOWED: NO` is removed. Signed
  builds embed the complication, and an unsigned appex inside a signed app
  fails device install.

**Verification.**

- With an override of `BUNDLE_ID_PREFIX = com.example.test`, the complication
  resolves to `com.example.test.pointandknow.watchkitapp.widgets` with
  entitlements cleared.
- Simulator builds are unchanged (`CODE_SIGNING_ALLOWED=NO` passed on the
  command line).

**Tooling.** `Tools/device-run.sh <TEAMID> [prefix]` writes `Local.xcconfig`,
runs XcodeGen, and builds both schemes for `generic/platform=iOS` and
`generic/platform=watchOS` with `-allowProvisioningUpdates`, so provisioning
errors surface before anything is installed. Not yet run with a real team.

---

## ADR-006 — Live Watch↔iPhone channel for confirm, status, GoTo and Stop (2026-10-08)

**Context.** Every Watch↔iPhone path used `updateApplicationContext` (latest
state) or `transferUserInfo` (a queue). That's right for state but dangerous
for actions: a queued GoTo can execute minutes later, after the user has
walked away from the telescope.

**Decision** (`PointingKit/LiveChannel.swift`, tested with a fake session and
a fake clock).

- `sendMessage` with a reply for:
  - confirmed target
  - telescope status
  - GoTo
  - Stop
- **GoTo, Stop and status** fail immediately with `.unreachable` when the
  iPhone isn't reachable, and with `.transportFailed` on error. The client has
  no queueing path for them.
- **Confirm** goes live when reachable. Otherwise, or on error, it's sent as
  `confirmRecord` through `transferUserInfo`. The phone stores that as
  history only, and it never unlocks GoTo.
- **Ordering.** Every message carries a monotonic `id`, persisted on the watch
  so it survives a relaunch, plus `sentAt`. The phone rejects:
  - an `id` not newer than the last one (`replayed`)
  - a GoTo whose age is over 3 s in either direction (`stale`)
  - a GoTo for an object other than the last live-confirmed one
    (`notConfirmed`)
  - a GoTo when the telescope isn't `ready` (`telescopeUnavailable`)
- **Stop always executes,** even out of order. Stopping is the safe direction.
- **Execution.** `BridgeTelescopeExecutor` resolves the confirmed object
  through `PointingResolver` and runs `SlewPlanner` with
  `intent.level = .high`: the user's confirmation stands in for pointing
  confidence. All geometric gates (Sun, altitude, magnitude, unknown Sun
  position) still apply. `TelescopeSession` then sends catalog coordinates,
  never wrist direction.
- **Transport.** `MockTelescopeTransport` only, for now. No motor can move
  through this path until the Seestar adapter exists.

**Wiring.**

- On the watch: `WatchLinkService.live`, a `LiveChannelClient` over
  `WCLiveSession`.
- On the iPhone: `PhoneLinkService.liveServer` (lock-protected, since the
  delegate runs on a background queue) replies inside
  `session(_:didReceiveMessage:replyHandler:)`.
- The observer location is pushed from the iPhone engine into a lock-protected
  box.
- Not yet driven from the watch UI: that comes with the identification loop
  (M5).

**Unverified.** Real `sendMessage` latency and clock skew between devices. The
3 s window may need tuning from device logs.

---

## ADR-007 — Watch Identify → Confirm loop on the provisional σ (2026-10-08)

**Decision.**

- **Outcome mapping.** `IdentificationOutcome` (PointingKit, pure, tested)
  maps the existing state machine and `CelestialIntent` onto the three
  product answers, with no new thresholds:
  - `idle` / `pointing` → *Hold steady*
  - `lock` → one answer
  - `uncertain` → *Possible matches* (best plus up to 3 candidates)
  - `searching` → *Not sure yet*
- **Watch panel.** `IdentificationPanel` sits under the status card. Confirm
  (button, or Double Tap on the single answer) plays a success haptic
  immediately, because matching and confirmation are complete on the watch,
  offline. It then sends `confirmTarget` over the live channel (ADR-006). The
  card says "Sent to iPhone", "Saved — iPhone not reachable", or "Couldn't
  send".
- **Provisional σ.** The σ in use is always shown as `σ 10.0° PROVISIONAL`
  until `ConfidencePolicy.isMeasured`.
- **iPhone.** The Link tab shows "Confirmed on Watch" with the name rebuilt
  from the object id in the phone's language. Queued records are labelled as
  such.
- **Reply timeout.** `LiveChannelClient.replyTimeout` is 4 s, longer than the
  phone's 3 s GoTo window. The watch simulator reported the shut-down iPhone
  as reachable, and `sendMessage` then never called back. Now a confirm falls
  back to a record, and status/GoTo/Stop return `.noReply` ("outcome
  unknown"), never a queue.
- **Object names.** `ObjectNameLocalization` with keys `object.name.<id>`.
  English shows "Saturn" and "Andromeda Galaxy"; Indonesian is unchanged.
- **Debug pose injector** (DEBUG only). Launch with
  `-debugPose single|ambiguous|empty|moving|object:<id>` and
  `-onboardingSeen YES` to drive every state on simulators. It uses one base
  attitude plus small yaw rotations; rebuilding the shortest arc each sample
  made roll jump and read as 9–46°/s of motion.

**Verified on simulators** (watchOS/iOS 26.5, SE 40 mm, Ultra 3, iPhone 17):

- all four outcomes render
- tapping Confirm on the Ultra 3 → "Saturn confirmed · Sent to iPhone"
- the iPhone Link tab shows "Confirmed on Watch — Saturn"
- the watch→phone round trip took ~3.5 s in the simulator; to be measured on
  devices against the 3 s GoTo window

**Known UX debt for the M6 pass.**

- The Confirm button sits below the fold on 40 mm, under the large status
  card.
- The prominent button is grey.
- "°/dtk" is untranslated in the English UI.
- The iPhone shows "10,0°" (comma) in English UI.
- The extended runtime session is rejected on unsigned simulator builds
  ("client is not entitled"); expected, to recheck on a signed device build.

**Update (M6 UX pass, same day).**

- *Layout.* The identify panel now sits **above** the status card, so Confirm
  is visible without scrolling on 40 mm.
- *Button.* The prominent Confirm button is green with **black** text. White
  measured about 1.8:1; black is about 11:1.
- *Every state pairs an icon with text.* A grayscale pass on SE 40 and
  Ultra 3 shows each state is identifiable without colour.
- *VoiceOver.* The σ line is read as a sentence ("Provisional accuracy
  threshold, 10 degrees, not yet measured"). Possible matches is a header,
  and Hold steady updates frequently.
- *Units and numbers.*
  - "°/dtk" is now catalog-driven (`unit.perSecondSuffix`, "/s" in English).
  - Numbers follow the **app** language (`Bundle.main.preferredLocalizations`),
    not the device language-region ("en-ID" printed "10,0°").
- *State reporting.* Watch → iPhone state reports hang off
  `PointingEngine.onIngest`, so debug poses and sensors report alike.
- *Reduce Motion.* Already gated through `MotionPolicy` for the pulse and the
  arrival pop. The new panel has no animation.
