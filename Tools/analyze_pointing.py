#!/usr/bin/env python3
"""Analyse Pointing Lab JSONL files (ADR-004, Docs/VALIDATION.md).

    python3 Tools/analyze_pointing.py ResearchLogs/*.jsonl            > report.md
    python3 Tools/analyze_pointing.py --json ResearchLogs/*.jsonl     > report.json

Stdlib only (numpy is used for the eigen-solver if it is installed).

What it reports, per frame x axis x arm x target:
  n, median / P90 / P95 great-circle error vs ground truth, repeatability
  (spread around the per-target mean direction), bias vector (mean
  d-azimuth*cos(alt), d-altitude in degrees), and globally the gravity-
  convention mismatch and delivered Hz per frame and stream mode.

Calibration replay, leave-one-target-out:
  * yaw:   one-point yaw offset from the trials of ONE other target
           (each other target in turn), applied to the held-out target;
  * yawAll: yaw offset fitted on ALL other targets;
  * wahba: full 3-D rotation (Horn's quaternion method) fitted on all other
           targets (needs >= 2 non-collinear).
  Arbitrary-heading frames only get calibrated numbers; raw error vs truth is
  meaningless there because azimuth has no absolute reference.

Pointing is recomputed from each trial's mean quaternion with the convention of
ADR-002 (v_ref = R(q) v_device, (E,N,U) = (-Y, X, Z)) and cross-checked against
the Swift summary, so a convention drift between the app and this script is
reported instead of silently skewing the numbers.
"""
import argparse
import json
import math
import sys
from collections import defaultdict

AXES = {
    "view": (0.0, 0.0, 1.0),
    "screenUp": (0.0, 1.0, 0.0),
    "screenRight": (1.0, 0.0, 0.0),
    "screenLeft": (-1.0, 0.0, 0.0),
    "screenDown": (0.0, -1.0, 0.0),
}
ABSOLUTE_FRAMES = {"xMagneticNorthZVertical", "xTrueNorthZVertical"}

# ---------------------------------------------------------------- vector math


def norm(v):
    m = math.sqrt(sum(c * c for c in v))
    return tuple(c / m for c in v) if m > 0 else None


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def angle_deg(a, b):
    return math.degrees(math.acos(max(-1.0, min(1.0, dot(norm(a), norm(b))))))


def quat_rotate(q, v):
    w, x, y, z = q
    qv = (x, y, z)
    t = tuple(2 * c for c in cross(qv, v))
    c2 = cross(qv, t)
    return tuple(v[i] + w * t[i] + c2[i] for i in range(3))


def enu_from_device(q, aim):
    """ADR-002: v_ref = R(q) aim; (E, N, U) = (-Y_ref, X_ref, Z_ref)."""
    r = quat_rotate(q, aim)
    return norm((-r[1], r[0], r[2]))


def enu_from_horizontal(alt, az):
    a, z = math.radians(alt), math.radians(az)
    return (math.cos(a) * math.sin(z), math.cos(a) * math.cos(z), math.sin(a))


def horizontal_from_enu(v):
    v = norm(v)
    alt = math.degrees(math.asin(max(-1.0, min(1.0, v[2]))))
    az = math.degrees(math.atan2(v[0], v[1])) % 360.0
    return alt, az


def rot_z(v, deg):
    """Rotate an ENU vector about Up so its azimuth increases by `deg`."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    # azimuth is measured North->East, i.e. clockwise seen from above
    return (v[0] * c + v[1] * s, -v[0] * s + v[1] * c, v[2])


def wrap180(d):
    return (d + 180.0) % 360.0 - 180.0


def circular_mean_deg(angles):
    s = sum(math.sin(math.radians(a)) for a in angles)
    c = sum(math.cos(math.radians(a)) for a in angles)
    if abs(s) < 1e-15 and abs(c) < 1e-15:
        return None
    return math.degrees(math.atan2(s, c))


def mean_direction(vs):
    return norm(tuple(sum(v[i] for v in vs) for i in range(3)))


# ------------------------------------------------------------- Wahba (Horn)


def largest_eigenvector_4(m):
    try:
        import numpy as np  # optional

        w, v = np.linalg.eigh(np.array(m, dtype=float))
        return [float(x) for x in v[:, int(np.argmax(w))]]
    except ImportError:
        pass
    n = 4
    a = [row[:] for row in m]
    v = [[1.0 if i == j else 0.0 for j in range(n)] for i in range(n)]
    for _ in range(100):
        off = sum(a[p][q] ** 2 for p in range(n) for q in range(p + 1, n))
        if off < 1e-22:
            break
        for p in range(n):
            for q in range(p + 1, n):
                if abs(a[p][q]) < 1e-300:
                    continue
                theta = (a[q][q] - a[p][p]) / (2 * a[p][q])
                t = (1.0 if theta >= 0 else -1.0) / (abs(theta) + math.sqrt(theta * theta + 1))
                c = 1 / math.sqrt(t * t + 1)
                s = t * c
                for k in range(n):
                    akp, akq = a[k][p], a[k][q]
                    a[k][p], a[k][q] = c * akp - s * akq, s * akp + c * akq
                for k in range(n):
                    apk, aqk = a[p][k], a[q][k]
                    a[p][k], a[q][k] = c * apk - s * aqk, s * apk + c * aqk
                for k in range(n):
                    vkp, vkq = v[k][p], v[k][q]
                    v[k][p], v[k][q] = c * vkp - s * vkq, s * vkp + c * vkq
    best = max(range(n), key=lambda i: a[i][i])
    return [v[k][best] for k in range(n)]


def wahba(measured, truth):
    """Rotation q with truth ~= q.rotate(measured). None if unobservable."""
    if len(measured) < 2:
        return None
    first = measured[0]
    if all(math.sqrt(sum(c * c for c in cross(m, first))) < 1e-6 for m in measured):
        return None
    s = [[0.0] * 3 for _ in range(3)]
    for m, t in zip(measured, truth):
        for i in range(3):
            for j in range(3):
                s[i][j] += m[i] * t[j]
    (sxx, sxy, sxz), (syx, syy, syz), (szx, szy, szz) = s
    n = [
        [sxx + syy + szz, syz - szy, szx - sxz, sxy - syx],
        [syz - szy, sxx - syy - szz, sxy + syx, szx + sxz],
        [szx - sxz, sxy + syx, -sxx + syy - szz, syz + szy],
        [sxy - syx, szx + sxz, syz + szy, -sxx - syy + szz],
    ]
    return norm(tuple(largest_eigenvector_4(n)))


# ------------------------------------------------------------------- stats


def percentile(values, p):
    v = sorted(x for x in values if x is not None and math.isfinite(x))
    if not v:
        return None
    return v[max(0, min(len(v) - 1, math.ceil(p * len(v)) - 1))]


def stats(errors):
    errors = [e for e in errors if e is not None]
    if not errors:
        return {"n": 0}
    return {
        "n": len(errors),
        "median": percentile(errors, 0.5),
        "p90": percentile(errors, 0.9),
        "p95": percentile(errors, 0.95),
    }


# ------------------------------------------------------------------ loading


def load(paths):
    trials, bad = [], 0
    for path in paths:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    trials.append(json.loads(line))
                except json.JSONDecodeError:
                    bad += 1
    return trials, bad


def observations(trials):
    """One record per trial x frame x axis, with recomputed pointing."""
    obs = []
    max_dev = 0.0
    for t in trials:
        truth = t.get("truth")
        if not truth:
            continue
        tv = enu_from_horizontal(truth["altitudeDeg"], truth["azimuthDeg"])
        arm = t.get("wear", {}).get("wrist", "?")
        target = t.get("target", {}).get("name", "?")
        for fr in t.get("frames", []):
            q = (fr.get("summary") or {}).get("meanQuaternion")
            if not q:
                continue
            for axis, vec in AXES.items():
                v = enu_from_device(q, vec)
                swift = (fr["summary"].get("pointing") or {}).get(axis)
                if swift:
                    max_dev = max(max_dev, angle_deg(v, enu_from_horizontal(
                        swift["altitudeDeg"], swift["azimuthDeg"])))
                obs.append({
                    "frame": fr["frame"], "axis": axis, "arm": arm, "target": target,
                    "aimInApp": t.get("aim"), "v": v, "truth": tv,
                    "streamMode": t.get("streamMode"),
                })
    return obs, max_dev


# ------------------------------------------------------------------ analysis


def bias_vector(pairs):
    """Mean (d-az*cos(alt), d-alt) in degrees over (measured, truth) pairs."""
    if not pairs:
        return None
    dx = dy = 0.0
    for v, t in pairs:
        ma, mz = horizontal_from_enu(v)
        ta, tz = horizontal_from_enu(t)
        dx += wrap180(mz - tz) * math.cos(math.radians(ta))
        dy += ma - ta
    return {"dAzCosAlt": dx / len(pairs), "dAlt": dy / len(pairs)}


def yaw_offset(pairs):
    deltas = [wrap180(horizontal_from_enu(t)[1] - horizontal_from_enu(v)[1]) for v, t in pairs]
    return circular_mean_deg(deltas)


def analyse(trials):
    obs, max_dev = observations(trials)
    groups = defaultdict(list)
    for o in obs:
        groups[(o["frame"], o["axis"], o["arm"])].append(o)

    rows = []
    calib = []
    for (frame, axis, arm), items in sorted(groups.items()):
        absolute = frame in ABSOLUTE_FRAMES
        by_target = defaultdict(list)
        for o in items:
            by_target[o["target"]].append(o)

        for target, its in sorted(by_target.items()):
            vs = [o["v"] for o in its]
            mean = mean_direction(vs)
            spread = [angle_deg(v, mean) for v in vs] if mean else []
            row = {
                "frame": frame, "axis": axis, "arm": arm, "target": target, "n": len(its),
                "repeatabilityMedian": percentile(spread, 0.5),
                "repeatabilityMax": max(spread) if spread else None,
            }
            if absolute:
                row["error"] = stats([angle_deg(o["v"], o["truth"]) for o in its])
                row["bias"] = bias_vector([(o["v"], o["truth"]) for o in its])
            rows.append(row)

        # Leave-one-target-out calibration replay.
        targets = sorted(by_target)
        if len(targets) < 2:
            continue
        yaw1, yaw_all, wah = [], [], []
        for held in targets:
            test = by_target[held]
            train_targets = [x for x in targets if x != held]
            # one-point: calibrate on each other target in turn
            for ref in train_targets:
                off = yaw_offset([(o["v"], o["truth"]) for o in by_target[ref]])
                if off is None:
                    continue
                yaw1 += [angle_deg(rot_z(o["v"], off), o["truth"]) for o in test]
            train = [o for x in train_targets for o in by_target[x]]
            off = yaw_offset([(o["v"], o["truth"]) for o in train])
            if off is not None:
                yaw_all += [angle_deg(rot_z(o["v"], off), o["truth"]) for o in test]
            q = wahba([o["v"] for o in train], [o["truth"] for o in train])
            if q is not None:
                wah += [angle_deg(quat_rotate(q, o["v"]), o["truth"]) for o in test]
        calib.append({
            "frame": frame, "axis": axis, "arm": arm, "targets": len(targets),
            "raw": stats([angle_deg(o["v"], o["truth"]) for o in items]) if absolute else None,
            "yawOnePointLOO": stats(yaw1),
            "yawAllLOO": stats(yaw_all),
            "wahbaLOO": stats(wah),
        })

    # Sensor / convention health.
    gravity = []
    hz = defaultdict(list)
    delivered = defaultdict(lambda: [0, 0])
    for t in trials:
        mode = t.get("streamMode") or "unknown"
        for fr in t.get("frames", []):
            s = fr.get("summary") or {}
            if s.get("gravityMismatchMedianDeg") is not None:
                gravity.append(s["gravityMismatchMedianDeg"])
            rate = fr.get("deliveredHzBeforeMark") or s.get("observedHz")
            if rate is not None:
                hz[(mode, fr["frame"])].append(rate)
            d = delivered[(mode, fr["frame"])]
            d[1] += 1
            if fr.get("deliveredInWindow", bool(fr.get("samples"))):
                d[0] += 1

    return {
        "trials": len(trials),
        "conventionCrossCheckMaxDeg": max_dev,
        "gravityMismatchDeg": {
            "median": percentile(gravity, 0.5), "p95": percentile(gravity, 0.95),
            "max": max(gravity) if gravity else None,
        },
        "deliveredHz": [
            {"streamMode": m, "frame": f, "median": percentile(v, 0.5), "min": min(v),
             "deliveredWindows": delivered[(m, f)][0], "windows": delivered[(m, f)][1]}
            for (m, f), v in sorted(hz.items())
        ],
        "rows": rows,
        "calibration": calib,
    }


# ------------------------------------------------------------------- output


def fmt(x, digits=1):
    return "–" if x is None else f"{x:.{digits}f}"


def fmt_stats(s):
    if not s or not s.get("n"):
        return "–"
    return f"{fmt(s['median'])} / {fmt(s['p90'])} / {fmt(s['p95'])} (n={s['n']})"


def markdown(r):
    out = ["# Pointing Lab report", ""]
    out.append(f"Trials: **{r['trials']}**")
    out.append("")
    out.append("## Sensor and convention health")
    out.append("")
    dev = r["conventionCrossCheckMaxDeg"]
    out.append(f"- Python vs Swift pointing (same quaternion, ADR-002): max deviation "
               f"{dev:.2e}° {'✅' if dev < 1e-3 else '❌ CONVENTION DRIFT'}")
    g = r["gravityMismatchDeg"]
    out.append(f"- Gravity vs convention prediction: median {fmt(g['median'], 2)}°, "
               f"P95 {fmt(g['p95'], 2)}°, max {fmt(g['max'], 2)}° "
               "(near 0° = quaternion convention confirmed on device)")
    out.append("")
    out.append("| stream mode | frame | Hz median | Hz min | windows with samples |")
    out.append("|---|---|---|---|---|")
    for h in r["deliveredHz"]:
        out.append(f"| {h['streamMode']} | {h['frame']} | {fmt(h['median'])} | {fmt(h['min'])} | "
                   f"{h['deliveredWindows']}/{h['windows']} |")
    out.append("")
    out.append("## Error per frame × axis × arm × target (north-referenced frames)")
    out.append("")
    out.append("Error = great-circle degrees, median / P90 / P95. Repeatability = spread "
               "around the per-target mean direction (median, max). Bias = mean "
               "(Δaz·cos alt, Δalt).")
    out.append("")
    out.append("| frame | axis | arm | target | error | repeatability | bias |")
    out.append("|---|---|---|---|---|---|---|")
    for row in r["rows"]:
        if "error" not in row:
            continue
        b = row.get("bias")
        bias = f"({fmt(b['dAzCosAlt'])}, {fmt(b['dAlt'])})" if b else "–"
        out.append(f"| {row['frame']} | {row['axis']} | {row['arm']} | {row['target']} | "
                   f"{fmt_stats(row['error'])} | {fmt(row['repeatabilityMedian'])}, "
                   f"{fmt(row['repeatabilityMax'])} | {bias} |")
    out.append("")
    out.append("## Calibration replay (leave one target out)")
    out.append("")
    out.append("| frame | axis | arm | targets | raw | yaw 1-point | yaw all | Wahba |")
    out.append("|---|---|---|---|---|---|---|---|")
    for c in r["calibration"]:
        out.append(f"| {c['frame']} | {c['axis']} | {c['arm']} | {c['targets']} | "
                   f"{fmt_stats(c['raw'])} | {fmt_stats(c['yawOnePointLOO'])} | "
                   f"{fmt_stats(c['yawAllLOO'])} | {fmt_stats(c['wahbaLOO'])} |")
    out.append("")
    return "\n".join(out)


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("files", nargs="+")
    p.add_argument("--json", action="store_true", help="machine-readable output")
    a = p.parse_args(argv)
    trials, bad = load(a.files)
    if not trials:
        print("no trials found", file=sys.stderr)
        return 1
    report = analyse(trials)
    report["badLines"] = bad
    if a.json:
        json.dump(report, sys.stdout, indent=2, default=lambda o: list(o))
        print()
    else:
        print(markdown(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
