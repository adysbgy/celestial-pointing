#!/usr/bin/env python3
"""Terjemahan pola → efek platform di `Apps/` wajib injektif dan lengkap.

**Cacat yang ditutup aturan ini, dan kenapa ia tidak terlihat.**

`HapticPolicy` (PointingKit, diuji di Linux) sudah memutuskan peristiwa mana
mendapat pola mana, dan sudah injektif atas keempat peristiwa. Sampai di
`Apps/`, dua berkas menerjemahkan pola itu ke API platform masing-masing:

    Apps/PointAndKnowWatch/Sources/HapticEngine.swift
        case .completed: return .success
        case .unsettled: return .retry
        case .failed:    return .failure
        case .tick:      return .click

    Apps/PointAndKnowiOS/Sources/PhoneHapticEngine.swift
        case .completed: UIImpactFeedbackGenerator(style: .medium)
        case .unsettled: UIImpactFeedbackGenerator(style: .rigid)
        case .failed:    UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .tick:      UIImpactFeedbackGenerator(style: .light)

Terjemahan itu **bukan hiasan**, dan ia bukan bagian yang aman. Diukur pada
salinan utuh pohon ini (proses baru, `./swift-ui-lint.sh` dijalankan atas
`Apps/`):

    .unsettled: .rigid   ->   .unsettled: .medium      swift-ui-lint.sh LULUS
    .unsettled: .retry   ->   .unsettled: .success     swift-ui-lint.sh LULUS

Dua keadaan, nol yang berbunyi — dan keduanya mengompilasi bersih. Akibatnya
**terasa di tangan**: getaran "ragu" menjadi tidak bisa dibedakan dari getaran
"berhasil" pada perangkat. Persis pelanggaran yang Aturan 47 tutup, hanya
satu tingkat lebih bawah: bukan pemetaan peristiwa→pola, melainkan
pola→efek. Model injektif tidak menolong kalau terjemahannya menyatu kembali.

Ini kelas yang berulang di repo ini dan sudah pernah nyata: `HapticPattern`
sebelumnya bernama `success`/`retry`/`failure`/`click`, dan Aturan 25 memerah
karena `switch result` (atas `Result<TelescopeCommand, Error>`) menyandang
himpunan label yang sama. Nama kasus enum yang berbagi himpunan label membuat
**setiap** `switch` di `Apps/` ambigu — bagi pembaca maupun bagi gerbang.
Aturan 106 menjaga terjemahannya, bukan nama kasusnya.

**Yang diperiksa, dan kenapa arahnya empat.**

1. Kedua berkas terjemahan ada. Gerbang yang kehilangan subjeknya hijau
   selamanya, jadi keberadaan keduanya diperiksa eksplisit.
2. Setiap `case` di kedua `switch` menerjemahkan ke efek yang **berbeda** dari
   semua `case` lain dalam berkas yang sama. Inilah inti injektivitas: dua
   pola yang memetakan ke efek yang sama berarti salah satu pola tidak bisa
   dikenali dari getaran.
3. Kedua `switch` **lengkap** — memuat keempat pola. Terjemahan yang
   kehilangan kasus membuat peristiwa itu tidak bergetar sama sekali, dan
   itu juga cacat: getaran adalah satu-satunya saluran yang tidak butuh mata.
4. Efek yang dipakai benar-benar efek platform yang nyata (`WKHapticType`
   `.success/.retry/.failure/.click`; UIKit `.light/.medium/.rigid` dan
   `.success/.warning/.error`). Efek yang tidak dikenal — mis. hasil salah
   ketik `.sccess` — akan ditolak, bukan diabaikan diam-diam.

**Batas yang diakui.** Gerbang ini membaca **teks**, jadi yang diukur adalah
perjanjian antar-teks, bukan rasa getaran di tangan. Efek `.light` dan
`.medium` pada iPhone memang berdekatan; yang diklaim di sini adalah bahwa
**dua pola tidak boleh memetakan ke efek yang sama persis**, dan bahwa
kasusnya lengkap — bukan bahwa jarak antar-efek sudah cukup lebar untuk
seluruh jari. Yang menahan jarak itu tetap `HapticPolicy` (pola peristiwa
berbeda) dan penilaian manusia di perangkat.

Pakai:
    python3 Tools/check-aturan106-terjemahan-haptic.py     # 0 = patuh
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: Berkas terjemahan pola → efek platform.
WATCH = os.path.join(ROOT, "Apps", "PointAndKnowWatch", "Sources",
                     "HapticEngine.swift")
PHONE = os.path.join(ROOT, "Apps", "PointAndKnowiOS", "Sources",
                     "PhoneHapticEngine.swift")

#: Keempat pola yang wajib punya terjemahan di kedua berkas.
PATTERNS = ["completed", "unsettled", "failed", "tick"]

#: Efek `WKHapticType` yang nyata. Sengaja sempit: yang dijaga adalah bahwa
#: efeknya dikenal, bukan bahwa ia "cukup berbeda".
WATCH_EFFECTS = {"success", "retry", "failure", "click"}

#: Efek UIKit yang nyata: gaya `UIImpactFeedbackGenerator` dan tipe
#: `UINotificationFeedbackGenerator`.
PHONE_IMPACT = {"light", "medium", "rigid", "soft", "heavy"}
PHONE_NOTIFICATION = {"success", "warning", "error"}


def read(path: str) -> str | None:
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return None


def strip_comments(source: str) -> str:
    """Buang komentar: doc-comment yang mengutip bentuk lama jangan diperiksa."""
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", source)


def parse_watch(code: str) -> tuple[dict[str, str], list[str]]:
    """`{pola: efek}` dari `case .x: return .y`, plus daftar masalah bentuk."""
    found: dict[str, str] = {}
    problems: list[str] = []
    for match in re.finditer(r"case\s+\.(\w+)\s*:\s*return\s+\.(\w+)", code):
        pattern, effect = match.group(1), match.group(2)
        if pattern in found:
            problems.append(
                f"`case .{pattern}` muncul dua kali di terjemahan jam")
        found[pattern] = effect
    return found, problems


def parse_phone(code: str) -> tuple[dict[str, str], list[str]]:
    """`{pola: efek}` dari `case .x: <efek UIKit>`, plus daftar masalah."""
    found: dict[str, str] = {}
    problems: list[str] = []
    for match in re.finditer(
            r"case\s+\.(\w+)\s*:\s*(?:return\s+)?(.*)", code):
        pattern, body = match.group(1), match.group(2).strip()
        if pattern in found:
            problems.append(
                f"`case .{pattern}` muncul dua kali di terjemahan iPhone")
            continue
        impact = re.search(r"UIImpactFeedbackGenerator\(style:\s*\.(\w+)\)",
                           body)
        if impact:
            found[pattern] = "impact:" + impact.group(1)
            continue
        notif = re.search(
            r"UINotificationFeedbackGenerator\(\)\s*\.\s*"
            r"notificationOccurred\(\.(\w+)\)", body)
        if notif:
            found[pattern] = "notification:" + notif.group(1)
            continue
        problems.append(
            f"`case .{pattern}` tidak menerjemahkan ke efek UIKit yang "
            f"dikenali: {body[:60]!r}")
    return found, problems


def main() -> int:
    failures: list[str] = []

    watch_src = read(WATCH)
    phone_src = read(PHONE)
    if watch_src is None:
        failures.append(
            "Apps/PointAndKnowWatch/Sources/HapticEngine.swift TIDAK ada — "
            "terjemahan pola→WKHapticType tidak punya subjek")
    if phone_src is None:
        failures.append(
            "Apps/PointAndKnowiOS/Sources/PhoneHapticEngine.swift TIDAK ada "
            "— terjemahan pola→UIKit tidak punya subjek")

    translations: dict[str, dict[str, str]] = {}
    if watch_src is not None:
        code = strip_comments(watch_src)
        if "switch pattern" not in code:
            failures.append(
                "HapticEngine.swift tidak lagi punya `switch pattern` — "
                "terjemahan pola→efek hilang, dan getaran berhenti berbunyi "
                "tanpa satu pun galat")
        found, problems = parse_watch(code)
        translations["jam"] = found
        failures.extend(f"[jam] {p}" for p in problems)
    if phone_src is not None:
        code = strip_comments(phone_src)
        if "switch pattern" not in code:
            failures.append(
                "PhoneHapticEngine.swift tidak lagi punya `switch pattern` "
                "— terjemahan pola→efek hilang, dan getaran berhenti berbunyi "
                "tanpa satu pun galat")
        found, problems = parse_phone(code)
        translations["iPhone"] = found
        failures.extend(f"[iPhone] {p}" for p in problems)

    # --- Kelengkapan ------------------------------------------------------
    for platform, mapping in translations.items():
        for pattern in PATTERNS:
            if pattern not in mapping:
                failures.append(
                    f"[{platform}] `case .{pattern}` tidak ada di terjemahan "
                    f"pola→efek — pola itu tidak bergetar sama sekali")

    # --- Efeknya dikenal ---------------------------------------------------
    if "jam" in translations:
        for pattern, effect in translations["jam"].items():
            if effect not in WATCH_EFFECTS:
                failures.append(
                    f"[jam] `.{pattern}` -> `.{effect}` bukan efek "
                    f"WKHapticType yang dikenal "
                    f"({', '.join(sorted(WATCH_EFFECTS))})")
    if "iPhone" in translations:
        for pattern, effect in translations["iPhone"].items():
            kind, _, name = effect.partition(":")
            if kind == "impact" and name not in PHONE_IMPACT:
                failures.append(
                    f"[iPhone] `.{pattern}` -> gaya `.{name}` bukan gaya "
                    f"UIImpactFeedbackGenerator yang dikenal "
                    f"({', '.join(sorted(PHONE_IMPACT))})")
            elif kind == "notification" and name not in PHONE_NOTIFICATION:
                failures.append(
                    f"[iPhone] `.{pattern}` -> tipe `.{name}` bukan tipe "
                    f"UINotificationFeedbackGenerator yang dikenal "
                    f"({', '.join(sorted(PHONE_NOTIFICATION))})")

    # --- Injektivitas, per platform ----------------------------------------
    for platform, mapping in translations.items():
        seen: dict[str, str] = {}
        for pattern in PATTERNS:
            if pattern not in mapping:
                continue
            effect = mapping[pattern]
            if effect in seen:
                failures.append(
                    f"[{platform}] `.{pattern}` dan `.{seen[effect]}` "
                    f"menerjemahkan ke efek yang SAMA (`{effect}`) — salah "
                    f"satu pola tidak bisa dikenali dari getaran")
            else:
                seen[effect] = pattern

    # --- Injektivitas antar platform untuk pasangan pola-------------------
    # Dua platform boleh memakai efek berbeda — memang harus, karena API-nya
    # berbeda. Yang dituntut adalah: untuk setiap pasangan pola, **tidak**
    # keduanya berubah menjadi sama. Ini diukur terpisah per platform di atas.

    if failures:
        for failure in failures:
            print(f"FAIL {failure}")
        print()
        print("-> Terjemahan pola→efek di Apps/ wajib satu pola satu efek,")
        print("   lengkap atas keempat pola, dan hanya memakai efek platform")
        print("   yang nyata. Pola peristiwa tetap dikunci HapticPolicy di")
        print("   PointingKit; yang dijaga di sini adalah bahwa terjemahannya")
        print("   tidak menyatukan kembali dua pola jadi satu rasa.")
        return 1

    print("OK HapticEngine.swift (jam) — 4 pola -> 4 efek WKHapticType beda")
    print("OK PhoneHapticEngine.swift (iPhone) — 4 pola -> 4 efek UIKit beda")
    print("OK kedua terjemahan lengkap atas keempat pola, efeknya dikenal")
    print()
    print("Aturan 106: terjemahan pola→efek di Apps/ injektif dan lengkap —")
    print("dua pola tidak bisa kembali terasa sama hanya karena satu baris")
    print("di `Apps/` yang tidak pernah dibangun swift-test.sh.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
