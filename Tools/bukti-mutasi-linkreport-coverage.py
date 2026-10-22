#!/usr/bin/env python3
"""Bukti bahwa penjaga baru di LinkReportCoverageTests benar-benar menggigit.

Tiga mutasi, satu per penjaga. Untuk tiap mutasi: pulihkan berkas, jalankan
HANYA kelas uji itu, dan tuntut exit != 0. Mutasi yang tidak membuat merah
berarti penjaganya kosong.

Jalankan dari akar repo: python3 Tools/bukti-mutasi-linkreport-coverage.py
"""
import pathlib
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
TESTS = REPO / "Packages/PointingKit/Tests/PointingKitTests/LinkReportCoverageTests.swift"
REPORT = REPO / "Packages/PointingKit/Sources/PointingKit/LinkReport.swift"

MUTATIONS = [
    (
        "peta dikirimDi mengklaim medan yang tidak pernah diisi",
        TESTS,
        '"note": [],',
        '"note": [.pointingState],',
        "Penjaga 2",
    ),
    (
        "entri peta menunjuk medan yang tidak ada di pesan",
        TESTS,
        '"sampleCount": [.calibrationReady],',
        '"sampleCount": [.calibrationReady],\n        "sentAtX": [.pointingState],',
        "Penjaga 1b",
    ),
    (
        "medan di pesan dibiarkan tanpa entri peta",
        TESTS,
        '"isCalibrated": [.pointingState],',
        "",
        "Penjaga 1",
    ),
    (
        "baris sigma kalibrasi dihapus dari laporan",
        REPORT,
        "        ] + sigmaAndTimeRows(message)",
        "        ]",
        "sapuan medan tak terlihat",
    ),
    (
        "baris waktu kalibrasi dihapus dari laporan",
        REPORT,
        '        rows.append(Row(title: TextLocalization.text(.linkRowTime),\n'
        '                        value: message.sentAt.formatted(date: .omitted, time: .standard)))\n'
        "        return rows",
        "        return rows",
        "sapuan medan tak terlihat (sentAt)",
    ),
]


def run_tests():
    return subprocess.run(
        ["./swift-test.sh"],
        cwd=REPO,
        capture_output=True,
        text=True,
    )


def main():
    failures = []
    for name, path, old, new, guard in MUTATIONS:
        original = path.read_text(encoding="utf-8")
        if old not in original:
            print(f"LEWATI {name}: teks jangkar tidak ditemukan")
            failures.append(name)
            continue
        path.write_text(original.replace(old, new, 1), encoding="utf-8")
        try:
            result = run_tests()
        finally:
            path.write_text(original, encoding="utf-8")

        # Setiap mutasi di daftar ini harus membuat merah — tidak ada lagi
        # kasus "kontrol" yang diharapkan hijau, karena entri peta yang tidak
        # menunjuk medan nyata kini punya penjaganya sendiri (Penjaga 1b) dan
        # memang harus merah.
        red = result.returncode != 0
        verdict = "OK" if red else "SALAH"
        if not red:
            failures.append(name)
        print(f"{verdict:5} {name} — {guard} (exit={result.returncode})")

    if failures:
        print("\n== BUKTI GAGAL ==")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("\nBersih: setiap penjaga menggigit saat dilanggar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
