#!/usr/bin/env python3
"""Jangkar tiap harness mutasi harus masih ada di berkas sasarannya.

Gerbang ini menutup kelas cacat yang **sudah dua kali** menjatuhkan `main`, dan
yang paling sulit dilihat karena tidak ada galat kompilasi, tidak ada langkah
merah, tidak ada berkas yang hilang.

Bentuk cacatnya. Setiap harness di `Tools/bukti-mutasi-*.py` memutasi berkas
**produksi** dengan sepasang string: `find` (jangkar, harus ada di sumber) dan
`replace` (penggantinya). Harness memulihkan berkasnya di `finally` plus handler
`SIGINT`/`SIGTERM` — tetapi **`SIGKILL` dan timeout melewati keduanya**
(docstring `bukti-mutasi-inti-gugus.py` mencatatnya sendiri). Mutasi lalu
tertinggal hidup di berkas produksi.

Kenapa penjaga yang ada tidak cukup. `mutasi_sumber.require_clean_sources`
membandingkan berkas dengan `git HEAD` dan menolak jalan di atas pohon kotor.
Itu benar dan bekerja — tetapi **begitu mutasi yang bocor ikut ter-commit**,
berkas itu *menjadi* HEAD, dan penjaganya puas selamanya. Terukur, bukan
teoretis: `CLUSTER_CORE_HALO_SCALE = 40.0` adalah mutasi keadaan 2
`bukti-mutasi-inti-gugus.py` yang tertinggal, ikut ter-commit di `cf3c56b`
(commit yang pesannya tentang ciri planet), dan baru tertangkap berjam-jam
kemudian — lewat gerbang drift `port == view`, yang berhasil hanya karena view
kebetulan memegang angka yang benar.

**Yang diperiksa di sini, dan kenapa arahnya dua.**

  * jangkar `find` ada di berkas sasaran  -> kalau hilang, kemungkinan besar
    yang ada di sana adalah `replace`: mutasi yang bocor.
  * `replace` tidak ada ketika `find` hilang -> itu bukti bocornya, bukan
    sekadar "komentar dirapikan orang".

Arah pertama sendirian akan merah setiap kali seseorang memperbarui jangkar
sebuah harness dengan sengaja (dan itu terjadi di repo ini: harness dijaga
tetap cocok dengan sumbernya). Dua arah bersama-sama hanya merah pada keadaan
yang memang salah: **`find` sudah tidak ada, sementara penggantinya ada.**

Cakupan diambil dari **harness-nya sendiri** (parsing AST `STATES`), bukan dari
daftar tangan: konstanta string tingkat modul di-resolve, begitu juga konstanta
**path** (`VIEW = os.path.join(ROOT, ...)`, `_sources = (VIEW,)`), supaya
berkas sasaran tiap jangkar diketahui persis. Daftar tangan akan jadi salinan
kedua yang menyusut diam-diam saat harness bertambah — kelas yang sudah berulang
di repo ini.

Pakai:
    python3 Tools/check-jangkar-harness.py        # 0 = tak ada mutasi bocor
"""
from __future__ import annotations

import ast
import fnmatch
import glob
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "Tools")
PATTERN = "bukti-mutasi-*.py"

#: Nama berkas yang **boleh** dibaca sebagai sasaran mutasi. Sengaja sempit:
#: hanya berkas produksi, bukan berkas `.pyc`, cache, atau berkas di `out/`.
#: Sebuah jangkar yang tidak ketemu di berkas mana pun di sini dilaporkan
#: sebagai "sasaran tak terbaca", bukan diabaikan — jangkar yang diabaikan
#: membuat gerbang ini hijau karena tidak memeriksa apa pun.
MAX_SOURCE_BYTES = 2_000_000

#: Ambang panjang untuk mendeteksi mutasi **sisipan** yang tertinggal.
#:
#: Suntingan sisipan punya bentuk `pengganti ⊃ jangkar`, jadi `anchor in text`
#: tetap benar setelah mutasinya mendarat — pemeriksaan jangkar tidak bisa
#: membedakan pohon bersih dari pohon termutasi. Yang membedakan adalah **teks
#: yang ditambahkan** (`pengganti` tanpa satu kemunculan jangkar).
#:
#: Ambang ini ada karena bagian tambahan yang sangat pendek terlalu mudah cocok
#: secara kebetulan. Terukur pada pohon bersih: `ENUM_NEW` di
#: `bukti-mutasi-kasus-planet.py` menambah `case uranus` (11 karakter) yang
#: memang sudah ada di enum, dan `bukti-mutasi-sabit-bibir-kawah.py` menambah
#: `// sama` (7) — keduanya suntingan no-op yang sah. Di bawah 40, keempat
#: kecocokan itu muncul sebagai kebocoran palsu; pada 40 ke atas, nol.
SISIPAN_MIN = 40


def _is_harness(path):
    """Apakah `path` salah satu berkas harness (`Tools/bukti-mutasi-*.py`).

    Dipakai oleh pemeriksaan mutasi sisipan: pasangan (jangkar, pengganti)
    dituliskan **di dalam** berkas harness, jadi teks tambahannya selalu
    ditemukan di sana. Harness yang menjadi saksi bagi dirinya sendiri akan
    melaporkan setiap suntingan sisipan sebagai kebocoran pada pohon bersih.
    """
    return (os.path.dirname(os.path.abspath(path)) == TOOLS
            and fnmatch.fnmatch(os.path.basename(path), PATTERN))


def _string(node, consts):
    """Nilai string sebuah simpul AST, atau None."""
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    if isinstance(node, ast.Name) and node.id in consts:
        return consts[node.id]
    if isinstance(node, ast.Subscript) and isinstance(node.value, ast.Name) \
            and isinstance(node.slice, ast.Constant) and isinstance(node.slice.value, str):
        # `ANCHORS["badan `linkAccessibilityLabel`"]`. Repo ini menyimpan
        # jangkar di tabel bernama lalu merujuknya dengan subskrip; tanpa
        # resolusi ini seluruh keadaan `kalimat-a11y` terbaca sebagai nol
        # pasangan, dan gerbangnya buta terhadap harness yang menulis
        # `PointingView.swift` di tempat.
        return consts.get(_subscript_key(node.value.id, node.slice.value))
    return None


def _subscript_key(name, key):
    """Kunci sintetis untuk `nama[kunci]` di dalam `consts`."""
    return f"{name}[{key!r}]"


def _path_expr(node, consts, inside_join=False):
    """Nilai sebuah ekspresi **path** (`os.path.join(...)`, konstanta, literal).

    Dikembalikan sebagai string absolut, atau None bila tidak bisa diselesaikan.
    Dipakai supaya berkas sasaran tiap jangkar diketahui, bukan ditebak dari
    daftar tetap.

    `inside_join=True` berarti simpul ini adalah **komponen** dari
    `os.path.join(...)`; di sana string literal harus tetap relatif, karena
    `os.path.join(ROOT, "Tools", "render-visuals.py")` berarti tiga komponen —
    bukan "ganti ROOT dengan yang absolut". Tanpa pembedaan ini, komponen
    terakhir yang absolut akan menelan seluruh jalur di depannya, dan gerbang
    mencari berkas di tempat yang salah (lalu melaporkannya "tak terbaca").
    """
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        value = node.value
        if inside_join or os.path.isabs(value):
            return value
        return os.path.join(ROOT, value)
    if isinstance(node, ast.Name):
        if node.id == "ROOT":
            return ROOT
        if node.id == "TOOLS":
            return TOOLS
        if node.id in consts:
            inner = consts[node.id]
            if inside_join or os.path.isabs(inner):
                return inner
            return os.path.join(ROOT, inner)
        return None
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) \
            and node.func.attr == "join":
        parts = [_path_expr(arg, consts, inside_join=True) for arg in node.args]
        if any(part is None for part in parts):
            return None
        resolved_parts = [part for part in parts if part is not None]
        out = ""
        for part in resolved_parts:
            out = part if os.path.isabs(part) else os.path.join(out, part)
        return out
    return None


def _module_constants(tree):
    """Nama -> nilai untuk konstanta string DAN konstanta path tingkat modul.

    Urutannya penting dan disengaja: **tabel string dulu**, baru skalar dan
    jalur. Repo ini menulis `A_LINK = ANCHORS[...]` dengan subskrip, jadi
    rujukan itu hanya bisa diresolusi kalau isi tabelnya sudah diketahui.
    Dengan urutan terbalik, `A_LINK` tidak masuk `consts`, seluruh keadaan
    `kalimat-a11y` terbaca nol pasangan, dan kebutaannya tersembunyi — tepat
    kelas cacat yang gerbang ini ada untuk menutup.
    """
    consts = {}
    for node in tree.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if not isinstance(target, ast.Name) or not isinstance(node.value, ast.Dict):
            continue
        for key, item in zip(node.value.keys, node.value.values):
            if isinstance(key, ast.Constant) and isinstance(key.value, str) \
                    and isinstance(item, ast.Constant) and isinstance(item.value, str):
                consts[_subscript_key(target.id, key.value)] = item.value
    for node in tree.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if not isinstance(target, ast.Name):
            continue
        text = _string(node.value, consts)
        if text is not None:
            consts[target.id] = text
            continue
        resolved = _path_expr(node.value, consts)
        if resolved is not None and ("/" in resolved or "\\" in resolved):
            consts[target.id] = resolved
    return consts


def _ekstensi_sumber(path):
    """Apakah berkas ini salah satu ekstensi **sumber** (bukan dokumen)?

    Kenapa ada: gerbang ini menjaga mutasi tertinggal, tapi sampai roda ini ia
    tidak pernah bertanya **berkas apa** yang dimutasi. Terukur, harness uji
    coba yang pasangannya `(README.md, "68 aturan")` dan
    `(swift-ui-lint.sh, "Aturan 68:")` diterima sebagai dua jangkar sah ->
    "+2 jangkar, 0 kebocoran, exit 0". Keduanya bukan satu pun baris kode:
    yang diubah adalah prosa laporan dan naskah gerbangnya sendiri. Sebuah
    harness bisa karena itu "menjaga kode" sementara hanya menyunting
    dokumen.

    Yang tidak diklaim: `swift-ui-lint.sh` memang **bukan** `.swift`, padahal
    sebagian besar harness repo ini memutasi berkas itu dengan benar. Daftar
    ini sengaja menyebut ekstensi yang diterima sehingga berkas seperti
    `.sh` muncul sebagai penyimpangan yang bisa dibaca -- bukan dilewatkan
    diam-diam, bukan juga dilarang tanpa alasan.
    """
    _, ext = os.path.splitext(path or "")
    return ext.lower() in _EXT_SUMBER


#: Ekstensi yang dianggap **sumber** ketika sebuah harness menyebut berkas
#: sasarannya eksplisit. `.md`/`.txt`/`.sh` tidak ada di sini dengan sengaja.
_EXT_SUMBER = (".swift", ".py", ".plist", ".xcstrings", ".entitlements",
               ".json", ".yml", ".yaml", ".strings")


def _looks_like_path(value):
    """Apakah nilai string ini **jalur berkas**, bukan label keadaan?

    `STATES` di repo ini memakai string pendek sebagai **label** ("port",
    "model", "view") dan string panjang sebagai **teks sumber**. Tanpa
    pembedaan ini, `"port"` diresolusi jadi `<ROOT>/port`, dan gerbang
    melaporkan "sasaran tak terbaca" untuk berkas yang memang tidak pernah
    ada — kebisingan yang menyamarkan temuan sungguhan.

    Dipakai hanya untuk memutuskan bentuk tuple mana yang sedang dibaca;
    berkasnya tetap diresolusi lewat `_path_expr`.
    """
    if not isinstance(value, str):
        return False
    if "/" in value or "\\" in value:
        return True
    return value.endswith((".py", ".swift", ".sh", ".yml", ".yaml", ".json",
                           ".xcstrings", ".plist", ".md", ".txt"))


def _edit_pairs(value, consts):
    """`(anchor, replacement, target_node)` dari satu nilai keadaan `STATES`.

    Bentuk yang dibaca — semuanya dipakai di `Tools/bukti-mutasi-*.py` hari ini:

      (find, replace)                  berkas dari `_sources`/KNOWN_TARGETS
      (find, replace, …)               sisa elemen diabaikan
      (path, find, replace[, …])       berkas eksplisit
      [(…), (…)]                       daftar edit
      {path: (find, replace)}          satu edit per berkas
      {path: [(find, replace), …]}     idem, berbentuk daftar

    Bentuk yang tidak dikenali **dilewati** — tetapi sekarang itu terlihat:
    jumlah jangkar yang terbaca dicetak, dan harness yang **bisa** memutasi
    sumber produksi sementara tidak menyumbang satu jangkar pun membuat
    gerbang keluar bukan-nol (lihat `main`). Sebelumnya ia dilewati tanpa
    suara, dan itu terbukti buta: 22 mutasi bocor yang ditanamkan dari
    harness berbentuk `(label, (find, replace))` semuanya dilaporkan "OK".
    """
    out = []
    if isinstance(value, ast.Dict):
        for key, item in zip(value.keys, value.values):
            for anchor, replacement, _ in _edit_pairs(item, consts):
                out.append((anchor, replacement, key))
        return out
    if isinstance(value, ast.List):
        for element in value.elts:
            out.extend(_edit_pairs(element, consts))
        return out
    if isinstance(value, ast.Tuple):
        parts = value.elts
        if len(parts) >= 3:
            raw = _string(parts[0], consts)
            if raw is not None and _looks_like_path(raw):
                # Bentuk `(path, find, replace)`. Kalau penggantinya bukan
                # string (mis. `X.replace(...)`), **jangan** jatuh ke bentuk
                # pasangan telanjang: di situ `parts[0]` adalah jalur, dan
                # jalur sebagai "jangkar" menghasilkan temuan kebocoran palsu.
                # Terukur: tanpa penjagaan ini gerbang melaporkan 25 kebocoran
                # pada pohon bersih.
                anchor = _string(parts[1], consts)
                replacement = _string(parts[2], consts)
                if anchor is not None:
                    out.append((anchor, replacement, parts[0]))
                return out
        if len(parts) >= 2:
            anchor = _string(parts[0], consts)
            replacement = _string(parts[1], consts)
            if anchor is not None:
                out.append((anchor, replacement, None))
        return out
    return out


def _tuple_constants(tree):
    """Nama -> simpul `ast.Tuple` tingkat modul.

    Dipakai untuk bentuk `*DEEP_SATURN` di `CASES`: repo ini menyimpan satu
    keadaan sebagai konstanta tuple lalu menyebarkannya ke dalam tabel dengan
    `*`. Tanpa resolusi ini, keadaan-keadaan itu terbaca sebagai `Starred` dan
    seluruh pasangannya hilang — kelas kebutaannya sama dengan bentuk
    `(label, (find, replace))` yang sudah terbukti menutupi 22 kebocoran.
    """
    tuples = {}
    for node in tree.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if isinstance(target, ast.Name) and isinstance(node.value, ast.Tuple):
            tuples[target.id] = node.value
    return tuples


def _flatten_state(item, tuples):
    """Elemen keadaan dengan `*nama` yang disebar menjadi elemen-elemennya."""
    out = []
    for element in item.elts:
        if isinstance(element, ast.Starred) and isinstance(element.value, ast.Name) \
                and element.value.id in tuples:
            out.extend(tuples[element.value.id].elts)
        else:
            out.append(element)
    return out


#: Nama tabel keadaan yang dibaca, sebagai **predikat** — bukan daftar nama.
#:
#: Kenapa predikat, bukan daftar. Daftar tangan harus diperbarui setiap kali
#: seseorang menamai tabel barunya dengan cara yang sedikit berbeda, dan
#: kegagalan memperbaruinya **diam**: tabel yang tidak dikenali terbaca sebagai
#: nol pasangan, dan gerbangnya hijau karena tidak memeriksa apa pun. Itu bukan
#: hipotesis — `bukti-mutasi-lengan.py` menyimpan empat keadaannya di
#: `PARITY_STATES`, dan selama daftar ini hanya memuat `STATES`/`CASES`, empat
#: mutasi bocor dari berkas itu tetap tak terlihat.
#:
#: Batasnya tetap sengaja sempit. Tabel data pendukung (`ARM_BLOBS`,
#: `NEIGHBOURS`, `FILES`, `STARS`, …) berisi pasangan angka/berkas yang mirip
#: (jangkar, pengganti) bagi pembaca yang tidak tahu konteksnya; membacanya
#: menghasilkan jangkar palsu. Terukur: membaca **seluruh** daftar tingkat modul
#: melaporkan 26 "kebocoran" pada pohon bersih — semuanya palsu — dan gerbang
#: yang merah pada pohon bersih akan dimatikan orang.
def _is_state_table(name):
    """Apakah `name` menamai tabel keadaan mutasi (bukan tabel data)?"""
    if name in ("STATES", "CASES"):
        return True
    return name.endswith("_STATES") or name.endswith("_CASES")


def _state_tables(tree):
    """Daftar `ast.List` untuk setiap tabel keadaan tingkat modul."""
    tables = []
    for node in tree.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if not isinstance(target, ast.Name) or not _is_state_table(target.id):
            continue
        if isinstance(node.value, ast.List):
            tables.append(node.value)
    return tables


def _collect_edits(tree, consts):
    """Seluruh `(anchor, replacement, target_path)` dari tiap bentuk `STATES`.

    Bentuk tingkat keadaan yang dibaca:

      (label, None)                    baseline — tidak ada mutasi
      (label, find, replace[, …])      pasangan telanjang di posisi 1 dan 2
      (label, (find, replace)[, …])    pasangan berbungkus tuple
      (label, path, [(…)], …)          jalur eksplisit di posisi 1
      (label, {path: (find, replace)}) satu edit per berkas
      (label, [(…), (…)])              daftar edit
      (label, *KONSTANTA_TUPLE, …)     keadaan yang disebar

    Bentuk `CASES`/`EDITS` yang **tidak** memuat pasangan (jangkar, pengganti)
    memang tidak terbaca di sini, dan itu dilaporkan lewat `main` sebagai
    "harness yang bisa memutasi sumber produksi tanpa satu jangkar pun" —
    bukan dilewati diam-diam.
    """
    edits = []
    tuples = _tuple_constants(tree)
    for table in _state_tables(tree):
        for item in table.elts:
            if not isinstance(item, ast.Tuple) or len(item.elts) < 2:
                continue
            parts = _flatten_state(item, tuples)

            # Pasangan telanjang: dua string berturut-turut di posisi 1 dan 2
            # (`("1. …", find, replace, harapan)`).
            #
            # Hanya bila posisi 1 **bukan** jalur: bentuk `(label, path, …)`
            # menaruh jalur di sana, dan jalur sebagai "jangkar" menghasilkan
            # kebocoran palsu. Terukur: tanpa penjagaan ini gerbang melaporkan
            # 25 kebocoran pada pohon bersih.
            if len(parts) >= 3:
                head = _string(parts[1], consts)
                if head is not None and not _looks_like_path(head):
                    anchor = head
                    replacement = _string(parts[2], consts)
                    if replacement is not None:
                        edits.append((anchor, replacement, None))

            for value in parts[1:]:
                if isinstance(value, ast.Constant):
                    continue  # skalar: sudah ditangani di atas
                for anchor, replacement, target in _edit_pairs(value, consts):
                    path = _path_expr(target, consts) if target is not None else None
                    edits.append((anchor, replacement, path))
    return edits


def _load_library(path):
    try:
        return ast.parse(open(path, encoding="utf-8").read()), None
    except (SyntaxError, UnicodeDecodeError) as error:
        return None, error


def _writes_production_in_place(tree):
    """Apakah harness ini menulis sumber produksi **di tempat**?

    Kriterianya mekanis, bukan daftar tangan, dan sengaja **hanya** penulisan:
    `mutasi_sumber.write_source` / `restore_verified` adalah jalur tulis yang
    dipakai harness yang menimpa berkas produksi lalu memulihkannya. Harness
    yang memutasi **salinan** (`mkdtemp`/`copytree`) menulis lewat `open(...)`
    biasa ke dalam kotak pasirnya, jadi kebutaannya tidak bisa mendaratkan
    mutasi di `main`.

    `require_clean_sources` **tidak** dihitung, walaupun ia hidup di modul yang
    sama: ia penjaga **baca** yang juga dipakai seluruh harness kotak pasir
    (terukur: 13 dari 18 yang tercatat buta hanya memanggilnya, tanpa pernah
    menulis). Menghitungnya akan menuntut harness kotak pasir menyumbang
    jangkar — tuntutan yang tidak ada hubungannya dengan kebocoran, dan
    gerbang yang menuntut hal yang tidak benar akan dilonggarkan orang.

    **Dibaca dari AST, bukan dari teks.** Versi pertama memakai `in source`,
    dan itu salah dengan cara yang menipu: `bukti-mutasi-jangkar-harness.py`
    menyimpan potongan kode harness contoh sebagai **string literal** di dalam
    pengujiannya sendiri, jadi teks `mutasi_sumber.write_source` muncul di
    berkas yang sebenarnya tidak pernah memanggilnya. Akibatnya gerbang
    menuntut jangkar dari berkas itu, merah pada pohon bersih, dan memaksa
    keadaan 1 harness ini gagal. Yang diukur harus **panggilan**, bukan
    tulisan tentang panggilan.
    """
    if tree is None:
        return False
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        if isinstance(func, ast.Attribute) and isinstance(func.value, ast.Name) \
                and func.value.id == "mutasi_sumber" \
                and func.attr in ("write_source", "restore_verified"):
            return True
    return False


#: Nama konstanta yang **harus** ada di harness yang memutasi sumber produksi
#: di tempat tetapi muatannya dirakit saat jalan.
#:
#: Kenapa lewat deklarasi di berkasnya, bukan daftar di sini. Sebagian harness
#: (`bukti-mutasi-lengan.py`, `-gerbang-kosong.py`, `-penjaga-identitas.py`)
#: membangun muatannya dari AST berkas sasaran atau dari fungsi
#: (`ring(8)`, `empty_gate(source, func)`, `mutate("morphology")`). Jangkar
#: seperti itu **tidak ada** sebagai teks tetap, jadi tidak ada pembaca statis
#: yang bisa menemukannya — dulu maupun nanti. Yang bisa dilakukan gerbang
#: adalah **menuntut alasannya tertulis di harness-nya**, lalu mencetaknya.
#:
#: Daftar pengecualian di dalam gerbang akan menjadi daftar tangan yang tidak
#: bisa diperiksa siapa pun, dan aturan repo ini sudah menetapkannya: gerbang
#: harus **membaca klaim dari kode**. Deklarasi di sini menjaga sifat itu, dan
#: sekaligus menutup kelasnya: harness **baru** yang menulis produksi tanpa
#: jangkar terbaca dan tanpa deklarasi membuat gerbang keluar bukan-nol.
#:
#: **Yang TIDAK diklaim.** Deklarasi ini tidak membuktikan bahwa alasannya
#: benar; gerbang hanya memeriksa bahwa alasannya ada, berupa literal, dan
#: cukup panjang untuk dinilai. Harness yang menulis alasan masuk akal padahal
#: jangkarnya sebenarnya terbaca akan lolos. Yang menahannya bukan gerbang ini
#: melainkan kenyataan bahwa alasan itu **tercetak setiap kali gerbang jalan**,
#: jadi ia bisa dibantah di tinjauan — dan itu batas yang disengaja: menuntut
#: gerbang menilai kebenaran prosa akan menghasilkan tebakan, bukan pengukuran.
EXEMPTION = "JANGKAR_KECUALI"

#: Panjang minimum alasan. Alasan sepanjang "karena" atau "kompleks" tidak
#: memberi pembaca apa pun, dan deklarasi yang tidak menjelaskan lebih buruk
#: daripada tidak ada deklarasi.
EXEMPTION_MIN_CHARS = 40


def _declared_exemption(source):
    """Alasan `JANGKAR_KECUALI` di berkas harness, atau None.

    Dibaca lewat AST, bukan regex: alasannya ditulis sebagai rangkaian literal
    yang disambung (`"…" "…"`), dan pengambil satu literal pertama akan
    memotong klaimnya di tengah kalimat — pembaca lalu tidak bisa menilai
    apakah alasannya sah. Alasan yang dirakit saat jalan juga tidak diterima,
    karena gerbang tidak bisa membacanya; itu sama saja dengan tidak ada.
    """
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return None
    for node in tree.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if not isinstance(target, ast.Name) or target.id != EXEMPTION:
            continue
        try:
            value = ast.literal_eval(node.value)
        except ValueError:
            return None
        if not isinstance(value, str):
            return None
        reason = " ".join(value.split())
        if len(reason) < EXEMPTION_MIN_CHARS:
            return None
        return reason
    return None


def collect_harness_edits():
    """(harness, anchor, replacement, target) untuk seluruh harness di disk.

    Juga mengembalikan daftar harness yang **bisa** menulis sumber produksi di
    tempat tetapi tidak menyumbang satu jangkar pun — itu bukan "tak terbaca
    yang tidak berbahaya", melainkan celah yang harus menutup gerbangnya.
    """
    out, unreadable, blind_leak_capable = [], [], []
    exempted = []
    for path in sorted(glob.glob(os.path.join(TOOLS, PATTERN))):
        tree, error = _load_library(path)
        name = os.path.basename(path)
        if tree is None:
            unreadable.append((name, str(error)))
            continue
        consts = _module_constants(tree)
        edits = _collect_edits(tree, consts)
        if not edits:
            unreadable.append((name, "tidak ada pasangan (jangkar, pengganti) terbaca"))
            try:
                source = open(path, encoding="utf-8").read()
            except (OSError, UnicodeDecodeError):
                source = ""
            if _writes_production_in_place(tree):
                reason = _declared_exemption(source)
                if reason is None:
                    blind_leak_capable.append(name)
                else:
                    exempted.append((name, reason))
            continue
        for anchor, replacement, target in edits:
            out.append((name, anchor, replacement, target))
    return out, unreadable, blind_leak_capable, exempted


def _read(path):
    try:
        if os.path.getsize(path) > MAX_SOURCE_BYTES:
            return None
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except (OSError, UnicodeDecodeError):
        return None


def main():
    edits, unreadable, blind_leak_capable, exempted = collect_harness_edits()
    harness_count = len(glob.glob(os.path.join(TOOLS, PATTERN)))
    print(f"harness di disk        : {harness_count}")
    print(f"pasangan jangkar       : {len(edits)}")
    with_target = sum(1 for _, _, _, t in edits if t)
    print(f"  dengan berkas sasaran: {with_target}")

    # Cakupan nol adalah **kegagalan**, bukan keberhasilan.
    #
    # Tanpa pemeriksaan ini, gerbang yang pembacanya rusak (mis. `STATES` berubah
    # bentuk, atau berkas harness-nya tidak terbaca) akan mencetak
    # "OK: 0 jangkar; tidak ada mutasi tertinggal" dan keluar 0 — hijau dengan
    # alasan yang salah, tepat kelas cacat yang gerbang ini ada untuk menutup.
    # Terukur: melumpuhkan `_collect_edits` menghasilkan persis keluaran itu,
    # dan `bukti-mutasi-jangkar-harness.py` keadaan 3 menangkapnya.
    if not edits:
        print()
        print("GAGAL: tidak ada satu pun pasangan (jangkar, pengganti) yang "
              "terbaca dari harness mana pun.")
        print("       Gerbang ini mengukur nol hal; ia tidak bisa menyatakan "
              "apa pun tentang mutasi tertinggal.")
        print("       Periksa apakah bentuk `STATES` di Tools/bukti-mutasi-*.py "
              "berubah sehingga _collect_edits berhenti mengenalinya.")
        return 1

    leaks, missing, unreadable_target = [], [], []
    cache = {}
    # Sasaran eksplisit yang ekstensinya bukan sumber. Dikumpulkan, bukan
    # diabaikan: harness yang "menjaga kode" tetapi hanya menyunting dokumen
    # lolos gerbang mutasi tertinggal tanpa menjaga apa pun (lihat
    # `_ekstensi_sumber`).
    nonsumber = []
    for name, anchor, replacement, target in edits:
        candidates = []
        if target:
            if not _ekstensi_sumber(target):
                nonsumber.append((name, anchor, target))
            text = cache.get(target)
            if text is None:
                text = cache[target] = _read(target)
            if text is None:
                unreadable_target.append((name, anchor, target))
                continue
            candidates = [(target, text)]
        else:
            # Tak ada berkas eksplisit: uji terhadap seluruh berkas produksi
            # yang dikenal repo ini. `find` hilang di **semua** yang diperiksa
            # baru berarti bocor.
            for rel in _sumber_produksi():
                path = os.path.join(ROOT, rel)
                text = cache.get(path)
                if text is None:
                    text = cache[path] = _read(path)
                if text is not None:
                    candidates.append((path, text))
        if not candidates:
            unreadable_target.append((name, anchor, target or "(tanpa sasaran)"))
            continue

        anchor_present = any(anchor in text for _, text in candidates)
        if anchor_present:
            # **Mutasi SISIPAN: jangkar masih ada, teks baru ikut tertinggal.**
            #
            # Sampai siklus ini gerbang berhenti di sini — `anchor in text`
            # sudah cukup, dan untuk 471 dari 496 suntingan memang cukup,
            # karena penggantinya menghapus jangkarnya. Dua puluh lima sisanya
            # **menyisipkan**: pengganti memuat jangkarnya sendiri, jadi
            # pemeriksaan ini menjawab "masih ada" pada pohon yang sudah
            # termutasi.
            #
            # Bentuk yang lolos karena itu nyata dan bukan karangan: keadaan 7
            # di `Tools/bukti-mutasi-jangkar-harness.py` menyisipkan
            # `PembungkusLuar`/`PembungkusBaru` (milik
            # `bukti-mutasi-aturan52-kartu-jam.py`) ke `PointingView.swift` lalu
            # membiarkannya — gerbang mencetak "OK: 496 jangkar" dan keluar 0.
            #
            # Yang diperiksa karena itu **teks yang ditambahkan**, bukan
            # jangkarnya: `added` = pengganti tanpa satu kemunculan jangkar.
            # Kalau bagian itu sudah ada di berkas, mutasinya mendarat.
            #
            # **Kenapa ambang 40 karakter, bukan "ada".** Bagian tambahan yang
            # pendek terlalu mudah cocok secara kebetulan. Terukur pada pohon
            # bersih: `ENUM_NEW` milik `bukti-mutasi-kasus-planet.py` menambah
            # `case uranus` (11 karakter) yang memang sudah ada di enum, dan
            # `bukti-mutasi-sabit-bibir-kawah.py` menambah `// sama` (7).
            # Keduanya suntingan **no-op** yang sah, bukan kebocoran; menandai
            # keduanya akan memerahkan gerbang pada pohon yang benar. Dengan
            # ambang 40, keempat kecocokan palsu itu hilang dan tidak ada
            # satu pun suntingan sisipan yang lebih panjang tertinggal di pohon
            # bersih (terukur: 0 dari 9).
            if replacement is not None and replacement != anchor and anchor in replacement:
                added = replacement.replace(anchor, "", 1).strip()
                if len(added) >= SISIPAN_MIN:
                    # **Harness tidak boleh menjadi saksinya sendiri.**
                    #
                    # Ketika `target` kosong, kandidatnya adalah seluruh berkas
                    # sumber — termasuk `Tools/bukti-mutasi-*.py`, tempat
                    # pasangan (jangkar, pengganti) itu **dituliskan**. Teks
                    # `added` karena itu selalu "ada" di berkas yang
                    # mendefinisikannya, dan tanpa pengecualian ini setiap
                    # suntingan sisipan tanpa sasaran eksplisit akan dilaporkan
                    # sebagai kebocoran pada pohon yang bersih. Terukur:
                    # `bukti-mutasi-aturan55-teks-mati.py` langsung memerahkan
                    # gerbang lewat `STATES`-nya sendiri.
                    #
                    # Yang dikecualikan hanya berkas harness (pola
                    # `bukti-mutasi-*.py`), bukan seluruh `Tools/`: sasaran
                    # seperti `Tools/render-visuals.py` memang produksi dan
                    # harus tetap diperiksa.
                    pembawa = [p for p, text in candidates
                               if added in text
                               and not _is_harness(p)]
                    if pembawa:
                        leaks.append((name, anchor, replacement,
                                      ", ".join(os.path.relpath(p, ROOT)
                                                for p in pembawa[:3])))
            continue
        if not anchor_present:
            # Pengganti `None` berarti harness membangun muatannya saat jalan
            # (`ring(8)`, `mutate("morphology")`, `empty_gate(source, func)`).
            # Jangkar hilang **dan** penggantinya tidak terbaca: yang bisa
            # dikatakan hanya bahwa jangkarnya tidak ada — bukan bahwa ada
            # mutasi tertinggal. Dilaporkan sebagai "hilang", tidak diklaim
            # sebagai kebocoran; mengklaimnya akan membuat gerbang merah pada
            # pohon bersih, dan gerbang seperti itu dimatikan orang.
            if replacement is None:
                missing.append((name, anchor))
                continue
            # **Berkas mana yang memuat penggantinya.** Tanpa ini, kebocoran
            # pada jangkar tanpa sasaran dilaporkan sebagai "(tanpa sasaran)",
            # dan pembaca tidak tahu berkas mana yang harus dipulihkan —
            # persis pada keadaan yang paling sulit ditebak (jangkar tanpa
            # sasaran, yaitu satu-satunya bentuk yang bisa bocor tanpa
            # disebut namanya).
            pembawa = [p for p, text in candidates if replacement in text]
            if pembawa:
                leaks.append((name, anchor, replacement,
                              ", ".join(os.path.relpath(p, ROOT)
                                        for p in pembawa[:3])))
            else:
                missing.append((name, anchor))

    for name, anchor, target in sorted(set(unreadable_target)):
        print(f"  TAK TERBACA  {name}: sasaran {target} tidak bisa dibaca")

    # Dedup: satu harness sering memakai jangkar yang sama di beberapa keadaan,
    # dan mencetaknya berkali-kali menyamarkan berapa banyak jangkar yang
    # sesungguhnya hilang.
    seen = set()
    for name, anchor in sorted(set(missing)):
        line = f"  jangkar hilang (pengganti tidak ada) : {name} -> {anchor[:60]!r}"
        if line not in seen:
            seen.add(line)
            print(line)
    for name, anchor, replacement, target in leaks:
        print(f"  MUTASI BOCOR : {name}")
        print(f"      berkas sasaran : {target}")
        print(f"      jangkar hilang : {anchor[:70]!r}")
        print(f"      pengganti ada  : {replacement[:70]!r}")

    print()
    if leaks:
        print(f"GAGAL: {len(leaks)} mutasi harness tertinggal di sumber produksi.")
        print("       Pulihkan berkasnya (nilai yang benar = yang dipakai kode, "
              "bukan yang tertinggal):")
        print("           git log -p -- <berkas>   # lihat nilai sebelum mutasi")
        return 1

    # Sasaran eksplisit yang bukan sumber: harness menyebut berkas tujuannya
    # sendiri, tetapi berkas itu dokumen/naskah, bukan kode. Sebelum pemeriksaan
    # ini ada, pasangan `(README.md, "68 aturan")` dihitung sebagai jangkar sah.
    if nonsumber:
        print(f"GAGAL: {len(nonsumber)} jangkar menyebut sasaran yang bukan "
              "berkas sumber.")
        print("       Mutasi atas dokumen/naskah tidak membuktikan bahwa kode "
              "berubah:")
        for name, anchor, target in nonsumber[:12]:
            print(f"           {name}: {target!r} <- {anchor!r}")
        if len(nonsumber) > 12:
            print(f"           ... dan {len(nonsumber) - 12} lagi")
        print("       Ekstensi yang diterima: "
              + ", ".join(_EXT_SUMBER))
        print("       Kalau mutasinya memang atas naskah (mis. `swift-ui-lint.sh`), "
              "nyatakan sasaran sumbernya eksplisit di `STATES` "
              "agar pasangannya diuji terhadap kode.")
        return 1

    # Harness yang **bisa** memutasi sumber produksi di tempat, tetapi tidak
    # menyumbang satu jangkar pun ke gerbang ini.
    #
    # Ini bukan "tak terbaca yang tidak berbahaya": kebutaannya justru berarti
    # mutasi bocor dari harness itu tidak akan pernah terlihat di sini. Bentuk
    # `STATES`-nya berubah, atau pasangannya tidak dikenali pembaca — dan
    # keduanya adalah hal yang **harus** menghentikan gerbang, bukan
    # dilewatkan. Terukur sebelum pemeriksaan ini ada: 22 mutasi bocor yang
    # ditanamkan dari harness berbentuk `(label, (find, replace))` semuanya
    # dilaporkan "OK".
    #
    # Daftar ini **tidak** dituntut kosong untuk harness yang memutasi salinan
    # (`copytree`/`mkdtemp`): kebutaannya tidak bisa mendaratkan apa pun di
    # `main`, dan menuntutnya terbaca akan memaksa bentuk tabel yang seragam
    # untuk pekerjaan yang memang berbeda.
    if blind_leak_capable:
        print(f"GAGAL: {len(blind_leak_capable)} harness yang memutasi sumber "
              "produksi di tempat tidak menyumbang satu jangkar pun.")
        print("       Gerbang ini **buta** terhadap mutasi bocor dari "
              "harness-harness itu:")
        for name in sorted(set(blind_leak_capable)):
            print(f"           {name}")
        print("       Perbaiki pembaca `_collect_edits`/`_edit_pairs` agar "
              "mengenali bentuk `STATES`-nya.")
        print(f"       Kalau jangkarnya memang dirakit saat jalan dan karena "
              f"itu tidak bisa dibaca statis, nyatakan itu di berkas "
              f"harness-nya dengan `{EXEMPTION} = \"<alasan>\"` "
              f"(minimal {EXEMPTION_MIN_CHARS} karakter) — jangan hapus "
              "pemeriksaan ini.")
        return 1

    # Harness yang muatannya dirakit saat jalan: jangkarnya tidak ada sebagai
    # teks tetap, jadi gerbang ini tidak bisa memeriksanya — dulu maupun nanti.
    # Dicetak, bukan disembunyikan: pembaca harus tahu berkas mana yang tidak
    # dijaga di sini, dan alasan yang ditulis harness-nya ikut ditampilkan
    # supaya klaimnya bisa diperiksa orang.
    for name, reason in sorted(set(exempted)):
        print(f"  dikecualikan : {name}")
        print(f"      alasan   : {reason}")

    print(f"OK: {len(edits)} jangkar; tidak ada mutasi tertinggal.")
    if missing:
        # **Dulu dicetak sebagai catatan lalu keluar 0.** Sekarang ia temuan.
        #
        # Jangkar yang tidak ditemukan dan penggantinya juga tidak ada berarti
        # dua hal yang tidak bisa dibedakan dari sini: sasarannya keliru, atau
        # teksnya memang sudah berubah. Gerbang yang mengklaim "tidak ada
        # mutasi tertinggal" tidak boleh menebak yang mana.
        #
        # Terukur sebelum ini: `return nil` disisipkan ke
        # `HapticPolicy.pattern(for:)` (mematikan seluruh getaran) -> gerbang
        # mencetak "OK: 496 jangkar" dan keluar 0, karena `HapticPolicy.swift`
        # tidak ada di `KNOWN_TARGETS` dan jangkarnya jadi "hilang" saja.
        # Bentuk itu benar-benar pernah tertinggal di pohon kerja repo ini.
        print()
        print(f"GAGAL: {len(missing)} jangkar tidak ditemukan di berkas "
              "sasarannya, dan penggantinya juga tidak ada.")
        print("       Ini bisa berarti sasaran harness-nya keliru, atau teks "
              "yang dimutasi sudah berubah:")
        for name, anchor in sorted(set(missing))[:12]:
            print(f"           {name}: {anchor[:70]!r}")
        if len(set(missing)) > 12:
            print(f"           ... dan {len(set(missing)) - 12} lagi")
        print("       Perbaiki jangkarnya dari sumber, jangan turunkan "
              "pemeriksaan ini.")
        return 1
    return 0


#: Berkas produksi yang boleh menjadi sasaran mutasi, untuk jangkar yang
#: harness-nya **tidak** menyebut berkas sasaran eksplisit.
#:
#: **Kenapa ini hasil penemuan, bukan daftar tangan.** Sampai keadaan 6 di
#: `bukti-mutasi-jangkar-harness.py` ada, daftar ini ditulis tangan dan
#: berhenti di 12 berkas, sementara `Apps/` + `Packages/` memuat ~200 berkas
#: sumber. Jangkar tanpa sasaran di luar 12 itu selalu "tidak ditemukan", dan
#: karena "tidak ditemukan" dulu hanya dicatat, gerbang **tidak bisa**
#: memerahkan mutasi tertinggal di 8 jangkar nyata (`HapticPolicy`,
#: `HapticEngine`, `PhoneHapticEngine`, `CalibrationView`) — termasuk
#: `return nil` yang mematikan semua getaran.
#:
#: Daftar tetap dipertahankan untuk berkas yang **tidak** berekstensi sumber
#: tetapi memang dimutasi harness (`swift-ui-lint.sh`, dan naskah gerbang
#: lain); penemuan menambahkan seluruh sumber di `Apps/` + `Packages/`.
KNOWN_TARGETS = (
    "Tools/render-visuals.py",
    "Tools/check-visuals.py",
    "Apps/Shared/CelestialVisualView.swift",
    "Apps/Shared/SlewVerdictBanner.swift",
    "Apps/Shared/OnboardingView.swift",
    "Apps/Shared/PointingEngine.swift",
    "Apps/Shared/MotionLogger.swift",
    "Apps/Shared/Resources/Localizable.xcstrings",
    "Apps/PointAndKnowWatch/Sources/PointingView.swift",
    "Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift",
    "Packages/PointingKit/Sources/PointingKit/NightVisual.swift",
    "swift-ui-lint.sh",
)

#: Ekstensi yang dipindai saat mencari sumber produksi. Sama dengan daftar
#: `_EXT_SUMBER`, ditambah `.sh` karena naskah gerbang repo ini memang
#: dimutasi oleh harness (dan itu sah — lihat `nonsumber` di `main`).
_EXT_PINDAI = _EXT_SUMBER + (".sh",)

#: Direktori yang dipindai untuk sumber produksi. `out/` dan `.build/`
#: sengaja tidak: keduanya keluaran, bukan sumber.
_DIR_PINDAI = ("Apps", "Packages", "Tools")

#: Berkas di luar `Apps/`/`Packages/`/`Tools/` yang ikut dipindai.
_BERKAS_PINDAI = ("project.yml", "swift-ui-lint.sh", "red-lint.sh",
                  "red-test.sh")


def _sumber_produksi():
    """Seluruh berkas sumber produksi, diurutkan — dihitung, bukan didaftar.

    Kenapa ada: daftar tangan `KNOWN_TARGETS` adalah himpunan yang harus
    dipelihara setiap kali berkas baru lahir, dan setiap kali ia ketinggalan,
    jangkar tanpa sasaran menjadi "tidak ditemukan" — yang dulu berarti hijau.
    Penemuan membuat cakupan gerbang tumbuh bersama pohonnya.

    Yang TIDAK diklaim: memindai lebih banyak berkas membuat setiap jangkar
    **menemukan** sasaran yang benar. Ia hanya menghapus alasan "berkasnya
    tidak pernah dibaca". Jangkar yang benar-benar basi tetap harus
    diperbaiki, dan sekarang itu memerahkan gerbang (lihat `missing`).
    """
    hasil = []
    for base in _DIR_PINDAI:
        akar = os.path.join(ROOT, base)
        for dirpath, dirnames, filenames in os.walk(akar):
            dirnames[:] = [d for d in dirnames
                           if d not in (".build", ".git", "node_modules")]
            for nama in filenames:
                if nama.endswith(_EXT_PINDAI):
                    hasil.append(os.path.relpath(os.path.join(dirpath, nama),
                                                 ROOT))
    for rel in _BERKAS_PINDAI:
        if os.path.isfile(os.path.join(ROOT, rel)):
            hasil.append(rel)
    # Digabung dengan daftar tetap supaya berkas yang sah tetapi berada di
    # luar ketiga direktori itu (kalau nanti ada) tidak diam-diam hilang.
    return tuple(sorted(set(hasil) | set(KNOWN_TARGETS)))


if __name__ == "__main__":
    sys.exit(main())
