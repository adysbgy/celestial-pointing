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

---

## ADR-008 — Telescope: standard ASCOM Alpaca first, Seestar-native later and POC-only (2026-10-08)

**Context.** Two facts drive this.

- **No official third-party API.** ZWO publishes no third-party control API for
  the Seestar.
- **The native path needs a vendor secret.** The community path through
  seestar_alp changed in **v3.2.2 (released 2026-05-06)**. Its release notes
  list *"Add interop PEM-based client authentication for firmware 7.18+"*
  (PR #735), and say this applies to "a subset of users". The PR explains the
  mechanism. Firmware 7.18 removed the legacy `verify` parameter, and remote
  clients must now run a **challenge-response** handshake:
  `get_verify_str` → sign the challenge with an **RSA private key** (PEM,
  SHA1withRSA / PKCS#1 v1.5) → `verify_client`. The key is the
  "interoperability PEM" extracted from the Seestar APK
  (bguthro/seestar-tool → "Extract PEM"). It is **not** a client certificate.
  (An earlier draft of this ADR said "client certificate"; corrected
  2026-10-09.)

So talking natively to a Seestar on current firmware means shipping or
extracting a private key from ZWO's own app. We won't ship that, and it can't
be a stable product dependency.

**Decision.**

- **Standard first.** The app talks **standard ASCOM Alpaca Telescope v1**
  (`PointingKit/AlpacaTelescope.swift`). seestar_alp, or any Alpaca driver, can
  bridge a Seestar to it, and any other Alpaca mount works unchanged.
- **Seestar-native later.** Seestar-native control stays a **later, POC-only**
  option, after Ady's exact firmware version is known.
- **Endpoints implemented:** `connected` (GET/PUT), `canslewasync`,
  `equatorialsystem`, `tracking` (NotImplemented is tolerated),
  `slewtocoordinatesasync` (RA in hours, Dec in degrees), `slewing`,
  `abortslew`.
- **Request tagging and errors.** Every request carries `ClientID` and an
  increasing `ClientTransactionID`. `ErrorNumber ≠ 0` becomes
  `AlpacaError.device`. Each blocking transport call is capped at 2.5 s, so
  the phone still answers the watch inside its 4 s reply timeout (ADR-006).
- **Coordinate frame comes from the mount.**
  - `equatorialsystem` 1 (topocentric/JNow) maps to `.ofDate`.
  - 2 maps to `.j2000`.
  - Anything else disables GoTo; we never guess.
  - A command whose frame differs from the mount's is refused before any
    network call.
- **Precession.** Of-date uses `SkyMath.precessJ2000ToDate`, which
  `PrecessionTests` already validates against AstronomyKit (worst case
  15.9″). `MountFrameTests` shows that Sirius J2000 versus of-date differs by
  ~0.29° in RA in 2026, matching the annual-rate formula. That is more than a
  fifth of the Seestar S50 field, so choosing the frame matters.
- **No async slew means no GoTo.** A mount without `CanSlewAsync` gets no
  capability, so GoTo is disabled.
- **Off by default.** The feature flag `telescope.alpaca.enabled` and the
  address (`host:port`) live in the iPhone Link tab.
- **Executor swap.** `SwitchableTelescopeExecutor` swaps the mock for Alpaca at
  runtime. While connecting, or on failure, there is no executor and GoTo is
  rejected as `telescopeUnavailable`.
- **iPhone permissions.**
  - `NSLocalNetworkUsageDescription` (id in `project.yml`, en and id in
    `InfoPlist.strings`).
  - `NSAppTransportSecurity.NSAllowsLocalNetworking = true` in a partial
    `Apps/PointAndKnowiOS/Info.plist`, so plain-HTTP Alpaca works on the local
    network only.

**Verified.**

- **Fake-server tests.** 12 tests run against an in-process URLProtocol fake
  server:
  - connect and request tagging
  - GoTo → slewing ×3 → ready, with RA in hours
  - abort mid-slew
  - a device error mid-slew
  - a disconnected device
  - no async slew, or an unsupported frame
  - frame mismatch
  - tracking NotImplemented
- **Simulator.** The iPhone simulator connected to a stand-in Alpaca server
  over real HTTP and showed "Connected (J2000)".

**Not verified.** Any real mount. seestar_alp's exact Alpaca behaviour
(EquatorialSystem, tracking). Stop latency on hardware.

---

## ADR-009 — GoTo / Stop from the watch (2026-10-09)

**Decision.**

- **Pure rules.** `TelescopeControlModel` (PointingKit, pure, 20 tests) owns
  every rule, and the views only render it.
  - **GoTo:**
    - It appears only for an object that the iPhone accepted over the live
      channel.
    - It needs a reachable iPhone and a fresh (≤ 10 s) "ready" report.
    - It is hidden whenever Stop is shown.
    - It is never bound to Double Tap.
  - **Stop (revised 2026-10-09 after an independent check):** the first
    version hid Stop once a report went stale, unless this watch had sent
    the GoTo. A slew started from the iPhone whose reports then stopped
    showed "state unknown" with **no Stop**. The rule now is:
    - Stop shows whenever a slew *might* be in progress: latest state slewing
      (fresh or stale), stale after any non-"off" report, error, a GoTo sent
      from here and not proven finished, or a Stop pending or failed.
    - It is hidden only when the latest **fresh** report is
      ready/off/disconnected and nothing is pending.
    - Before any report arrives it is shown unless the feature is known off
      (the last "off" report is remembered across launches).
    - Stop now lives in a persistent bar at the top of the main watch
      screen (`TelescopeStopBar`), independent of the confirmation card.
    
    Original rule:
    - reported slewing
    - a GoTo was sent and isn't proven finished: accepted, no reply, or the
      state became unknown or error
    - a failed Stop
    
    It survives "Point again".
  - **A GoTo counts as finished** when a fresh report shows slewing then ready,
    or ready persists 20 s after acceptance.
  - **A rejected GoTo** (iPhone said no) means "not moving".
  - **Older reports never overwrite newer ones.**
- **Status transport, two paths.**
  - The iPhone reports `TelescopeStatus` in the application context every 2 s.
    The context is now built from separate pointing and telescope parts, so
    neither erases the other, and the watch skips a pointing message it has
    already handled.
  - While the iPhone is reachable, the watch also asks over the live channel
    every 3 s, because the simulator showed a 17 s stall in context delivery.
- **No queue, no retry.** Unreachable shows "Phone not reachable". A failed
  Stop says to stop it on the iPhone.
- **Telescope selection on the iPhone.**
  - Debug builds use the mock telescope when Alpaca is off. Release builds have
    **no** telescope then: a mock reporting "ready" would show a false GoTo.
  - Alpaca on but not yet connected → no telescope ("Not connected — GoTo
    unavailable"), never the mock.
- **Simulator tools.**
  - The mock slews for a fixed time (default 8 s; DEBUG
    `-debugMockSlewSeconds`).
  - DEBUG `-debugTelescope ready|slewing|off` fakes reports on the watch for
    screenshots.

**Verified on simulators** (iPhone 17 + Ultra 3, 26.5):

- *With the mock:*
  - Confirm → "Telescope ready" → GoTo → Stop with "Telescope moving" →
    "Telescope reached the target".
  - GoTo → Stop mid-slew → "Telescope stopped".
- *With the Python stand-in Alpaca server over HTTP:* the watch GoTo produced
  `PUT tracking`, then `PUT slewtocoordinatesasync RightAscension=6.752477
  Declination=-16.716116` (Sirius J2000), and the watch Stop produced
  `PUT abortslew`.

**Not verified.** Real mount behaviour. Real WatchConnectivity latency and
context delivery. The 10 s / 3 s / 20 s constants are provisional (see
VALIDATION.md).

---

## ADR-010 — Watch redesign: one screen, one job (2026-10-09)

**Problem.** Ady, on his own Series 10: "the UI/UX is a mess, I don't
understand it". The review (`Docs/WATCH_UX_REVIEW.md`) found:

- seven or more competing blocks
- technical numbers in the main flow
- four toolbar icons
- duplicated status
- daylight advice that was wrong
- developer tools in the product flow

**Decision.** A new `HomeView` replaces `PointingView` as the root:

- point → big name → "Yes, that's it" (Double Tap)
- a `ResultView` with two plain facts and the telescope section
- a native `WatchSettingsView` for everything else

The old screen remains under Settings → Developer → Technical details. No
engine logic changed. New copy goes in `WatchHomeText` (31 catalog keys,
tested), and the "not sure" hint now shows the engine's real search reason.
Spec: `Docs/WATCH_UX_SPEC.md`.

**Verified** on 40, 42 and 49 mm simulators (en and id), with screenshots in
`Docs/watch-ux/after/`.

**Not verified.** A night-sky test by Ady on the real Watch.

## ADR-011 — North-referenced frame, daylight screen, live guide (2026-10-09)

**Problem.** On his real Watch at 13:44 WIB, Ady saw "Not sure yet" every
time. The evidence is in `Docs/WATCH_NOT_SURE_ANALYSIS.md`: it was daytime, so
220 of 220 sampled directions had no candidate. The watch also used
`xArbitraryZVertical`, whose azimuth is random each session until calibration.
And at night 43% of the sky has no object within the 20° cone.

**Decision.**
- **Frame.** The watch prefers `xTrueNorthZVertical`, then
  `xMagneticNorthZVertical`, then arbitrary.
  - If true north is refused at runtime (`CMErrorTrueNorthNotAvailable`, e.g.
    no location permission), `MotionLogger` drops to the next frame.
  - Calibration still applies on top as an azimuth correction.
  - On an arbitrary frame, Home shows "Calibrate first".
- **Daylight.** When the sky is bright and nothing passes the filters, Home
  shows "It's daytime", the time of civil dusk (Sun at −6°), and the three
  brightest objects one hour after dark. It no longer shows a generic
  "Not sure".
- **Guide.** When not locked, Home shows a compass ring whose marker points
  to the nearest *visible* object, with its distance. This covers both
  searching and moving while far from every object.
  - The guide never locks, never plays the success haptic, and never enables
    GoTo.
- **Unchanged.** The PRD rule that the Moon/Venus are rejected in daylight.
  Allowing very bright objects (mag ≤ −3.5) by day is an open product decision.

**Verified.**
- Unit tests in `SkyGuideTests`:
  - arrow geometry, including across north;
  - nearest object;
  - the report's afternoon has zero visible objects;
  - Jakarta dusk falls at 18:0x WIB;
  - tonight list;
  - frame order and fallback.
- 46 mm simulator screenshots: `Docs/watch-ux/after-*-46mm.png`.

**Not verified.** Which frames the real Series 10 reports, and how accurate its
compass is near metal.

## ADR-012 — City sky by default (2026-10-09)

**Problem.** A rehearsal for Ady's first night test (Jakarta, 18:45, 19:30
and 21:00 WIB) used the default naked-eye limit of mag 6.0, a dark-sky value.
- Half the "visible" objects were deep-sky objects that can't be seen from a
  city: Lagoon, Omega, Butterfly, the Sagittarius cluster.
- Pointing exactly at Antares gave "Maybe Antares / Butterfly / Ptolemy".
- The guide could send the user toward a nebula they can't see.

**Decision.**
- New `SkyQuality` setting: **city** (the default) or **dark**.
  - City: limit mag **3.0**, moonlight tightening 0.5 mag.
  - Dark: the old policy.
- Watch Settings has a "Dark sky" toggle.
- `PointingController.setVisibilityPolicy(_:)` applies the change live and
  invalidates old answers, like `setConfidencePolicy(_:)`.
- The iPhone app keeps the dark-sky policy for now.

**Verified.** `TonightRehearsalTests`, with the city sky in Jakarta at all
three times:
- 7 or 8 visible objects, including Saturn.
- **Every** visible object locks to itself when pointed at.
- Saturn, Vega, Antares and Fomalhaut still lock with a 7° wrist error.
- With the dark-sky policy, Antares is ambiguous (kept as a regression proof).

## ADR-013 — iPhone "Sky" tab, and the iPhone was always rendered light (2026-10-10)

**Problem.** The iPhone app was still a set of research tabs (Diagnostics,
Experiment 1, Link, Lab), with no counterpart to the new watch flow. Building
the counterpart exposed an older bug: the root `TabView` set
`.preferredColorScheme(nightMode ? .dark : nil)`.
- That root preference overrode every tab's `forceDarkScheme()`.
- On an iPhone set to light mode, the whole app rendered white.
- The colour tokens are computed for a dark background, so secondary text was
  barely readable.

**Decision.**
- **New first tab, "Sky"** (`SkyHomeView`), which shows:
  - the object last confirmed on the watch: artwork, name, kind and
    brightness, its direction and height now, and the time;
  - by day: "It's daytime", the dusk time, and "Tonight";
  - by night: "Visible now", each object with direction and height in words;
  - the same city/dark-sky switch as on the watch.
- `SkyGuideModel` and `ObjectKind.guideSymbol` move to `Apps/Shared`, so both
  apps use the same sky logic.
- New helper `PointingResolver.object(forID:observer:date:)` turns the watch's
  id into an object, with the name rebuilt in the iPhone's language.
- The root view always forces the dark scheme. Night mode (red) stays a
  palette choice.
- DEBUG: `-debugConfirmed <id>` fills the card for screenshots.

**Verified.** iPhone 17 simulator, light-mode device, Jakarta at midnight:
dark rendering, Saturn card, visible-now list
(`Docs/watch-ux/after-iphone-sky-tab.png`).
