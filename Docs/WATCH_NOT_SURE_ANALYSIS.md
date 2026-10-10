# Why the watch said "Not sure yet" every time

**Report:** Ady, 9 Oct 2026, 13:44 WIB, real Apple Watch Series 10.
**Report text:** "kenapa not sure yet terus". It also "feels like a cheap app".

## How "Not sure yet" is produced

`HomeView` shows it for `IdentificationOutcome.notSure`, which comes from
`PointingState.searching`. That state means the wrist was still, but the
resolver found **no candidate** in the 20° cone.

An object is a candidate only if it passes **all** of these checks
(`VisibilityFilter.classify`):

| Check | Threshold |
|---|---|
| Altitude | ≥ 5° |
| Magnitude | ≤ 6.0, tightened by moonlight |
| Distance from the Sun | ≥ 30° |
| Sky dark | Sun < −6° |

On top of that there is a separate hard rule: never claim anything while
pointing within the Sun-safe cone.

## Evidence

I ran the production resolver (`EngineFactory.makeResolver()`) for Jakarta
(−6.2°, 106.8°), sampling 220 directions above 10° altitude.

### 13:44 WIB, the time of the report

- **Sky.** Sun altitude **+59°**. Moon at +42°, but only **2% lit** (new moon
  is 10 Oct).
- **Rejected objects.** `daylight` 14, `tooCloseToSun` 4, `belowHorizon` 24,
  `tooFaint` 7.

| Object | Rejected as |
|---|---|
| Moon | tooCloseToSun |
| Mercury | tooCloseToSun |
| Venus | tooCloseToSun (near inferior conjunction, 23 Oct) |
| Jupiter | daylight |
| Mars | belowHorizon |
| Saturn | belowHorizon |

- **Outcome.** **220 of 220 directions give no candidate**: "Not sure yet"
  everywhere, by design.

### 20:00 WIB, tonight, assuming a perfect compass

| Outcome | Directions |
|---|---|
| lock | 29 (13%) |
| possible matches | 97 (44%) |
| none | 94 (43%) |

The catalog is thin: 49 objects, about 15 of them up at once.

## Root causes

1. **Daytime.** Nothing is identifiable in daylight. The old UI said
   "Not sure yet" without explaining that it was daytime or when to come back.
2. **Arbitrary compass frame.** The watch ran Core Motion in
   `xArbitraryZVertical`. Its azimuth is **random every time the sensor
   starts** and only becomes meaningful after a calibration in the same
   session. Without calibration, pointing at Jupiter makes the engine search a
   different part of the sky. The result is "Not sure", or worse, a wrong name.
3. **Empty sky with no guidance.** Even at night with a perfect compass, 43%
   of directions have nothing within 20°. The screen gave no direction to move.
4. **The design gave no next action.** A grey question mark and one generic
   line felt cheap.

Ruled out:

- **Location.** The fallback location is Jakarta, so even without permission
  the sky would be right for Ady.
- **Hold-still threshold.** It was not the cause: "Not sure" is only shown
  *after* the wrist is judged still.

## Fixes (ADR-011)

- **North-referenced frame:** `xTrueNorthZVertical`, then
  `xMagneticNorthZVertical`, then arbitrary, with a runtime fallback.
  "Calibrate first" is shown only when the frame really has no heading.
- **Daytime screen:**
  - "It's daytime"
  - "Stars appear around 18:07" (civil dusk, computed from the ephemeris)
  - the three brightest objects tonight
- **Live guide:** a compass ring with a marker that rotates toward the
  nearest visible object, plus its distance in degrees ("Move to Rigel, 35°").
  It appears whenever the user isn't locked. It never claims an identity.
- **Polish:**
  - SF Rounded
  - larger artwork on lock (64 pt)
  - kind icons in lists
  - smooth cross-fade between states, and numeric transitions on the distance
- **Developer screen:** Settings → Developer → "Why not sure?" shows the live
  values: state, hint, frame, calibration, location, Sun altitude, number of
  visible objects, pointing direction, rate, and nearest object.

## Still open

- **Real-watch frame check.** Confirm on the real watch which frames it
  reports (look at "Why not sure?" → frame).
- **Product decision:** allow the Moon and Venus in daylight when bright and
  far from the Sun (mag ≤ −3.5)? The PRD currently forbids it; a test guards
  that rule.
- **Catalog.** A larger catalog of ~150 stars brighter than mag 3 would cut
  the "nothing here" share well below 43%.

## Rehearsal for the first night test (ADR-012)

Setup: Jakarta, 9 Oct 2026, 18:45 / 19:30 / 21:00 WIB, production pipeline,
north-referenced frame.

### Dark-sky limit (mag 6.0)

- About half the targets are invisible deep-sky objects.
- Antares, and every cluster in the south-west, came out "possible matches".

### City limit (mag 3.0), the new default

| Time (WIB) | Visible | Locks on itself |
|---|---|---|
| 18:45 | 8 | 8 |
| 19:30 | 7 | 7 |
| 21:00 | 7 | 7 |

The objects:
- Saturn (east, 20°, rising to 53°)
- Vega (north-west)
- Altair (high, north to west)
- Deneb (north, low)
- Fomalhaut (south-east, high)
- Antares (south-west, setting)
- Achernar (south-east, low)
- Hadar (south-west, very low, only early)

With a 7° pointing error, Saturn, Vega, Antares and Fomalhaut still lock.
