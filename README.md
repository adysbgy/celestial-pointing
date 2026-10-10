# CELESTIAL POINTING ENGINE

Arahkan jam ke langit, ketahui apa yang kamu lihat.

Aplikasi watchOS + iOS yang mengubah arah pergelangan menjadi **identitas
objek langit**, lalu mengantarkan objek itu ke teleskop lewat alur
`POINT → IDENTIFIKASI → GOTO AMAN`.

---

## Isi

- [Ide inti](#ide-inti)
- [Arsitektur](#arsitektur)
- [Menjalankan di Mac](#menjalankan-di-mac)
- [Mode malam, Always-On, & aksesibilitas](#mode-malam-always-on--aksesibilitas)
- [Complication & lokalisasi](#complication--lokalisasi)
- [Menjalankan uji di Linux](#menjalankan-uji-di-linux)
- [Experiment 1](#experiment-1)
- [Aturan yang tidak bisa ditawar](#aturan-yang-tidak-bisa-ditawar)

---

## Ide inti

Sebagian besar aplikasi astronomi bekerja dengan kamera atau GPS lalu
menampilkan peta. Yang ini bekerja dari **arah tunjuk** — dan justru karena
itu, satu keputusan desain mendasari seluruhnya:

> **Akurasi jam tangan adalah hipotesis, bukan fakta.**

Jam tidak tahu ke mana ia mengarah seakurat kompas tahu utara. Jadi engine
**tidak pernah** mengubah arah pergelangan menjadi perintah motor teleskop.
Yang terjadi selalu tiga langkah:

```
arah tunjuk  →  identifikasi objek  →  GOTO yang sudah diuji aman
   (POINT)        (OBJECT ID)              (SAFE GOTO)
```

Dan setiap kali keyakinannya rendah, aplikasi **mengatakan bahwa ia ragu**.
Visual objek yang meyakinkan untuk tebakan yang ragu adalah kebohongan
yang paling mudah dipercaya — jadi saat engine ragu, yang tampil adalah
kandidat samar bertanda tanya, bukan gambar pasti.

> **Uncertainty > false confidence.** Engine yang jujur ragu masih berguna;
> engine yang yakin tapi salah merusak kepercayaan.

---

## Arsitektur

Dua paket SwiftPM, dua app. Logika **tidak** hidup di app — app hanya
memegang UI dan pembungkus sensor.

```
┌─────────────────────────────────────────────────────┐
│  Apps/                                              │
│    PointAndKnowWatch   app jam (pointing+kalibrasi)  │
│    PointAndKnowiOS     app iPhone (diagnostik, Exp 1)│
│    Shared/             visual, tema, malam, onboarding│
├─────────────────────────────────────────────────────┤
│  Packages/PointingKit      logika lapisan app         │
│    kalibrasi, alur, perekam Experiment 1,            │
│    pesan Watch↔iPhone, label tampilan & ucapan       │
├─────────────────────────────────────────────────────┤
│  Packages/CelestialEngine  mesin inti                │
│    katalog, efemeris, resolver, keyakinan,           │
│    pengaman slew, jembatan teleskop                  │
└─────────────────────────────────────────────────────┘
```

Pemisahannya bukan soal kerapian. Seluruh `Packages/` terbangun dan teruji
di **Linux** — termasuk komputer tanpa Xcode. Hanya pembungkus app yang
bergantung pada Mac. Konsekuensinya:

- logika yang bisa diuji **wajib** diuji di sana;
- teks yang diucapkan VoiceOver (`RowSpeech`, `CalibrationSpeech`) ikut pindah
  ke paket, karena kalimat terucap adalah janji produk yang **tidak pernah
  terlihat salah di layar mana pun** — satu-satunya cara menangkapnya
  adalah uji.

`project.yml` adalah sumber kebenaran untuk proyek Xcode; `.xcodeproj`
**tidak** di-commit karena tidak bisa ditinjau di pull request.

---

## Mode malam, Always-On, & aksesibilitas

Fitur ini bukan hiasan — masing-masing mematuhi aturan "akurasi adalah
hipotesis" dan "ragu lebih baik daripada yakin yang salah".

- **Mode malam (merah).** Toggle satu ketuk (ikon bulan) menyimpan
  `@AppStorage`. Seluruh palet dipaksa ke merah murni (>620 nm) supaya
  rhodopsin tidak rusak — **termasuk** warna prosedural pada gambar objek.
  Satu penjaga (`NightVisual`) mengubah setiap warna gambar dari kanal
  merahnya, dan diuji di Linux (aturan 15 gerbang UI): versi lama menulis
  angka malam sendiri per warna, dan 10 dari 13 di antaranya bukan merah
  murni, jadi "merah" itu hanya terlihat merah, bukan benar-benar aman.
- **Always-On Display.** Saat `isLuminanceReduced` menyala, app menukar
  tampilan dengan `ReducedLuminanceView` — hanya nama objek + status, kontras
  tinggi, dan **seluruh animasi dihentikan** (hemat baterai + tak ada denyut
  di layar redup).
- **VoiceOver.** Status, panel detail, tombol kalibrasi, dan "Catat" punya
  `accessibilityLabel`. Yang diucapkan hanya info yang **hanya bisa dilihat**:
  fase Bulan, bentuk objek langit dalam (galaksi/gugus/nebula), dan warna
  spektral bintang dari indeks B−V. Planet **tidak** dideskripsikan gambarnya
  karena namanya sudah mengidentifikasi; pernyataan bentuk ikut **dibungkam
  saat engine ragu** (`isConfirmed == false`) supaya suara tak lebih yakin
  daripada gambarnya. Kalimat terucap hidup di `PointingKit`, bukan di view,
  supaya bisa diuji (aturan 4 & 16).
- **Reduced Motion.** Preferensi pengguna (`accessibilityReduceMotion`) dan
  layar redup mematikan animasi lewat satu keputusan bersama (`MotionPolicy`,
  teruji di Linux) — jam dan iPhone tidak bisa berbeda pendapat (aturan 7).

---

## Complication & lokalisasi

- **Complication watchOS.** `PointAndKnow Watch Complication` (WidgetKit,
  terbenam di dalam app jam) menampilkan ringkasan objek terkunci terakhir
  (`ComplicationDigest.headline`) tanpa membuka app. Empat keluarga didukung —
  lingkaran, persegi panjang, inline, dan **sudut** — dan setiap cabangnya
  merender ikon keadaan bersama nama objek (Aturan 23), supaya nama kandidat
  `.uncertain` tidak pernah terbaca sama dengan nama yang sudah terkunci.
  Katedral diuji: `ComplicationDigestStalenessTests` memastikan ringkasan objek
  basi tidak terdengar seperti hasil sekarang, dan `ComplicationStaleSymbolTests`
  menjaga simbol lamanya.
- **Lokalisasi.** Teks UI ada di `Localizable.xcstrings` (Bahasa Indonesia +
  Inggris). `SWIFT_EMIT_LOC_STRINGS` **sengaja dimatikan** karena katalog
  ditulis tangan dan di-commit — flag itu hanya untuk ekstraksi otomatis, dan
  menyalakannya akan menduplikasi kunci yang sudah ada. Aturan 4 & 11 gerbang
  UI menjaga setiap teks UI punya padanan bahasa Inggris, dan specifier
  katalog cocok dengan template kode.
- **Izin sensor.** `NSMotionUsageDescription` dan
  `NSLocationWhenInUseUsageDescription` di `Info.plist` menjelaskan **kenapa**
  (Bahasa Indonesia, lewat `InfoPlist.strings`) — penolakan izin ditangani
  dengan pesan yang jelas, bukan crash atau senyap (aturan 14).

---

## Menjalankan di Mac

Butuh Xcode 16+ (diuji di macOS 15) dan XcodeGen.

```bash
brew install xcodegen
xcodegen generate      # menghasilkan PointAndKnow.xcodeproj
open PointAndKnow.xcodeproj
```

Lalu pilih skema:

| Skema | Untuk apa |
|---|---|
| `PointAndKnow` | app iPhone — 3 tab: Diagnostik, Experiment 1, Tautan |
| `PointAndKnow Watch` | app jam — pointing + kalibrasi |

Menjalankan app jam butuh perangkat atau simulator watchOS yang berpasangan
dengan simulator iPhone.

Kenapa bukan `.xcodeproj` yang di-commit: konflik pada berkas itu hampir
selalu diselesaikan dengan menimpa milik orang lain, dan proyek ini
sepenuhnya bisa dibangun ulang dari teks.

---

## Menjalankan uji di Linux

Tidak punya Mac, atau mau cepat? Semua logika teruji di Linux.

```bash
./swift-test.sh        # PointingKit via Docker Swift 6.0
./swift-typecheck.sh   # parse seluruh berkas Apps/ (sintaks saja)
./swift-ui-lint.sh     # aturan UI yang tidak bisa ditegakkan compiler
```

Hitungan uji saat ini: **CelestialEngine 222**, **PointingKit 846**.

Tiga gerbang itu menutup tiga celah yang berbeda, dan sengaja terpisah:

| Gerbang | Yang ia tangkap |
|---|---|
| `swift-test.sh` | logika di `Packages/` — tempat sebagian besar cacat berada |
| `swift-typecheck.sh` | kesalahan sintaks di `Apps/`, yang tidak ikut terbangun di Linux |
| `swift-ui-lint.sh` | aturan UI yang tidak terlihat oleh compiler *maupun* oleh mata |

`swift-ui-lint.sh` lahir dari satu alasan spesifik: **ukuran font tetap
(`.system(size:)`) mengabaikan Dynamic Type**, dan tidak ada compiler yang
memperingatkannya. Aturan itu pernah ditegakkan sekali, lalu muncul lagi
di berkas yang ditambahkan belakangan — karena tidak ada yang menegakkannya
setelahnya. Gerbang adalah satu-satunya yang mengingat.

Sejak itu berkasnya tumbuh jadi **29 aturan**, dan semuanya bentuk yang sama:
hal yang benar di sumbernya tapi salah di layar, yang tidak terlihat oleh
compiler maupun mata. Yang paling sering menyelamatkan: paritas kunci
katalog string (aturan 6), penjaga reduce-motion pada setiap API gerak
(aturan 7), hitungan uji di README yang tidak boleh membusuk (aturan 10),
permukaan kartu yang harus datang dari token yang kontrasnya dihitung
(aturan 20), denyut gambar yang harus digerbangi `hasPulse` supaya
`Canvas` planet tidak digambar ulang 20×/detik untuk piksel yang sama
(aturan 21), setiap cabang complication yang wajib merender ikon
keadaan bersama nama objeknya, supaya kandidat yang belum pasti tidak
terbaca sebagai identitas yang terkunci (aturan 23), indeks warna
bintang yang hanya boleh sampai ke gambar lewat `drawableStarColorIndex`
supaya warna tidak diklaim saat engine ragu (aturan 24), setiap
`TipePaket.anggota` di `Apps/` yang harus benar-benar ada di paket (aturan
26), dan **label argumen** `TipePaket(Label:)` yang harus sama dengan
deklarasinya (aturan 27).

Dua aturan terakhir lahir dari kelas cacat yang sama: pemakaian API paket
dari view hanya ketahuan saat `Apps/` benar-benar dikompilasi terhadap
paket, dan di Linux hanya `swift-typecheck.sh` yang bisa melakukannya —
untuk **dua** berkas Foundation. Aturan 26 menutup jalur keanggotaan,
aturan 27 menutup jalur pemanggilan.

### Uji harus pernah merah

Uji yang langsung hijau belum membuktikan apa-apa selain bahwa kode saat ini
cocok dengan ekspektasi penulisnya. Repo ini punya alat untuk membuktikan
sebaliknya:

```bash
./red-test.sh <berkas-uji> <nama-test> <berkas-sumber> <lama> <baru>
```

Ia menyuntikkan cacat ke sumber, menjalankan uji, dan **gagal bila uji tetap
hijau** — karena uji yang tidak bisa merah tidak menangkap apa pun.

> **Batasnya, apa adanya:** skrip ini menjalankan uji di dalam
> `Packages/PointingKit`. Untuk membuktikan uji di `CelestialEngine` merah,
> jalankan `swift test --package-path Packages/CelestialEngine --filter …`
> secara manual setelah menyuntikkan mutasinya sendiri.

---

## Experiment 1

Bagaimana kita tahu akurasi jam itu hipotesis, bukan keyakinan? Dengan
mengukurnya.

Experiment 1 adalah alat ukurnya, dan sengaja dirancang supaya **tidak bisa
menyembunyikan hasil buruk**:

1. Pilih **target yang diketahui** dari daftar (efemeris memberi arah
   sebenarnya saat itu juga).
2. Arahkan jam ke target itu, lalu tekan rekam.
3. Yang direkam bukan hanya tebakan engine, tapi **galat sudut** antara arah
   tunjuk dan arah sebenarnya — plus keadaan dan laju pergelangan saat itu.
4. Verdict dihitung: benar / salah, dan yang terpenting **FALSE LOCK** —
   engine yakin tinggi *tetapi salah*.

**FALSE LOCK adalah mode kegagalan yang dicari.** Itu satu-satunya hasil
yang benar-benar berbahaya: engine yang ragu membuat pengguna berhati-hati,
sedangkan engine yang yakin dan salah membuat pengguna berhenti memeriksa.
Targetnya nol, dan layar tidak akan menyembunyikannya kalau tidak nol.

Hasil bisa diekspor sebagai JSON untuk dianalisis lebih lanjut.

Cara menjalankan: buka app iPhone → tab **Experiment 1** → ikuti urutan di
atas. Kebenaran (ground truth) mengikuti lokasi yang sedang dipakai engine,
jadi tunggu lokasi sungguhan tiba sebelum mulai merekam.

---

## Aturan yang tidak bisa ditawar

Aturan ini bukan preferensi gaya; masing-masing pernah dilanggar dan
menimbulkan cacat nyata.

1. **Akurasi jam adalah hipotesis.** Jangan pernah mengubah arah pergelangan
   menjadi perintah motor. Selalu `POINT → OBJECT ID → SAFE GOTO`.
2. **Ragu lebih baik daripada yakin yang salah.** Jangan tampilkan visual
   yang mengklaim identitas saat engine ragu — tampilkan kandidat samar.
3. **Jangan tampilkan pengenal mesin ke pengguna.** `sirius` di layar bukan
   bug yang terlihat dari satu berkas; ia benar di sumbernya dan salah di
   layar. Label tampilan punya satu sumber.
4. **Kalimat yang diucapkan harus teruji.** VoiceOver membaca satuan
   tertulis sebagai deretan karakter. Bentuk terucap hidup di `PointingKit`
   supaya bisa diuji, bukan dirangkai di view.
5. **Ukuran font tetap dilarang.** Pakai `.body`, `.headline`, `.title2`
   atau `@ScaledMetric`. `swift-ui-lint.sh` yang menegakkan.
6. **Teks UI Bahasa Indonesia.**

---

## Lisensi

Proyek pendidikan — Apple Developer Academy Final Challenge.

Data dan pustaka pihak ketiga yang ikut didistribusikan dicatat di
[`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md). Yang paling perlu
diketahui: `Catalogue.swift` memuat koordinat dari HYG Database, dan
data itu berlisensi **CC BY-SA 4.0** — copyleft. Berkas itu adalah karya
turunan, jadi ia tunduk pada CC BY-SA 4.0 terpisah dari sisa kode di
repo ini.

Lisensi untuk kode proyek ini sendiri **belum ditetapkan** (belum ada
berkas `LICENSE`). Selama belum ada, default hukumnya adalah hak cipta
penuh — orang lain tidak otomatis boleh memakai ulang kode ini.
