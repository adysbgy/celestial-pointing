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
  Kedaluwarsa diuji: `ComplicationDigestStalenessTests` memastikan ringkasan
  objek basi tidak terdengar seperti hasil sekarang, dan
  `ComplicationStaleSymbolTests`
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

Hitungan uji saat ini: **CelestialEngine 222**, **PointingKit 1101**.

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

Sejak itu berkasnya tumbuh jadi **101 aturan**, dan semuanya bentuk yang sama:
hal yang benar di sumbernya tapi salah di layar, yang tidak terlihat oleh
compiler maupun mata. Nomornya sampai 102 karena **Aturan 69 tidak tinggal di
berkas ini**: ia menjaga berkas sasaran mutasi (`Tools/check-jangkar-harness.py`)
dan hidup di `Tools/`. Menghitung nomor tertinggi sebagai jumlah aturan akan
melebihkan satu; yang dihitung di sini adalah blok yang benar-benar berjalan.
Yang paling sering menyelamatkan: paritas kunci
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

Aturan 30 lahir dari arah yang **tidak** dijaga aturan 14. Aturan 14
menuntut setiap `INFOPLIST_KEY_NS*UsageDescription` di `project.yml` punya
terjemahan per bahasa — tetapi himpunan kuncinya dibaca dari `project.yml`
sendiri, jadi kunci yang dideklarasikan engine dan **tidak pernah ditulis
ke sana** tidak pernah masuk perbandingan. Persis itu yang terjadi pada
`NSLocalNetworkUsageDescription`: dideklarasikan dan diuji di
`CelestialEngine`, absen dari `project.yml` maupun kedua
`InfoPlist.strings`, dan seluruh aturan yang ada saat itu hijau sementara
aplikasi diam-diam tidak akan pernah menemukan teleskop. Aturan 30 membaca
deklarasi kuncinya dari `Packages/`, jadi kunci baru yang ditambah engine
merah sampai ia benar-benar sampai ke proyek.

Aturan 31 menutup kelas yang berlawanan dari kebanyakan aturan di sini:
bukan kunci yang hilang dari proyek, tapi **kawat yang hidup di `Apps/`**.
`visualForDisplayedObject` adalah satu-satunya jalur yang menghubungkan arah
fase ke gambar objek, dan karena ia berada di `Apps/` ia tidak terjangkau
`swift-test.sh` (Linux hanya membangun `Packages/`) — jadi sebelum aturan
ini, satu-satunya penjaganya adalah komentar. Kawat itu pernah berbunyi
`isMoon ? moonIsWaxing : nil`, yang mematikan seluruh fase planet dalam:
Venus tampil sebagai bola penuh persis saat engine baru saja menghitung
iluminasinya 2 persen. Perbaikannya mendarat di sumber tanpa satu uji pun
yang menangkapnya, karena uji menguji **rumus**-nya, bukan **pengawat**-nya.

Aturan 33 menutup kelas yang sama pada lapisan yang berbeda: bukan kawat
antara dua medan, melainkan **pengambilan bobot dari sebuah putusan**.
`SlewVerdictBanner` menggambar dua kelas bahaya — keselamatan (cahaya
Matahari ke lensa) dan mutu (terlalu redup) — dan pembedaannya hanya hidup
kalau ikon diambil dari `decision.verdictSymbolName` dan warna dari
`decision.verdictTone`. Versi pertamanya menulis keduanya langsung di view,
dan `SlewVerdict.verdictTone` menyebut versi itu sebagai cacatnya. Diukur
sebelum aturan ini ada: kedua baris dikembalikan ke bentuk tetap itu, lalu
**seluruh aturan UI saat itu lulus, typecheck lulus, dan 755 uji hijau** —
jadi memundurkan pemisahan bobot ke bentuk yang salah tidak menghasilkan
satu pun kegagalan.
`SlewVerdictTests` menguji **nilai** kedua aksesor itu, tetapi tidak ada uji
yang menuntut **view membacanya**; rumus yang benar dan tidak pernah dipakai
tetap hijau selamanya. Karena itu aturan ini membaca **tiga** hal sekaligus:
ikon datang dari putusannya, nada datang dari putusannya, dan nada itu
benar-benar dipakai menggambar — tanpa yang ketiga, cacatnya bisa
"diperbaiki" dengan menghitung nada lalu tetap menggambar warna tetap.

Aturan 34 menutupnya sekali lagi, kali ini pada **argumen keyakinan**.
`PointingKit` punya enam aksesor yang sengaja menerima `isConfirmed:` supaya
bisa menolak mengklaim identitas saat engine ragu — warna bintang
(`drawableStarColorIndex`), bentuk kabut (`drawableMorphology`), palet planet
(`Palette.drawable`), dan ketiga jalur suaranya (`spokenStarColor`,
`spokenPhase`, `spokenDeepSkyMorphology`). Rumusnya benar dan masing-masing
punya uji Swift. Yang tidak diperiksa siapa pun adalah **nilai yang dikirim
dari `Apps/`**: `swift-test.sh` hanya membangun `Packages/`, dan
`check-visuals.py` merender **port Python**-nya, bukan view Swift-nya. Jadi
berkas yang bisa salah justru berkas yang tidak dilihat kedua gerbang itu.
Diukur sebelum aturan ini ada: `isConfirmed: isConfirmed` di
`CelestialVisualView.swift` diganti `isConfirmed: true` — satu kata, di kawat
yang memutuskan apakah bentuk objek langit dalam boleh diklaim — dan
**lint lulus, typecheck lulus, 755 uji hijau**. Memaksa klaim identitas tidak
menghasilkan satu pun kegagalan, walaupun PRD menyebut larangan itu sebagai
aturan paling keras. Aturan 34 membaca daftar aksesornya **dari model**, bukan
dari salinan di dalam skrip, lalu menuntut setiap pemanggilan di `Apps/`
mengirim sesuatu selain literal `true`/`false` — sambil **sengaja tetap hijau**
pada literal yang sah (`OnboardingView`, `#Preview`), karena gerbang yang
memerah pada kode yang benar akan dilonggarkan orang, dan gerbang yang
dilonggarkan tidak menjaga apa pun.

Satu lapis lebih dalam, dan itu ditemukan dengan bertanya "argumen apa lagi
yang ada hanya supaya engine boleh menolak menjawab": `phaseGeometry(waxing:)`
menerima **`Bool?`**, bukan `Bool`. Modelnya menyebut alasannya sendiri —
"`nil` menghasilkan `nil`: tanpa arah, gambar apa pun yang digambar akan
memihak ke satu sisi, dan itu pernyataan yang tidak dihitung engine". Diukur:
kedua situs `waxing: visual.isWaxing` di `CelestialVisualView.swift` diganti
`waxing: true`, lalu **lint lulus dan typecheck lulus**. Sabit yang menghadap
ke arah salah menyatakan "ini bulan sabit awal" saat engine hanya tahu "ada
sabit" — dan brief memang menyebut "sabit harus benar arahnya". Gerbang yang
hanya mencari `isConfirmed:` akan melewatkannya sepenuhnya, jadi bagian kedua
Aturan 34 mengukur argumen `waxing:` secara terpisah, di **kedua** situs.

Aturan 35 menutup kelas yang sama sekali berbeda, walaupun bentuknya mirip:
**satu berkas yang bertentangan dengan dirinya sendiri.** `PointingView`
menampilkan status tautan ke iPhone di dua kanal yang membaca satu fakta yang
sama — ikon (`link.isReachable ? "iphone.gen3.radiowaves…" : "iphone.slash"`)
dan suara (`LinkStatusText.linkSpeech(isReachable:)`). Diukur: argumen suara
diganti `link.isReachable` → `true`, satu kata di satu tempat, lalu **lint
lulus, typecheck lulus, 755 uji hijau**. Artinya ikon bisa berkata "iPhone
tidak terjangkau" sementara VoiceOver membacakan "iPhone terhubung", dan tidak
ada satu pun gerbang yang berbunyi. Aturan 34 tidak menangkapnya karena
daftar aksesornya dibaca dari deklarasi ber-`isConfirmed:` — dan `linkSpeech`
menerima `isReachable`.

Karena itu Aturan 35 tidak memakai daftar nama, melainkan prinsipnya: berkas
yang **membaca** `.p` dari sebuah penerima tidak boleh mengirim literal
`true`/`false` untuk parameter `p` di berkas itu. Aksesornya dicari dari model
(setiap `func` PointingKit ber-parameter `Bool` — 16 buah saat ini), bukan
disalin. Batasnya sengaja sempit: `setSensorAvailable(false)` di `MotionLogger`
adalah **perintah** ("hentikan sensor"), bukan klaim, dan berkas itu tidak
membaca `.available` sama sekali — jadi ia tetap hijau. Yang dilarang adalah
fakta yang sudah dibaca lalu diganti tetapan di kanal lain, karena di situlah
layar dan suara bisa berbeda.

Aturan 37 menutup kelas yang **tidak bisa** ditangkap gerbang cepat mana pun,
dan itu sudah dibuktikan dengan cara yang paling langsung: cacatnya mendarat
di `main`. Penambahan `.paleDisk` dan `.blueDisk` ke `enum
DistinguishingFeature` memperbarui **satu** dari dua `switch` atas
`palette.feature` di `CelestialVisualView.swift`; yang terlewat ada di jalur
sabit. Pada commit itu seluruh gerbang Linux hijau — 216 + 799 uji, seluruh
aturan UI saat itu, `swift-typecheck.sh` — dan yang merah hanya Apple Build
(macos-15): `error: switch must be exhaustive`.

Kenapa Linux memang tidak bisa melihatnya: runner Linux hanya membangun
`Packages/`, tidak pernah `Apps/`, dan kelengkapan `switch` adalah pemeriksaan
**semantik** yang butuh seluruh tipe diketahui — `swiftc -parse` tidak
melakukannya. Jadi satu-satunya gerbang yang mampu adalah yang paling lambat.
Karena itu Aturan 37 **menurunkan** himpunan kasus dari enum di
`Packages/PointingKit/Sources/`, lalu menuntut setiap `switch` di `Apps/` yang
tidak punya `default:` memuat seluruh himpunan itu — bukan mencocokkan daftar
nama (`paleDisk`, `blueDisk`), yang akan hijau lagi begitu kasus berikutnya
ditambahkan.

Batasnya diakui dan diukur: ini sapu teks, bukan pemeriksa tipe. Ia hanya
berbunyi bila setiap klausa `case`-nya murni daftar `.anggota` (tanpa `let`,
`where`, atau literal), tidak ada `default:`, dan labelnya subset dari
**tepat satu** enum. Syarat terakhir itu lahir dari pengukuran, bukan
kehati-hatian: versi pertama tanpa syarat itu menuduh
`ReducedLuminanceView.swift:57` — `switch ReducedLuminanceVisual.plan(...)`
yang sudah benar — sebagai kehilangan `Subline`, `UncertainReason`, dan
`DistinguishingFeature`, semata karena enum-enum itu kebetulan punya superset
label yang sama. Gerbang yang menuduh kode benar akan dilonggarkan orang.
Yang TIDAK diklaim: ia tidak membuktikan `switch`-nya benar, hanya lengkap.

Aturan 38 lahir dari pengukuran yang sama dengan yang melahirkan Aturan 36,
dan menutup **kelasnya**, bukan satu namanya. `Apps/Shared/PointingEngine.swift`
punya tiga permukaan kejujuran yang lahir dari satu keputusan `PointingSnapshot`
yang teruji di Linux: `isDisplayingStaleObject`, `confirmsDisplayedIdentity`,
dan `carriesUncertaintyMarker`. Aturan 36 menambat **satu** nama di antaranya.
Terukur: menegasikan atau mengganti badan dua sisanya — termasuk menjadi
literal `true` — membiarkan seluruh aturan yang ada saat itu lulus. Akibatnya
tidak simetris
dan dua di antaranya lebih parah dari yang ditutup Aturan 36:
`isDisplayingStaleObject -> true` membuat peringatan "sisa pandangan
sebelumnya" menyala terus-menerus pada jam, dan `carriesUncertaintyMarker ->
false` membuat **nama kandidat** tampil sebagai temuan di layar redup —
persis keadaan yang menurut docstring properti itu paling berbahaya, karena di
sana nama kandidat menjadi huruf terbesar di layar.

Karena itu aturan ini **menurunkan** permukaannya dari model alih-alih
mendaftar namanya: sebuah `var <Nama>: Bool` di `Apps/` yang namanya sama
dengan anggota `Bool` di `Packages/` adalah penerusan, dan penerusan harus
menyebut anggota itu di badannya. Daftar tiga nama akan hijau lagi besok pagi
begitu permukaan keempat ditambahkan. Syarat "namanya ada di model" bukan
hiasan: `NightMode.isOn`, `AudioCue.isOn`, `MotionLogger.isAvailable`, dan
`LocationProvider.hasRealLocation` adalah preferensi dan keadaan sensor, bukan
keputusan engine — menuntut mereka menyebut anggota model berarti menuduh kode
yang benar, dan gerbang yang menuduh kode benar akan dilonggarkan orang.
`confirmsDisplayedIdentity` ikut tercakup walau namanya tidak ada di model,
karena penamaan sisi UI-nya sengaja berbeda dari `confirmsIdentity`.

Aturan 48 menutup kelas yang **saya sendiri** buat di siklus yang sama.
Angka pop saat kunci (`response: 0.42`, `dampingFraction: 0.82`, jeda `0.08`,
skala `1.04`) ditulis terpisah di jam dan iPhone; saya memindahkannya ke
`MotionPolicy.LockArrival` — lalu mengukur apakah pemindahan itu dijaga
sesuatu. Jawabannya tidak: `.spring(response: 0.90, dampingFraction: 0.30)`
dengan skala puncak `1.60` di `PointingView.swift` tetap membuat **seluruh
gerbang yang ada saat itu lulus**. Angka yang dipindah ke paket tidak menutup apa pun selama
`Apps/` masih boleh menulis angkanya sendiri; uji di Linux menahan **nilai** di
model, dan hanya gerbang yang bisa menahan bahwa view benar-benar membacanya.

Saluran kedua ditemukan dengan sapuan yang sama dan umurnya lebih panjang:
`TimelineView(.animation(minimumInterval: 1.0 / 30.0))` di tiga layar. Angka
itu bukan angka tampilan — `TimelineView` menyegarkan **seluruh** `Canvas`,
jadi setiap frame menggambar ulang planet, pita, cincin, dan kabut yang
pikselnya tidak berubah. Di jam tangan itu baterai. Mengubahnya jadi
`1.0 / 60.0` juga membuat seluruh gerbang yang ada saat itu lulus.

Karena itu Aturan 48 menyapu tiga bentuk yang **ditulis langsung**:
`minimumInterval: <angka>`, `.spring(response: <angka>)`, dan
`dampingFraction: <angka>`. Batasnya dinyatakan: angka yang lewat variabel
perantara (`let r = 0.42; .spring(response: r)`) atau dirakit fungsi helper
tidak terlihat — itu sebabnya `LockArrivalMotionTests` dan
`PulseFrameRateTests` menahan nilai di model, sementara aturan ini menahan
**dari mana** `Apps/` mengambilnya. Dua penjaga, dua kelas.

Aturan 75 menutup kelas yang sama pada ikon complication — bukan pada **ada**
ikonnya, melainkan pada **apakah ikon itu membaca waktu**. Complication berjalan
di proses terpisah dan hanya menerima cuplikan baru saat ada perubahan, jadi
ikon di pergelangan bisa jadi berjam-jam lebih tua dari cuplikan yang
digambar. Model sudah menjawabnya: `presentedSymbolName(at:)` menggeser ikon
lock/ragu yang sudah basi menjadi `clock.badge.exclamationmark`, dan ujinya
sendiri (`ComplicationStaleSymbolTests`) menandai bentuk tanpa waktu sebagai
kedaluwarsa. Yang belum dijaga satu pun gerbang adalah **pemakaiannya di view**:
Aturan 23 hanya menuntut sebuah `presentedSymbolName` muncul di cabang
complication, tanpa melihat apakah bentuk itu memanggil `at:`. Terukur sebelum
aturan ini ada — mengganti kelima `presentedSymbolName(at: Date())` menjadi
bentuk tanpa waktu membiarkan seluruh aturan yang ada saat itu lulus,
sementara centang hijau
"kunci berhasil" kini berdiri di pergelangan berjam-jam sesudah pandangan
pengguna berpindah. Ia aturan sendiri, bukan perluasan Aturan 23, karena
keduanya menjawab dua pertanyaan yang gagal karena dua sebab berbeda.

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
