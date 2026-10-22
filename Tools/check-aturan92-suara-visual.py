#!/usr/bin/env python3
"""Aturan 92: setiap suara visual di PointingKit wajib diucapkan kedua app.

Kenapa aturan ini ada.

Gambar objek menyampaikan empat hal yang **tidak** bisa dibaca dari baris teks
mana pun di layar: fase Bulan, bentuk objek langit dalam, warna spektral
bintang, dan kelas spektralnya. Untuk pembaca layar, satu-satunya jalan
informasi itu sampai adalah aksesor `spoken*` di `PointingKit`
(`spokenPhase`, `spokenDeepSkyMorphology`, `spokenStarColor`,
`spokenStarClassLine`), yang dipanggil dari pembangun label aksesibilitas.

Sampai siklus ini, sambungan itu dijaga **tidak ada apa pun**. Diukur dengan
mutasi pada pohon yang seharusnya hijau: keempat cabang dihapus dari
`kindAccessibilityLabel` di `PointingView.swift`, lalu `./swift-ui-lint.sh`
dijalankan — **91 aturan hijau, exit 0**. Hal yang sama berlaku untuk
`visualPanelLabel` di `DiagnosticsView.swift`. Artinya di perangkat pembaca
layar mendengar "Bulan, magnitudo −10,4" tanpa "sabit muda": gambar
menunjukkan bentuknya, suara tidak, dan tidak satu pun gerbang berbunyi. Itu
kelas cacat yang berulang di repo ini — kode benar di paket, tidak tersambung
di app — dan paling sulit dilihat justru karena tampilannya sempurna.

Kenapa yang diukur adalah **daftar aksesor**, bukan empat nama.

Menuliskan empat nama di sini akan membuat aturan ini berhenti mengukur tepat
saat katalog visual bertambah — yaitu persis saat ia paling dibutuhkan.
Aksesor kelima akan lolos tanpa suara sementara aturannya tetap hijau dan
tampak bekerja. Karena itu daftarnya **dipanen dari `PointingKit`**: setiap
`func spoken*` instance di dalam `public extension CelestialVisual` ikut
diukur, sehingga menambah satu berarti menambah satu tuntutan pada kedua app.

Pembantu `static` sengaja **tidak** ikut. `static func spokenStarClass(...)`
di berkas yang sama dipanggil `spokenStarClassLine` untuk menyusun kalimatnya;
ia tidak punya `self`, jadi ia tidak bisa tahu objek mana yang sedang
digambar. Menuntutnya dipanggil dari app akan berbunyi untuk kode yang benar,
dan aturan yang berbunyi untuk hal benar akan dimatikan orang.

Yang diperiksa:

1. Setiap aksesor suara visual dipanggil di `Apps/PointAndKnowWatch/Sources`
   **dan** di `Apps/PointAndKnowiOS/Sources`. Satu app yang tertinggal berarti
   cacat yang sama hanya muncul di satu perangkat, dan tidak ada yang akan
   mencarinya di sana.

2. Pemanggilan itu harus benar-benar **sampai** ke `.accessibilityLabel`.
   Bukan sekadar "berkasnya memuat `.accessibilityLabel`" — berkas view mana
   pun memuatnya, jadi syarat itu lolos walau hasilnya dibuang. Yang diukur
   rantainya: deklarasi yang memuat pemanggilan menyebut deklarasi lain, dan
   begitu seterusnya, sampai ada deklarasi yang muncul di dalam argumen
   `.accessibilityLabel(...)`. Bentuk ini ditemukan justru karena versi
   pertama checker ini **hijau** saat satu label dibuang dari berkas yang
   masih punya delapan label lain.

3. Nol aksesor = GAGAL, bukan lolos. Ekstensi yang hilang atau berganti nama
   lebih mungkin berarti aturan ini berhenti mengukur daripada `PointingKit`
   berhenti punya suara visual.

Batasnya jujur: ini sapuan **teks**, bukan pemeriksaan tipe atau render. Ia
tidak bisa membuktikan kalimat yang disusun benar, dan tidak bisa membuktikan
`isConfirmed` diteruskan dengan nilai yang tepat — itu diukur tes `PointingKit`
di Linux (`MoonPhaseSpeechTests`, `StarColorSpeechTests`, dan sejenisnya). Ia
membuktikan **sambungannya ada di kedua app dan sampai ke pembaca layar**,
bagian yang tadinya tidak diukur siapa pun.

Jalankan dari akar repo. Exit 0 = bersih, 1 = ada yang putus.
"""
import pathlib
import re
import sys

PAKET = pathlib.Path("Packages/PointingKit/Sources/PointingKit")
APPS = pathlib.Path("Apps")

APP_WAJIB = (
    ("app jam", pathlib.Path("Apps/PointAndKnowWatch/Sources")),
    ("app iPhone", pathlib.Path("Apps/PointAndKnowiOS/Sources")),
)

EKSTENSI_VISUAL = re.compile(r"public\s+extension\s+CelestialVisual\s*\{", re.M)
# `^` + indentasi: hanya deklarasi, bukan pemanggilan `visual?.spokenPhase(`.
AKSESOR = re.compile(
    r"^[ \t]*(?:(?:public|internal)\s+)?func\s+(spoken[A-Za-z0-9_]*)\s*\(", re.M)
STATIC_FUNC = re.compile(r"\bstatic\s+func\s")

# Deklarasi berbadan kurawal: `var x: T { ... }`, `func x(...) { ... }`.
# Tanda tangan **boleh memanjang ke baris berikutnya** (`visualPanelLabel`
# di app iPhone punya tujuh parameter, satu per baris). Tanpa `[^{}]*` yang
# menyeberangi baris, deklarasi itu tidak masuk peta, rantainya putus di
# langkah pertama, dan gerbang melaporkan kode yang benar sebagai tidak
# tersambung — persis bug yang ditemukan saat aturan ini pertama dijalankan.
DEKLARASI = re.compile(
    r"^[ \t]*(?:(?:private|public|internal|fileprivate|static)\s+)*"
    r"(?:var|func)\s+(\w+)[^{}]*\{", re.M)

KEDALAMAN_RANTAI = 4


def buang_komentar(isi):
    """Buang komentar supaya docstring yang menyebut nama aksesor tidak dihitung."""
    isi = re.sub(r"/\*.*?\*/", "", isi, flags=re.S)
    return re.sub(r"//[^\n]*", "", isi)


def blok_kurawal(isi, brace_buka):
    """Teks dari `{` di `brace_buka` sampai pasangannya, inklusif."""
    depth, i = 0, brace_buka
    while i < len(isi):
        if isi[i] == "{":
            depth += 1
        elif isi[i] == "}":
            depth -= 1
            if depth == 0:
                return isi[brace_buka:i + 1]
        i += 1
    return isi[brace_buka:]


def panen_aksesor():
    """Aksesor suara visual instance dari paket -> himpunan berkas asalnya."""
    hasil = {}
    for path in sorted(PAKET.glob("*.swift")):
        isi = buang_komentar(path.read_text(encoding="utf-8"))
        for m in EKSTENSI_VISUAL.finditer(isi):
            badan = blok_kurawal(isi, isi.index("{", m.start()))
            for dm in AKSESOR.finditer(badan):
                # Lewati pembantu `static`: lihat docstring.
                baris_awal = badan.rfind("\n", 0, dm.start()) + 1
                if STATIC_FUNC.search(badan[baris_awal:dm.end()]):
                    continue
                hasil.setdefault(dm.group(1), set()).add(path.name)
    return hasil


def peta_deklarasi(isi):
    """Nama deklarasi -> daftar badannya (satu nama bisa muncul berkali-kali)."""
    peta = {}
    for m in DEKLARASI.finditer(isi):
        nama = m.group(1)
        peta.setdefault(nama, []).append(blok_kurawal(isi, isi.index("{", m.start())))
    return peta


def argumen_label(isi):
    """Teks argumen setiap `.accessibilityLabel(...)`."""
    hasil = []
    for m in re.finditer(r"\.accessibilityLabel\s*\(", isi):
        depth, i = 1, m.end()
        while i < len(isi):
            if isi[i] == "(":
                depth += 1
            elif isi[i] == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        hasil.append(isi[m.end():i])
    return hasil


def menyebut(teks, nama):
    return re.search(r"\b" + re.escape(nama) + r"\b", teks) is not None


def sampai_ke_label(isi, nama_aksesor):
    """Apakah pemanggilan `nama_aksesor` di berkas ini sampai ke `.accessibilityLabel`?"""
    peta = peta_deklarasi(isi)

    # Deklarasi yang muncul di dalam argumen `.accessibilityLabel(...)`.
    akar = set()
    for arg in argumen_label(isi):
        for nama in peta:
            if menyebut(arg, nama):
                akar.add(nama)
    if not akar:
        return False

    # Deklarasi yang memuat pemanggilan aksesor.
    pola = re.compile(r"\b" + re.escape(nama_aksesor) + r"\s*\(")
    awal = []
    for nama, daftar in peta.items():
        for badan in daftar:
            if pola.search(badan):
                awal.append(nama)
    if not awal:
        return False

    # Arah rantai: dari deklarasi ke **pemanggilnya**, bukan ke yang dipanggil.
    # `kindAccessibilityLabel` menyusun potongan kalimatnya sendiri, dan
    # `detailAccessibilityLabel` yang menyebutnya lalu menyerahkannya ke
    # `.accessibilityLabel(...)`. Menelusuri arah sebaliknya akan berhenti di
    # deklarasi pertama dan melaporkan kode yang benar sebagai putus.
    pemanggil = {}
    for nama, daftar in peta.items():
        for badan in daftar:
            for lain in peta:
                if lain != nama and menyebut(badan, lain):
                    pemanggil.setdefault(lain, set()).add(nama)

    def mencapai(nama, sisa, dilihat):
        if nama in akar:
            return True
        if sisa == 0 or nama in dilihat:
            return False
        dilihat.add(nama)
        for naik in pemanggil.get(nama, ()):
            if mencapai(naik, sisa - 1, dilihat):
                return True
        return False

    return any(mencapai(n, KEDALAMAN_RANTAI, set()) for n in awal)


def main():
    if not PAKET.is_dir():
        print(f"GAGAL {PAKET} tidak ada: Aturan 92 tidak mengukur apa pun,")
        print("      dan suara visual bisa lepas dari kedua app tanpa galat.")
        return 1
    if not APPS.is_dir():
        print(f"GAGAL {APPS} tidak ada: Aturan 92 tidak mengukur apa pun.")
        return 1

    aksesor = panen_aksesor()
    if not aksesor:
        print("GAGAL tidak ada aksesor `spoken*` di `public extension CelestialVisual`:")
        print("      Aturan 92 tidak mengukur apa pun (ekstensinya hilang atau")
        print("      berganti nama?). Gambar objek menyampaikan fase, bentuk, warna,")
        print("      dan kelas spektral — untuk pembaca layar hanya lewat aksesor itu.")
        return 1

    masalah = []

    for perangkat, direktori in APP_WAJIB:
        if not direktori.is_dir():
            masalah.append(
                f"{direktori} tidak ada: suara visual tidak diukur di {perangkat}.")
            continue

        berkas = sorted(direktori.rglob("*.swift"))
        isi_berkas = {p: buang_komentar(p.read_text(encoding="utf-8")) for p in berkas}

        for nama, asal in sorted(aksesor.items()):
            pola = re.compile(r"\b" + re.escape(nama) + r"\s*\(")
            pemanggil = [p for p, isi in isi_berkas.items() if pola.search(isi)]

            if not pemanggil:
                masalah.append(
                    f"{nama}() (dari {', '.join(sorted(asal))}) tidak dipanggil di "
                    f"{perangkat} ({direktori}): informasi yang hanya terlihat di "
                    f"gambar tidak sampai ke pembaca layar di perangkat itu.")
                continue

            if not any(sampai_ke_label(isi_berkas[p], nama) for p in pemanggil):
                masalah.append(
                    f"{nama}() dipanggil di {perangkat} tetapi hasilnya tidak "
                    f"pernah mencapai `.accessibilityLabel` "
                    f"({', '.join(str(p) for p in pemanggil)}): disuarakan ke "
                    f"tidak ada, dan tidak ada gerbang lain yang bisa melihatnya.")

    if masalah:
        for m in masalah:
            print(f"  - {m}")
        return 1

    print(f"Aturan 92: {len(aksesor)} suara visual diucapkan kedua app "
          f"({', '.join(sorted(aksesor))}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
