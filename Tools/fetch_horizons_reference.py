#!/usr/bin/env python3
"""Segarkan golden reference efemeris dari NASA/JPL Horizons.

Kenapa ini ada:
    Akurasi efemeris adalah hipotesis yang harus diuji, bukan diasumsikan
    (PRD v0.4). `EphemerisTests` membandingkan backend AstronomyKit dengan
    fixture ini. Fixture di-commit ke repo supaya CI tetap deterministik dan
    tidak butuh jaringan.

Jalankan hanya bila ingin memperluas rentang tanggal/benda:
    python3 Tools/fetch_horizons_reference.py

Sumber data: https://ssd.jpl.nasa.gov/api/horizons.api
Kerangka: airless apparent RA/Dec, equator & equinox of date, geosentris
          (CENTER='500@399'), satuan derajat.
"""

from __future__ import annotations

import json
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path

# Horizons body IDs: 301 Bulan, 199 Merkurius, 299 Venus, 499 Mars, 599 Jupiter, 699 Saturnus.
BODIES: dict[str, str] = {
    "moon": "301",
    "mercury": "199",
    "venus": "299",
    "mars": "499",
    "jupiter": "599",
    "saturn": "699",
}

DATES: list[str] = [
    "2000-01-01 00:00",
    "2024-01-01 00:00",
    "2026-06-15 12:00",
]

MONTHS = {
    "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6,
    "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12,
}

OUT = Path(__file__).resolve().parent.parent / "Packages" / "CelestialEngine" / \
    "Tests" / "CelestialEngineTests" / "Fixtures" / "horizons_reference.json"


def fetch(body_id: str, start: str) -> str:
    stop = (datetime.strptime(start, "%Y-%m-%d %H:%M") + timedelta(minutes=1)) \
        .strftime("%Y-%m-%d %H:%M")
    params = {
        "format": "text",
        "COMMAND": f"'{body_id}'",
        "OBJ_DATA": "'NO'",
        "MAKE_EPHEM": "'YES'",
        "EPHEM_TYPE": "'OBSERVER'",
        "CENTER": "'500@399'",
        "START_TIME": f"'{start}'",
        "STOP_TIME": f"'{stop}'",
        "STEP_SIZE": "'1m'",
        "QUANTITIES": "'2,9'",
        "ANG_FORMAT": "'DEG'",
        "APPARENT": "'AIRLESS'",
    }
    url = "https://ssd.jpl.nasa.gov/api/horizons.api?" + urllib.parse.urlencode(params)
    last: Exception | None = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=60) as response:
                return response.read().decode()
        except Exception as exc:  # noqa: BLE001 - retry any transport error
            last = exc
            time.sleep(2)
    raise RuntimeError(f"Horizons gagal untuk {body_id} @ {start}: {last}")


def parse(text: str) -> tuple[float, float, float, str]:
    lines = text.splitlines()
    marker = lines.index("$$SOE")
    row = lines[marker + 1]
    match = re.match(r"\s*(\S+)\s+(\d\d:\d\d)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)", row)
    if not match:
        raise RuntimeError(f"baris tak terduga: {row!r}")
    date_s, time_s, ra, dec, mag = match.groups()
    year, month, day = date_s.split("-")
    iso = f"{int(year):04d}-{MONTHS[month]:02d}-{int(day):02d}T{time_s}:00Z"
    return float(ra), float(dec), float(mag), iso


def main() -> int:
    samples = []
    for name, body_id in BODIES.items():
        for date in DATES:
            ra, dec, mag, iso = parse(fetch(body_id, date))
            samples.append({
                "body": name, "utc": iso,
                "raDeg": ra, "decDeg": dec, "magnitude": mag,
            })
            print(f"  {name:8s} {iso}  ra={ra:9.5f}  dec={dec:+9.5f}  mag={mag:+7.3f}")

    fixture = {
        "_note": "Golden reference for ephemeris validation. NOT produced by this project's code.",
        "_source": "NASA/JPL Horizons API (https://ssd.jpl.nasa.gov/api/horizons.api)",
        "_retrieved": datetime.utcnow().strftime("%Y-%m-%d"),
        "_frame": "Airless apparent RA/Dec, Earth equator & equinox of date, geocentric (CENTER='500@399')",
        "_query": "QUANTITIES='2,9' ANG_FORMAT='DEG' APPARENT='AIRLESS'",
        "_ephemeris": "DE441 (Moon/planets), jup365_merged (Jupiter), sat441l (Saturn), mar099 (Mars)",
        "samples": samples,
    }
    OUT.write_text(json.dumps(fixture, indent=2) + "\n")
    print(f"\n{len(samples)} sampel -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
