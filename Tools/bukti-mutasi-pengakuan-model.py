#!/usr/bin/env python3
"""Buktikan gerbang "setiap pengakuan MODEL terbaca" **bisa** merah.

Kenapa harness ini ada.

Gerbang `check_model_claims_are_on_the_token_line` lahir dari cacat yang
ditemukan pada kode yang baru saja ditulis: `RING_SHADOW_OPACITY` diberi
komentar `# MODEL:` di baris **sebelumnya**, pembaca paritas hanya mengenali
bentuk satu-baris, dan token itu tidak pernah masuk himpunan yang diperiksa.
Gerbang paritasnya melaporkan "26 pemeriksaan, 0 gagal" — hijau, dan tidak
satu pun angkanya berarti untuk token itu.

Gerbang yang hijau pada hari ia ditulis tidak membuktikan apa pun. Harness ini
membuktikan ia **bisa** merah, dan merah pada keadaan yang memang salah.

Kenapa cacatnya layak gerbang tersendiri, bukan sekadar perbaikan satu baris.

Saat gerbang ini ditulis, pembaca diperluas untuk mengenali bentuk
komentar-di-atas. Diukur pada `git show HEAD:Tools/render-visuals.py`: token
terbaca naik **28 → 29**, dan yang **angkanya benar-benar dibandingkan** naik
**18 → 21**. Tiga token (`BAND_FEATHER_FRACTION`, `BAND_LIMB_SHADING_STRENGTH`,
`CLUSTER_CORE_BRIGHTEN`) sudah ada di port sejak siklus sebelumnya dengan
pengakuan yang tidak pernah diperiksa — jadi yang rusak bukan satu token,
melainkan **pembacanya**, dan kerusakannya berlangsung diam-diam selama
beberapa siklus.

Keadaan yang diuji, dan apa yang masing-masing buktikan:

  [baseline]              Gerbang hijau pada pohon nyata. Kalau tidak, harness
                          ini salah dan keadaan lain tidak membedakan apa pun.

  1. komentar di atas     Bentuk yang **sah** dan lazim untuk konstanta yang
     token                komentarnya panjang. **Wajib hijau.** Gerbang yang
                          memerah di sini akan memaksa semua orang menulis satu
                          baris panjang, dan gerbang yang memaksa kerapian akan
                          dimatikan orang — setelah itu ia tidak menjaga apa pun.

  2. token beranotasi     `RING_SHADOW_OPACITY: float = 0.62  # MODEL: …`.
                          **Wajib merah.** Ini sisa lubang yang tidak ditutup
                          perluasan pembaca: barisnya memuat pengakuan, dan
                          pembaca paritas melewatinya. Diukur: bentuk ini hijau
                          ("36 token dari 36 pengakuan") sebelum cabangnya
                          ditambahkan.

  3. pengakuan di atas    Anotasi bahwa **fungsi** meniru model. Tidak ada
     `def`                konstanta yang bisa dibandingkan, jadi ini **wajib
                          hijau**. Diukur: 18 pengakuan berbentuk ini ada di
                          port; melaporkannya akan merah pada kode yang benar.

  4. pembaca dikembalikan Keadaan yang paling penting. Pembaca dimonkeypatch
     ke bentuk satu-baris    ke regex lamanya, dan gerbang **wajib merah**.
                          Tanpa keadaan ini, gerbang bisa saja membandingkan
                          pembaca dengan dirinya sendiri dan selalu hijau —
                          persis cacat yang membuat gerbang paritas buta
                          terhadap `RING_SHADOW_OPACITY` selama ini.

Keadaan 4 memakai monkeypatch, bukan mutasi berkas: yang diuji adalah
**kemampuan gerbang menolak pembaca yang lebih sempit**, dan pembaca adalah
fungsi di dalam gerbang itu sendiri, bukan teks di berkas produksi. Menulis
ulang `render-visuals.py` untuk itu akan menguji hal yang berbeda.
"""

from __future__ import annotations

import importlib.util
import os
import re
import sys

sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import mutasi_sumber as MS  # noqa: E402

spec = importlib.util.spec_from_file_location(
    "check_visuals", os.path.join(HERE, "check-visuals.py"))
CV = importlib.util.module_from_spec(spec)
sys.argv = ["check-visuals.py"]
spec.loader.exec_module(CV)
R = CV.R

PORT = os.path.join(ROOT, "Tools", "render-visuals.py")

#: Nama hasil yang diharapkan, dibaca dari gerbangnya sendiri lewat awalan —
#: bukan ditulis ulang di sini. Kalau gerbangnya berganti nama, harness ini
#: merah, bukan diam-diam membandingkan dengan nama yang tidak pernah muncul.
PREFIX = "port: setiap pengakuan MODEL terbaca"


def jalankan():
    """Jalankan gerbangnya dan kembalikan (nama, ok, detail) satu pemeriksaan."""
    results = []
    CV.check_model_claims_are_on_the_token_line(results)
    return [(r.name, r.ok, r.detail) for r in results]


def laporkan(label, hasil, harap_merah, harap=1, wajib_sebut=None):
    """Periksa satu keadaan.

    Tiga besaran yang **berbeda** dan tidak boleh saling menumpang:

      * `harap`       — berapa pemeriksaan yang dikeluarkan gerbangnya. Kalau
                        jumlahnya berubah, gerbangnya berhenti mengukur, dan
                        itu merah.
      * `harap_merah` — berapa di antaranya wajib merah. Sebagian merah adalah
                        keadaan yang sah, jadi ini angka, bukan boolean.
      * `wajib_sebut` — potongan teks yang harus muncul di detail pemeriksaan
                        yang merah. Tanpa ini, "1 merah" juga terpenuhi bila
                        yang merah justru pemeriksaan yang salah — dan harness
                        akan melaporkan sesuai harapan sambil membuktikan
                        kebalikannya.
    """
    if len(hasil) != harap:
        print(f"SALAH {label:34s} -> {len(hasil)} pemeriksaan, harus {harap}")
        return False
    merah = [h for h in hasil if not h[1]]
    nama_benar = all(h[0].startswith(PREFIX) for h in hasil)
    ok = len(merah) == harap_merah and nama_benar
    if ok and wajib_sebut is not None and merah:
        ok = all(wajib_sebut in h[2] for h in merah)
    print(f"{'OK  ' if ok else 'SALAH'} {label:34s} -> "
          f"{len(merah)}/{harap} MERAH (harap {harap_merah})"
          + ("" if nama_benar else ", nama pemeriksaan tidak dikenal"))
    if not ok:
        for nama, _, detail in hasil:
            print(f"       {nama}: {detail[:160]}")
    return ok


def sisipkan_komentar_di_atas(teks, token):
    """Pindahkan pengakuan `token` ke baris **sebelumnya**, dan buktikan pindah.

    Tanpa pemeriksaan ini, keadaan bisa "lulus" karena penggantiannya tidak
    menemukan apa pun — lalu yang diukur adalah berkas yang tidak berubah.
    """
    inline = re.compile(
        r"^(" + re.escape(token) + r"\s*=\s*[^\n#]*?)\s*#\s*MODEL:\s*`([^`]+)`",
        re.M)
    match = inline.search(teks)
    if not match:
        raise SystemExit(
            f"GAGAL: pengakuan inline untuk `{token}` tidak ditemukan — "
            "keadaan ini tidak bisa membuktikan apa pun. Perbarui harness "
            "setelah bentuk barisnya berubah.")
    before, claim = match.group(1), match.group(2)
    return (teks[:match.start()] + f"# MODEL: `{claim}`\n{before}"
            + teks[match.end():])


def main():
    print("Gerbang paritas: setiap pengakuan MODEL terbaca\n")
    hasil = []

    # 0. Kontrol negatif lebih dulu.
    hasil.append(laporkan("pohon utuh", jalankan(), 0))

    MS.require_clean_sources([PORT])
    asli = open(PORT, encoding="utf-8").read()

    # Token yang pengakuannya sudah berbentuk inline di pohon ini. Dibaca dari
    # pohon, bukan ditulis di sini: kalau bentuknya berubah, harness ini
    # berhenti dan memberi tahu, alih-alih memutasi baris yang tidak ada.
    tokens = [m.group(1) for m in re.finditer(
        r"^([A-Z][A-Z0-9_]*)\s*=\s*[^\n#]*#\s*MODEL:\s*`[^`]+`", asli, re.M)]
    if not tokens:
        raise SystemExit("GAGAL: tidak ada pengakuan inline di port — "
                         "harness ini tidak bisa menguji bentuk apa pun.")

    try:
        # 1. Komentar panjang di atas token: bentuk yang sah, wajib hijau.
        MS.write_source(PORT, sisipkan_komentar_di_atas(asli, tokens[0]))
        hasil.append(laporkan("komentar di atas token (sah)", jalankan(), 0))

        # 2. Token beranotasi tipe: pengakuan yang tidak terbaca paritas.
        beranotasi = re.sub(
            r"^(" + re.escape(tokens[0]) + r")(\s*=\s*[^\n#]*?)(\s*#\s*MODEL:)",
            r"\1: float\2\3", asli, count=1, flags=re.M)
        if beranotasi == asli:
            raise SystemExit(f"GAGAL: anotasi atas `{tokens[0]}` tidak "
                             "mengubah apa pun — keadaan 2 tidak menguji apa pun.")
        MS.write_source(PORT, beranotasi)
        hasil.append(laporkan("token beranotasi tipe", jalankan(), 1,
                              wajib_sebut="tak terbaca"))
    finally:
        MS.restore_verified(PORT, asli)

    # 3. Pengakuan di atas `def`: batas yang dinyatakan, wajib hijau.
    def_line = re.search(r"^def ([a-z_][A-Za-z0-9_]*)\(", asli, re.M)
    if def_line is None:
        raise SystemExit("GAGAL: tidak ada `def` di port — keadaan 3 tidak "
                         "bisa diuji.")
    atas_def = (asli[:def_line.start()]
                + f"# MODEL: `CelestialVisual.{def_line.group(1)}`\n"
                + asli[def_line.start():])
    MS.require_clean_sources([PORT])
    try:
        MS.write_source(PORT, atas_def)
        hasil.append(laporkan("pengakuan di atas `def` (sah)", jalankan(), 0))
    finally:
        MS.restore_verified(PORT, asli)

    # 4. Pembaca dikembalikan ke bentuk satu-baris: gerbang wajib merah.
    #
    #    Inilah keadaan yang membuat gerbangnya bukan tautologi. Ia menguji
    #    **kemampuan gerbang menolak pembaca yang lebih sempit**, jadi yang
    #    dipatch adalah pembacanya, bukan berkas produksi.
    sempit = (lambda src: {m.group(1): m.group(2).strip() for m in re.finditer(
        r"^([A-Z][A-Z0-9_]*)\s*=\s*[^\n#]*#\s*MODEL:\s*`([^`]+)`", src, re.M)})
    luas = CV._port_tokens_modeled_after
    try:
        CV._port_tokens_modeled_after = sempit
        hasil.append(laporkan("pembaca dikembalikan ke satu-baris", jalankan(),
                              1, wajib_sebut="tak terbaca"))
    finally:
        CV._port_tokens_modeled_after = luas

    print()
    if not all(hasil):
        print(f"{hasil.count(False)} keadaan tidak sesuai harapan")
        return 1
    print(f"{len(hasil)} keadaan, 0 tidak sesuai harapan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
