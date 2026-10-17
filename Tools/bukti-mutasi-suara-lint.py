#!/usr/bin/env python3
"""Buktikan Aturan 46 berbunyi pada kelasnya, dan **diam pada kode benar**.

Kenapa berkas ini ada.

Aturan 46 mengawal satu baris di `Apps/Shared/AudioCue.swift` yang memutuskan
peristiwa mana yang boleh terdengar seperti berhasil:

    guard AudioCue.isOn, events.contains(.lockSucceeded) else { return }

Itu bukan rincian implementasi, melainkan politik PRD: hanya `lockSucceeded`
yang boleh berbunyi. Bunyi saat engine ragu adalah false confidence yang
berwujud suara — dan bunyi adalah satu-satunya saluran bagi pengguna yang
tidak melihat layar, jadi tidak ada teks yang bisa membantahnya.

Diukur sebelum Aturan 46 ada (salinan utuh, proses baru, mutasi yang
**mengompilasi**):

    guard ... events.contains(.lockSucceeded) ...    swift-ui-lint.sh LULUS (exit 0)
    guard ... .lockSucceeded || .uncertain ...       swift-ui-lint.sh LULUS (exit 0)
    guard ... .uncertain ...                         swift-ui-lint.sh LULUS (exit 0)
    guard AudioCue.isOn                              swift-ui-lint.sh LULUS (exit 0)

Empat keadaan, **nol** yang berbunyi. Yang paling sunyi bukan yang terakhir
(bunyi hilang, cukup terlihat) melainkan yang kedua: engine ragu berbunyi
**persis** seperti engine yakin.

Yang ketiga (`hanya ragu`) menguji arah sebaliknya: pemilihan yang **hanya**
membunyikan keraguan — bunyi setiap kali engine tidak yakin, diam setiap kali
ia yakin. Itu kebalikan sempurna dari yang dimaksud PRD, dan ia sama
sunyinya.

Kenapa Aturan 38/42 tidak menangkapnya: keduanya menuntut permukaan yang
**namanya ada sebagai anggota model** dan badannya "menyebut faktanya".
`play(_:)` adalah fungsi berbadan banyak-pernyataan yang menerima daftar
peristiwa; tidak ada nama permukaan untuk ditambat. Yang salah bukan
apakah `lockSucceeded` disebut, melainkan **aturan pemilihan**-nya.

**Non-vakuositas diukur, bukan diklaim.** Setiap keadaan cacat dijalankan
sekali lagi dengan program Aturan 46 **dimatikan** (semua pola diganti pola
yang tidak pernah cocok). Kalau keadaan-keadaan itu berbalik hijau di sana,
maka yang berbunyi memang aturan ini — bukan sebab lain.

Pakai: python3 Tools/bukti-mutasi-suara-lint.py
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINT = os.path.join(ROOT, "swift-ui-lint.sh")

sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (butuh ROOT dulu)

#: Berkas yang dibaca harness ini — lewat penjaga yang **sama** dengan semua
#: harness `bukti-mutasi-*.py`, bukan salinan penjaga sendiri.
WATCHED = [LINT,
           os.path.join(ROOT, "Apps"),
           os.path.join(ROOT, "Packages", "PointingKit")]

TARGET = "Apps/Shared/AudioCue.swift"

#: Badan yang benar hari ini. Jangkar mutasinya; kalau ini hilang dari
#: sumber, harness **berhenti** daripada melaporkan "sesuai harapan" atas
#: nol pembuktian.
NEW = ("guard AudioEventPolicy.shouldPlay(events: events,\n"
       "                                          isAudioEnabled: AudioCue.isOn) "
       "else { return }")

#: Keadaan cacat: (nama, badan pengganti, harus_berbunyi). `None` = baseline.
#:
#: **Yang sengaja TIDAK ada di sini: `guard AudioCue.isOn else { return }` dan
#: `return`.** Keduanya menghapus pemilihan peristiwa, bukan menulisnya salah
#: — dan Aturan 46 mengklaim satu hal saja: pemilihan yang **ditulis langsung**
#: di `Apps/` akan terbaca. Menuntut aturan ini berbunyi pada badan yang tidak
#: menyebut peristiwa apa pun berarti menuntutnya menebak, dan satu-satunya
#: cara memuaskannya adalah pola selebar `if` — yang lalu menuduh setiap
#: percabangan sah di `Apps/`.
#:
#: Kedua keadaan itu tetap dibuktikan, di tempat yang memang mengukur
#: perilakunya: `Tools/bukti-mutasi-suara.py` menjalankan
#: `AudioEventPolicyTests` atas kedua mutasi yang sama, dan keduanya memerahkan
#: uji. Yang menjaga bunyi-hilang adalah **uji**, bukan sapu teks; yang
#: menjaga pemilihan-salah-di-Apps/ adalah sapu teks ini. Dua kelas, dua
#: penjaga — dan batas masing-masing dinyatakan, bukan disembunyikan.
KEADAAN = [
    ("baseline (kode apa adanya)", None, False),
    ("bentuk lama", "guard AudioCue.isOn, events.contains(.lockSucceeded) else { return }", True),
    ("ragu ikut berbunyi", "guard AudioCue.isOn, events.contains(.lockSucceeded) || events.contains(.uncertain) else { return }", True),
    ("hanya ragu", "guard AudioCue.isOn, events.contains(.uncertain) else { return }", True),
    ("basil ulang (pulih)", None, False),
]


def extract_rule(number: str) -> str:
    """Ambil program Python Aturan `number` dari `swift-ui-lint.sh`."""
    src = open(LINT, encoding="utf-8").read()
    header = re.compile(r'^echo "== Aturan (\d+):', re.M)
    marks = list(header.finditer(src))
    for i, m in enumerate(marks):
        if m.group(1) != number:
            continue
        end = marks[i + 1].start() if i + 1 < len(marks) else len(src)
        section = src[m.start():end]
        prog = re.search(r"python3 - <<'PY'[^\n]*\n(.*?)\nPY\n", section, re.S)
        if not prog:
            sys.exit(f"GERBANG: Aturan {number} tidak menjalankan "
                     f"python3 - <<'PY' — pembaca ini perlu disesuaikan.")
        return prog.group(1)
    sys.exit(f"GERBANG: Aturan {number} tidak ditemukan di swift-ui-lint.sh.")


#: Keluaran yang **bukan** temuan: aturan yang berhenti mengukur (dan
#: mengatakan begitu), atau yang melaporkan keadaan bersih. Keduanya bukan
#: "aturan berbunyi", dan memperlakukannya begitu membuat harness ini merah
#: pada aturan yang sudah dimatikan.
BUKAN_TEMUAN = (
    "tidak mengukur apa pun",
    "Bersih:",
)


def run_rule(program: str, workdir: str) -> tuple[int, str]:
    """Jalankan program aturan; kembalikan keluaran **hanya bila berbunyi**."""
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    p = subprocess.run([sys.executable, "-c", program], cwd=workdir,
                       capture_output=True, text=True, env=env)
    gabung = p.stdout + p.stderr
    if "Traceback (most recent call last)" in gabung:
        sys.exit("GERBANG: program aturan mati dengan traceback — harness ini "
                 "tidak bisa mengukur apa pun.\n" + gabung)
    if any(tanda in p.stdout for tanda in BUKAN_TEMUAN):
        return p.returncode, ""
    return p.returncode, gabung


def copy_repo() -> str:
    """Salin `Apps/` saja: Aturan 46 hanya membaca pohon itu."""
    workdir = tempfile.mkdtemp(prefix="suara-")
    shutil.copytree(os.path.join(ROOT, "Apps"), os.path.join(workdir, "Apps"))
    return workdir


def inject_body(workdir: str, body: str) -> None:
    """Ganti badan `play` di salinan berkasnya.

    Harus **tepat satu** yang cocok: jangkar yang meleset membuat keadaan
    cacat dilaporkan hijau padahal berkasnya tidak pernah berubah.
    """
    path = os.path.join(workdir, TARGET)
    text = open(path, encoding="utf-8").read()
    n = text.count(NEW)
    if n != 1:
        sys.exit(f"GERBANG: jangkar badan tidak unik ({n} kali) di {TARGET} — "
                 f"harness ini tidak bisa mengukur. Jangkarnya mungkin "
                 f"berubah di sumber; perbarui NEW.")
    open(path, "w", encoding="utf-8").write(text.replace(NEW, body, 1))


def to_legacy(program: str) -> str:
    """Matikan semua pola — aturan berhenti mengukur.

    Itu keadaan pohon sebelum Aturan 46 ada. Kalau keadaan-keadaan cacat
    tetap berbunyi di sini, maka yang berbunyi bukan aturan ini.
    """
    marker = "POLA = ("
    if marker not in program:
        sys.exit("GERBANG: program Aturan 46 tidak memuat penanda `POLA`; "
                 "harness non-vakuositas ini perlu disesuaikan sebelum ia "
                 "bisa mengukur apa pun.")
    head = program[:program.index(marker)]
    _, _, tail = program[program.index(marker):].partition("\n)\n")
    # `re.compile(r'(?!x)x')` tidak pernah cocok, tetapi **tetap** kumpulan
    # pola yang sah. Menghapus penugasannya akan mematikan program dengan
    # `NameError`, dan traceback dibaca harness ini sebagai "aturan
    # berbunyi" — gerbang mati-terbuka di dalam harness-nya sendiri.
    return head + "POLA = (re.compile(r'(?!x)x'),)\n" + tail


def main() -> int:
    mutasi_sumber.require_clean_sources(WATCHED)
    program = extract_rule("46")

    failures: list[str] = []
    ran = 0

    # ── a. Sasaran: setiap keadaan cacat berbunyi, baseline diam. ─────────
    for nama, body, must_fire in KEADAAN:
        workdir = copy_repo()
        try:
            if body is not None:
                inject_body(workdir, body)
            _, out = run_rule(program, workdir)
            fired = bool(out.strip())
            ran += 1
            if fired != must_fire:
                failures.append(
                    f"  {nama}: {'hijau' if not fired else 'merah'} pada "
                    f"keadaan yang seharusnya "
                    f"{'berbunyi' if must_fire else 'diam'}")
            if fired and must_fire and TARGET not in out:
                failures.append(
                    f"  {nama}: berbunyi, tetapi temuannya tidak menyebut "
                    f"{TARGET} — yang merah bukan aturan ini")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    # ── b. Non-vakuositas: dengan aturan dimatikan, cacat berbalik hijau. ──
    legacy = to_legacy(program)
    for nama, body, must_fire in KEADAAN:
        if not must_fire:
            continue
        workdir = copy_repo()
        try:
            inject_body(workdir, body)
            _, out = run_rule(legacy, workdir)
            ran += 1
            if out.strip():
                failures.append(
                    f"  non-vakuositas / {nama}: versi tanpa pola juga "
                    f"berbunyi — keadaan ini tidak membuktikan Aturan 46 "
                    f"mengukur apa pun")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    if ran < 3:
        sys.exit("GERBANG: kurang dari tiga keadaan benar-benar dijalankan; "
                 "'sesuai harapan' atas hampir nol pembuktian bukan bukti.")

    konteks = "Aturan 46: peristiwa berbunyi tidak dipilih sendiri di Apps/"
    if failures:
        print(f"{konteks} — {len(failures)} keadaan TIDAK sesuai harapan "
              f"(dari {ran}):")
        print("\n".join(failures))
        return 1
    cacat = len([k for k in KEADAAN if k[2]])
    print(f"{konteks} — {ran} keadaan, semuanya sesuai harapan "
          f"({len(KEADAAN)} keadaan, {cacat} non-vakuositas).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
