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
