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
