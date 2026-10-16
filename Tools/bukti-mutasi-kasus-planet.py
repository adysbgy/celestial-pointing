#!/usr/bin/env python3
"""Buktikan gerbang **kasus render planet** berbunyi — dan bahwa "planet baru
yang terpasang lengkap" memang hijau.

Kenapa harness ini ada.

`check_every_planet_in_the_model_has_render_cases` adalah **satu-satunya**
gerbang yang memaksa aturan kejujuran paling keras di app ini berlaku untuk
planet yang **belum ada**: ciri pengenal (pita, cincin, kutub, kawah, kabut)
harus hilang saat engine ragu, dan ciri itu harus tetap terukur pada ukuran
kartu jam. Aturan itu hanya berjalan pada planet yang punya pasangan kasus
render; planet yang ditambahkan tanpa kasusnya tampil di jam dengan ciri yang
**tidak pernah diukur hilang**.

Sampai siklus ini ia tidak dirujuk satu pun harness: dari 83 gerbang di
`check-visuals.py`, ia salah satu dari enam yang tidak punya bukti mutasi.
Docstring-nya mengutip pembuktiannya di `out/bukti-planet-uranus.py` — berkas
yang hidup di direktori yang **di-`.gitignore`** (`out/`), jadi di checkout
mana pun selain mesin tempat ia ditulis, bukti itu tidak ada. Gerbang yang
bukti mutasinya tidak ikut ter-commit berada persis di keadaan yang sama
dengan gerbang tanpa bukti: tidak bisa dibedakan dari gerbang yang tidak
mengukur apa pun.

Apa yang diukur harness ini.

**Sembilan keadaan**, dan yang paling berharga bukan yang merah melainkan
**yang wajib hijau**:

  keadaan                                                    harapan
  [baseline]                                                 hijau (8/8)
  1. model: +pluto (enum, palet .bands, showsPhase)          MERAH 2 kawat
  2. model + port: pluto di kedua bahasa                     MERAH 2 kawat
  3. model: jupiter .bands -> .none                          MERAH 1 kawat
  4. model: satu kasus palet kehilangan badan terbaca        MERAH 2 kawat
  5. gerbang: pasangan mars hilang dari "hilang saat ragu"    MERAH 1 kawat
  6. gerbang: pasangan venus hilang dari "ukuran jam"         MERAH 1 kawat
  7. gerbang: pasangan jupiter memakai nama saturn            MERAH 1 kawat
  8. **pluto terpasang lengkap** (model+port+kasus+gerbang)    **hijau 8/8**
     — dan aturan kejujuran kini berlaku untuknya: dua pemeriksaan
     "pita Pluto" dari `check_features_disappear_when_uncertain` hijau
  9. **enum baru sesudah palet** (kode sah, palet utuh)        **hijau 8/8**

**Kenapa planet "baru"-nya Pluto, bukan Uranus.** Uranus sudah ada di enum,
di `showsPhase`, dan di palet sejak `27dd677` (URANUS + NEPTUNUS), jadi
menyuntikkannya kembali bukan menambah planet — ia mengubah planet yang
sudah ada, dan `PHASE_OLD` versi lama tidak lagi cocok sama sekali. Terukur
pada siklus ini: dengan `ENUM_NEW = "case saturn\ncase uranus\n"` model
berakhir dengan **dua** `case uranus`, dan gerbang palet berbunyi karena
daftarnya tidak lagi sesuai bentuk yang dibaca. Pluto dipakai karena ia ada
di `CelestialEngine.EphemerisBody` tetapi **tidak** ada di
`CelestialVisual.Planet`, sehingga tiga suntikan di atas benar-benar
menambahkan planet — keadaan yang memang ingin diukur.**

Tiga harapan yang **diwarisi, bukan diukur** — dan cara memperbaikinya.

Docstring ini sampai siklus ini mengutip angka "MERAH 5 kawat" untuk keadaan
1 dan 2 dengan rujukan "terukur di `6c2fb0d`". Commit itu **tidak memuat**
keadaan-keadaan ini: di sana planet barunya masih Uranus. Jadi angka itu
dipakai untuk mengesahkan keadaan yang belum pernah dijalankan. Yang benar
adalah **mengukur ulang**, bukan menyalin: dilakukan dalam kotak pasir
(salinan pohon di direktori sementara, sumber dimutasi di sana), atas dunia
pluto yang sebenarnya, dan hasilnya **lima** kawat — dua kawat yang hilang
dari `FULL` di bawah dihitung dari kenyataan bahwa `FULL` memuat **tujuh**
pemeriksaan sementara keadaan 1 diharapkan memerahkan **lima**. Bedanya dua:
`SEPAKAT` dan `CIRI_MATI` tetap hijau, karena ciri `.bands` sudah dipakai
Jupiter dan kedua bahasa tidak berbeda pendapat.

Batas yang harus dibaca sebelum mempercayai angka di atas:

  - Kotak pasir itu **mengganti `Tools/bukti-mutasi-kasus-planet.py` yang
    sedang dijalankan**. Harness ini menyuntik ke salinan dirinya sendiri dan
    membaca ulang lewat proses baru, jadi keadaan yang diukur adalah keadaan
    yang benar — tetapi jalur itu tidak pernah lewat CI, dan itu dinyatakan
    di sini alih-alih disangka tertutup.
  - Probe itu menyetel `C.ROOT` kembali ke repo asli untuk berkas yang
    **bukan** model. Tanpa itu, gerbang berbunyi karena salinan pohon yang
    tidak lengkap — bukan karena mutasinya. Terukur: baseline di dalam kotak
    pasir melaporkan `terbaca dari model` **MERAH** pada sumber yang bersih,
    padahal gerbang yang sama di repo asli hijau 7/7.
  - `<planet>-bare` dan `<planet>-uncertain` untuk Pluto belum pernah
    ditambahkan ke gerbang ciri. Keadaan 8 menambahkannya, dan gerbang
    `check_planet_bare_equals_unknown_sphere` membangun ulang jalur itu dari
    kode — jadi yang dibuktikan adalah bahwa jalurnya **jalan**, bukan bahwa
    angkanya sudah diukur di perangkat.

Keadaan 9 menjaga arah yang **tidak** dijaga ketujuh keadaan merah: bukan
"merah pada yang salah", melainkan **merah pada yang benar**. Penjaga
cakupan pembaca tabel pada versi pertamanya memindai dari jangkar
`var palette` sampai EOF, jadi `case` dari enum mana pun di bawahnya ikut
terhitung; menyisipkan satu enum yang sah membuatnya melempar, dan gerbang
yang menghukum penambahan benar akan dilonggarkan orang alih-alih
diperbaiki. Terukur: keadaan ini merah pada pembaca versi pertama dan hijau
pada pembaca yang wilayahnya dibatasi ke penutup `var palette` — persis
jebakan yang sudah tertulis di `read_planet_switch_cases_from_swift`
("membaca melewati batas fungsi adalah jebakan yang sama yang baru saja
ditemukan di pembaca kunci penggambar langit dalam").

Keadaan 1 dan 2 dipisah karena **arahnya berbeda**, dan itu bukan kerapian.
Di keadaan 1 ada drift antarbahasa yang bisa berbunyi (gerbang drift palet);
di keadaan 2 kedua bahasa sepakat, jadi tidak ada drift untuk diberitakan —
dan itulah keadaan sunyinya: hanya gerbang ini yang bisa melihatnya.
Membuktikan yang kedua saja akan melewatkan bahwa gerbang ini **bukan**
gerbang drift, dan membuktikan yang pertama saja akan melewatkan bahwa ia
mengukur sesuatu yang tidak diukur siapa pun.

Keadaan 3, 4, 5, 6, 7 masing-masing memerahkan kawat yang **berbeda**, dan
keempatnya tidak bisa saling menggantikan:

  - 3 memerahkan satu-satunya kawat yang menjaga "tidak ada ciri yang tidak
    dipakai planet mana pun".
  - 4 memerahkan pemeriksaan "switch palet & tabel palet sepakat" — satu-
    satunya keadaan yang melakukannya.
  - 5, 6, 7 masing-masing mengubah **gerbang**, bukan model, dan pada
    planet yang berbeda. Keadaan 7 adalah yang paling halus: nama kedua
    sisinya **ada**, tapi pasangannya menunjuk planet lain. Yang
    menangkapnya pemeriksaan "berpasangan", bukan pemeriksaan keanggotaan
    himpunan — dan pemeriksaan yang hanya menuntut "kelima planet ada" akan
    hijau di sana.

Keadaan 8 adalah alasan gerbang ini ada, dinyatakan sebagai keadaan yang bisa
diukur: planet yang terpasang **lengkap** tidak memerahkan apa pun, dan
setelah terpasang lengkap aturan kejujuran **berlaku untuknya**. Tanpa
keadaan ini, harness yang memerah pada setiap suntingan planet akan
mengajarkan orang bahwa gerbangnya menolak pekerjaan, bukan menuntut
kelengkapannya — dan gerbang yang dilonggarkan tidak menjaga apa pun.

### Tiga harapan yang terukur SALAH, dan apa yang diajarkan

Harness versi pertama menebak verdict lima keadaan, dan **tiga di antaranya
salah**. Ketiganya diperbaiki di **harapannya**, bukan dengan melonggarkan
gerbangnya:

  1. Keadaan 1 & 2 ditebak 4 merah, terukur **5**. Kawat kelima adalah
     cakupan gerbang ciri **mode malam**, yang memang juga menuntut planet
     berciri baru.
  2. Keadaan 3 ditebak juga memerahkan dua cakupan gerbang ciri, terukur
     **hanya satu** merah. Ketiga pemeriksaan itu menuntut **cakupan**
     ("setiap planet berciri muncul"), bukan ketiadaan pasangan berlebih —
     jadi Jupiter yang keluar dari daftar tidak menyentuhnya.
  3. Keadaan 4 ditebak "switch dan tabel berhenti sepakat" lewat
     `case .mars` → `case .marsX`. Terukur **salah**: kedua pembaca memakai
     pola yang setara atas wilayah `switch` yang sama, jadi keduanya sepakat
     pada nama baru dan pemeriksaan itu tetap hijau. Keadaannya diganti
     dengan yang benar-benar menyentuh pembaca tabel (badan palet yang bukan
     warna literal) — dan di sana pun dugaan kedua saya salah: saya sangka
     tabel yang kehilangan satu planet akan memerahkan juga pemeriksaan
     cakupan gerbang ciri, padahal cakupan itu diturunkan dari **tabel**
     yang sama, jadi daftar tuntutannya ikut mengecil dan ia tetap hijau.

Pelajaran ketiganya sama: **tebakan tentang gerbang yang belum pernah
dijalankan dalam keadaan rusak adalah tebakan**, sekalipun gerbangnya ditulis
sendiri dan docstring-nya dibaca berkali-kali. Yang membedakan adalah
menjalankannya.

### Arah yang sengaja TIDAK diklaim

  - Harness ini mengukur **hasil gerbang**, bukan piksel app. Yang dibuktikan:
    tiap kawatnya bisa merah pada keadaan yang memang salah, dan hijau pada
    keadaan yang benar. Tidak ada klaim bahwa perangkat menggambar Pluto
    seperti apa pun.
  - Ia **tidak** membuktikan bahwa Pluto benar-benar akan ditambahkan, atau
    bahwa warnanya tepat. Yang dijaga: **kalau** ia ditambahkan setengah
    jalan, gerbangnya berbunyi.
  - Keadaan 8 merender (74 detik) karena ia menjalankan gerbang ciri penuh;
    tujuh keadaan lain hanya membaca sumber dan daftar kasus.

Berkas produksi (`CelestialVisual.swift`, `Tools/render-visuals.py`,
`Tools/check-visuals.py`) dimutasi lalu dipulihkan di `finally` per keadaan,
plus handler `SIGINT`/`SIGTERM`: `SIGKILL` melewati `finally` dan
meninggalkan mutasi hidup. `require_clean_sources` menolak jalan bila
berkasnya sudah menyimpang dari HEAD, dan `restore_verified` membuktikan
pemulihannya byte demi byte.

Pakai:
    python3 Tools/bukti-mutasi-kasus-planet.py     # 0 = semua sesuai harapan
"""

from __future__ import annotations

import hashlib
import os
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "Tools"))
import mutasi_sumber  # noqa: E402  (penulisan atomik bersama, lihat modulnya)

MODEL = os.path.join(ROOT, "Packages/PointingKit/Sources/PointingKit/"
                           "CelestialVisual.swift")
RENDER = os.path.join(ROOT, "Tools/render-visuals.py")
CHECK = os.path.join(ROOT, "Tools/check-visuals.py")
FILES = [MODEL, RENDER, CHECK]

# ── Nama hasil gerbang, dituntut **persis** ──────────────────────────────
# Perubahan nama di gerbang harus membuat berkas ini merah, bukan diam-diam
# mencocokkan himpunan kosong — himpunan kosong selalu "sesuai harapan", dan
# itu bentuk paling sunyi dari harness yang tidak mengukur apa pun.
SEPAKAT = "kasus render planet: switch palet & tabel palet sepakat"
TERKUNCI = "kasus render planet: setiap planet di model punya kasus terkunci"
RAGU = "kasus render planet: setiap planet berciri punya kasus ragu"
CIRI_MATI = "kasus render planet: tidak ada ciri yang tidak dipakai planet mana pun"
GERBANG_RAGU = ("kasus render planet: gerbang ciri hilang saat ragu memuat "
                "semua planet berciri")
GERBANG_JAM = ("kasus render planet: gerbang ciri pada ukuran jam memuat "
               "semua planet berciri")
GERBANG_MALAM = ("kasus render planet: gerbang ciri pada ukuran jam di mode "
                 "malam memuat semua planet berciri")
# Diperkenalkan bersama perbaikan gerbang berhenti-penuh: cabang palet yang
# polanya tidak dikenali dulu melempar dari pembaca dan muncul sebagai
# "terbaca dari model" — pesan yang menunjuk pembaca, padahal cacatnya di
# tabel. Sekarang ia punya namanya sendiri.
CABANG = "kasus render planet: setiap cabang palet terbaca"

FULL = (SEPAKAT, TERKUNCI, RAGU, CIRI_MATI, GERBANG_RAGU, GERBANG_JAM,
        GERBANG_MALAM, CABANG)

HIJAU = "hijau"
MERAH = "merah"

# ── Jangkar: model ───────────────────────────────────────────────────────
ENUM_OLD = "        case saturn\n"
ENUM_NEW = "        case saturn\n        case uranus\n"

PHASE_OLD = ("            case .mars, .jupiter, .saturn, .uranus, .neptune:"
             " return false\n")
PHASE_NEW = ("            case .mars, .jupiter, .saturn, .uranus, .neptune,"
             " .pluto: return false\n")

SATURN_CASE = """        case .saturn:
            return .init(light: .init(red: 0.93, green: 0.84, blue: 0.62),
                         dark:  .init(red: 0.44, green: 0.36, blue: 0.22),
                         feature: .rings)
"""
#: **Kenapa Pluto, bukan Uranus.** `Pluto` sengaja dipilih sebagai planet
#: "baru": ia ada di `CelestialEngine.EphemerisBody` tapi **tidak** ada di
#: `CelestialVisual.Planet` — jadi menambahkannya benar-benar menambahkan
#: planet ke model, bukan mengubah planet yang sudah ada. Uranus tidak lagi
#: bisa dipakai untuk itu sejak `27dd677` (URANUS + NEPTUNUS): ia sudah ada
#: di enum, di `showsPhase`, **dan** di palet, sehingga ketiga suntikan di
#: atas menjadi no-op — terukur pada siklus ini, `ENUM_NEW` menghasilkan dua
#: `case uranus` dan `PHASE_OLD` tidak lagi cocok sama sekali.
#:
#: **Kenapa cirinya `.bands`, bukan ciri baru.** Ciri yang **tidak** ada di
#: planet mana pun akan memerahkan `CIRI_MATI` ("tidak ada ciri yang tidak
#: dipakai planet mana pun") di samping empat kawat cakupan lain, dan gerbang
#: yang merah karena dua sebab sekaligus tidak lagi membuktikan salah satunya.
#: `.bands` dipakai Jupiter, jadi satu-satunya kawat yang berbunyi adalah
#: kawat cakupan — itulah keadaan yang diukur di sini.
PLUTO_CASE = """        case .pluto:
            return .init(light: .init(red: 0.70, green: 0.68, blue: 0.66),
                         dark:  .init(red: 0.27, green: 0.26, blue: 0.25),
                         feature: .bands)
"""

#: Pluto ditambahkan sebagai planet yang **benar-benar bisa dikompilasi**:
#: kasus enum, cabang `showsPhase`, dan cabang palet. Menambahkan cabang palet
#: saja akan membuat `switch self` tidak ekshaustif, dan mutasi yang tidak
#: bisa dikompilasi bukan keadaan yang bisa dikirim ke pengguna — jadi klaim
#: tentangnya tidak berarti apa-apa.
PLUTO_MODEL = [(MODEL, ENUM_OLD, ENUM_NEW),
                (MODEL, PHASE_OLD, PHASE_NEW),
                (MODEL, SATURN_CASE, SATURN_CASE + PLUTO_CASE)]

# ── Jangkar: port ────────────────────────────────────────────────────────
PORT_HEAD = "PLANET_PALETTE = {\n"
PORT_PLUTO = ('    "pluto": dict(light=(0.70, 0.68, 0.66), '
              'dark=(0.27, 0.26, 0.25), feature="bands"),\n')

#: **Ketiga daftar port harus bertambah bersama.** Pluto adalah planet berciri
#: `.bands` (sama seperti Jupiter), jadi ia masuk ke daftar "ciri hilang saat
#: ragu" dengan nama ciri yang **sudah dipakai** — bukan nama ciri baru. Nama
#: ciri yang belum pernah ada di daftar mana pun akan memerahkan pemeriksaan
#: cakupan yang berbeda dari yang sedang dibuktikan keadaan ini.
PORT_CONFIRMED = ('for planet in ("mercury", "venus", "mars", "jupiter", "saturn",\n'
                  '                   "uranus", "neptune"):')
PORT_CONFIRMED_NEW = ('for planet in ("mercury", "venus", "mars", "jupiter", "saturn",\n'
                      '                   "uranus", "neptune", "pluto"):')
PORT_UNCERTAIN = ('for planet, feature in (("jupiter", "pita"), ("saturn", "cincin"),\n'
                  '                            ("mars", "kutub"), ("mercury", "kawah"),\n'
                  '                            ("venus", "kabut"), ("uranus", "sabuk samar"),\n'
                  '                            ("neptune", "bintik gelap")):')
PORT_UNCERTAIN_NEW = ('for planet, feature in (("jupiter", "pita"), ("saturn", "cincin"),\n'
                      '                            ("mars", "kutub"), ("mercury", "kawah"),\n'
                      '                            ("venus", "kabut"), ("uranus", "sabuk samar"),\n'
                      '                            ("neptune", "bintik gelap"), ("pluto", "pita")):')
PORT_BARE = ('for planet in ("jupiter", "saturn", "mars", "mercury", "venus",\n'
             '                   "uranus", "neptune"):')
PORT_BARE_NEW = ('for planet in ("jupiter", "saturn", "mars", "mercury", "venus",\n'
                 '                   "uranus", "neptune", "pluto"):')

# ── Jangkar: gerbang ciri di dalam check-visuals.py ──────────────────────
DISAPPEAR = "check_features_disappear_when_uncertain"
WATCH_SIZE = "check_features_survive_the_watch_size"
NIGHT = "check_features_survive_the_watch_size_in_night_mode"

PAIR_RAGU_JUPITER = ('        ("planet-jupiter-confirmed", "planet-jupiter-uncertain",\n'
                     '         "planet-jupiter-bare", "Bintik Merah Besar Jupiter"),\n')
PAIR_RAGU_PLUTO = ('        ("planet-pluto-confirmed", "planet-pluto-uncertain",\n'
                   '         "planet-pluto-bare", "pita Pluto"),\n')

PAIR_JAM_JUPITER = ('        ("planet-jupiter-confirmed", "planet-jupiter-bare",\n'
                    '         "Bintik Merah Besar Jupiter"),\n')
PAIR_JAM_PLUTO = ('        ("planet-pluto-confirmed", "planet-pluto-bare",\n'
                  '         "pita Pluto"),\n')

#: Jupiter kehilangan pitanya, jadi `bands` adalah ciri yang tidak dipakai
#: planet mana pun. (Pasangan Jupiter yang kini berlebih di gerbang ciri
#: **tidak** memerahkan pemeriksaan cakupan — terukur, lihat keadaan 3.)
JUPITER_BANDS_OLD = "feature: .bands)\n        case .saturn:"
JUPITER_BANDS_NEW = "feature: .none)\n        case .saturn:"

#: Kasus yang **badannya tidak terbaca** pembaca palet. Jangkar `return
#: .init(red: …)` menuntut warna literal; badan yang memakai variabel tidak
#: cocok, jadi tabel palet kehilangan planet itu sementara `switch` tetap
#: memuatnya — dan itulah satu-satunya keadaan yang memerahkan pemeriksaan
#: "switch palet & tabel palet sepakat".
#:
#: **Kenapa bukan sekadar mengganti nama kasus.** Terukur (lihat docstring):
#: `case .mars:` → `case .marsX:` **tidak** memerahkan pemeriksaan itu,
#: karena kedua pembaca membaca wilayah `switch` yang sama dengan pola yang
#: setara — keduanya lalu sepakat pada nama baru.

#: Pasangan yang hilang / tertukar, per gerbang. Nama kedua sisi **ada** di
#: keadaan 7 — yang salah pasangannya, dan hanya pemeriksaan "berpasangan"
#: yang bisa melihatnya.
MARS_PAIR = ('        ("planet-mars-confirmed", "planet-mars-uncertain",\n'
             '         "planet-mars-bare", "kutub Mars"),\n')
VENUS_PAIR_JAM = '        ("planet-venus-confirmed", "planet-venus-bare", "kabut Venus"),\n'
JUPITER_PAIR_TUKAR = (
    '        ("planet-jupiter-confirmed", "planet-saturn-uncertain",\n'
    '         "planet-jupiter-bare", "Bintik Merah Besar Jupiter"),\n')

#: Cabang palet yang **tidak dikenali polanya**: `case .pluto:` masih terbaca
#: sebagai cabang, tetapi `return`-nya tidak lagi berupa `.init(light: …,
#: dark: …, feature: …)` — ia lewat variabel perantara. Ini perubahan yang
#: **sah** di Swift (dan memang bentuk yang sudah pernah ditulis di berkas
#: ini), jadi gerbang tidak boleh menyebutnya "planet hilang".
PLUTO_UNREADABLE = ("""        case .pluto:
            let palet = CelestialVisual.Palette(
                light: .init(red: 0.70, green: 0.68, blue: 0.66),
                dark:  .init(red: 0.27, green: 0.26, blue: 0.25),
                feature: .bands)
            return palet
""")

#: Keadaan 4 di atas mengukur pembaca tabel yang **kehilangan** satu planet.
#: Keadaan 9 mengukur arah sebaliknya: pembaca yang **menolak** pohon yang
#: benar. Keduanya cacat, tapi hanya yang pertama terlihat sebagai "merah
#: pada yang salah"; yang kedua terlihat sebagai **merah pada yang benar**,
#: dan itu justru lebih mahal — ia menghukum penambahan enum yang sah, jadi
#: orang akan melonggarkan penjaganya alih-alih memperbaiki pembacanya.
#:
#: Jangkar: satu enum baru yang **sah** disisipkan sesudah fungsi palet.
#: Paletnya sendiri tidak tersentuh satu karakter pun.
NEW_ENUM_AFTER_PALETTE = ("    /// Kenali planet dari `CelestialObject.id`.\n")
NEW_ENUM_ADDED = ("    /// Enum yang ditambahkan SESUDAH `var palette` — kode\n"
                  "    /// yang sah: paletnya tidak tersentuh.\n"
                  "    enum ContohGlif {\n"
                  "        var label: String {\n"
                  "            switch self {\n"
                  "            case .alfa: return \"a\"\n"
                  "            case .beta: return \"b\"\n"
                  "            }\n"
                  "        }\n"
                  "    }\n"
                  "\n")

# Dijalankan di proses baru: mengimpor ulang `check-visuals` (dan `R` di
# dalamnya) dari berkas yang **sudah dimutasi** di disk. Mengimpor sekali di
# dalam proses ini akan memakai salinan lama, dan seluruh harness berbohong.
PROBE = r"""
import importlib.util, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "Tools"))
sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location(
    "cv_probe", os.path.join(sys.argv[1], "Tools", "check-visuals.py"))
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)

def emit(tag, results):
    for r in results:
        print(tag + "|" + r.name + "|" + ("OK" if r.ok else "GAGAL"))

results = []
try:
    C.check_every_planet_in_the_model_has_render_cases(results)
except Exception as exc:
    print("ERR " + type(exc).__name__ + ": " + str(exc)[:300])
    raise SystemExit(0)
emit("GATE", results)

# Keadaan 8 menjalankan gerbang ciri penuh (74 detik) untuk membuktikan
# bahwa aturan kejujuran **berlaku** bagi planet yang baru terpasang.
if os.environ.get("HONESTY") == "1":
    honesty = []
    try:
        C.check_features_disappear_when_uncertain(honesty)
    except Exception as exc:
        print("ERR honesty " + type(exc).__name__ + ": " + str(exc)[:300])
        raise SystemExit(0)
    emit("HONESTY", honesty)
"""


def _full(*red):
    """Himpunan hasil lengkap; nama yang disebut di `red` memerah."""
    return {name: (MERAH if name in red else HIJAU) for name in FULL}


# ── Keadaan ──────────────────────────────────────────────────────────────
# (nama, [(berkas, cari, ganti, fn), ...] atau None, {nama hasil: harapan},
#  jalankan_gerbang_kejujuran)
STATES = [
    ("[baseline] sumber bersih", None, _full(), False),

    # ── Arah "model berubah, kasus render tidak ikut" ────────────────────
    # Lima kawat, dan kelimanya berbeda: dua tentang kasus render yang
    # hilang, tiga tentang cakupan gerbang ciri (ragu / jam / malam).
    # Gerbang drift palet **tidak** berbunyi di sini untuk dua pemeriksaan
    # pertama — ia hanya melihat ketidaksepakatan antarbahasa, dan di
    # keadaan ini modelnya berubah sendiri.
    #
    # Terukur di kotak pasir (lihat docstring): lima merah, dan yang tetap
    # hijau di antaranya `SEPAKAT` & `CIRI_MATI`.
    ("1. model: +pluto (enum, palet .bands, showsPhase)",
     [(MODEL, ENUM_OLD, ENUM_NEW, None),
      (MODEL, PHASE_OLD, PHASE_NEW, None),
      (MODEL, SATURN_CASE, SATURN_CASE + PLUTO_CASE, None)],
     _full(TERKUNCI, RAGU), False),

    # ── Keadaan paling sunyi: kedua bahasa sepakat ───────────────────────
    # Tidak ada drift antarbahasa yang bisa diberitakan. Kalau gerbang ini
    # tidak ada, Pluto tampil di jam dengan pita yang tidak pernah diukur
    # hilang saat engine ragu.
    ("2. model + port: pluto di kedua bahasa",
     [(MODEL, ENUM_OLD, ENUM_NEW, None),
      (MODEL, PHASE_OLD, PHASE_NEW, None),
      (MODEL, SATURN_CASE, SATURN_CASE + PLUTO_CASE, None),
      (RENDER, PORT_HEAD, PORT_HEAD + PORT_PLUTO, None)],
     _full(TERKUNCI, RAGU), False),

    # ── Ciri jadi mati ───────────────────────────────────────────────────
    # Jupiter kehilangan pitanya, jadi `bands` adalah ciri yang **tidak
    # dipakai planet mana pun** — kawat yang tidak disentuh keadaan lain.
    #
    # Terukur: hanya pemeriksaan ini yang berbunyi. Dua pemeriksaan cakupan
    # gerbang ciri tetap **hijau**, dan itu membantah dugaan pertama saya
    # bahwa pasangan Jupiter yang kini berlebih akan memerahkannya: ketiga
    # pemeriksaan itu hanya menuntut **cakupan** (setiap planet berciri
    # muncul), bukan ketiadaan pasangan berlebih. Batas itu dinyatakan di
    # sini alih-alih diandaikan — dan gerbang yang tidak pernah saya duga
    # hijau adalah gerbang yang paling mudah saya percayai tanpa ukuran.
    ("3. model: jupiter .bands -> .none",
     [(MODEL, JUPITER_BANDS_OLD, JUPITER_BANDS_NEW, None)],
     _full(CIRI_MATI), False),

    # ── Pembaca tabel palet kehilangan satu planet ───────────────────────
    # Satu-satunya keadaan yang memerahkan "terbaca dari model": badan kasus
    # palet tidak terbaca (lewat variabel perantara, bukan warna literal),
    # sehingga pembaca tabel **melempar** penjaga cakupannya. Terukur: tepat
    # 1 merah, "terbaca dari model", dan enam pemeriksaan lain hilang karena
    # gerbang berhenti lebih awal.

    # **Kenapa suntingan Pluto, bukan suntingan Uranus yang sudah ada.**
    # Sempat ditulis dengan jangkar `case .uranus` yang ada di model, dan
    # terukur bekerja, tetapi bentuknya salah: `PLUTO_CASE` dan kasus Uranus
    # yang asli tidak bisa dibedakan oleh pembaca, jadi yang diuji bukan lagi
    # "badan tak-terbaca memerahkan pembaca" melainkan keberuntungan bentuk
    # tulisan satu planet tertentu. Yang dipakai karena itu **kasus Pluto
    # yang baru disuntikkan oleh keadaan ini sendiri** — satu planet, satu
    # keadaan, satu sebab.
    #
    # **Kenapa bukan `case .mars` → `case .marsX`.** Itu dugaan pertama saya,
    # dan terukur **salah**: kedua pembaca memakai pola yang setara atas
    # wilayah `switch` yang sama, jadi keduanya sepakat pada nama baru dan
    # pemeriksaan itu tetap hijau.
    #
    # **Dan kenapa lima pemeriksaan lain hijau di sini** — juga terukur, dan
    # juga membantah dugaan saya: cakupan gerbang ciri diturunkan dari
    # **tabel palet**, bukan dari `switch`, jadi tabel yang kehilangan satu
    # planet hanya membuat daftar tuntutannya mengecil dan ia tetap hijau.
    # Artinya pemeriksaan "sepakat" ini adalah **satu-satunya** penjaga atas
    # ketidaksepakatan switch↔tabel; kalau ia hilang, tabel yang kehilangan
    # planet lewat begitu saja.
    #
    # Keadaan ini mengukur **pembaca teks**, bukan build. Untuk Suntingan
    # Uranus versi lama batas itu penting (`.uranus` memang tidak ada di enum
    # waktu itu); untuk Pluto ia bahkan lebih tegas — Pluto memang **tidak**
    # ada di `CelestialVisual.Planet`, jadi kasusnya tidak akan pernah
    # dikompilasi. Batas itu dinyatakan, bukan disangka tertutup.
    #
    # **Harapannya `CABANG` dan `SEPAKAT`, keduanya merah — dan dua-duanya
    # adalah perbaikan siklus ini.** Sempat ditulis `_full(SEPAKAT)` dan
    # terukur merah sebagai "cacat bukti"; sempat ditulis `_full(TERKUNCI)`
    # dan terukur merah lagi. Kedua kegagalan itu benar, dan sebabnya sama:
    # **gerbangnya dulu salah bentuk.**
    #
    # Bentuk lama: pembaca melempar begitu ada cabang tak terbaca, dan
    # pemanggilnya melaporkan lemparan itu sebagai "terbaca dari model" —
    # **sebelum** sempat membandingkan tabel dengan `switch`. Jadi satu
    # perubahan yang sah pada badan satu kasus palet menghasilkan pesan yang
    # menunjuk pembaca, dan enam pemeriksaan sesudahnya tidak pernah
    # tercatat, termasuk "sepakat" yang justru yang paling tepat menggambarkan
    # cacatnya (tabel kehilangan planet, `switch` masih memuatnya).
    #
    # Bentuk sekarang: pembaca mengembalikan planet yang tak terbaca sebagai
    # `("unreadable", urutan)`, gerbang berjalan sampai selesai, dan yang
    # merah adalah **dua nama yang tepat** — `SEPAKAT` (tabel vs switch) dan
    # `CABANG` (polanya memang belum mengenali bentuk baru itu). Ini yang
    # membedakan keadaan 4 dari sekadar "gerbang menyala": bukan *apakah* ia
    # menyalakan, melainkan *apa yang ia sebut*.
    ("4. model: satu kasus palet kehilangan badan yang terbaca",
     [(MODEL, SATURN_CASE, SATURN_CASE + PLUTO_UNREADABLE, None)],
     _full(SEPAKAT, CABANG), False),

    # ── Tiga cara gerbang ciri bisa kehilangan cakupannya ────────────────
    ("5. gerbang: pasangan mars hilang dari 'hilang saat ragu'",
     [(CHECK, MARS_PAIR, "", DISAPPEAR)],
     _full(GERBANG_RAGU), False),

    ("6. gerbang: pasangan venus hilang dari 'ukuran jam'",
     [(CHECK, VENUS_PAIR_JAM, "", WATCH_SIZE)],
     _full(GERBANG_JAM), False),

    # Nama kedua sisinya ada; yang salah pasangannya. Pemeriksaan yang hanya
    # menuntut "kelima planet ada" akan hijau di sini.
    ("7. gerbang: pasangan jupiter memakai nama saturn",
     [(CHECK, PAIR_RAGU_JUPITER, JUPITER_PAIR_TUKAR, DISAPPEAR)],
     _full(GERBANG_RAGU), False),

    # ── Yang wajib hijau: planet baru, terpasang lengkap ─────────────────
    # Model + port + kelima kasus render + ketiga gerbang ciri. Tidak satu
    # pun kawat berbunyi, **dan** aturan kejujuran kini berlaku untuk Pluto:
    # dua pemeriksaan "pita Pluto" dari gerbang ciri muncul dan hijau.
    ("8. pluto terpasang LENGKAP (wajib hijau)",
     [(MODEL, ENUM_OLD, ENUM_NEW, None),
      (MODEL, PHASE_OLD, PHASE_NEW, None),
      (MODEL, SATURN_CASE, SATURN_CASE + PLUTO_CASE, None),
      (RENDER, PORT_HEAD, PORT_HEAD + PORT_PLUTO, None),
      (RENDER, PORT_CONFIRMED, PORT_CONFIRMED_NEW, None),
      (RENDER, PORT_UNCERTAIN, PORT_UNCERTAIN_NEW, None),
      (RENDER, PORT_BARE, PORT_BARE_NEW, None),
      (CHECK, PAIR_RAGU_JUPITER, PAIR_RAGU_JUPITER + PAIR_RAGU_PLUTO, DISAPPEAR),
      (CHECK, PAIR_JAM_JUPITER, PAIR_JAM_JUPITER + PAIR_JAM_PLUTO, WATCH_SIZE),
      (CHECK, PAIR_JAM_JUPITER, PAIR_JAM_JUPITER + PAIR_JAM_PLUTO, NIGHT)],
     _full(), True),

    # ── Yang wajib hijau: enum baru SESUDAH palet ────────────────────────
    # Kode yang sah dan tidak menyentuh palet sama sekali. Harapannya hijau,
    # jadi keadaan ini **tidak** membuktikan penjaganya berbunyi (itu tugas
    # keadaan 4). Yang ia buktikan sebaliknya: penjaganya **tidak menghukum
    # penambahan yang benar**.
    #
    # Terukur kenapa ia perlu ada: penjaga cakupan itu pada versi pertamanya
    # memindai dari jangkar `var palette` sampai **EOF**, sehingga `case`
    # dari enum mana pun di bawahnya ikut terhitung. Menyisipkan enum ini
    # membuat pembaca melempar "hanya mengenali 7 dari 9 cabang `case`" —
    # merah pada pohon yang benar. Jebakan yang sama sudah tertulis di
    # `read_planet_switch_cases_from_swift`; pembaca tabel mewarisinya karena
    # penjaganya ditulis belakangan.
    ("9. enum baru sesudah palet (wajib hijau)",
     [(MODEL, NEW_ENUM_AFTER_PALETTE, NEW_ENUM_ADDED + NEW_ENUM_AFTER_PALETTE,
       None)],
     _full(), False),
]

#: Dua pemeriksaan yang **hanya** ada kalau aturan kejujuran berlaku bagi
#: Pluto. Namanya dibaca dari label pasangan yang ditambahkan keadaan 8,
#: jadi gerbang yang berhenti menamai cirinya akan membuat keadaan ini tidak
#: sesuai harapan — bukan diam-diam lulus.
HONESTY_PLUTO = ("pita Pluto hilang saat ragu",
                 "pita Pluto ragu == bola tak dikenal")


def run_probe(honesty: bool):
    """Jalankan gerbang di proses baru. → (verdicts, galat)."""
    env = dict(os.environ, HONESTY="1" if honesty else "0")
    out = subprocess.run([sys.executable, "-c", PROBE, ROOT],
                         capture_output=True, text=True, timeout=1200, env=env)
    if out.returncode != 0:
        return None, out.stderr.strip()[-1500:]
    verdicts = {}
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("ERR "):
            continue
        parts = line.split("|")
        if len(parts) != 3:
            continue
        tag, name, state = parts
        verdicts[tag + "\u0000" + name] = HIJAU if state == "OK" else MERAH
    return verdicts, None


def mutate(path, old, new, fn):
    """Suntikkan `old` -> `new`; `fn` membatasi ke badan satu fungsi.

    Tanpa pembatasan fungsi, jangkar yang muncul sekali **per gerbang** (dua
    gerbang ciri memuat pasangan yang sama) akan menyasar gerbang pertama —
    yang bukan gerbang yang sedang diuji — dan harness-nya lalu mengukur
    berkas yang salah sambil terlihat benar.
    """
    text = open(path, encoding="utf-8").read()
    if fn is not None:
        start = text.index(f"def {fn}(")
        end = text.find("\ndef ", start + 1)
        end = len(text) if end == -1 else end
        region = text[start:end]
        if region.count(old) != 1:
            return (f"KELEMAHAN BUKTI: di dalam {fn}(): jangkar muncul "
                    f"{region.count(old)}x, butuh 1")
        text = text[:start] + region.replace(old, new, 1) + text[end:]
    else:
        count = text.count(old)
        if count != 1:
            return (f"KELEMAHAN BUKTI: {os.path.basename(path)}: jangkar "
                    f"muncul {count}x, butuh 1")
        text = text.replace(old, new)
    if new not in text:
        return "KELEMAHAN BUKTI: hasil suntikan tidak ditemukan"
    mutasi_sumber.write_source(path, text)
    return None


def main():
    mutasi_sumber.require_clean_sources(FILES)
    originals = {path: open(path, "rb").read() for path in FILES}
    baseline_md5 = {path: hashlib.md5(data).hexdigest()
                    for path, data in originals.items()}
    failures = []

    def restore():
        for path, data in originals.items():
            mutasi_sumber.restore_verified(path, data)

    def on_signal(signum, _frame):
        restore()
        print(f"\n[signal {signum}] sumber produksi dipulihkan, keluar.")
        sys.exit(130)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)

    try:
        for name, edits, expected, honesty in STATES:
            restore()
            problems = []
            gate = {}
            honest = {}
            if edits is not None:
                for path, find, replace, fn in edits:
                    problem = mutate(path, find, replace, fn)
                    if problem:
                        problems.append(problem)
                        break
            if not problems:
                verdicts, error = run_probe(honesty)
                if verdicts is None:
                    problems.append(f"probe gagal: {error}")
                else:
                    gate = {k.split("\u0000", 1)[1]: v for k, v in verdicts.items()
                            if k.startswith("GATE\u0000")}
                    # Gerbang model adalah **gerbang berhenti-penuh**: begitu satu
                    # pemeriksaan gagal, ia `return` dan pemeriksaan sesudahnya
                    # tidak pernah dicatat. Jadi "hasil hilang" pada keadaan yang
                    # memang memerahkan gerbang ini **bukan** cacat bukti — itu
                    # bentuk yang diharapkan lahir dari cara gerbangnya berhenti.
                    # Yang dibandingkan karena itu: verdict untuk nama yang
                    # memang dilaporkan, dan larangan atas nama tak terduga.
                    # **Gerbang yang tidak melaporkan apa pun selalu "sesuai
                    # harapan"** — pemeriksaan atas himpunan kosong tidak bisa
                    # salah, jadi abort total akan lulus diam-diam. Itu bentuk
                    # paling sunyi dari harness yang tidak mengukur apa pun,
                    # dan ia pernah hampir terjadi di sini: `return` pada
                    # pembaca membuat gerbang keluar tanpa satu pun Result.
                    if not gate:
                        problems.append(
                            "gerbang tidak melaporkan satu pun pemeriksaan — "
                            "abort, bukan merah yang bisa dibaca")
                    elif expected.get(SEPAKAT) == MERAH:
                        expectation = {n: w for n, w in expected.items()
                                       if n in gate}
                    else:
                        expectation = expected
                    missing = sorted(set(expectation) - set(gate))
                    extra = sorted(set(gate) - set(expectation))
                    if missing:
                        problems.append(f"hasil hilang: {missing}")
                    if extra:
                        problems.append(f"hasil tak terduga: {extra}")
                    wrong = [f"{n} diharapkan {w} terukur {gate[n]}"
                             for n, w in expectation.items()
                             if n in gate and gate[n] != w]
                    if wrong:
                        problems.append("verdict salah: " + "; ".join(wrong))
                    if honesty:
                        honest = {k.split("\u0000", 1)[1]: v
                                  for k, v in verdicts.items()
                                  if k.startswith("HONESTY\u0000")}
                        for wanted in HONESTY_PLUTO:
                            if wanted not in honest:
                                problems.append(
                                    f"aturan kejujuran tidak berlaku bagi Pluto: "
                                    f"'{wanted}' tidak ada di antara "
                                    f"{len(honest)} pemeriksaan")
                            elif honest[wanted] != HIJAU:
                                problems.append(
                                    f"'{wanted}' merah — ciri Pluto tidak "
                                    "tergambar, jadi tidak ada yang hilang saat ragu")

            if problems:
                failures.append(f"{name}: " + " | ".join(problems))
                print(f"{name}: TIDAK SESUAI HARAPAN")
                for item in problems:
                    print(f"    {item}")
            else:
                if honesty:
                    red = sum(1 for v in verdicts.values() if v == MERAH)
                    print(f"{name}: sesuai harapan (0 merah dari "
                          f"{len(verdicts)} pemeriksaan; aturan kejujuran "
                          f"berlaku bagi Pluto)")
                else:
                    red = sum(1 for v in verdicts.values() if v == MERAH)
                    print(f"{name}: sesuai harapan ({red} merah dari "
                          f"{len(verdicts)} pemeriksaan)")
    finally:
        restore()

    for path, digest in baseline_md5.items():
        after = hashlib.md5(open(path, "rb").read()).hexdigest()
        rel = os.path.relpath(path, ROOT)
        print(f"md5 {rel}: {digest} -> {after} "
              f"({'pulih persis' if after == digest else 'TIDAK PULIH'})")
        if after != digest:
            failures.append(f"sumber produksi tidak pulih persis: {path}")

    if failures:
        print(f"\n{len(failures)} KELEMAHAN BUKTI:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print(f"\n{len(STATES)} keadaan, semuanya sesuai harapan.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
