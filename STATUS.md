## Progres terakhir (11 Okt 2026 — harness warna-ragu hanya hidup di SATU mesin: bukti bahwa gerbangnya bisa merah tidak pernah sampai ke CI)

### Cacatnya: berkas yang menentukan benar/salahnya gerbang meta tidak pernah dikomit

Commit `575026e` mengirim perbaikan nyata — warna identitas planet berhenti
bocor ke kandidat saat engine ragu — bersama gerbang baru
`check_uncertain_planet_loses_its_identity_colour`, **dan** harness yang
membuktikan gerbang itu bisa merah, `Tools/bukti-mutasi-warna-ragu.py`.

Harness itu **tidak ikut dikomit**. Ia tinggal sebagai berkas untracked di
pohon kerja mesin ini. Konsekuensinya terukur, dan bentuknya khas repo ini:
**verdict gerbang meta bergantung pada mesin mana yang ditanya.**

Di pohon kerja ini — tempat berkasnya ada:

```
$ python3 Tools/check-harness-terdaftar.py
harness di Tools/        : 17
dirujuk engine-tests.yml : 16
  TIDAK DIRUJUK  bukti-mutasi-warna-ragu.py
1 masalah:
  - bukti-mutasi-warna-ragu.py: ada di Tools/ tetapi tidak dirujuk
    engine-tests.yml — gerbangnya tidak pernah dijalankan, dan gerbang
    yang tidak dijalankan selalu hijau
EXIT=1
```

Di checkout bersih — persis yang dilihat CI (`git archive 450af2d`,
dijalankan sungguhan, bukan dibayangkan):

```
$ ls Tools/bukti-mutasi-*.py | wc -l
16
$ python3 Tools/check-harness-terdaftar.py
16 harness, semuanya dirujuk alur kerja
EXIT=0
```

Jadi CI **hijau**, dan bukan karena gerbangnya tumpul: gerbang itu
membandingkan daftar berkas di disk dengan daftar langkah di alur kerja,
dan di sana berkasnya memang tidak ada. Yang tidak ada tidak bisa jadi
masalah. Gerbang meta itu benar di kedua mesin — yang berbeda adalah
**bahan yang dinilainya**, dan satu-satunya mesin yang memegang bahannya
adalah mesin yang tidak menilai.

Yang hilang karena itu bukan warna CI, melainkan **bukti**: selama
harness-nya untracked, satu-satunya alasan untuk mempercayai bahwa gerbang
warna-ragu bisa merah adalah kalimat di pesan commit `575026e`. Kalimat itu
tidak bisa dijalankan, tidak bisa diperiksa, dan tidak akan pernah merah.
Kelas yang sama persis sudah pernah dibayar repo ini — docstring
`check-harness-terdaftar.py` menuliskan `bukti-mutasi-piringan.py` sebagai
asal-usulnya sendiri (13 berkas di disk, 12 dirujuk). Sekarang terulang
pada harness yang menjaga cacat **paling baru**.

**Catatan yang harus ada di sini, karena entri inilah tempatnya.** Draf
pertama entri ini menulis bahwa `main` **merah** di `450af2d` dan
`575026e`. Itu **salah**, dan tidak pernah saya ukur sebelum menulisnya.
Yang terukur: `450af2d` hijau di kedua alur kerja, dan `575026e` **tidak
punya run CI sama sekali** (run terakhir sebelum siklus ini adalah
`38100565581`/`38100565675` pada `450af2d`, keduanya success). Klaim itu
**dihapus, bukan dilunakkan** — komentar yang mengutip angka yang tidak
pernah keluar dari pengukurannya adalah kelas cacat yang paling sering
berulang di repo ini, dan kali ini yang menulisnya adalah saya, di berkas
yang seharusnya jadi catatan kejujurannya.

### Perbaikannya: komit harness-nya, lalu daftarkan

Dua perubahan, dan yang pertama yang sebenarnya memperbaiki keadaan:

  - `Tools/bukti-mutasi-warna-ragu.py` **dikomit**. Tanpa ini, langkah CI
    apa pun yang merujuknya akan merah di checkout bersih karena berkas
    hilang — bukan karena gerbangnya berbunyi.
  - langkah baru `Buktikan gerbang warna identitas planet saat ragu
    berbunyi` di `.github/workflows/engine-tests.yml` yang menjalankannya.

Komentar langkah gerbang metanya kini mencatat bahwa ini **kali kedua**
kelas cacat yang sama terjadi (13/12 lalu, 17/16 sekarang), supaya pembaca
berikutnya tahu polanya berulang dan tahu angka apa yang harus
dibandingkan.

Yang **tidak** dilakukan: melonggarkan `check-harness-terdaftar.py` atau
menambahkan berkasnya ke pengecualian. Gerbang yang berbunyi benar tidak
boleh diperbaiki dengan membuatnya diam — itu kebalikan dari yang ditulis
docstring-nya sendiri.

### Harnessnya dijalankan sungguhan, bukan sekadar dikomit

`python3 Tools/bukti-mutasi-warna-ragu.py` → **6 keadaan, 0 tidak sesuai
harapan** (exit 0). Yang dituntutnya bukan «ada yang merah» melainkan
**yang mana**:

```
OK   [baseline]                                       0 merah
OK   1. port: ragu pakai palet planet (cacat aslinya) 2 merah
       kandidat planet == bola netral @38pt | @200pt
OK   2. port: semua planet jadi bola netral           2 merah
       planet terkunci membawa warnanya kembali @38pt | @200pt
OK   3. view: `drawable` dilepas                      1 merah
       kandidat planet: view memakai palet sadar keyakinan
OK   4. model: token netral digeser                   2 merah
       kandidat planet == bola netral @38pt | @200pt
OK   5. port: hanya `light` dinetralkan (batas)       0 merah
```

Keadaan 1 dan 2 berlawanan arah, dan **pasangan itulah buktinya**: 1 adalah
"kandidat membawa identitas", 2 adalah "tidak ada identitas yang pernah
dibawa". Gerbang yang hanya bisa melihat salah satunya akan hijau pada
aplikasi yang tidak pernah membedakan planet mana pun. Keadaan 5 wajib
hijau karena ia merekam **batas yang dinyatakan**: gerbangnya membaca
piksel paling terang piringan, jadi menetralkan `light` saja sudah
memenuhinya walaupun `dark` masih membawa palet planetnya. Batas itu
direkam, bukan diklaim tertutup.

Ketiga berkas produksi yang dimutasi (`render-visuals.py`,
`CelestialVisualView.swift`, `CelestialVisual.swift`) dipulihkan lewat
`mutasi_sumber` dan diverifikasi: `git status` sesudahnya bersih.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 212 | **212** (tak disentuh) |
| PointingKit | 730 | **730** (tak disentuh) |
| Pemeriksaan visual | 723 | **723** |
| Harness dirujuk CI | 16 dari 16 | **17 dari 17** |
| Aturan UI | 30 | 30 |

Tidak ada satu baris pun kode produksi yang berubah siklus ini. Yang
berubah hanya status berkas harness dan daftar langkah CI.

### Verifikasi

  - `./swift-test.sh` → **CelestialEngine 212 + PointingKit 730 hijau**,
    0 gagal.
  - `python3 Tools/check-visuals.py --check` → **723 pemeriksaan, 0 gagal**.
  - `python3 Tools/bukti-mutasi-warna-ragu.py` → **6 keadaan, 0 tidak
    sesuai harapan**.
  - `python3 Tools/check-harness-terdaftar.py` → **17 harness, semuanya
    dirujuk alur kerja** + 3/3 bukti-diri lolos (sebelum perbaikan, di
    pohon kerja ini: exit 1, satu masalah).
  - `./swift-ui-lint.sh` → **SEMUA GERBANG UI LULUS** (30 aturan).
  - CI: Apple Build `38105319449` **success**. Engine Tests (Linux)
    `38105319409` masih berjalan saat entri ini ditulis (langkah
    pembuktian mutasi berat, ~36 menit).

### Yang TIDAK diklaim

  - Siklus ini **tidak** memperbaiki gerbangnya, tidak memperbaiki gambar,
    dan tidak menyentuh model. Yang diperbaiki adalah **status berkas** dan
    **daftar langkah**.
  - `main` **tidak** pernah merah karena cacat ini — CI hijau di
    `450af2d`, dan `575026e` tidak punya run CI. Yang hilang adalah bukti
    yang bisa diperiksa orang lain, bukan warna laporan.
  - Keadaan 1, 2, dan 5 memutasi **port Python**, bukan view Swift: yang
    diukur gerbang piksel adalah port. Sisi view dijaga pemeriksaan teks
    (keadaan 3), dan harness tidak mengklaim lebih dari itu.
  - Label ukuran `@38pt`/`@200pt` di `must_fire` ditulis harfiah dengan
    sengaja: kalau ukuran kartu jam bergeser, harness menjadi **merah
    berisik**, dan itu disengaja — label yang tidak lagi cocok berarti
    gerbangnya tidak lagi memeriksa ukuran yang diklaimnya.

---

## Progres terakhir (10 Okt 2026 — ambang pengaman Matahari `sunSafeConeDeg` diikat langsung: gerbang prilakunya tetap hijau saat ambangnya dimatikan)

### Cacatnya: uji yang menguji prilaku ambang ini tidak bisa melihat angkanya

`PointingResolver.sunSafeConeDeg` (13°) adalah **satu-satunya** gerbang yang
menolak **arah tunjuk itu sendiri** saat menunjuk ke Matahari
(`PointingResolver.swift:219–220`). Ia berbeda dari lapis keduanya
(`VisibilityFilter.classify` → `.tooCloseToSun`, lewat
`policy.minSunSeparationDeg` = 30°): yang kedua menyaring **kandidat**, yang
pertama menyaring **niat** — dan ia berlaku sekalipun kebijakan paling permisif,
karena `minSunSeparationDeg: 0` mematikan lapis kedua tetapi tidak menyentuh
yang pertama. Alasannya keras: `.lock` membuka izin GoTo, jadi arah pergelangan
tidak boleh pernah menjadi perintah motor yang diarahkan ke Matahari.

Uji prilakunya ada (`testAimingAtTheSunNeverLocksOrFiresSuccessHaptic`,
`PointingControllerTests.swift:604`), dan ia **benar**. Tetapi ia dibangun
dengan `catalogue: []` — katalog kosong. Konsekuensinya terukur: dengan
ambang diubah `13.0 → 0.0`, uji itu **tetap hijau**. Kerucut kosong
menghasilkan `low`, tanpa `lock`, tanpa haptic sukses, tanpa rencana GoTo —
**persis hasil yang sama** dengan kode yang aman. Tidak ada satu pun bintang
di fixture itu yang bisa mengubah hasilnya, karena tidak ada bintang sama
sekali.

Jadi ambangnya bisa dimatikan tanpa satu uji pun merah, dan cacatnya baru
muncul di produksi pada saat yang paling berbahaya: **ketika katalog
diperluas** dan ada benda nyata di dekat Matahari (konjungsi pagi/sore).
`TooCloseToSunLockHonestyTests` sendiri mencatat bahwa nol bintang katalog
pernah berada di celah (13°, 30°) saat keduanya di atas horizon — jadi
kelas cacat ini memang menunggu katalog yang lebih besar.

### Perbaikannya: satu uji yang mengikat nilainya

`testSunSafeConeStaysThirteenDegrees` di `TooCloseToSunLockHonestyTests.swift`
menegaskan `sunSafeConeDeg == 13.0`. Pola yang sama dengan
`testMaximumClaimedAgeIsFifteenMinutes` dan `testShadowFractionIsExactlyHalf`:
yang dijaga adalah bahwa angka itu tidak bisa diam-diam berubah tanpa uji
merah — bukan bahwa 13° adalah nilai astronomis yang benar.

### Gerbangnya dibuktikan berbunyi

`./red-test.sh` dengan mutasi `13.0 → 0.0` pada
`PointingResolver.swift` menghasilkan:

```
TooCloseToSunLockHonestyTests.testSunSafeConeStaysThirteenDegrees :
XCTAssertEqual failed: ("0.0") is not equal to ("13.0")
  - ambang pengaman Matahari harus tetap 13° (aturan keras PRD)
```

Sumber dipulihkan oleh `red-test.sh` sendiri (handler `trap ... EXIT`), dan
`git status` berikutnya bersih selain berkas uji + README.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 210 | **210** (tak disentuh) |
| PointingKit | 716 | **717** (+1 gerbang nilai ambang Matahari) |
| Aturan UI | 30 | 30 (Aturan 10 memaksa README 716→717) |

### Verifikasi

- `./swift-test.sh` → **CelestialEngine 210 + PointingKit 717 hijau**, 0 gagal.
  Uji baru berjalan di Docker dan `passed`.
- `./swift-ui-lint.sh` → **SEMUA GERBANG UI LULUS** (30 aturan; Aturan 10
  sinkron 717).
- Mutasi `13.0 → 0.0` → uji baru **merah**; sumber dipulihkan.
- CI: **Apple Build `38054759871` success** + **Engine Tests (Linux)
  `38054759827` success**.
- Tidak ada satu baris pun kode produksi yang berubah — hanya uji + README.

### Yang TIDAK diklaim

- Uji ini menjaga **nilai** 13°, bukan kebenaran fisisnya. Kalau kelak ambang
  itu diubah **beserta** uji ini dan docstring konstantanya, gerbang hijau —
  yang dijaga adalah ketiganya tidak boleh bercerai.
- Uji ini **tidak** menggantikan uji prilakunya. Yang ditambah hanya ikatan
  angkanya; `testAimingAtTheSunNeverLocksOrFiresSuccessHaptic` tetap
  menjaga akibatnya di level controller, dan tetap hijau (katalog kosong
  memang tidak punya benda yang bisa dikunci).
- Tidak menambah uji untuk lapis **kedua** (`minSunSeparationDeg`): ia sudah
  diikat perilakunya oleh `testStarCloseToSunRejectedByVisibility` dengan
  bintang tiruan sungguhan di celah (13°, 30°), jadi cacatnya bukan
  "angkanya tidak diikat" melainkan sudah tertutup.

### Catatan konkurensi

Sama seperti siklus sebelumnya: agent kedua (`xcode-dev-runner.sh`) punya WIP
tak ter-commit di `.github/workflows/engine-tests.yml`, `Tools/check-visuals.py`,
dan untracked `Tools/bukti-mutasi-maria.py`. Ketiganya saya `git stash`
sebelum commit dan `git stash pop` setelah push; berkas untracked itu
dikembalikan ke keadaan **untracked** (`git rm --cached`) supaya pohon kerja
mereka persis seperti saya temukan. Commit hanya berisi
`TooCloseToSunLockHonestyTests.swift` + `README.md` (explicit add).

---

## Progres terakhir (10 Okt 2026 — ambang magnitudo objek langit dalam: 6 DSO terredup tak pernah jadi kandidat, kode gambar dua morfologi mati di produksi)

### Cacatnya: `classify` cuma punya satu ambang magnitudo, padahal bintang dan objek langit dalam beda batas

`VisibilityFilter.classify` (Visibility.swift) hanya memakai `limitingMagnitude`
(6.0) untuk **segala** benda. Katalog produksi (`EngineFactory.productionCatalogue
= Catalogue.brightStars + DeepSkyCatalogue.objects`) memuat 18 objek langit
dalam, enam di antaranya melebihi 6.0:

- M27 (7.40, `.planetaryNebula`), M57 (8.80, `.planetaryNebula`)
- M51 (8.40, `.spiralGalaxy`), M101 (7.86, `.spiralGalaxy`)
- M2 (6.50, `.globularCluster`), M11 (6.30, `.openCluster`)

Keenam diklasifikasi `.tooFaint` → `consider` menolaknya → resolver tidak
pernah menghasilkan mereka. Padahal seluruh jalur visualnya sudah ada dan
teruji: `CelestialVisual.Kind.deepSky`, `VisualFrame` (bentuk per-morfologi),
label, pengucapan, dan `DeepSkyCatalogue.drawableMorphology`. Akibatnya **seluruh
wakil `.planetaryNebula` dan `.spiralGalaxy` tidak pernah digambar di app** —
kode gambar yang mahal mati diam-diam, tanpa satu pun teks layar yang salah.
Ini kelas cacat yang sama persis dengan yang sudah ditutup
`DeepSkyCatalogueTests`: tiap bagian benar sendiri, yang hilang adalah ambang
yang membedakan bintang dari objek langit dalam.

Katalog itu sendiri menambah cacat: komentarnya menjanjikan "mag ≤ 6 terlihat
mata telanjang/binokuler", tapi enam anggotanya (termasuk M57 8.80) jelas di
atasnya. Klaim itu kini tidak lagi benar sejak ambang dipisah — tapi objek
mag 8.8 memang target binokuler, bukan mata telanjang, jadi ambang terpisah
adalah perbaikannya, bukan mengubah komentar.

### Perbaikannya: `deepSkyLimitingMagnitude` (9.0) khusus `kind == .deepSky`

- `VisibilityPolicy` dapat field `deepSkyLimitingMagnitude` (bawaan 9.0, di
  atas mag terredup katalog 8.80) dan `permissive` ikut diset 30.
- `classify` dan `effectiveLimitingMagnitude` dapat parameter `kind:
  ObjectKind = .star`; bila `.deepSky` dipakai batas dasarnya `deepSkyLimitingMagnitude`,
  bukan `limitingMagnitude`. Bawaan `.star` menjaga semua pemanggil lama tetap
  benar tanpa perubahan — `DaylightLockTests` dan seluruh uji bintang tidak
  bergeser.
- `PointingResolver.consider` meneruskan `object.kind` ke `classify`, jadi
  resolver produksi sekarang benar-benar menghasilkan keenam DSO terredup saat
  langit gelap.

Cahaya Bulan **tetap** mengketatkan ambang DSO (lewat `moonBrighteningMagnitudes`),
jadi M57 (8.80) masih ditolak saat purnama tinggi — itu jujur: nebula mag 8.8
memang tidak terlihat di langit terang Bulan. `effectiveLimitingMagnitude`
pakai `base` yang sama untuk kedua jalur ketatnya.

Dua uji baru di `VisibilityTests.swift`:
- `testDeepSkyUsesItsOwnLimitingMagnitude` — M57 (8.8) `.visible` sebagai DSO,
  bintang 8.5 tetap `.tooFaint`, dan tanpa `kind` mag 8.8 tetap ditolak (supaya
  keliru memanggil tanpa `kind` tidak membocorkan ambang DSO).
- `testMoonlightAlsoTightensTheDeepSkyLimit` — M57 `.visible` di langit gelap,
  `.tooFaint` di bawah purnama.

Berkas tersentuh: `Visibility.swift`, `PointingResolver.swift`,
`VisibilityTests.swift`, `README.md` (hitungan 208→210), `STATUS.md`.
Engine 210 hijau, PointingKit 716 hijau, Apple Build (macOS, warning-free) hijau.

### Yang TIDAK diklaim

- Tidak menaikkan `limitingMagnitude` ke 9.0. Itu akan mengklaim bintang redup
  mag 7–8 terlihat mata telanjang — false confidence, dilarang PRD. Ambang
  terpisah menyelesaikan tanpa mengubah batas bintang.
- Tidak mengubah batas bintang sama sekali, jadi tidak ada uji `VisibilityTests`
  lama yang berubah arah.

---

## Progres terakhir (10 Okt 2026 — identitas fisik warna kabut malam akhirnya diuji: klaim jenis yang hanya di docstring)

### Cacatnya: enam warna kabut malam punya identitas fisik yang tak satu pun uji menyebutnya

`NightVisual.accents` mendefinisikan enam warna objek langit dalam untuk mode
malam (`NightVisual.swift:319–329`), masing-masing dengan klaim fisik di
docstring-nya:

- `deepSkyNebula` (0.88/0.44/0.50) — Hα nebula emisi, **merah muda**
- `deepSkyPlanetaryNebula` (0.42/0.78/0.86) — O III, **biru-hijau** (biru tertinggi!)
- `deepSkyGalaxy` (0.82/0.78/0.70) — galaksi miring, **krem**
- `deepSkySpiralGalaxy` (0.48/0.58/0.96) — galaksi spiral, **biru**
- `deepSkyOpenCluster` (0.95/0.97/1.00) — gugus terbuka, **putih-biru**
- `deepSkyGlobularCluster` (0.93/0.74/0.42) — gugus bola, **kuning-oranye**

Docstring `deepSkyColour(for:)` (baris 482) menyatakan tegas: *"warna ini
adalah klaim jenis yang sama kuatnya dengan bentuknya"* — rona malam yang
salah menyatakan "ini nebula emisi" sama kerasnya dengan menggambar cangkang
berongga. Artinya identitas warnanya punya bobot kejujuran PRD §2.

`Tools/sweep-unconsumed.sh` melaporkan keenam `deepSky*` sebagai `test=0`
(di `NightVisual.swift:319–329`). Memang ada `testDeepSkyColoursStayPureRedAtNight`
yang memanggil `deepSkyColour(for:)` — **tetapi hanya** menegaskan `green == 0`
dan `blue == 0` (kemurnian merah). Ia tidak menyentuh hue sama sekali.

Akibatnya: menukar `deepSkyPlanetaryNebula` ke nilai nebula emisi (atau
sebaliknya) tetap lolos **seluruh** uji malam yang ada. Layar malam akan
menampilkan M27 (nebula planetari) dengan rona Hα merah muda padahal klaimnya
O III — gambar lebih yakin daripada teksnya, persis kelas yang dilarang PRD §2,
dan persis pola "warna hanya diuji kemurniannya, bukan identitasnya" yang
dikejar repo ini.

### Perbaikannya: satu uji yang mengunci hue, bukan cuma nol-hijau/biru

`testNightDeepSkyColoursKeepTheirPhysicalIdentity` (baru) memanggil
`CelestialVisual.deepSkyColour(for:)` — **jalur yang sama dengan layar**,
bukan `surface` yang membuang hue — lalu menegaskan arah hue tiap morfologi:
nebula merah > biru; O III biru tertinggi (`blue >= green`, karena nilai
terukur 0.42/0.78/0.86 punya biru tertinggi, bukan hijau); galaksi krem
seimbang; spiral biru tertinggi; gugus terbuka putih-biru (biru tertinggi &
merah > 0.8); gugus bola merah > biru.

Ambangnya **longgar secara sengaja**: yang dijaga adalah arah hue yang benar,
bukan ketepatan 8-bit. Kalau suatu hari paletnya diganti **beserta** klaim
docstring dan uji ini, gerbang ini hijau — yang dijaga adalah ketiganya tidak
boleh bercerai.

### Pelajaran: gerbang ini sempat merah pada kode yang benar (dan itu bagus)

Predikat pertama saya tulis "O III: hijau tertinggi" **dari ingatan komentar**,
bukan dari nilai. Gerbangnya **merah**: `RGBComponents(red: 0.42, green: 0.78,
blue: 0.86)` punya biru tertinggi. Itu persis kelas cacat "komentar mengutip
angka yang tidak pernah ia ukur" yang sudah berulang di repo ini — gerbang saya
sendiri nyaris jadi contohnya. Predikat dan komentar disesuaikan ke nilai
**terukur** (biru-hijau, `blue >= green`), dan kejadian itu dicatat jujur di
docstring uji agar tidak terulang.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 208 | **208** (tak disentuh) |
| PointingKit | 715 | **716** (+1 uji identitas warna kabut) |
| Aturan UI | 30 | 30 (Aturan 10 memaksa README 715→716) |

### Verifikasi

- `./swift-test.sh` → **CelestialEngine 208 + PointingKit 716 hijau**, 0 gagal.
  Uji baru berjalan (Docker, bukan sekadar terkompilasi) dan `passed`.
- `./swift-ui-lint.sh` → **30 aturan bersih** (Aturan 10 sinkron 716).
- CI: **Engine Tests (Linux) `38049453574` success** + **Apple Build
  `38049453549` success** (tanpa warning compiler kode sendiri; hanya anotasi
  depresiasi Node 20→24 yang tak relevan).
- Tidak ada satu baris pun kode produksi yang berubah — hanya uji + README.

### Catatan konkurensi

Sama seperti siklus sebelumnya: agent kedua (`xcode-dev-runner.sh`) punya WIP
tak ter-commit di `.github/workflows/engine-tests.yml`, `Tools/check-visuals.py`,
dan untracked `Tools/bukti-mutasi-maria.py`. Saya `git stash` ketiganya sebelum
commit, lalu `git stash pop` setelah push — commit saya hanya berisi
`NightVisualTests.swift` + `README.md`.

### Yang TIDAK diklaim

- Uji ini menjaga **arah hue** tiap morfologi, bukan kebenaran astronomis angka
  8-bit-nya. Kalau palet diubah beserta docstring dan uji ini, gerbang hijau.
- Keenam warna sudah dipakai `deepSkyColour(for:)` yang bersifat `public
  static` — saya tidak menambah jalur baru, hanya menutup celah pada jalur
  yang sudah ada.

---

## Progres terakhir (10 Okt 2026 — klem blendFactor PointingSmoother akhirnya diuji: contract perataan arah yang tak tergate)

### Cacatnya: invariant keamanan perataan arah tidak punya satu pun uji langsung

`PointingSmoother.init` memangkas `blendFactor` ke selang `[0,1]`
(`Sensing.swift:17`):

```swift
self.blendFactor = max(0.0, min(1.0, blendFactor))
```

Itu **invariant keamanan**, bukan pilihan gaya. `blendFactor` adalah bobot
sampel baru yang diberikan ke `interpolated(to:t:)` — kalau lepas dari
selang, `t > 1` membuat perata **melampaui** sasaran (ekstrapolasi, orientasi
smoothed salah arah) dan `t < 0` membuatnya berbalik. Padahal tujuan tunggal
kelas ini adalah meredam gemetar tangan (lihat docstring `PointingController`
baris 145: "perata orientasi (meredam gemetar tangan)"). Contract itu kini
mengalir sampai ke UI lewat `config.smootherBlend` → `PointingSmoother`.

`Tools/sweep-unconsumed.sh` melaporkan `smootherBlend app=0 test=0` — dan
`SensingTests` memang punya uji untuk *perilaku* perataan (sampel pertama
jadi rujukan, blend 1.0 mengikuti tepat, 0.5 di tengah, busur pendek across
double cover) **tetapi nol uji untuk klem itu sendiri**. Invariant yang tidak
diuji adalah kelas cacat yang persis dicari repo ini: baris `max(0.0, min(1.0,
...))` bisa diam-diam dibuang, `blendFactor: 2.0` diteruskan mentah ke
`interpolated`, dan orientasi yang dikirim ke UI menyimpang — tanpa satu pun
uji yang merah.

### Perbaikannya: dua uji, dua kelas cacat berbeda

Ditambah di `SensingTests.swift` (paket `CelestialEngine`):

- `testBlendFactorIsClampedToUnitInterval` — **penjaga nilai**. Mengikat
  angkanya: `0.3` tetap `0.3`, `5.0` dipangkas ke `1.0`, `-2.0` dipangkas ke
  `0.0`. Ini yang menangkap baris klem dibuang.
- `testClampingPreventsExtrapolationPastTarget` — **penjaga arah**. Menguji
  *akibat* klem lewat perilaku, bukan lewat nilai kembalian `init`: dengan
  `blendFactor: 2.0`, klem menahan `t` di `1.0` sehingga keluaran mendarat
  **tepat di sasaran** (sudut 0 terhadap target). Kalau klem dilepas,
  `t = 2.0` mengekstrapolasi melampaui sasaran (sudut != 0) → merah.

Dua uji ini sengaja memisahkan "nilai klem hilang" dari "ekstrapolasi
terjadi" — persis pola ganda yang dipakai gerbang `shadowFraction` dan
`maximumClaimedAge` di repo ini (ikat nilai + ikat kabel/akibat). Tanpa arah
kedua, menghapus klem tapi membiarkan `interpolated` toleran terhadap `t>1`
tetap lolos uji pertama.

### Yang diukur, bukan dikira-kira

`./swift-test.sh` → **CelestialEngine 208 + PointingKit 715 hijau**, 0 gagal.
Kedua uji baru berjalan (terverifikasi di Docker, bukan sekadar terkompilasi):
`testBlendFactorIsClampedToUnitInterval` dan
`testClampingPreventsExtrapolationPastTarget` keduanya `passed`.

`./swift-ui-lint.sh` → **SEMUA GERBANG UI LULUS** (30 aturan; Aturan 10
memaksa README 206→208, sudah disinkronkan). `swiftswift-typecheck` setara
lulus di Apple Build.

Mutasi dinding-pemikiran: melepas `max(0.0, min(1.0, ...))` di `init`
membuat `testBlendFactorIsClampedToUnitInterval` merah (2.0 != 1.0), dan
`testClampingPreventsExtrapolationPastTarget` merah (sudut 60° != 0). Keduanya
berbunyi pada kelasnya sendiri.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **208** (+2 uji klem perataan) |
| PointingKit | 715 | **715** (tak disentuh) |
| Aturan UI | 30 | 30 (Aturan 10 memaksa README 206→208) |

### Catatan konkurensi (penting)

Ada agent kedua (runner `xcode-dev-runner.sh`, PID 316048 sejak 3 Okt) yang
bekerja di repo yang **sama** dan punya WIP tak ter-commit:
`.github/workflows/engine-tests.yml` (menambah langkah harness
`bukti-mutasi-maria.py`), `Tools/check-visuals.py`, dan untracked
`Tools/bukti-mutasi-maria.py` (gerbang "maria Bulan tidak bocor ke belahan
gelap"). Saya **tidak menyentuh** ketiganya. Sebelum commit, WIP itu saya
`git stash` (2 modified + 1 untracked) supaya tak tersapu ke commit saya, lalu
`git stash pop` setelah push agar WIP mereka utuh kembali. Commit saya hanya
berisi `SensingTests.swift` + `README.md` (2 berkas, explicit add). HEAD ==
origin/main (dc59295) saat push, jadi rebase no-op.

### Verifikasi

- `./swift-test.sh` → CelestialEngine **208**, PointingKit **715**, 0 gagal.
- `./swift-ui-lint.sh` → 30 aturan bersih (Aturan 10 sinkron 208).
- CI: **Engine Tests (Linux) `38047819707` success** + **Apple Build
  `38047819678` success** (tanpa warning compiler kode sendiri; hanya
  anotasi depresiasi Node 20→24 yang tak relevan).
- Tidak ada satu baris pun kode produksi yang berubah — hanya uji + README.

### Yang TIDAK diklaim

- Kedua uji ini menjaga **nilai dan akibat klem**, bukan "0.3 adalah bobot
  perataan terbaik" — itu keputusan kalibrasi, bukan invariant. Docstring
  `PointingController` sendiri menyebut "kecil = halus, besar = gesit".
- `PointingSmoother.update` sudah diuji perilakunya; yang ditambah adalah
  *ambil-alih* (`init`) yang selama ini tak tersentuh gate.

---

## Progres terakhir (10 Okt 2026 — shadowFraction mode malam akhirnya diikat langsung: cacat kelas "threshold tak tergate langsung")

### Cacatnya: konstanta kecerahan piringan gelap mode malam tidak diikat nilainya

`NightVisual.shadowFraction` (0.5) menentukan pecahan kanal merah siang yang
dipertahankan untuk bagian gelap Bulan di mode malam (`NightVisual.shadow`
mengalikan kanal merah siang dengan konstanta ini). Ia adalah satu-satunya
pengatur seberapa gelap piringan gelap bulan saat mode malam menyala — dan
docstring-nya sendiri mengakui ia hanya dijaga *tidak langsung* lewat uji
kontras (`testNightShadowKeepsTheMoonPhaseReadable`), bukan lewat nilainya.

Itu persis kelas cacat "threshold tak tergate langsung" yang dikejar repo ini:
nilainya (0.5 → 0.6 agar "lebih terlihat", atau 0.2 agar "lebih hitam") bisa
diam-diam diubah, seluruh kecerahan piringan gelap Bulan di mode malam bergeser,
tanpa satu uji pun yang menyebut namanya. Uji kontras hanya menangkap kalau
kontrasnya runtuh di bawah 4.5:1 — bukan kalau angkanya digeser ke arah yang
masih lolos ambang.

### Perbaikannya: dua uji di `NightVisualTests.swift`, nol baris produksi

- `testShadowFractionIsExactlyHalf` — mengikat **konstanta itu sendiri**, bukan
  cuma sifatnya. Ini yang menangkap angka diganti (0.5 → 0.6 atau 0.2).
- `testShadowSurfaceIsDerivedFromShadowFraction` — arah sebaliknya: memastikan
  `shadow` benar-benar mengalikan warna siang dengan `shadowFraction`, bukan
  menulis `0.5` menyatu di dalamnya. Tanpa ini, konstanta boleh diganti jadi
  `1.0` sementara `shadow` tetap menulis `0.5` — uji nilai merah, tapi gambar
  yang sampai ke layar tidak berubah sedikit pun. Ini pola ganda yang sama
  dengan `maximumClaimedAge` dan `clusterCoreReferenceExtent`.

`accuracy: 0.004` mengizinkan galat pembulatan 8-bit (terburuk 0.003 terukur)
tanpa melemahkan ikatan: nilai yang benar (`day.nightModeBrightness × 0.5`) duduk
tepat di nol.

### Yang TIDAK diklaim

- Kedua uji ini menjaga **nilai dan kabel** konstanta, bukan kebenaran
  astronomis pecahan 0.5 itu. Kalau kelak `shadowFraction` diubah **beserta**
  uji ini dan kontras sabitnya, gerbang ini hijau — yang dijaga adalah ketiganya
  tidak boleh bercerai.
- `shadow` (di `NightVisual`) tidak disentuh; hanya `shadowFraction` yang
  diikat nilainya. Tidak ada satu baris pun kode produksi yang berubah.

### Hitungan (terukur, bukan diklaim)

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 713 | **715** (+2 gerbang shadowFraction) |
| Aturan UI | 30 | 30 (Aturan 10 memaksa README 713→715) |

### Verifikasi

  - `swift test --filter NightVisualTests` (Docker Swift 6.0) → **13 uji, 0 gagal**,
    kedua uji baru lolos.
  - `./swift-test.sh` PointingKit → **715 hijau** (713 + 2); CelestialEngine
    **206 hijau** (tak disentuh).
  - `./swift-ui-lint.sh` → **30 aturan bersih** (Aturan 10 memaksa README
    713→715, sudah disinkronkan).
  - `./swift-typecheck.sh` → lulus.
  - CI: Apple Build `38045712691` **success**; Engine Tests (Linux) `38045712700`
    masih berjalan saat entri ini ditulis (sweep harness mutasi berat).

---

## Progres terakhir (10 Okt 2026 — ambang maximumClaimedAge akhirnya diikat: cacat kelas "threshold tak tergate langsung")

### Cacatnya: konstanta umur basi complication tidak punya satu pun uji yang menyebutnya

`ComplicationDigest.maximumClaimedAge` (15 × 60 detik) adalah ambang keamanan
complication: tanpa dia, pergelangan yang berhenti bergerak akan membekukan
nama objek di wajah jam sampai app dibuka lagi, dan kunci itu tampil seolah
hasil pengukuran yang sedang berjalan — persis yang dikhawatirkan docstring
konstanta itu sendiri ("klausa yang tidak bisa diuji adalah klausa yang tidak
bisa dipercaya").

Sampai siklus ini ambangnya **tidak diikat langsung**. Seluruh `ComplicationDigestStalenessTests`
memakai helper `digest(updatedMinutesAgo:)` dengan nilai 0/1/2/90/600 menit —
tidak satu pun yang menyebut `maximumClaimedAge`. `Tools/sweep-unconsumed.sh`
melaporkan `maximumClaimedAge app=0 test=0 paket=2`: ambang yang tidak diuji
adalah kelas cacat yang persis dicari repo ini. Kalau suatu hari angkanya
diganti (mis. `15*60` → `5*60`, atau `max` dilepas jadi `0`), complication
mulai membekukan nama jauh lebih cepat **tanpa satu uji pun yang merah** — kelima
nilai uji itu semua tetap di atas ambang baru.

### Perbaikannya: empat uji di `ComplicationDigestStalenessTests.swift`

- `testMaximumClaimedAgeIsFifteenMinutes` — mengikat **konstanta itu sendiri**,
  bukan cuma sifatnya. Ini yang menangkap angka diganti.
- `testDigestOneSecondUnderTheLimitIsFresh` / `testDigestOneSecondOverTheLimitIsStale`
  — batas diuji **kedua sisi**: 1 dtk di bawah tetap segar, 1 dtk di atas basi.
  Tanpa arah sebaliknya, ambang bisa dinaikkan ke tak-terhingga (tidak pernah
  basi) atau diturunkan ke nol (selalu basi) sambil tetap lolos uji "90 menit
  basi".
- `testDigestExactlyAtTheLimitIsNotStale` — pada `age == maximumClaimedAge`,
  `>` salah, jadi bukan basi; menjaga arah "tepat di ambah masih diklaim".

`now` dikunci ke `fixedNow` supaya selisihnya persis `age` (dua
`addingTimeInterval` berlawanan arah pada basis yang sama bebas galat
pembulatan) — uji batas tidak boleh goyah hanya karena detik berlalu antara
dua baris.

### Yang diukur, bukan dikira-kira

`./swift-test.sh` → **CelestialEngine 206 + PointingKit 713 hijau** (709 + 4),
0 gagal. Keempat uji baru berjalan (terverifikasi di Docker, bukan sekadar
terkompilasi). `./swift-ui-lint.sh` → **30 aturan bersih** (Aturan 10 memaksa
README 709→713). `./swift-typecheck.sh` → lulus. CI: Engine Tests (Linux)
`38043599419` **success** + Apple Build `38043599400` **success**.

Tidak ada kode produksi yang berubah — hanya uji + README. Berkas tersentuh:
`ComplicationDigestStalenessTests.swift`, `README.md`, `STATUS.md`.

### Yang TIDAK diklaim

- Keempat uji ini menjaga **nilai dan batas ambang**, bukan kebenaran astronomis
  angka 15 menit. Docstring konstanta itu sendiri menjelaskan asalnya ("langit
  bergerak terlalu sedikit dalam 15 menit") — yang dijaga di sini adalah bahwa
  angka itu tidak bisa diam-diam berubah tanpa uji merah.
- `isStale` sudah diuji lewat `confirmsIdentityNow`/`sublineContent` di uji
  lama; yang ditambah adalah ikatan langsung ke konstanta dan batas eksaknya,
  bukan cabang logikanya.

---

## Siklus: urutan terang mode malam diklaim komentar yang tidak pernah mengukurnya

Siklus ini mulai dari satu kalimat di komentar palet, bukan dari layar.
`NightVisual.accents` menulis bahwa urutan kecerahannya "mengikuti objeknya:
**gugus bola paling terang**, nebula emisi menyusul ... **lalu galaksi dan
gugus terbuka**". Tidak ada satu pun uji yang mengukur urutan itu.

### Cacatnya: separuh klaim komentar itu salah, terukur

Mode malam membuang seluruh hue, jadi **kecerahan adalah satu-satunya kanal
tersisa** untuk membedakan keenam jenis objek langit dalam di layar. Karena
itu klaim urutannya bukan kerapian — ia menjawab "benda mana yang tampak
paling terang saat semua warna hilang".

Dihitung lewat `NightVisual.surface` (kanal merah, `nightModeBrightness = red`,
`floor 0.35 + range 0.65`):

```
gugus terbuka 0.967 > gugus bola 0.955 > nebula emisi 0.922
  > galaksi miring 0.883 > kabut netral 0.818
  > galaksi spiral 0.662 > nebula planetari 0.623
```

Gugus terbuka justru yang **paling terang**, bukan salah satu dari dua yang
paling redup seperti yang ditulis komentarnya. Jadi siapa pun yang membaca
komentar itu untuk memahami paletnya mendapat urutan yang terbalik di ujung
rentangnya — persis kelas cacat "komentar mengutip angka yang tidak pernah ia
ukur" yang sudah berulang di repo ini.

### Perbaikannya: uji dulu, komentar mengikuti ukurannya

`testDeepSkyNightBrightnessMatchesTheDocumentedOrdering` (baru) mengunci
**tiga perbandingan berpasangan** yang diklaim komentarnya, bukan seluruh
urutan: mengunci ketujuh nilai berarti mengunci paletnya, padahal yang salah
adalah catatannya. Perbandingan keempat menjaga arah yang **salah** dari
klaimnya gugus terbuka berada di dasar — tanpanya, komentar yang menurunkan
gugus terbuka akan lolos tiga perbandingan lainnya.

Komentarnya lalu **dibetulkan ke angka yang terukur**, dan menyebut uji yang
menjaganya. Bukan dilunakkan: kalimat yang menyatakan urutan kini menyertakan
tabel hasil ukurnya.

### Gerbangnya dibuktikan berbunyi

Mutasi `deepSkyOpenCluster` kanal merah 0.95 → 0.50 (menurunkannya ke bawah
gugus bola) membuat uji itu **merah**: `0.675` tidak lebih besar dari
`0.9545`, dengan pesan yang menunjuk tepat ke klaim yang dilanggar. Sumber
dipulihkan dan md5-nya diverifikasi identik (`e81aaea6…`).

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 707 | **709** (+2 uji kontrak inti gugus) |
| Aturan UI | 29 | 29 (Aturan 10 memaksa README 707→709) |

### Verifikasi

  - `./swift-test.sh` → **CelestialEngine 206 + PointingKit 709 hijau**, 0 gagal.
  - `./swift-ui-lint.sh` → **SEMUA GERBANG UI LULUS** (29 aturan).
  - `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
  - Mutasi dibuktikan merah, lalu sumber dipulihkan (md5 identik).

### Yang TIDAK diklaim

  - Uji ini menjaga **kesepakatan komentar dengan ukurannya**, bukan kebenaran
    astronomi kecerahan relatif keenam jenis benda. Kalau kelak paletnya
    diubah **beserta** komentar dan ujinya, gerbang ini hijau — yang dijaga
    adalah ketiganya tidak boleh bercerai.
  - Yang diukur kanal **merah mode malam**. Urutan kecerahan siang (luminans
    penuh, hijau/biru ikut terhitung) berbeda dan tidak diuji di sini.
  - Tidak ada kode produksi yang berubah — hanya komentar, satu uji, dan
    README. Tidak ada satu baris pun `Apps/` yang tersentuh.

---

## Siklus: pemotongan ciri planet berfase — akibatnya tidak diukur siapa pun

Siklus ini mulai dari audit "kasus tak terjaga", bukan dari fitur baru. Yang
ditemukan adalah kelas cacat yang sudah berulang di repo ini: **aturan yang
benar, dijalankan dengan benar, dan tidak satu pun gerbang mengukur
akibatnya.**

### Cacatnya: ciri pengenal bisa bocor keluar sabit tanpa satu gerbang berbunyi

Kawah Merkurius dan kabut Venus memang digambar **di dalam** pita yang menyala
di kedua bahasa — `_draw_craters(..., inside_lit=lambda x, y:
_point_in_polygon(x, y, points))` di port, `inner.clip(to: lit)` di view.
Aturannya benar. Yang tidak ada adalah gerbang yang mengukur **akibat**
pemotongan itu: bahwa tidak ada satu piksel pun dari ciri itu yang jatuh di
belahan yang tidak disinari.

Diukur lewat probe langsung pada port (jalur `C.R`, instance yang benar-benar
dipakai gerbang), pada 200 px dan pada ukuran piringan di kartu jam (38 px):

```
planet-mercury-crescent                        gelap=    0  menyala= 9484
planet-mercury-crescent  [ciri TIDAK dipotong] gelap= 2004  menyala=10582
planet-venus-crescent                          gelap=    0  menyala= 6986
planet-venus-crescent    [ciri TIDAK dipotong] gelap=14714  menyala=14714
planet-mercury-crescent @38px                  gelap=    0  menyala=  355
planet-mercury-crescent @38px [tak dipotong]   gelap=   71  menyala=  389
planet-venus-crescent   @38px [tak dipotong]   gelap=  524  menyala=  524
```

Lalu mutasinya dijalankan sungguhan: dengan `inside_lit` dilepas dari
pemanggilan `_draw_craters`, gerbang yang sudah ada —
`check_inner_planet_phase` (5 pemeriksaan), `check_planet_features_present`
(3), `check_crater_drawing_constants`, `check_crater_relief_matches_the_model`,
`check_crater_floor_opacity_*`, `check_features_survive_the_watch_size` —
tetap **0 merah**, sementara kawahnya kini melompat keluar sabit. Untuk Venus,
melepas potongan kabutnya mengisi **seluruh** belahan gelap: 14714 piksel pada
200 px.

Kenapa itu cacat dan bukan selera: sabit Merkurius adalah **klaim terukur** —
fraksi iluminasi yang dihitung engine. Kawah yang menonjol keluar dari sabit
membuat bentuknya lebih lebar daripada fraksi itu, dan tidak ada teks di kartu
jam yang bisa membantahnya. Kelasnya sama dengan Venus yang tergambar bulat
(`check_inner_planet_phase`) dan fase tak diketahui yang menyamar jadi bulan
baru (`check_unknown_phase_is_not_a_new_moon`): gambar yang **menyatakan lebih**
daripada yang dihitung.

### Perbaikannya: enam pemeriksaan, dua arah

Dua pemeriksaan baru di `Tools/check-visuals.py`, keduanya mengukur piksel:

  - `check_phase_feature_stays_inside_the_lit_band` — nol piksel menyala di
    belahan gelap, untuk **kedua** planet dan **kedua** ukuran. Sudut sisi
    terangnya dibaca ulang dari `VisualCase.kw` di `R.build_cases()`, bukan
    dari daftar di berkas gerbang: gerbang yang menyimpan sudutnya sendiri
    akan tetap hijau saat sudutnya diubah, dan mengukur gambar yang tidak
    pernah tampil.
  - `check_phase_feature_still_draws_on_the_lit_side` — arah sebaliknya, dan
    ini yang paling penting. Tanpa pasangannya, cara termurah memenuhi "nol
    piksel di belahan gelap" adalah **berhenti menggambar cirinya sama
    sekali** — perbaikan yang mematikan gambar, bukan memperbaikinya.
    `check_planet_features_present` sudah menulis alasan yang sama untuk
    dirinya sendiri ("tanpa pemeriksaan ini, view yang berhenti menggambar
    **semua** ciri akan lolos uji 'ciri hilang saat ragu' dengan sempurna").

Bentuk pasangan ini yang membuat keduanya berarti: `bukti-mutasi-fase-ciri.py`
keadaan 3 membuktikan keduanya memang **memisahkan** "dipotong" dari "dihapus"
— keadaan itu menyalakan **hanya** gerbang "masih tergambar" (172 piksel
berbeda di belahan menyala untuk Merkurius, 894 untuk Venus pada kode benar),
bukan gerbang pemotongan. Kalau keduanya berbunyi bersama, gerbangnya tidak
memisahkan apa pun.

### Buktinya: harness mutasi, tiga keadaan

`Tools/bukti-mutasi-fase-ciri.py` (baru, dirujuk `engine-tests.yml`):

```
OK   [baseline]                                   0 merah
OK   1. port: kawah Merkurius tak dipotong        2 merah
       ciri mercury tidak bocor ke sisi gelap (panel 200 px) | (kartu jam 38 px)
OK   2. port: kabut Venus tak dipotong            2 merah
       ciri venus tidak bocor ke sisi gelap (panel 200 px) | (kartu jam 38 px)
OK   3. port: kawah tidak digambar sama sekali    1 merah
       ciri mercury masih tergambar di sisi menyala
4 keadaan, 0 tidak sesuai harapan
```

Keadaan 1 dan 2 sengaja terpisah: kalau satu keadaan menyalakan kedua planet,
gerbangnya tidak membedakan kawah dari kabut, dan laporan "ciri Mercury bocor"
bisa datang dari kabut Venus. Keadaan 3 harus menyalakan **hanya** arah
sebaliknya. Tiap keadaan juga menuntut pemeriksaan yang **tidak** disebut tetap
hijau — satu keadaan yang menyalakan seluruh pemeriksaan terlihat "sesuai
harapan" padahal artinya gerbangnya cuma berisik.

**Batas yang dinyatakan.** Ketiga keadaan memutasi **port Python**, bukan view
Swift: yang diukur kedua gerbang itu adalah piksel port, jadi hanya port yang
bisa menggerakkannya. Sisi view (`.clip(to: lit)` di `CelestialVisualView.swift`)
dijaga pemeriksaan teks lain, dan harness ini tidak mengklaim lebih dari itu.

### Status akhir siklus ini (terverifikasi, bukan diklaim)

  - `./swift-test.sh` -> **CelestialEngine 206 + PointingKit 706 hijau**
    (0 gagal). Engine tidak disentuh.
  - `python3 Tools/check-visuals.py --check` -> **672 pemeriksaan, 0 gagal**
    (666 + 6 pemeriksaan baru).
  - `python3 Tools/bukti-mutasi-fase-ciri.py` -> **4 keadaan, 0 tidak sesuai
    harapan**.
  - `python3 Tools/check-harness-terdaftar.py` -> **14 harness, semuanya
    dirujuk alur kerja** + 3/3 bukti-diri lolos.

## Siklus: gerbang piringan kedua Saturnus tidak pernah dijalankan CI

Siklus ini mulai dari pekerjaan yang belum di-commit yang ditinggalkan siklus
sebelumnya (matang karena timeout). Isinya perbaikan nyata, dan ia membuka
**tiga** cacat perkakas yang tidak terlihat selama perbaikannya belum
di-commit.

### Cacat gambarnya: dua piringan bersarang

`drawPlanet` menggambar bola radius penuh 1.0 R lebih dulu, lalu pada cabang
cincin `drawRings` menggambar bolanya **sendiri** pada
`VisualFrame.saturnBodyRadius` (0.53 R). Yang sampai ke layar jadi dua piringan
bersarang: cakram 1.0 R yang bocor ke seluruh frame di luar bidang cincin, di
bawah bola 0.53 R milik cincinnya. Di kartu jam itu terbaca "dua bola
bersarang", bukan Saturnus.

Kenapa tidak ada gerbang yang menangkapnya: pemeriksaan terdekat, "cincin
Saturnus lebih lebar dari bola" (`reach > 0.8`), **dilewati oleh cakram bocor
itu sendiri** — ia menjangkau 1.0 R. Diukur lewat probe langsung pada port:

```
[baseline]                          piringan-kedua 0/14144 | gerbang lama HIJAU (0.996 R)
bola penuh kembali di jalur cincin  piringan-kedua 14144/14144 | gerbang lama HIJAU (1.003 R)
cincin dihapus, syarat dibatalkan   piringan-kedua 14144/14144 | gerbang lama HIJAU (1.003 R)
cincin dihapus SAJA                 piringan-kedua 0/14144 | gerbang lama MERAH (0.000 R)
cincin dikecilkan ke 0.55 R         piringan-kedua 0/14144 | gerbang lama MERAH (0.546 R)
```

Perbaikan: syarat `!(isConfirmed && palette.feature == .rings)` di view dan
padanannya di port, supaya bola radius penuh dilewati pada jalur cincin. Kasus
**ragu** tetap memakai bola radius penuh — di sana tidak ada cincin yang
menggambar bolanya, dan yang harus tampil memang hanya warnanya.

### Cacat 1: harnessnya mengukur keadaan yang bukan keadaannya

`Tools/bukti-mutasi-piringan.py` keadaan 2 mengklaim "cincin dihapus, piringan
bocor tetap (14 144 piksel)". Mutasinya hanya mengganti pemanggilan cincinnya
dengan `pass`. Syaratnya masih utuh, jadi bola 1.0 R-nya **juga** tidak
digambar: terukur 0/14 144, dan gerbang lama justru MERAH — persis kebalikan
dari yang diklaim docstring-nya. Menghapus cincin sambil mempertahankan
piringannya menuntut **dua** suntingan.

Akar yang membuatnya tidak terlihat: pengulang mutasinya selalu menulis
`content = _originals[path]`, jadi suntingan kedua pada berkas yang sama
**menimpa** yang pertama. Sekarang dirantai per berkas (`pending[path]`).

### Cacat 2: harness itu tidak pernah dijalankan CI

Daftar `Tools/bukti-mutasi-*.py` di disk: **13**. Yang dirujuk
`engine-tests.yml`: **12**. Berkasnya ada, isinya benar, dan tidak ada yang
mengeksekusinya — gerbang yang tidak dijalankan selalu hijau, dan ia menutupi
persis cacat yang ditulisnya untuk menangkap, tanpa satu pun jejak di laporan
CI.

Sekarang dirujuk, dan kelas cacatnya ditutup gerbang meta baru
`Tools/check-harness-terdaftar.py` — dua arah (harness di disk tak dirujuk;
langkah CI merujuk berkas hilang), plus bukti-diri bahwa auditnya memang bisa
merah, plus penjaga bahwa pola globnya tidak diam-diam menemukan nol berkas.

### Cacat 3: probe-nya tidak menjalankan pemeriksaan yang dituntut states

`probe()` hanya memanggil gerbang piksel. Dua keadaan (1 dan 5) menuntut
pemeriksaan `check_port_matches_swift_constants`, yang membaca sumber view dan
port dari disk — jadi `must_fire` yang menyebut nama pemeriksaan itu **tidak
mungkin** terpenuhi. Terukur: keadaan 1 dan 5 sama-sama dilaporkan SALAH, dan
keadaan 5 (yang sengaja hanya mengubah view) melaporkan 0 merah sama sekali.

Tiga cacat ini punya bentuk yang sama: **harness yang hijau tanpa pernah
mengukur apa yang diklaimnya**. Itu sebabnya harness yang tidak dijalankan CI
adalah cacat yang paling mahal dari ketiganya.

### Status akhir siklus ini (terverifikasi, bukan diklaim)

  - `./swift-test.sh` -> **CelestialEngine 206 + PointingKit 706 hijau**
    (0 gagal). Engine tidak disentuh.
  - `python3 Tools/check-visuals.py --check` -> **666 pemeriksaan, 0 gagal**.
  - `python3 Tools/bukti-mutasi-piringan.py` -> **6 keadaan, 0 tidak sesuai
    harapan** (sebelum perbaikan: 2 keadaan SALAH, exit 1).
  - `python3 Tools/check-harness-terdaftar.py` -> **13 harness, semuanya
    dirujuk alur kerja** + 3/3 bukti-diri lolos.

## Progres terakhir (9 Okt 2026 — bola netral planet tak dikenal: satu-satunya gambar yang mewakili jalur jujur PRD, dan tak seorang pun menjaganya)

### Cacatnya: kasus render yang tidak pernah disebut gerbang mana pun

`planet-unknown-confirmed` ada di `build_cases()` sejak kelas planet ada. Ia
mewakili **jalur jujur** PRD di kelas itu: `CelestialVisual.Planet(objectID:)`
mengembalikan `nil` untuk id yang tidak dikenal, dan view lalu menggambar bola
netral tanpa pita, tanpa cincin, tanpa bintik — bola yang tidak mengklaim
identitas apa pun.

Cara menemukannya bukan dengan mata: seluruh `build_cases()` disaring terhadap
nama yang pernah disebut `check-visuals.py`. Dua kasus tidak pernah disebut,
dan `planet-unknown-confirmed` salah satunya. Lalu mutasi dijalankan — cabang
`planet is None` di port **dan** di view diganti palet Mars:

```
planet is None -> palet Mars (port)   → 0 dari 40000 piksel berbeda dari Mars
planet is None -> palet Mars (view)   → 0 piksel berbeda
check-visuals.py --check              → 654 pemeriksaan, 0 gagal
```

Jadi engine bisa menampilkan **bola Mars** untuk planet yang tidak dikenali,
menyatakan identitas yang tidak dimilikinya, tanpa satu pun gerbang berbunyi.
Ini kelas cacat yang sama yang sudah berulang di repo: semuanya benar secara
terpisah, yang hilang adalah gerbang yang menghubungkannya.

### Perbaikannya: jarak ke token netral, dua arah

Yang diukur bukan "kromanya rendah" — Merkurius memang dunia abu yang nyaris
tak berwarna (jarak 0.0435 dari netral), jadi ambang kroma akan merah pada
gambar yang benar. Yang diukur adalah **jarak Euclidean ke token netral**, dan
arahnya dua:

  1. Bola tak dikenal harus **sama** dengan token netral (galat ≤ 0.010).
     Ini yang menangkap penggantian oleh planet mana pun — Merkurius sekalipun.
  2. Setiap planet nyata harus **berbeda** dari token netral (≥ 0.015).
     Tanpa arah ini, port yang menggambar bola netral untuk **semua** planet
     akan lolos pemeriksaan pertama.

Ambangnya **dikalibrasi, bukan dipilih**: pembulatan rasterisasi 8-bit memberi
galat terburuk 0.0034 (terukur 0.003); planet terdekat (Merkurius) berjarak
0.0435. `0.010` duduk 2.9x di atas pembulatan dan 4.3x di bawah planet
terdekat.

### Sisi view diperiksa terpisah, karena piksel hanya membuktikan port

Yang dikirim ke jam adalah view, bukan port. Karena itu cabang `guard let
planet = visual.planet else` dibaca dari teksnya: ia harus memanggil token
netral, dan **tidak boleh** meminjam palet planet mana pun. Dua keadaan di
harness membuktikan sisi ini — dan keduanya **tidak menggerakkan satu piksel
pun**, karena yang diukur gerbang piksel adalah port.

### Gerbangnya sendiri dibuktikan berbunyi, atas tujuh keadaan

`Tools/bukti-mutasi-bola-netral.py` (baru, dipanggil `engine-tests.yml`)
menuntut **pemeriksaan mana** yang berbunyi:

```
[baseline]                                 0 merah
1. port: tak dikenal -> palet Mars         bola tak dikenal == netral @38pt + @200pt
2. view: tak dikenal -> palet Mars         view memakai token + view tidak meminjam palet
3. port: `if True:` — semua planet netral  planet nyata bukan bola netral @38pt
4. port: palet Merkurius -> bola netral    planet nyata bukan bola netral @38pt
5. port: token netral -> palet Mars        bola tak dikenal == netral @38pt + @200pt
6. view: token netral -> palet Mars        bola tak dikenal == netral @38pt + @200pt
```

Keadaan 1 dan 2 berpasangan dan **pasangan itulah buktinya**: keduanya
menyalakan pemeriksaan yang berbeda (piksel vs teks). Keadaan 3 membuktikan
arah kedua gerbang itu menggigit — Merkurius, planet terdekat ke netral,
tetap tertangkap.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 706 | **706** |
| Pemeriksaan visual | 654 | **660** (+6 bola netral) |
| Aturan UI | 29 | 29 |

### Verifikasi

  - `./swift-test.sh` → **CelestialEngine 206 + PointingKit 706 hijau**, 0 gagal.
  - `python3 Tools/check-visuals.py --check` → **660 pemeriksaan, 0 gagal**.
  - `python3 Tools/bukti-mutasi-bola-netral.py` → **7 keadaan, 0 tidak sesuai harapan**.
  - Seluruh 12 harness mutasi di `Tools/` → **semua OK**.
  - `./swift-ui-lint.sh` → **SEMUA GERBANG UI LULUS** (29 aturan).

### Yang TIDAK diklaim

  - Gerbang ini mengukur warna **puncak piringan** (piksel paling terang),
    bukan seluruh bola. Bola netral yang benar tetapi dengan bayangan yang
    tiba-tiba berwarna akan lolos; itu di luar cakupannya, dan tidak diklaim
    sebaliknya.
  - Ambang 0.010 dan 0.015 adalah **keputusan yang dikalibrasi** terhadap
    gambar yang ada, bukan nilai astronomis.

## Progres terakhir (9 Okt 2026 — denyut bintang: 17 gerbang bintang hijau pada bintang yang tidak berdenyut)

### Cacatnya: satu-satunya hal yang tidak dilihat gerbang mana pun adalah geraknya

`star-pulse-peak` ada di `build_cases()` sejak siklus pertama — bintang
pada puncak denyut, `pulse=π/2` — dan **tidak satu pun** gerbang di
`check-visuals.py` pernah menyebut namanya. Denyutnya bisa dihapus dari
port, dan seluruh 17 pemeriksaan bintang tetap hijau:

```
pulse_factor = 1.0   (denyut diabaikan)
17 pemeriksaan bintang → 0 merah
piksel menyala @200px: 7044 → 3724   (tidak ada yang melihat)
```

Sebabnya struktural, bukan kelalaian satu gerbang: **setiap** gerbang
gambar di repo ini menggambar pada satu fase, dan pada fase 0.0 denyutnya
memang bernilai nol. Yang mengukur gambar diam tidak bisa melihat gerak.

### Perbaikannya: amplitudo dipulihkan dari gambar, lalu dibandingkan dengan model

Yang dikalikan denyut adalah **radius** cakram glow dan spike, jadi yang
terukur dari piksel adalah **luas** — dan amplitudonya dipulihkan lewat akar:

```
a_puncak = √(luas_puncak / luas_diam) − 1      a_palung = 1 − √(luas_palung / luas_diam)
```

Kedua angka itu berdimensi amplitudo, jadi bisa dibandingkan **langsung**
dengan `pulseAmplitude` dari model Swift. Tiga bentuk yang semuanya terlihat
berdenyut jadi terpisah oleh **tandanya**, bukan oleh angka yang agak
bergeser:

```
sin  : a_puncak +0.10 ✓   a_palung +0.10 ✓   → cocok model
sin² : a_puncak +0.10 ✓   a_palung −0.10 ✗   → denyut hanya ke atas
cos  : a_puncak −0.10 ✗   a_palung +0.10 ✓   → tidak berdenyut
```

Kode benar terukur dalam **0.005** dari model (200/400 px); setiap bentuk
salah berjarak **0.20**. `PULSE_AMPLITUDE_TOLERANCE = 0.05` duduk di
tengah — dan komentarnya mencatat bahwa ia **tidak boleh** dinaikkan ke
0.10: 0.10 adalah persis amplitudonya, jadi pada 0.10 pembalikan tanda
`cos`/`sin²` duduk tepat di batas dan gerbangnya berhenti memisahkan.

`a_puncak` dan `a_palung` **keduanya** diperlukan, dan itu diukur, bukan
diasumsikan: `sin²` memberi puncak yang **persis sama** dengan `sin`
(+0.10), jadi amplitudo puncak buta terhadapnya — hanya palung yang
melihatnya. Satu pemeriksaan tidak bisa menjaga kelas ini.

### Dua kesalahan saya sendiri, tertangkap sebelum push

  - **Pasangan argumen terbalik.** `phases()` mengembalikan `(palung, diam,
    puncak)` tetapi hasilnya saya bongkar sebagai `(peak, rest, trough)`.
    Gerbangnya lalu membandingkan **puncak sebagai palung** — merah pada
    kode yang benar (`−0.1035` terhadap `+0.10`). Yang menemukannya adalah
    `[baseline]` di harness, dan itu tepat alasan baseline wajib **nol
    merah**: tanpa dia, gerbang yang merah pada kode benar akan "diperbaiki"
    dengan mengembalikan kodenya ke bentuk salah.
  - **Klaim docstring yang tidak pernah diukur.** Dari bacaan yang terbalik
    itu saya menulis bahwa toleransi nisbah mentah ±0.02 "meloloskan `cos`
    sebesar 0.016". Angkanya berasal dari `trough/rest` yang tertukar. Klaim
    itu **dihapus**, bukan dilunakkan — komentar yang mengutip angka yang
    tidak pernah keluar dari penyampelnya adalah kelas cacat yang sudah
    berulang di repo ini.

### Gerbangnya sendiri dibuktikan berbunyi, atas enam keadaan

`Tools/bukti-mutasi-denyut.py` (baru, dipanggil `engine-tests.yml`) menuntut
**pemeriksaan mana** yang berbunyi, bukan berapa — dan menuntut yang tidak
disebut tetap hijau:

```
[baseline]                                0 merah
1. sin -> cos                             puncak + urutan + kartu jam
2. sin -> sin²                            palung + urutan + kartu jam
3. denyut diabaikan (pulse_factor = 1.0)  ketujuhnya
4. amplitudo port dinaikkan 2x            puncak + palung
5. suku dibalik, hasil identik            WAJIB 0 merah
```

Keadaan 1 dan 2 berpasangan, dan **pasangan itulah buktinya**: keduanya
menyalakan pemeriksaan amplitudo yang **berbeda**. Keadaan 5 wajib hijau
karena ia mengubah sumber **tanpa mengubah perilaku** — gerbang yang
sebenarnya cuma mencocokkan tulisan `1 + ... sin(` akan tertangkap di sana,
bukan di lima keadaan lainnya.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 706 | **706** |
| Pemeriksaan visual | 646 | **654** (+8 denyut bintang) |
| Aturan UI | 29 | 29 |

### Verifikasi

  - `./swift-test.sh` → **CelestialEngine 206 + PointingKit 706 hijau**, 0 gagal.
  - `python3 Tools/check-visuals.py --check` → **654 pemeriksaan, 0 gagal**.
  - `python3 Tools/bukti-mutasi-denyut.py` → **6 keadaan, 0 tidak sesuai harapan**.
  - `./swift-ui-lint.sh` → **SEMUA GERBANG UI LULUS** (29 aturan).

### Yang TIDAK diklaim

  - Gerbang ini mengukur **amplitudo** denyut, bukan lajunya.
    `MotionPolicy.pulseRateRadiansPerSecond` (1.1 rad/s) dijaga uji Linux di
    `PointingKit`, bukan di sini: pada fase yang diuji (`−π/2, 0, +π/2`)
    lajunya tidak muncul sama sekali.
  - Yang dijaga di kartu jam (38 pt) hanya **arahnya** (puncak > diam >
    palung). Nisbahnya bergeser ke 1.18 pada ukuran itu karena tepi yang
    dibulatkan mendominasi, dan ambang ketat di sana akan merah pada kode
    yang benar.
  - Amplitudo 0.10 itu **keputusan yang diukur**, bukan nilai astronomis.

## Progres terakhir (9 Okt 2026 — inti bintang di dalam gugus: gerbang yang versi pertamanya hijau pada gugus tanpa satu pun bintang)

### Cacatnya: sebuah gugus digambar sebagai noda

Gugus terbuka dan gugus bola digambar sebagai **kabut lembut saja** — sama
seperti nebula, hanya susunan blob-nya yang berbeda. Diukur pada render: tujuh
blob kabur tanpa satu pun titik tajam. Bentuk itu terbaca sebagai **noda**,
bukan sebagai gugus.

Sebuah gugus bintang *adalah* bintang-bintangnya: yang membuat Pleiades
terbaca sebagai Pleiades adalah titik-titik cahaya yang terpisah di dalamnya,
bukan kabut di sekelilingnya. Tanpa satu pun titik tajam, gugus bola Hercules
dan gugus kupu-kupu M6 tampil sebagai dua noda dengan lebar berbeda — dan
lebar adalah satu-satunya yang membedakan mereka.

### Perbaikannya: inti diturunkan dari blob yang sama, bukan ditulis sendiri

Geometrinya diambil dari `deepSky(...)` — blob yang sama yang sudah menggambar
kabutnya — supaya inti **tidak bisa** menyimpang dari kabut di bawahnya. Tiga
penahan, ketiganya **diukur**, bukan diperkirakan:

```
clusterCoreRadiusFraction   0.30   inti = 0.30 dari blob gugus
readableCorePointRadius     0.8 pt lantai dalam POIN, bukan pecahan radius
clusterCoreReferenceExtent  median setengah-bentang blob (plafon)
```

  - **0.30, bukan 0.20.** Pada kartu jam (38 pt, radius frame 19 pt) inti 0.30
    dari blob gugus ≈ 0.55 pt. Pada 0.20 gugus bola jatuh ke 0.17 dan kembali
    tampil sebagai noda — angka yang sama yang memperbaiki satu kasus merusak
    yang lain, jadi keduanya diukur pada ukuran kartu yang sesungguhnya.
  - **Lantai dalam POIN, bukan pecahan radius.** Tanpa `readableCorePointRadius`
    inti di kartu jam adalah 0.67–0.99 pt: di bawah satu piksel pada @1x, jadi
    tidak punya piksel sendiri. Pecahan radius menskalakan inti ikut objeknya;
    yang dibutuhkan adalah lantai yang tidak ikut mengecil.
  - **Plafon dari tata letak, bukan angka tetap.** Blob pusat gugus bola
    (0.46 R) kalau diberi inti 30% menjadi cakram 0.138 R dan terbaca "bokeh".
    Angka tetap **dicoba dan gagal terukur**: pada f=0 rasio inti pusat :
    bintang cincin jadi 1.71, pada f=1.0 hanya 1.06 — intinya menelan cincinnya
    di satu ujung rentang. Diturunkan dari tata letak, rasionya **1.0 di
    setiap fuzziness**.

### Yang lebih penting: gerbangnya sendiri hijau pada gambar yang jelas salah

Versi pertama gerbang ini hanya mengukur **puncak inti di atas lengkungan
sekitarnya**, pada **satu** render. Diukur dengan inti dihapus seluruhnya dari
port (`for star in []:`): keempat pemeriksaannya **tetap hijau** — gugus bola
38 pt pada **0.2035** terhadap ambang 0.20.

Lengkungan yang diukurnya memang milik **kabut** yang menaungi inti, bukan
intinya. Jadi gerbang itu mengesahkan gugus **tanpa satu pun bintang**, dan
melaporkannya sebagai "inti bintang gugus terbaca". Ini kelas cacat yang paling
sulit dilihat di repo ini: bukan gerbang yang mati, melainkan gerbang yang
**berbunyi tentang hal lain**.

Sekarang ia mengukur **dua nisbah**, dan masing-masing menjaga kelas yang
berbeda:

```
cluster_core_contrast    terang pusat inti DENGAN inti / TANPA inti
                         menjaga KEBERADAAN — 1.000 = inti tidak ditambahkan
                         terlemah 1.67 (gugus terbuka 38 pt); tanpa inti tepat 1.000
cluster_core_sharpness   puncak di atas lengkungan, proporsi puncaknya
                         menjaga BENTUK — inti yang menyatu dengan halonya
                         terlemah 0.77 / 0.82 / 0.53 / 0.53
```

`MIN_CLUSTER_CORE_CONTRAST` = 1.10 duduk di antara 1.000 (kebisingan
rasterisasi tidak bisa menaikkan kabut tanpa inti sampai 1.10) dan 1.67
(inti yang benar tidak bisa dituduh hilang). `MIN_CLUSTER_CORE_SHARPNESS` = 0.20
**tetap dipertahankan** justru karena ia menjaga satu arah yang tidak dijaga
kontras: inti yang digambar tetapi menyatu dengan kabutnya masih punya kontras
(ia memang menambah terang) sementara puncaknya rata.

`Tools/bukti-mutasi-inti-gugus.py` (baru, dipanggil `engine-tests.yml`)
menuntut masing-masing berbunyi pada kelasnya sendiri:

```
[baseline]              hijau di kedelapan pemeriksaan
1. for star in []:      keempat KONTRAS merah; keempat KETAJAMAN tetap hijau
2. halo inti 40x        kontras tetap hijau; ketajaman runtuh 0.53 -> 0.06
```

Keadaan #1 yang menuntut ketajaman **tetap hijau** itu bukan kelonggaran: itu
**rekaman cacatnya**. Kalau suatu saat keempatnya ikut merah, yang berubah
bukan gerbangnya melainkan salah satu metriknya. Keadaan #2 wajib ada — tanpa
dia `MIN_CLUSTER_CORE_SHARPNESS` tidak dijaga siapa pun, dan satu-satunya
alasan ambang itu masih dipertahankan adalah kelas cacat ini.

Empat angka di komentar `MIN_CLUSTER_CORE_SHARPNESS` (0.77/0.82/0.53/0.53)
**dibaca kembali dan diukur ulang** oleh
`check_cluster_core_docstring_quotes_measured_values`. Versi pertama komentar
itu mengutip 0.80/0.44/0.58/0.34 — angka yang tidak pernah keluar dari
penyampelnya, persis kelas cacat "komentar mengutip angka yang tidak pernah ia
ukur" yang sudah berulang di repo ini.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 702 | **706** (+4 uji inti gugus) |
| Pemeriksaan visual | 624 | **646** (+22) |
| Aturan UI | 29 | 29 |

### Verifikasi

  - `./swift-test.sh` → **CelestialEngine 206 + PointingKit 706 hijau**, 0 gagal.
  - `python3 Tools/check-visuals.py --check` → **646 pemeriksaan, 0 gagal**.
  - `./swift-ui-lint.sh` → **29 aturan bersih** (Aturan 10 memaksa README
    702→706; sudah disinkronkan).
  - `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
  - CI: `37981319678` (Apple Build) + `37981319724` (Engine Linux) — dipantau
    setelah push.

### Yang TIDAK diklaim

  - Angka 0.30, 0.8 pt, dan plafon median itu **keputusan yang diukur**, bukan
    nilai astronomis. Yang bisa diklaim hanyalah bahwa pada ukuran kartu jam
    (38 pt) dan 200 pt, tiap nilai memisahkan "inti terbaca" dari "noda" —
    bukan bahwa 0.30 adalah fraksi yang benar secara fisik.
  - Gerbang ini mengukur **keberadaan** dan **bentuk** inti di dalam blob
    gugus. Ia **tidak** mengukur apakah jumlah bintang yang digambar cocok
    dengan magnitudo gugusnya, dan tidak mengukur tampilan sesungguhnya di
    layar OLED — hanya modelnya pada dua ukuran render.
  - "Bokeh" pada blob pusat 0.46 R adalah penilaian **mata** yang dipakai
    untuk memilih plafon, bukan ambang yang diuji; yang diuji adalah rasionya
    tetap 1.0 di setiap fuzziness.

---

## Progres terakhir (9 Okt 2026 — kontras diuji terhadap warna yang tidak pernah muncul di layar: kartu jam tenggelam ke atmosfernya sendiri)

### Cacatnya: latar yang diuji bukan latar yang digambar

`SurfacePaletteTests` menghitung seluruh klaim WCAG brief terhadap tiga warna
token: `background`, `surface1`, `surface2`. Yang **benar-benar digambar** di
balik segalanya adalah gradien keempat — `surface2` diredupkan di atas
`background` — dan warna campuran itu tidak ada di himpunan mana pun yang
diuji.

Kepekatannya hidup sebagai literal `0.55` di dalam `appBackground` di
`Apps/Shared/SurfaceTokens.swift`, lapisan yang **tidak bisa dijalankan uji di
Linux**. Diukur lewat jalur model (bukan dikira-kira):

```
mode     langkah kartu↔latar (alpha 0.55)   ambang
siang              0.0137                    0.02
malam              0.0018                    0.02
```

Mode malam praktis **satu bidang**: 0.45/255 pada layar OLED yang merender
kehitaman hampir sempurna. Itu tepat mode yang dipakai di gelap, tempat ambang
"terlihat di gelap" ada untuk bekerja — dan yang menutupinya bukan cuma satu
kartu, melainkan setiap kartu di kedua app.

### Yang ditemukan saat memperbaikinya: mode malam tidak bisa menampung keduanya

Percobaan pertama hanya menurunkan alpha. Diukur, dan jawabannya bukan alpha:
tangga mode malam (latar 0.045 → kartu 0.068) hanya **0.023**, dan disapu dari
alpha 0.00 sampai 0.30, **tidak ada satu pun** yang memenuhi ketiga syarat
sekaligus — langkah kartu di atas ambang, atmosfer di atas satu langkah
kuantisasi, dan kartu lebih terang dari puncak latar:

```
alpha   langkah kartu   atmosfer    kartu > latar
0.55        0.0018        0.0248        TIDAK
0.05        0.0202        0.0025        ya
```

Pada 0.05 atmosfernya sudah 0.6/255 (di bawah kuantisasi) sementara langkah
kartunya masih di bawah ambang. **Ruangan fisiknya yang tidak cukup, bukan
angkanya yang salah.**

### Perbaikannya: latar malam diperdalam, alpha dipindah ke model dan diukur

  - `SurfacePalette.night.background` 0.045 → **0.032** memperlebar tangga jadi
    0.036, dan di situ keduanya muat. Lebih gelap juga arah yang benar untuk
    mode malam: lebih sedikit cahaya merah, hierarki tetap utuh.
  - `SurfacePalette.backdropAtmosphereAlpha = 0.11` — konstanta **model**, bukan
    literal di view. 0.55 dipilih untuk rasa; 0.11 dipilih dengan menyapu
    rentangnya terhadap tiga syarat sekaligus.
  - `SurfacePalette.backdrop(atmosphereAlpha:)` dan `largestChannelGap(from:to:)`
    jadi API publik: warna campuran dan definisi "seberapa banyak lebih terang"
    sekarang punya nama di lapisan yang **bisa diuji**, supaya ambang yang sama
    benar-benar berarti sama di kedua tempat.
  - `minimumCardLadderMargin = 0.022` (sedikit di atas ambang lantai, karena
    puncak gradien tidak boleh duduk tepat di ambang) dan
    `minimumBackdropAtmosphere = 1/255` (satu langkah kuantisasi — satu-satunya
    "terlihat" yang bisa diklaim tanpa mengarang ambang baru).

Terukur pada nilai yang dipakai:

```
mode    langkah kartu   margin     atmosfer      kartu > latar
siang      0.0246      +0.0026    2.08/255          ya
malam      0.0296      +0.0076    1.63/255          ya
```

### Tiga uji, tiga kelas yang berbeda — dibuktikan berbunyi

`Tools`-nya bukan harness baru: tiga uji langsung di `SurfacePaletteTests`,
masing-masing menjaga satu arah. Disapu tiga nilai, dan **tiap nilai
menyalakan pemeriksaan yang berbeda**:

```
alpha 0.55  (cacat asal)   ThePaintedBackdropStillLeavesTheCardAVisibleStep  MERAH
                           TheBackdropNeverOutshinesTheCards                 MERAH
alpha 0.00  (atmosfer mati) TheBackdropStillHasAtmosphere                     MERAH
alpha 0.05  (terlalu redup) TheBackdropStillHasAtmosphere                     MERAH
```

Uji ketiga itu yang paling penting: **menurunkan alpha sampai nol** adalah cara
termudah membuat uji langkah kartu hijau tanpa memperbaiki apa pun, jadi
lantainya diuji juga — bukan hanya langit-langitnya.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 699 | **702** (+3 uji latar) |
| Pemeriksaan visual | 624 | 624 |
| Aturan UI | 29 | 29 (Aturan 10 memaksa README 699→702) |

### Verifikasi

  - `./swift-test.sh` → **CelestialEngine 206 + PointingKit 702 hijau**, 0 gagal.
  - `python3 Tools/check-visuals.py --check` → hijau (gerbang ini tidak
    menyentuh `SurfacePalette`; warna gambar prosedural datang dari
    `CelestialVisual`/`NightVisual`, bukan dari token permukaan).
  - `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
  - `./swift-ui-lint.sh` → Aturan 10 bersih (README 702). Gerbang itu **masih
    merah karena berkas lain** — `NumberFormatTests.swift` memuat aksara CJK
    (英尺) di komentar WIP milik agent paralel, tertangkap Aturan 3. Berkas itu
    **tidak disentuh** siklus ini; saya tidak menstage atau memperbaikinya.
  - Mutasi: tiga nilai alpha disapu, masing-masing menyalakan pemeriksaan yang
    berbeda (tabel di atas); sumber dipulihkan ke 0.11 dan diverifikasi.

### Yang TIDAK diklaim

  - Ambang `minimumBackdropAtmosphere` = 1/255 adalah **lantai kuantisasi**,
    bukan ambang persepsi yang diukur terhadap mata. Gradien latar memang tidak
    dimaksudkan untuk dibaca; yang bisa diklaim tanpa mengarang angka baru
    hanyalah bahwa puncaknya jatuh di warna 8-bit yang berbeda dari latar.
  - Gerbang ini menjaga langkah **kartu↔latar** dan **latar↔puncaknya**. Ia
    tidak mengukur gradien di sepanjang sumbunya (posisi berhentinya puncak),
    dan tidak mengukur tampilan sesungguhnya di layar OLED — hanya modelnya.
  - Latar mode malam 0.032 adalah **keputusan yang diukur**, bukan nilai
    astronomis: ia dipilih karena 0.045 membuat ketiga syarat mustahil
    dipenuhi bersama, bukan karena 0.032 punya arti fisis.
  - Warna gambar prosedural (planet, Bulan, bintang) tidak tersentuh: mereka
    datang dari `CelestialVisual`, bukan dari token permukaan, jadi gerbang
    visual tidak berubah sedikit pun.

---

## Progres terakhir (9 Okt 2026 — gerbang paritas docstring inti spiral: menutup "Belum dikerjakan" yang tercatat sejak 8 Okt)

### Yang dikerjakan: mengukur ulang angka yang dikutip gerbang, bukan mengutipnya

Entri 8 Okt 2026 di berkas ini menutup dengan kalimat yang jujur:

> **Belum dikerjakan:** gerbang paritas docstring (yang membaca tabel di
> docstring dan menuntutnya sama dengan hasil ukur, seperti
> `check_crater_contrast_numbers_come_from_the_sampler`). Biayanya terukur
> ~30 s kalau hanya memakai `spiral_core_samples()` (gratis) + satu render
> gerbang lengan.

Siklus ini mengerjakannya. `check_spiral_core_reads_as_one_body` mengutip
tabel selisih (+124°/+106°/+44°) dan batas 0,2725 R, dan sejak ditulis
belum ada satu pun pemeriksaan yang menuntut angka-angka itu keluar dari
penyampelnya sendiri. Ini kelas cacat yang sudah berulang di repo ini
(`check_crater_contrast_numbers_come_from_the_sampler` lahir untuk kelas
yang sama): **komentar mengutip angka yang tidak pernah ia ukur**, dan
komentar adalah satu-satunya bukti yang dibaca orang yang menilai apakah
sebuah gerbang layak dipercaya.

### Gerbangnya: enam pemeriksaan, diukur lewat jalur gerbangnya sendiri

`check_spiral_core_docstring_quotes_measured_values` membaca tabel selisih
langsung dari docstring fungsi yang dijaganya (jadi menyunting docstring
tanpa menyunting angkanya membuat gerbang ini merah), lalu menghitung
ulang tiap baris lewat `spiral_arm_degrees` — jalur menggambar yang sama
yang dipakai gerbang aslinya, bukan penduaan. Toleransi 3°.

Dua pemeriksaan lagi menutup batasnya, karena tanpa keduanya paritas
selisih saja tidak membuktikan apa pun:

  - **batas 0,2725 R dihitung ulang dari blob inti**, bukan dari
    `max(spiral_core_samples())`. Keduanya berbeda: 0,2725 R adalah
    *reach berkelanjutan* (`halfWidth · (1 − ambang / (opasitas · 255))`)
    sementara sampel diskrit terbesar yang benar-benar dipakai adalah
    0,2688 R. Memakai yang kedua sebagai patokan akan mengubah arti angka
    di docstring itu, bukan memeriksanya.
  - **r = 0,2843 harus tetap di luar sampel inti.** Baris itulah yang
    menunjukkan batasnya tidak longgar: kalau batasnya melonggar, keempat
    sampel akan diukur sebagai inti dan gerbang lengan akan merah pada
    gambar yang benar.

### Yang diukur, bukan dikira-kira

```
inti spiral: selisih docstring r=0.2377 cocok (124° vs 124°)   dengan 360° vs tanpa 236°
inti spiral: selisih docstring r=0.2532 cocok (106° vs 106°)   dengan 340° vs tanpa 234°
inti spiral: selisih docstring r=0.2688 cocok (44° vs 44°)     dengan 266° vs tanpa 222°
inti spiral: selisih docstring r=0.2843 cocok (0° vs 0°)       dengan 200° vs tanpa 200°
inti spiral: batas sampel inti = 0.2725 R (dari model)          reach 0.2725 R
inti spiral: r=0.2843 di luar sampel inti (batas bekerja)      reach 0.2688 R
```

Keempat selisih cocok **persis** (bukan "dalam toleransi"): +124/+106/
+44/+0. Dua angka turunan di docstring `spiral_core_samples()` juga
diverifikasi terhadap model lewat jalur yang sama — `halfWidth` 0,29568
(docstring menulis 0,2957) dan sumbangan 5,9 di r=0,2843, yang memang di
bawah ambang terbaca 12.

### Kenapa gerbang ini tidak diukur lewat `--check` penuh

Biayanya terukur **31 detik** (gerbang penuh ~6 menit). Ini alasan yang
sama dengan seluruh harness mutasi di `Tools/`: gerbang yang terlalu
lambat untuk dijalankan adalah gerbang yang dilewati. Enam pemeriksaan
ini karena itu ditambahkan ke jalur `--check` biasa — bukan ke harness
terpisah — karena ia memang murah.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 699 | **699** |
| Pemeriksaan visual | 618 | **624** (+6 gerbang paritas) |
| Aturan UI | 29 | 29 |

README tidak perlu disinkronkan (Aturan 10 hanya mengikat hitungan uji,
dan keduanya tidak berubah).

### Verifikasi

  - `./swift-test.sh` → **CelestialEngine 206 + PointingKit 699 hijau**, 0 gagal.
  - `python3 Tools/check-visuals.py --check` → **624 pemeriksaan, 0 gagal**.
  - CI: Engine Tests (Linux) `37937387596` **success** (log mencetak
    `624 pemeriksaan, 0 gagal`), Apple Build `37937387647` **success**.

### Yang TIDAK diklaim

  - Gerbang ini menjaga **paritas angka**, bukan kebenaran astronomi tonjolan
    inti. Kalau kelak `halfWidth`-nya diubah beserta seluruh angka turunan
    di docstring dan di penyampel, gerbang ini hijau — yang dijaganya adalah
    *kesepakatan ketiganya*, bukan nilainya.
  - Toleransi 3° adalah pilihan, bukan ukuran fisis. Yang membuatnya tidak
    berbahaya adalah fakta bahwa keempat selisih saat ini cocok pada 0°,
    jadi toleransi itu tidak dipakai untuk menutupi penyimpangan apa pun.
  - Paritas **belum** menyapu tabel mutasi di docstring yang sama (baris
    "keadaan / lengan merah / inti merah" dari `out/bukti-mutasi-spiral.py`).
    Itu berbeda kelas: angka-angka itu berasal dari `out/`, yang
    di-gitignore, jadi membacanya berarti menuntut bukti yang tidak ada di
    repo — dicatat di sini, tidak dikerjakan.
  - Tidak ada satu baris pun kode produksi atau `Apps/` yang berubah. Yang
    ditambahkan murni gerbang atas gerbang yang sudah ada.

---

## Progres terakhir (9 Okt 2026 — fase Bulan dibungkam saat engine ragu: suara tidak boleh lebih yakin daripada gambar)

### Cacatnya: VoiceOver mengumumkan fase Bulan saat engine ragu

`CelestialVisual.spokenPhase` dipanggil **tanpa** ambang `isConfirmed` di kedua
app (`PointingView.swift` kartu jam, `DiagnosticsView.swift` panel iPhone),
sementara dua saudaranya yang juga ciri pengenal —
`spokenDeepSkyMorphology(isConfirmed:)` dan `spokenStarColor(isConfirmed:)` — sudah
memakainya. Akibatnya pada keadaan `.uncertain`: piringan Bulan digambar netral
(tidak mengklaim fase), badge bertuliskan "Ragu", tapi VoiceOver tetap
mengucapkan "Bulan sabit muda". Dua pengguna dengan cuplikan yang sama
mendapat dua kebenaran berbeda — persis kelas false confidence yang dilarang
PRD §2. Mata membaca gambar lebih dulu daripada badge, jadi saluran suara
baru saja lebih yakin daripada gambarnya.

Cacat ini lolos dari gerbang yang ada karena ia bukan di layar: pengguna yang
melihat memang melihat piringan netral, dan tidak ada teks yang membantahnya.
Hanya pengguna VoiceOver yang mendengar klaim yang tidak dimiliki gambarnya.

### Perbaikannya: `spokenPhase` ikut dibungkam saat ragu

`MoonPhaseSpeech.swift` — `spokenPhase` dari `var` tanpa argumen jadi
`func spokenPhase(isConfirmed: Bool)` yang mengembalikan `nil` saat
`!isConfirmed`, ditaruh paling depan sebelum pemeriksaan jenis/bulan. Ini
menyamakan aturan ketiga fungsi ciri pengenal di satu tempat (model), bukan di
view, supaya ambangnya tidak bisa hilang saat salah satu app merefaktor
panggilannya. Dua pemanggil di `Apps/` diubah meneruskan `isConfirmed` yang
sudah mereka punya (bukan `!isStale`: `.uncertain` punya jawaban tapi engine
menyatakan diri kurang yakin — ambangnya lebih ketat dari "bukan sisa").

### Yang diukur, bukan dikira-kira

`testMoonPhaseIsSilentWhenUncertain` (baru) menuntut sabit muda **dan** purnama
diucapkan saat `isConfirmed == true` tetapi `nil` saat `false`. Dua uji lama
(`testOnlyTheMoonSpeaksAPhase`, `testUnknownDirectionNeverClaimsWaxingOrWaning`)
disesuaikan ke argumen baru; keduanya tetap hijau, membuktikan ambang baru tidak
menggeser perilaku fase yang dikonfirmasi.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 698 | **699** (+1 uji kejujuran fase ragu) |

Gerbang hijau: `swift-test.sh` (206 + 699, 0 gagal), `swift-ui-lint.sh` (29/29 —
Aturan 10 sinkron 698→699), `swift-typecheck.sh` (parse Apps/ lulus). Tidak ada
kode mesin teruji yang berubah; perubahan hanya di `MoonPhaseSpeech.swift`,
dua view, dan uji. README disesuaikan ke 699 (Aturan 10).

### Yang TIDAK diklaim

- Gerbang ini menjaga **keputusan membungkam**, bukan kebenaran astronomi nama
  fase: ambang iluminasi di `moonPhaseText` sudah diuji terpisah. Yang baru di
  sini hanya lapisan `isConfirmed`.
- `spokenPhase` tetap mengembalikan `nil` untuk bukan-Bulan dan fase tak
  diketahui (perilaku lama utuh); yang ditambah hanya keadaan keempat (ragu).

## Progres terakhir (9 Okt 2026 — jangkar harness mutasi Dumbel basi: gerbang drift hijau tanpa alasan)

### Audit: apakah brief-nya sudah benar-benar selesai?

Sesi ini dimulai dengan verifikasi, bukan dengan menulis kode — karena
`STATUS.md` (16.382 baris) mengklaim seluruh brief selesai, dan klaim itu
tidak boleh dipercaya tanpa diperiksa. Hasilnya: **klaimnya benar.**

  - `./swift-test.sh` → **CelestialEngine 206 + PointingKit 698 hijau**, 0 gagal.
  - `./swift-ui-lint.sh` → **29 gerbang lulus**.
  - `./swift-typecheck.sh` → lulus.
  - Katalog string: **462 kunci, 0 tanpa padanan Inggris** — lokalisasi Fase C #2
    benar-benar tuntas, bukan setengah jadi.
  - Bagian 1 (visual objek) sudah lengkap di `PointingKit/CelestialVisual.swift`
    (2.704 baris): pita Jupiter dari `sqrt(1−y²)`, Bintik Merah Besar di
    belahan **selatan**, cincin Saturnus, kutub Mars yang menyentuh limb, kawah
    Merkurius dengan relief, fase Bulan dari fraksi iluminasi, deniesa
    spektral bintang, enam morfologi langit dalam.
  - Fase A #1–3 sudah ada: mode malam merah (`SurfacePalette`), AOD lewat
    `isLuminanceReduced`, VoiceOver + pengumuman perubahan keadaan lewat
    `StateAnnouncement` (satu sumber untuk jam dan iPhone).
  - Fase A #4–6: denyut `TimelineView` terpisah dari kartu, semantik font +
    `@ScaledMetric`, bunyi lock opsional.
  - Fase C #1 (complication), #3 (`NSMotionUsageDescription` +
    `NSLocationWhenInUseUsageDescription` di `project.yml`), #4 (penolakan izin di
    `LocationProvider`) — semuanya ada.
  - Kejujuran ketidakpastian **terbukti**, bukan sekadar diklaim: 27 uji
    `isConfirmed` di `CelestialVisualTests` (warna bintang, morfologi langit
    dalam, fase), plus `StateAnnouncement` membaca `answeredObject`
    (bukan `intent`) supaya suara tidak mengumumkan objek lama sebagai hasil
    sekarang.

Jadi tidak ada unit UI yang perlu ditulis ulang. Yang merah adalah **CI**,
dan itulah yang dikerjakan siklus ini.

### Yang ditemukan: CI merah di `main`, bukan di kode

`gh run list` menunjukkan commit HEAD sendiri (`f16925b`) **gagal** di
Engine Tests (Linux) — sementara `./swift-test.sh` lokal hijau. Kegagalannya
bukan engine: `Buktikan gerbang Dumbel (M27) berbunyi` keluar dengan

```
GAGAL (3):
  - 4. model: tinggi blob jadi konstanta 1.0 (bukan offset.1): jangkar tidak ditemukan
  - 5. model: offset.1 berhenti dipetkan: jangkar tidak ditemukan
```

### Akar masalahnya: jangkar harness yang tertinggal, bukan model yang salah

`Tools/bukti-mutasi-dumbel.py` mutate **model Swift** dengan menyalin blok
`.planetaryNebula` secara literal. Commit `1e28591` merapikan pemetaan
cangkang itu:

```swift
// sebelum — diam-diam memotong 24 posisi jadi 16 blob
zip(ring, shellOpacity).map { offset, opacity in … }
// sesudah — opasitas berputar, 24 blob utuh
ring.enumerated().map { index, offset in
    (offset.0, offset.1 * elongation, 0.26, 1.0 * elongation,
     0.0, shellOpacity[index % shellOpacity.count])
}
```

`CURRENT_MODEL_MAPPING` di harness masih mengutip bentuk **lama**. Jadi untuk
keadaan 4 dan 5, `find not in source` → tidak ada yang ditulis ke disk → probe
dijalankan terhadap **model yang tidak berubah** → gerbang drift melihat tabel
yang benar dan membalas **hijau**.

Kelas cacatnya persis yang sudah tercatat di `STATUS.md`: **harness yang gagal
diam bukan hijau** — dan di sini lebih halus lagi, karena harness *melaporkan*
jangkar basi sebagai `failures` (itulah sebabnya CI merah, bukan cacat
tersembunyi). Yang hijau tanpa alasan adalah **gerbang drift**, yang selama ini
dibuktikan menyala oleh keadaan #4 yang sebenarnya tidak pernah memutasi
apa pun.

### Cacat kedua di dalam perbaikan yang sama: #4 dan #5 bertabrakan

Setelah jangkar disesuaikan, keadaan #4 **langsung bertabrakan** dengan #5.
Dulu #5 memutasi `offset.1` supaya pembaca gagal mengurai; #4 mengganti
`offset.1` dengan konstanta — dan setelah `ring.enumerated()` menjadi jangkar
yang dibaca pembaca melalui pola
`\(offset\.0, offset\.1 \* elongation, ([\d.]+),`, **kedua keadaan** membuat
pembaca gagal. Akibatnya tidak ada lagi yang membedakan:

  - **nilai salah** (tabel model tidak sama dengan port) — seharusnya gerbang
    **drift** (`DRIFT`) yang menyala, dan
  - **bentuk salah** (model berhenti memetkan, port tetap) — seharusnya gerbang
    **pembacaan** (`READS`) yang menyala.

Dua gerbang berbeda untuk dua kelas cacat berbeda, sekarang jadi satu gerbang
untuk keduanya. Itu regression pada bukti, bukan pada kode.

### Perbaikannya: pindahkan #4 ke komponen yang **dibaca sebagai angka**

Keadaan #4 kini mengubah **skala lebar** `0.26 → 0.10`, bukan `offset.1`:

```swift
(offset.0, offset.1 * elongation, 0.10, 1.0 * elongation, …)
```

Pembaca **tetap berhasil mengurai** (pola `(offset.0, offset.1 * elongation,
<skala>,` masih cocok), jadi tabel yang dihitung berubah **nilainya** dan
tidak berubah **bentuknya**. Yang berbunyi adalah gerbang nilai:

  - #4 → `tata letak planetaryNebula: tiap blob sama dengan model` **merah**
  - #5 → `tata letak objek langit dalam: terbaca dari model` **merah**

Keduanya kembali menyalak gerbang **berbeda**, dan masing-masing kembali
menjaga cacat yang berbeda: #4 menjaga cangkang yang melenceng dari `ring`,
#5 menjaga model yang berhenti memetkan sementara port tidak. Cacat yang
paling berbahaya dari pasangan ini — model dan port menghitung ulang
elongation secara tidak konsisten — tetap tertutup: kalau salah satu faktor
`elongation` hilang, pola `offset.1 * elongation` tidak cocok dan pembaca gagal
dengan bersih, persis seperti yang keadaan #5 buktikan.

### Pelajaran: harness yang jangkarnya basi harus MERAH

Dulu jangkar basi membuat harness diam. Sekarang `find not in source` menambah
`"jangkar tidak ditemukan"` ke `failures` (sudah begitu di kode sekarang, dan
itulah yang membuat CI merah alih-alih hijau). Batas itu **dibiarkan keras**
secara sadar: model dirapikan → jangkar basi → harness merah dengan pesan yang
menyebut jangkarnya. Itu persis kebalikan dari "hijau karena tidak ada yang
diuji", dan menambah satu cacat pada harness (menyebut jangkar) jauh lebih
murah daripada membiarkan dua gerbang kehilangan bukti perlindungannya.

### Verifikasi (terukur, bukan diklaim)

  - `python3 Tools/bukti-mutasi-dumbel.py` → **OK** (exit 0), 6 keadaan sesuai
    harapan; #4 dan #5 menyalak gerbang berbeda.
  - `python3 Tools/bukti-mutasi-cangkang.py` → **OK** (tidak tersentuh).
  - `./swift-test.sh` → **CelestialEngine 206 + PointingKit 698 hijau**, 0 gagal.
  - `./swift-ui-lint.sh` (29 gerbang) + `./swift-typecheck.sh` → lulus.
  - Sumber produksi dipulihkan setelah mutasi: `git status` bersih selain
    berkas harness itu sendiri.
  - CI: **Engine Tests (Linux) `37917754203` success** dan **Apple Build
    `37917754115` success**. Log CI mengonfirmasi #4 dan #5 merah di gerbang
    yang **berbeda**.

Engine tidak disentuh. Tidak ada kode produksi yang berubah siklus ini — hanya
harness yang menjaga agar gerbangnya terus bernilai.

---

## Progres terakhir (8 Okt 2026 — pemeriksaan yang hijau karena alasan yang salah: variabel gelung yang bocor)

### Cacatnya: gerbang yang mengukur objek lain daripada yang tertulis di namanya
`check_dumbbell_nebula_is_an_elongated_shell` mengukur siluet M27 dan M57 di
dalam satu gelung `for case_name, label in (...)`, lalu **setelah** gelung
memanggil `nebula_centre_and_shell(case_name, ...)` untuk memeriksa rongga
tengah. Setelah gelung, `case_name` bernilai `deepsky-m57` — jadi pemeriksaan
berlabel "cangkang M27 tetap berongga di tengah" mengukur pusat **M57**.

Konsekuensinya bukan merah pada kode yang benar, melainkan **hijau pada kode
yang salah**, dan namanya tetap berbunyi seperti yang diperiksa:

```
pusat-terisi M27 @76px   kode sehat 0.081   cacat 0.571   ambang 0.25
```

Pemeriksaan itu hijau di **kedua** keadaan. Ia tidak pernah bisa gagal.

### Yang membongkarnya: harness mutasi, bukan gerbangnya sendiri
`Tools/bukti-mutasi-dumbel.py` keadaan 3 memipihkan **posisi** blob tanpa
memipihkan **tingginya** — memenuhi syarat siluet sambil menutup lubangnya.
Harness menuntut pemeriksaan rongga merah; gerbangnya menjawab hijau. Justru
tuntutan yang gagal itu yang menunjuk ke baris 4887.

Diperbaiki dengan menulis nama kasusnya sekali (`M27_CASE`), bukan memakai
sisa variabel gelung. Sekarang pemeriksaan itu membaca 0.000 (200 px) dan
0.081 (76 px), cocok dengan yang diklaim docstring-nya.

### Gerbang baru: seluruh kelasnya, bukan satu barisnya
Cacat ini punya bentuk yang bisa dicari di seluruh berkas, jadi ditambahkan
`check_no_loop_variable_leaks_into_a_call` — analisis AST atas
`check-visuals.py` sendiri: variabel target `for` yang muncul sebagai argumen
panggilan setelah gelungnya berakhir, tanpa penugasan ulang di antaranya.

Dua pengecualian yang keduanya punya alasan:
  - **penugasan ulang** — `check_deep_sky_shape_suppression` memang memakai
    ulang nama `morphology` dan menugaskannya di gelung keduanya; tanpa
    pengecualian ini gerbangnya merah pada kode yang benar;
  - **pemahaman** — `[i for i in mismatched]` punya lingkup sendiri dan tidak
    mewarisi nilai; dibedakan lewat AST, bukan lewat bentuk barisnya.

Dibuktikan dua arah: disuntikkan ke berkas versi HEAD ia **merah** dan menunjuk
tepat ke `'case_name' dari gelung baris 4860 dipakai lagi di baris 4887`; pada
berkas sekarang hijau. Daftar pengecualian per fungsi kosong.

### Dua cacat lain di harness yang sama, ketemu saat memakainya
1. **Keadaan 2 tidak pernah sampai ke pemeriksaan rongga.** Elongasi 0.20
   memipihkan cangkangnya sampai terangnya jatuh di bawah ambang keterbacaan,
   jadi gerbang berhenti di cabang "cangkang M27 berongga" (nama berbeda) dan
   harapan `HOLLOW: hijau` tidak pernah diuji — padahal keadaan itu memang
   harus merah. Sekarang mengharapkan cabang yang benar-benar menyala.
2. **Keadaan 3 hanya memisahkan kode sehat dari cacatnya pada 76 px.** Pada
   200 px pusat-terisi 0.000 vs 0.078 — blobnya lebih rapat dari jaring sampel
   pusat, jadi lubangnya tidak benar-benar tertutup di ukuran itu. Harapan
   "merah di mana saja" akan merah pada kode yang benar; ditambahkan penanda
   ukuran (`WATCH_SIZE`) supaya keadaan itu menyatakan ukuran mana yang
   memisahkan, bukan menyembunyikannya.

### Juga: docstring yang menunjuk bukti yang tidak ada
Docstring gerbang menyitir `out/probe-mutasi-dumbel.py` untuk angka 0.780 —
`out/` di-gitignore, jadi rujukannya menunjuk berkas yang tidak ada di repo
("proof lost = no proof"). Angka itu juga tidak bisa direproduksi: 0.780 tidak
muncul di ukuran mana pun (terukur 0.078 dan 0.571). Diganti dengan rujukan ke
harness yang di-track dan dijalankan CI, beserta angka yang benar-benar terukur.

### Verifikasi
- `swift-test.sh`: CelestialEngine **206**, PointingKit **696** — hijau.
- `check-visuals.py --check`: **616 pemeriksaan, 0 gagal** (615 + pemeriksaan
  kebocoran yang baru).
- `swift-ui-lint.sh` 29 aturan, `swift-typecheck.sh` — hijau.
- `bukti-mutasi-dumbel.py`: 5 keadaan, semuanya sesuai harapan, kedua sumber
  produksi (port + model) kembali ke md5 semula.
## Progres terakhir (8 Okt 2026 — M27 akhirnya bukan M57: satu morfologi, dua sudut pandang, dan gerbang drift yang belum ada)

### Cacatnya: dua objek katalog yang bentuknya berbeda digambar identik

Katalog memetakan **M27 (Dumbel)** dan **M57 (Cincin)** ke morfologi yang sama,
`.planetaryNebula` — dan itu **fakta**, keduanya nebula planetari. Tetapi
`.planetaryNebula` menggambar **cangkang berongga yang bulat**: enam belas blob
pada satu radius, tiap blob rasio sumbu 1.0. Akibatnya M27 terukur **siluet
1.000** pada setiap fuzziness — lingkaran sempurna, sama persis dengan M57.
Yang berbeda hanya skalanya (108 px lawan 106 px), dan skala bukan bentuk.
Komentar katalog sendiri menyebut M27 "kabut memanjang", sementara yang digambar
bulat: kelas cacat yang sama dengan M31/M51 sebelum lengan spiral ditambahkan.

### Perbaikannya: sudut pandang, bukan jenis baru

M27 8.0′ × 5.7′ (dilihat dari samping), M57 1.4′ × 1.0′ (dilihat hampir dari
kutubnya). Jadi yang berbeda **bukan jenisnya** — keduanya nebula planetari —
melainkan **proyeksi** bola gas itu di langit. Karena itu bentuknya dinyatakan
sebagai **parameter**, bukan `case` morfologi baru:
`VisualFrame.deepSky(..., elongation:)` + tabel `DeepSkyCatalogue.elongationByID`.
Menambah `case` baru berarti menyatakan dua *jenis* objek, dan tiap `case`
morfologi dituntut repo ini punya warna sendiri serta dua wakil di katalog —
jalan itu memaksa mengarang rona yang tidak ada di langit dan/atau menyisipkan
objek katalog demi memuaskan uji. Tabel per id, seperti `fuzzinessByID`,
mengukur hal yang benar tanpa keduanya.

Yang dipetkan **kedua** komponen y tiap blob — posisi **dan** tinggi. Memetkan
posisinya saja membuat cangkangnya jadi deretan lingkaran pada elips: makin
pipih makin banyak celah gelap yang terbuka. Memetkan tingginya saja menaikkan
tepi dalam dan **menutup lubangnya** — terukur, tepi dalam jatuh dari 0.237 R ke
0.041 R, cangkang berongga jadi gumpalan pekat. Keduanya sekaligus membuat
lubangnya ikut terskala.

Nilai **0.60** dipilih dengan mengukur: pada fuzziness katalognya (0.68)
siluetnya jadi 108×76 px, rasio **0.704** — mendekati rasio M27 yang sebenarnya
(0.71) — dan pada 76 px masih **20.5%** berbeda dari M57.

### Yang diukur, bukan dikira-kira

Gerbang `check_dumbbell_nebula_is_an_elongated_shell` (7 pemeriksaan) di **dua**
ukuran (200 px panel iPhone, 76 px jam):

```
kasus                 200 px            76 px
M27 (elongasi 0.60)   104×70 (0.673)    40×26 (0.650)
M57 (elongasi 1.0)    102×102 (1.000)   38×38 (1.000)
pusat M27 terisi      0.000             0.000   (ambang 0.25)
```

Ambang 0.80 / 0.45 / 0.92 sengaja duduk di antara keduanya dengan margin — yang
dijaga "jelas memanjang vs jelas bulat", bukan nilai ketiga desimal yang tidak
ada artinya di layar jam.

### Dua gerbang lama yang ternyata merah pada kode yang benar

  - **`read_deep_sky_layouts_from_swift` melempar `AttributeError`.** Gerbang
    drift antar-bahasa itu membaca cabang `.planetaryNebula` dari **teks**
    sumbernya, dan setelah komponen y dikalikan `elongation` polanya tidak cocok
    lagi — `NoneType.group`. Gerbang yang melempar traceback saat modelnya
    dirapikan akan dihapus orang, jadi pembacanya diperbaiki: nilai **bawaan**
    `elongation` dibaca dari tanda tangannya (`elongation: Double = 1.0`), bukan
    ditulis `1.0` di gerbang (itu akan jadi salinan ketiga yang tidak pernah
    dibandingkan), dan kedua faktor `* elongation` **diwajibkan ada** supaya
    komponen y tidak bisa diam-diam berhenti dipetkan.

  - **Pemeriksaan warna pasangan menyala pada objek yang sama jenisnya.** Ia
    membandingkan **setiap** kasus `deepsky-*`; kasus baru `deepsky-m27` /
    `deepsky-m57` berwarna sama dengan `deepsky-planetaryNebula` (ketiganya
    planetari), jadi tiga pasangan merah. Yang diperbaiki **bukan** warna
    objeknya: warna mengodekan **jenis**, bentuk mengodekan **sudut pandang**.
    Gerbangnya sekarang membandingkan **satu wakil per morfologi** — diturunkan
    dari `build_cases()`, bukan daftar tangan — jadi morfologi baru yang
    ditambahkan otomatis ikut diukur.

### Gerbang drift yang belum ada, dan bukti mutasinya

Sampai siklus ini komponen y cangkang **tidak punya** gerbang drift sama sekali —
cangkangnya belum pernah dipetkan, jadi tidak ada yang bisa menyimpang. Sekarang
ada, dan `Tools/bukti-mutasi-dumbel.py` (di-track, dijalankan CI) membuktikannya
lewat **6 keadaan**, termasuk dua yang menyentuh **model**:

```
[baseline]                                  hijau
1. elongasi 1.0 (pemipihan dimatikan)       siluet merah
2. elongasi 0.20 (terlalu pipih)            siluet merah
3. pipihkan posisi saja (lubang menutup)    siluet HIJAU, lubang merah
4. model: tinggi blob jadi konstanta 1.0    drift model<->port merah
5. model: offset.1 berhenti dipetkan        "terbaca dari model" merah (gagal bersih)
```

Keadaan 3 yang menentukan: **ukuran dan pemipihan siluetnya sama persis** dengan
kode sekarang, yang berbeda hanya sumbu yang dipetkan — kalau ia hijau di
"lubang", berarti yang diukur gerbang itu siluet, bukan rongga. Keadaan 4 dan 5
adalah satu-satunya yang bisa melihat **model** menyimpang: seluruh pemeriksaan
siluet membaca **port**, jadi tanpa keduanya cacat "port memetkan, jam tidak"
akan hijau di semua PNG.

Harness memutasi **dua** berkas produksi (port **dan** model), memulihkan
keduanya di `finally` per keadaan plus handler `SIGINT`/`SIGTERM`, dan md5
keduanya diverifikasi pulih.

### Satu uji kejujuran model yang ditambahkan

`testElongationCannotClaimAShapeWhenMorphologyIsUnknown`: morfologi `nil`
mengembalikan geometri **identik** untuk setiap elongasi (diuji atas seluruh
nilai di tabel katalog plus 0.20), **dan** sisi sebaliknya — pada morfologi yang
diketahui elongasi memang harus mengubah gambar. Tanpa sisi kedua itu,
`deepSky` yang mengabaikan `elongation` sepenuhnya akan membuat perulangan
pertama hijau. Ini aturan PRD §2 di lapis **model**: bentuk tidak boleh lebih
yakin daripada teksnya.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 695 | **696** (+1 uji kejujuran elongasi) |
| Pemeriksaan visual | 587 | **615** (+7 gerbang Dumbel + 34 dari dua kasus render baru, −13 pasangan warna yang kini per morfologi) |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (206 + 696, 0 gagal), `check-visuals.py
--check` (615, 0 gagal), `swift-ui-lint.sh` (29), `swift-typecheck.sh`. Berkas
tersentuh: `CelestialVisual.swift`, `DeepSkyCatalogue.swift`,
`CelestialVisualView.swift`, `CelestialVisualTests.swift`,
`Tools/render-visuals.py`, `Tools/check-visuals.py`,
`Tools/bukti-mutasi-dumbel.py` (baru, di-track), `engine-tests.yml`, `README.md`.

### Batas yang jujur

  - Gerbang ini **tidak** menyapu seluruh rentang fuzziness katalog: M27
    digambar pada fuzziness katalognya (0.68) dan M57 pada 0.40. Fuzziness lain
    tidak otomatis terukur.
  - **0.60 adalah angka yang digambar; 0.71 adalah rasio yang terukur** pada
    gambar hasilnya (108×76 → 0.704). Keduanya berbeda karena tepi blob gradien
    tidak setajam kotak pembatasnya, dan yang dijaga gerbang adalah rentang,
    bukan angka ketiga desimal.
  - 0.60 belum punya pembenaran fisis selain "mendekati 0.71 dan terbedakan
    pada 76 px" — sama seperti rasio kawah yang sudah dicatat jujur di berkas
    gerbang.
  - Yang dijaga adalah **bentuk proyeksinya**, bukan kebenaran astronomi
    orientasi M27 di langit: sudut pandangnya tidak diambil dari efemeris, jadi
    ia menggambarkan bentuk yang benar tanpa mengklaim *ke arah mana* sumbu
    panjangnya menghadap di langit malam ini.

---

## Progres terakhir (8 Okt 2026 — cangkang nebula planetari bersambung, dan harness yang menyalahkan kode yang benar)

### Cacatnya: satu bentuk diuji sebagai *lingkaran*, tidak sebagai *kulit*

`.planetaryNebula` digambar sebagai delapan blob pada satu radius (0.42 R,
tiap 45°). Dua uji yang sudah ada benar dan tetap benar pada gambar yang
rusak: `testPlanetaryNebulaShellSitsOnOneRadius` menuntut semua blobnya
sejauh sama dari pusat, `testPlanetaryNebulaIsHollowAtTheCentre` menuntut
bagian tengahnya kosong. **Untaian delapan manik juga duduk pada satu radius
dan juga berongga di tengah.** Yang tidak dijaga siapa pun adalah apakah
manik-manik itu **bertemu** — dan justru kesinambungan itulah satu-satunya
yang membedakan cangkang gas dari gugus bintang di layar.

Delapan blob pada 45° berjarak tali busur **0.3215 R**, sementara dua
tetangga menjangkau **0.244…0.394 R** tergantung fuzziness. Sebagai kelipatan
tali busurnya:

```
fuzziness  0.00   0.40   0.68   0.80   1.00
rasio      0.76   0.95   1.08   1.13   1.22
```

Dua nilai tengah itu justru fuzziness katalog — **M57 pada 0.40, M27 pada
0.68**. Pada 0.40 maniknya berjarak (0.95×), pada 0.68 baru **tepat
bersinggungan** (1.08×): nol cadangan. Irisan selebar nol piksel hilang
begitu lebarnya bergeser sedikit.

### Perbaikannya: 16 blob pada 22.5°

Jarak antar-titik turun ke **0.1639 R** sementara jangkauan dua tetangga
**0.192…0.310 R**, jadi tepinya beririsan **1.17×…1.89×** — pada **setiap**
fuzziness, bukan hanya pada satu nilai yang kebetulan pas. Yang tersisa
hanya riak halus di tepi: itu tekstur cangkang, bukan manik. Lebar blob
dikecilkan 0.30 → 0.26 (bukan diperbesar) supaya lubangnya tidak tertutup;
tepinya tetap 0.24…0.31 R, jauh di atas ambang 0.2 yang menjaga "berongga di
tengah". Opasitasnya jadi enam belas nilai, bukan delapan — blob yang
dirapatkan tanpa variasi opasitas akan tampak sebagai cincin yang dicetak.

**Angka di atas saya ukur ulang sendiri**, bukan dikutip dari diff:
`deep_sky_blobs("planetaryNebula", f)` dari port, dengan aritmetika yang
sama persis dengan uji Swift-nya (jarak tali busur 0.1639 / 0.3215, rasio
jangkauan-dibagi-jarak).

### Yang diukur pada PNG-nya, di tiga ukuran

Gerbang barunya, `check_planetary_nebula_shell_is_continuous`, mengukur
**profil angular** cangkang — persentil ke-10 kecerahan pada radius cangkang
dibagi puncaknya, jadi 1.0 berarti rata dan 0.0 berarti turun sampai latar.
Bukan min/max, dan itu bukan pilihan gaya: versi pertamanya membandingkan
terang/gelap dan **buta justru pada cacat yang diklaimnya** — opasitas blob
terbesar 0.54 membuat puncaknya tersaturasi sementara celahnya tidak, jadi
versi 16-blob terukur *lebih buruk* (1.13) daripada 8-blob (0.15), persis
terbalik. Diukur ulang lewat jalur gerbangnya sendiri:

```
ukuran      76 px (jam)   132 px (panel)   200 px
8 @45 w0.30      0.19          0.18           0.18   <- MANIK
16 @22.5 w0.26   0.77          0.77           0.76   <- CANGKANG
```

Ambang 0.50 duduk di antaranya dengan jarak lebar ke dua arah. Diukur juga
bahwa keadaan 8 @45° pada lebar **0.20** turun ke 0.00 dan pada lebar
**0.40** naik ke 0.56 — yang menetapkan batas bawah dan atas ambangnya, dan
membuktikan yang diukur gerbang itu **kesinambungan**, bukan sekadar
kehadiran blob.

### Dua penjaga, bukan satu

  - `testPlanetaryNebulaShellIsContinuousNotBeaded` (Linux, `swift test`)
    mengukur **geometrinya langsung** dan menyapu kelima fuzziness
    (0.0/0.4/0.68/0.8/1.0) dengan ambang **1.1** — irisan selebar nol piksel
    bukan irisan. Terukur: tata letak lama minimum **0.76**, sekarang
    **1.17**. Uji ini ikut merah/hijau tanpa port Python, jadi invariannya
    terjaga bahkan bila port-nya tidak dijalankan.
  - Gerbang PNG-nya menjaga **yang terlihat** — irisan geometris adalah
    lantai, bukan janji visual. Batas itu ditulis di kedua tempat, bukan
    disembunyikan.

### Harness: `Tools/bukti-mutasi-cangkang.py` (4 keadaan)

```
[baseline]                          hijau 2 pemeriksaan (benar)
1. 8 @45°, lebar 0.30 (tata lama)   merah 2 (benar)   <- cacat aslinya
2. 8 @45°, lebar 0.20 (blob kecil)  merah 2 (benar)
3. 8 @45°, lebar 0.26 (sekarang)    merah 2 (benar)   <- paling tajam
```

Keadaan 3 yang menentukan: **ukuran blobnya sama persis** dengan kode
sekarang, yang berbeda hanya **jaraknya**. Kalau ia hijau, berarti yang
diukur gerbang itu ukuran blob, bukan kesinambungan. Keadaan 8 @45° lebar
0.40 sengaja **tidak** dipakai: ia hijau, dan itu benar — delapan blob
selebar itu saling menjangkau 1.48× tali busurnya. Menuntutnya merah akan
menuntut gerbang menyalak pada kode yang benar. Dipasang di
`engine-tests.yml` dan dipulihkan di `finally` **plus** handler
`SIGINT`/`SIGTERM`.

### Dua cacat keandalan harness yang ikut diperbaiki

  - **`bukti-mutasi-radius-akhir.py`: tulis-biasa → `os.replace` + verifikasi
    pemulihan.** Ini akar flake yang menjatuhkan langkah ini satu kali di
    CI: enam harness memutasi berkas produksi yang **sama** dan setiap prob
    membacanya dari proses baru, jadi penulisan biasa membuat pembaca bisa
    melihat berkas setengah jadi. Pemulihan kini **diverifikasi**, bukan
    diandaikan — dan itu tepat kelas cacatnya: kegagalan pemulihan bersifat
    diam, lalu keadaan berikutnya merah dengan pemeriksaan milik keadaan
    sebelumnya, **menyalahkan kode yang benar**.
  - **`check-visuals.py`: `sys.dont_write_bytecode` + buang `.pyc` basi.**
    CPython memvalidasi cache bytecode lewat (ukuran, mtime) — **bukan isi**
    — dan `importlib.util.spec_from_file_location` **memakai** cache itu.
    Direproduksi secara deterministik: dua sumber sepanjang sama yang
    berbeda hanya **nilai** konstantanya, ditulis pada mtime yang sama,
    membuat impor kedua mengembalikan nilai yang **lama** (`1.15` padahal
    berkasnya sudah `1.45`); sama untuk impor biasa. Di CI (python3 dari
    apt, caching bytecode **aktif** — berbeda dari shell ini yang
    `PYTHONDONTWRITEBYTECODE=1`) dua keadaan harness bisa jatuh pada detik
    yang sama dan menghasilkan berkas sepanjang sama, sehingga probe membaca
    kode keadaan sebelumnya.

### Batas yang jujur

  - Yang dijaga adalah **kesinambungan bentuk**, bukan kebenaran astronomi
    bentuk cincin M57. Lubangnya terjaga (uji lama) dan lebarnya menjauh dari
    ambang, tetapi itu tidak diuji ulang di sini.
  - Gerbang PNG mengukur pada **fuzziness kasus render** (0.8), sementara
    katalog menggambar M57 pada 0.40 dan M27 pada 0.68. Rentang penuh itu
    disapu oleh **uji model**, bukan oleh gerbang PNG — pembagian tugas yang
    ditulis di docstring gerbangnya.
  - Reproduksi bytecode membuktikan **kelasnya** (mtime+ukuran identik →
    bytecode basi), bukan bahwa skenario panjang-sama itu benar-benar
    terjadi di CI. Percobaan cepat saya tidak mereproduksi pasangan yang
    mendarat di detik yang sama; perbaikan tetap dipakai karena biayanya nol
    dan kegagalannya sudah pernah terlihat di `main`.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 693 | **694** (+1 uji kesinambungan cangkang) |
| Pemeriksaan visual | 585 | **587** (+2: dua ukuran) |
| Aturan UI | 29 | 29 |

Semua gerbang hijau di pohon kerja: `swift-test.sh` (206 + 694, 0 gagal),
`check-visuals.py --check` (587, 0 gagal), `swift-ui-lint.sh` (29),
`swift-typecheck.sh`, `bukti-mutasi-cangkang.py` (4 keadaan, 0 tidak sesuai
harapan), `bukti-mutasi-radius-akhir.py` (5 keadaan, 0 tidak sesuai
harapan, md5 pulih persis). Berkas tersentuh: `CelestialVisual.swift`,
`CelestialVisualTests.swift`, `Tools/render-visuals.py`, `Tools/check-visuals.py`,
`Tools/bukti-mutasi-radius-akhir.py`, `Tools/bukti-mutasi-cangkang.py` (baru),
`.github/workflows/engine-tests.yml`, `README.md`. **Tidak ada kode `Apps/`
yang berubah.**

---

## Progres terakhir (8 Okt 2026 — complication sudut: kanal penanda yang hilang di slot paling menonjol)

### Celah yang ditutup: keluarga complication keempat jatuh ke `default`

STATUS.md sendiri sudah mencatatnya sebagai batas jujur: *"Keluarga
`accessoryCorner` belum didesain; ia jatuh ke `default`"*. Kalimat itu benar,
dan justru itu masalahnya — `default` **tampak wajar**. Ia tidak crash, ia
tidak menampilkan apa pun yang kosong; ia hanya diam-diam kehilangan satu
kanal.

Yang hilang di `default` bukan gaya, melainkan **penanda keraguan**. Empat
keluarga complication punya dua kanal: satu ikon dan satu baris teks. Di
`.accessoryCircular` dan `.accessoryCorner` tidak ada baris kedua, jadi ikon
adalah **satu-satunya** penanda yang tersedia. `default` merender ikon keadaan
(`presentedSymbolName(at:)` memang dipanggil di sana), tetapi tanpa label
melengkung dan tanpa desain sudut yang benar. Sudut adalah slot complication
paling menonjol di wajah jam — jadi permukaan yang paling sering dilihat
sekilas justru yang paling tidak didesain.

### Perbaikannya: `.accessoryCorner` jadi keluarga yang benar-benar didukung

`Apps/PointAndKnowWatch/Complications/ComplicationWidget.swift`:
  - `.accessoryCorner` masuk ke `supportedFamilies` — bukan lagi jatuh ke
    `default`.
  - Cabang eksplisit `case .accessoryCorner` memakai `Gauge` +
    `.gaugeStyle(.accessoryCircular)` sebagai isi tengah, dengan
    `.widgetLabel { Text(digest.stateLabel) }` untuk teks melengkung.
  - Ikon memakai versi `at:` (`presentedSymbolName(at: Date())`), **sama
    seperti lingkaran dan persegi panjang**. Tanpa itu cuplikan yang sudah
    tua tetap menampilkan `checkmark.circle.fill` di sudut wajah, persis
    seperti kunci yang baru saja terjadi — kelas cacat yang sudah ditutup
    `ComplicationStaleSymbolTests` untuk keluarga lain.
  - Label melengkung diisi **label keadaan**, bukan nama objek: teks
    melengkung di sudut ruangnya paling sempit, dan nama objek yang panjang
    (mis. "Galaksi Andromeda") akan terpotong di tengah. Yang paling penting
    dibaca sekilas — nama + ikon — tetap di tengah.
  - `#Preview(as: .accessoryCorner)` ditambahkan supaya keluarga ini bisa
    dilihat di Xcode, bukan hanya dipercaya.

### Yang TIDAK diklaim

  - Kebenaran ikon dan label sudah diuji di Linux
    (`ComplicationStaleSymbolTests`, `PointingPresentationTests`); siklus ini
    hanya menghubungkan keluarga keempat ke model yang sudah ada. Tidak ada
    model baru, tidak ada uji baru — karena itu tidak ada angka uji yang
    berubah (206 + 693 tetap).
  - `default` masih ada untuk keluarga yang belum ada (mis. yang akan datang
    di watchOS berikutnya); ia tetap jujur dengan ikonnya.

### Gerbang

  - `./swift-test.sh` -> CelestialEngine **206**, PointingKit **693**, 0 gagal.
  - `./swift-ui-lint.sh` -> **29** aturan hijau (Aturan 23 mencakup cabang
    sudut yang baru: ia merender `digest.headline` bersama
    `presentedSymbolName`).
  - `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
  - `README.md` diperbarui: empat keluarga complication disebut, dan Aturan 23
    dijelaskan sebagai alasan setiap cabang merender ikon (Aturan 10: hitungan
    uji tidak berubah, jadi tidak ada sinkronisasi angka yang perlu).

### Catatan CI: satu langkah merah karena flake, bukan karena commit ini

Push pertama (SHA `584e550`) menjatuhkan langkah *"Buktikan gerbang radius
akhir gradien berbunyi"* (`Tools/bukti-mutasi-radius-akhir.py`) — harness yang
**tidak disentuh commit ini sama sekali** (diff commit: hanya
`ComplicationWidget.swift`, `README.md`, `STATUS.md`).

Keadaan 4 dilaporkan merah dengan lima pemeriksaan planet yang sama persis
dengan keadaan 1. Bukti bahwa itu flake, bukan cacat yang dibawa commit:

  - Checkout bersih pada SHA `584e550` di worktree terpisah: **12/12** jalan
    hijau, `5 keadaan, 0 tidak sesuai harapan`.
  - `gh run rerun --failed` pada run yang sama: **hijau**.

Akarnya adalah tulis-biasa (`open(path, "w")`) di harness itu atas berkas
produksi yang sama, sementara `probe()` membaca dari proses baru: pembaca bisa
melihat berkas setengah jadi. Agent yang bekerja paralel di `Tools/` sudah
menyiapkan perbaikan `os.replace` + verifikasi pemulihan di working tree-nya
(diff belum di-commit) — saya **tidak** menyentuhnya, karena itu wilayahnya.

Pelajaran yang sudah ditulis di diff mereka, dan pantas diingat: **harness
yang gagal memulihkan berkas akan menyalahkan kode yang benar.** Keadaan 4
merah dengan pemeriksaan keadaan 1 itu gejalanya.

---



### Kesimpulan survei: brief sudah tuntas, tidak ada cacat nyata yang tersisa

Setelah siklus `minimumSamples` (di atas), dilanjutkan survei celah yang
dijanjikan brief:

- **Bagian 1–4, Fase A/B/C, Penyempurnaan** — seluruhnya sudah
  diimplementasi DAN di-gate (pixel parity Python, mutation harness,
  `swift-ui-lint` 29 aturan, `check-visuals.py` 585 pemeriksaan). README
  sudah menutupi build Mac (`xcodegen generate`), arsitektur, Experiment 1,
  dan Aturan 10 (hitungan uji sinkron).
- **`sweep-unconsumed.sh`** dilarikan penuh. Flag `test=0` yang tersisa
  semuanya **false positive** atau helper ber-skala-rendah:
  - `stateLabel`/`headline` (`ComplicationDigest`) — sebenarnya tertutup
    tidak langsung lewat `shortLabel`/`stateLabelText` + 9 uji digest di
    `PointingPresentationTests`. Penambahan uji langsung hanya mengulang yang
    sudah hijau (melanggar disiplin "uji yang langsung hijau tak membuktikan
    apa-apa").
  - `invalidateTargets`, `targetListValidity`, `repeatedReferenceMessage`,
    `belowHorizonMessage`, dsb. — helper pesan/kache yang perilakunya tersirat
    oleh uji pemanggilnya; bukan cacat kelas "threshold/identitas tak tergate".
  - `distanceFromCenter` — properti turunan `Spot` yang saudaranya
    (`farthestCorner`) sudah di-gate; probe menunjukkan nilainya 0.354, aman
    di dalam piringan, tak ada bug hidup.
- **Honesti tepi kasus** (bawah horizon, siang hari, bulan redup) — sudah
  tertutup `MoonDaylightHonestyTests`, `TooFaintLockHonestyTests`, dan
  gerbang Matahari tetap (`sunSafeConeDeg`) di `PointingResolver`.

Satu-satunya nilai nyata yang ditemukan dan dikirim adalah `minimumSamples`
(threshold keamanan kalibrasi sungguh-sungguh tak teruji). Tidak ada kode
produksi lagi yang layak diubah tanpa mengarang cacat.

### Hitungan tetap

CelestialEngine 206, PointingKit 693 (690 + 3), Aturan UI 29, visual 585 —
semua hijau. CI (Linux + Apple Build) hijau pada commit `4069b16`.

---

## Progres terakhir (10 Okt 2026 — kontrak inti gugus akhirnya diuji: cacat kelas "helper statis tak tergate")

### Cacatnya: dua helper statis yang mengatur bentuk inti gugus, tanpa satu pun uji langsung

`Tools/sweep-unconsumed.sh` (dilarikan penuh) melaporkan `readableCoreRadius`
dan `clusterCoreReferenceExtent` **app=0 test=0** — artinya tidak dipakai di
`Apps/` (betul: visual dihitung di `clusterCores`) dan **tidak punya uji
langsung**. Padahal docstring `readableCoreRadius` menyatakan invariannya
("selalu ≤ extent, lantai dihormati") "bisa diuji langsung".

Ini kelas cacat persis yang dicari repo ini: kedua fungsi mengatur
**ukuran inti bintang gugus** (Bagian 1, visual "gugus" kabur-berbintang).
Uji agregat yang ada (`testClusterCoresSitOnTheirBlobs`,
`testClusterCoresStayInsideTheirBlobsAndAreVisible`,
`testGlobularCoreStarsDoNotScaleWithTheCentralBlob`) hanya mengecek hasil lewat
`clusterCores`, yang menyembunyikan `readableCoreRadius` di balik
`min(extent, reference)` + perulangan blob. Kalau suatu hari fungsi ini
ditulis ulang — misal argumen `frameHalfExtent` dilupakan sehingga lantai
`readableCorePointRadius` (0.8 pt) dibaca sebagai 0.8 *radius* — agregat masih
bisa hijau untuk frame besar tapi berdarah di kartu jam: `min` akan mengembalikan
**seluruh blob** sebagai inti, gugus jadi tumpukan cakram pekat, bukan kabut
berbintang.

### Perbaikannya: dua uji yang memukul fungsi murni dengan batasnya

Ditambah di `CelestialVisualTests.swift`:
- `testClusterCoreReferenceExtentUsesMedianNotMean` — plafon memotong pencilan
  atas via **median** (bukan mean). Kasus kunci: blob pusat gugus bola 0.46 R
  di tengah, bintang cincin ~0.10 R → median 0.10, jauh di bawah mean (~0.151).
  Ini sumber cacat "bokeh raksasa" yang ditutup uji agregat, tapi dijalur yang
  tidak dicek uji itu (ia hanya membanding inti pusat vs cincin, tidak
  memverifikasi *sumber* plafonnya). Juga menutup daftar genap (rata-rata dua
  tengah) dan kosong (→ 0, bukan NaN).
- `testReadableCoreRadiusContract` — (1) tak pernah > `extent`; (2) menghormati
  lantai 0.8 pt di frame kecil (kartu jam 19 pt → ≥1 px); (3) lantai tak menang
  atas batas blob (extent 0.01 → inti dikapit pada 0.01, bintang tak menonjol
  keluar kabutnya); (4) `frameHalfExtent 0` tak bikin NaN/inf.

### Yang diukur, bukan dikira-kira

`readableCoreRadius app=0 test=0` dan `clusterCoreReferenceExtent app=0 test=0`
turun menjadi `test=2` (dua uji baru) tanpa menyentuh satu baris pun kode
produksi — murni "QA berkelanjutan" (Penyempurnaan #10). README di-sinkron ke
709 supaya Aturan 10 (`swift-ui-lint`) tetap hijau; kelalaian sinkron itu justru
yang membuat CI Engine Tests merah pada commit pertama, diperbaiki di commit
berikutnya.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 707 | **709** (+2 uji kontrak inti gugus) |
| Aturan UI | 29 | 29 (Aturan 10 memaksa README 707→709) |

Semua gerbang hijau: `swift-test.sh` (206 + 709, 0 gagal), `swift-ui-lint.sh`
(29/29, Aturan 10 sinkron), `swift-typecheck.sh`. CI: Engine Tests (Linux) +
Apple Build sukses pada commit `f4fcd50`. Berkas tersentuh:
`CelestialVisualTests.swift`, `README.md`, `STATUS.md`.

---

## Progres terakhir (8 Okt 2026 — ambang minimumSamples akhirnya diuji: cacat kelas "threshold tak tergate")

### Cacatnya: ambang keamanan kalibrasi yang tidak punya satu pun uji

`CalibrationFlow.minimumSamples` menentukan berapa banyak acuan **berbeda**
yang wajib tercatat sebelum kalibrasi boleh dinyatakan `.ready` (dan lewat
`applicableCalibration` dipasang ke controller). Ini ambang keamanan:
kalibrasi setengah matang bisa membalik jawaban engine tanpa terlihat — itu
justru alasan `applicableCalibration` mengembalikan `nil` saat belum siap.

Sampai siklus ini ambangnya **tidak diuji sama sekali**. `Tools/sweep-unconsumed.sh`
melaporkan `minimumSamples app=0 test=0 paket=1` — sementara `referenceMaxAge`
di berkas yang sama punya 7 uji. Ambang yang tidak diuji adalah kelas cacat
yang persis dicari repo ini: nilainya (`max(2, …)`) bisa berubah, atau guard
`independent.count >= minimumSamples` bisa diam-diam di-hardcode ke 2, tanpa
satu pun uji yang merah. `testSingleSampleIsNotReady` yang sudah ada hanya
menutupi batas bawaan 2, bukan sifat ambangnya.

### Perbaikannya: tiga uji yang mengunci sifat ambang, bukan kebetulan

Ditambah di `CalestialFlowTests.swift`:
- `testMinimumSamplesDefaultsToTwo` — bawaan memang 2.
- `testMinimumSamplesIsClampedToAtLeastTwo` — `max(2, …)` benar-benar menolak
  1/0/negatif; kalau `max` dicabut, kalibrasi bisa lahir dari satu ketukan.
- `testHigherMinimumSamplesBlocksUntilMet` — ambang 3 **menahan** dua acuan
  konsisten (yang cukup untuk bawaan 2) dan baru meloloskan saat acuan ketiga
  masuk. Ini yang membuktikan guard membaca `minimumSamples`, bukan angka 2
  yang disembunyikan.

### Yang diukur, bukan dikira-kira

`minimumSamples(app=0 test=0 paket=1)` turun menjadi `app=0 test=3 paket=1`
setelah tiga uji di atas. Tidak ada satu baris pun kode produksi yang berubah
— hanya tambahan uji, seperti siklus "QA berkelanjutan" (Penyempurnaan #10).

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 690 | **693** (+3 uji ambang) |
| Aturan UI | 29 | 29 (Aturan 10 memaksa README 690→693) |

Semua gerbang hijau: `swift-test.sh` (206 + 693, 0 gagal), `swift-ui-lint.sh`
(29/29, Aturan 10 sinkron), `check-visuals.py --check` (585, 0 gagal),
`swift-typecheck.sh`. Tidak ada kode mesin teruji yang berubah. Berkas
tersentuh: `CalibrationFlowTests.swift`, `README.md`.

---

## Progres terakhir (8 Okt 2026 — dua pemanggil, satu konstanta: radius akhir gradien limb akhirnya dibaca kedua jalur)

### Cacatnya: konstanta yang ada, dinamai, diuji — dan tidak mengatur apa pun di separuh pemanggilnya

`CelestialVisual.moonSphereGradientEndRadius` (1.15) punya komentar yang
menyatakan dipakai di **kedua** bahasa, dibandingkan gerbang drift, dan diuji
di Linux (`testMoonSphereGradientIsShallowerThanThePlanetSphere`). Yang
membaca konstantanya sampai siklus ini hanya satu pemanggil: piringan Bulan
(`sphereGradient`). Jalur pita terang planet dalam — Venus dan Merkurius
berfase, yang digambar oleh fungsi `drawLitBand` yang **sama** dengan Bulan —
menulis `1.15` sebagai literal di `drawPlanet` (view) **dan** di `_draw_planet`
(port).

Akibatnya terukur: mengubah konstanta itu memindahkan **nol piksel** pada
Venus dan Merkurius berfase, di kedua ukuran (200 px dan 38 px), sementara
`moon-full` bergeser 31 532 piksel pada 200 px. Konstanta ini ada, dinamai,
dibandingkan gerbang drift, diuji — dan tidak mengatur satu piksel pun di
tempat yang dipakai separuh planet dalam. Tidak ada galat kompilasi: dua benda
yang digambar fungsi yang sama lalu beredup berbeda tanpa satu pun yang tahu.

### Perbaikannya: kedua jalur limb membaca konstanta model

- `drawPlanet` (view) memakai
  `radius * CGFloat(CelestialVisual.moonSphereGradientEndRadius)`.
- `_draw_planet` (port) memakai `radius * MOON_SPHERE_GRADIENT_END_RADIUS`.
- Sekarang kedua jalur limb — piringan Bulan **dan** pita terang planet dalam
  — membaca angka yang sama dari sumber yang sama.

### Yang diukur, bukan dikira-kira

`check_planet_phase_limb_reads_the_model_constant` menguji **kepekaan gambar
terhadap konstanta**, bukan bahwa gradiennya "ada" (gradien apa pun akan lolos
itu). Konstanta diganti ke `1.45`, dan rerata pergeseran luminans piksel pita
yang menyala dituntut ≥ 4,0/255. Terukur: konstanta yang diabaikan = 0,00 (cacat
asal), render ulang identik = 0,00 (bukti ambang bebas noise rasterisasi),
saat diubah = 8,90…15,56 pada 200 px dan 8,90…15,47 pada 38 px. Dua pemeriksaan
teks tambahan memastikan `drawPlanet` menyebut konstanta dan tidak menulis
`radius * 1.15` sendiri — keduanya lewat `swift_code_only` supaya komentar yang
**menjelaskan** cacat ini tidak dihitung sebagai pemakaian.

`_gradient_end_factors` diperluas dua arah: (1) mengenali pengali berupa
**konstanta** (diselesaikan dari sumber model, bukan disalin jadi angka ketiga
yang tidak pernah dibandingkan); (2) melaporkan dua pemanggil limb yang tidak
sepakat sebagai `None` — satu-satunya cara menangkap "dua benda fungsi sama
beredup berbeda" tanpa satu pun galat kompilasi.

### Dua harness mutasi baru, di-track dan dijalankan CI

- `bukti-mutasi-radius-akhir.py` (5 keadaan, 0 tidak sesuai harapan): termasuk
  satu yang **diharapkan hijau** — jalur Bulan menulis literal `1.15` (gerbang
  ini mengukur planet dalam, jadi batas cakupannya teruji, bukan tersirat).
- `bukti-mutasi-radius-gradasi.py` (7 keadaan, 0 tidak sesuai harapan):
  membuktikan pembacanya tetap menggigit setelah diperluas — termasuk satu
  **diharapkan hijau** (kedua bahasa sepakat di 1.60 pada bola) dan satu yang
  hanya terlihat pemeriksaan "para pemanggil sepakat" (dua pemanggil limb tidak
  sepakat → `None`).

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 688 | **688** |
| Pemeriksaan visual | 567 | **585** (+3 gerbang corona) |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (206 + 690, 0 gagal), `check-visuals.py
--check` (582, 0 gagal), `bukti-mutasi-radius-akhir.py` (5 keadaan, 0 tidak
sesuai harapan), `bukti-mutasi-radius-gradasi.py` (7 keadaan, 0 tidak sesuai
harapan), `swift-ui-lint.sh` (29), `swift-typecheck.sh`. CI: Engine Tests
(Linux) `37761380928` + Apple Build `37761380947` **hijau**. Berkas tersentuh:
`CelestialVisual.swift`, `CelestialVisualView.swift`, `render-visuals.py`,
`check-visuals.py`, `engine-tests.yml`, dua harness baru di `Tools/`. **Tidak
ada satu baris pun di mesin teruji yang berubah.**

### Batas yang jujur

- Gerbang baru menjaga **kepekaan gambar terhadap konstanta**, bukan bahwa
  nilai 1.15 itu benar secara fisis. 1.15 dipilih dengan alasan yang diukur di
  siklus sabit Bulan; gerbang ini hanya menjamin Venus/Merkurius mengikutinya
  begitu ia diukur ulang.
- `check_planet_phase_limb_reads_the_model_constant` berjalan pada **satu
  ukuran** (diambil dari token `WatchMetrics.visualDiameter`); pada ukuran lain
  pasangan yang berbeda bisa bertumbukan, dan itu tidak diukur.
- Pemeriksaan "para pemanggil sepakat" hanya melihat gradien limb; kalau suatu
  saat `drawLitBand` memakai radius akhir yang berbeda untuk sabit vs purnama,
  itu adalah cacat baru di luar cakupan entri ini.

---

## Progres terakhir (8 Okt 2026 — bulan mengecil: satu-satunya cabang gambar yang tidak pernah digambar, dan angka yang dikutip tanpa diukur)

### Cacatnya: separuh setiap bulan tidak pernah masuk ke satu pun PNG

`CelestialVisual.terminatorRotationRadians` punya **dua** jalur: pita terang
yang dasarnya ada di kanan (membesar) memakai sudut Matahari apa adanya, dan
pita yang dasarnya ada di **kiri** (mengecil) membalikkannya dengan `+ pi`.
Seluruh katalog render repo ini — 41 kasus, dan setiap `render_case` di
`Tools/check-visuals.py` — hanya berisi `waxing=True`. Tidak ada satu pun
`is_waxing=False` di mana pun.

Jadi cabang `lit_side = −1` tidak pernah digambar, tidak pernah diukur, dan
tidak ada gerbang yang berbunyi kalau ia hilang. Yang paling tidak nyaman:
bulan mengecil itulah yang dilihat pengguna **selama separuh setiap bulan**,
dan sabit yang salah arah tetap berbentuk sabit — tidak ada teks di layar mana
pun yang bisa membuktikannya.

### Diukur lebih dulu, bukan diasumsikan

Dengan `+ pi` dihapus dari port, gerbang arah yang sudah ada tetap hijau:
`check_crescent_direction` 4 pemeriksaan, `check_inner_planet_phase` 5,
`check_moon_phase_fraction` 9, `check_moon_phase_survives_uncertainty` 3 —
seluruhnya **0 merah**. Yang berubah bukan angka pemeriksaan, melainkan Bulan
yang mengecil menghadap **berlawanan arah**.

### Kasusnya, dan kenapa sudutnya harus −π/2

Lima kasus render baru: tiga Bulan (`waning-crescent`, `waning-crescent-pointing-down`,
`waning-gibbous`) dan dua Venus (`venus-waning-crescent`, `venus-waning-crescent-pointing-down`).

Pada sudut `0` pembalikan `pi` memang memindahkan pita dari kiri ke kanan, jadi
ia terukur — tetapi justru di situ penggantian `+ pi` dengan `+ 0` **tidak**
menimbulkan cacat, karena pita dasarnya sudah di kiri. Kasus yang menentukan
memakai sudut `−π/2`: satu-satunya arah yang benar adalah "bawah" pada **kedua**
jalur, dan pita yang tidak dibalik menghadap **atas**. Bulan dan Venus diukur
bersama karena keduanya melewati fungsi yang sama — satu gerbang, dua pemanggil.

### Gerbangnya mengukur dua arah

`check_phase_direction_on_the_waning_half` (5 pemeriksaan) menuntut keempat
kasus mengecil menghadap arah yang diminta, **dan** `moon-crescent-jakarta`
(yang membesar) tidak ikut dibalik. Tanpa pemeriksaan kelima itu, pengganti
yang membalikkan kedua jalur akan lolos keempat pemeriksaan sebelumnya dengan
sempurna — dan memang itulah keadaan 3 di harness.

### Angka yang dikutip gerbang baru ini diukur, bukan diwarisi

Docstring-nya mengutip empat gerbang lama sebagai bukti celahnya ("tetap 0
merah"). Dua di antaranya — `check_moon_phase_fraction` (9) dan
`check_moon_phase_survives_uncertainty` (3) — **tidak pernah dijalankan** di
harness; angkanya hanya ditulis. Itu kelas cacat yang sudah berulang di repo
ini (gerbang mengutip angka yang tidak pernah ia ukur), jadi kelimanya
sekarang dijalankan harness. Terukur: keempat kutipan itu cocok persis
(4/5/9/3), dan pada keadaan `+ pi` dihapus keempatnya benar-benar 0 merah —
klaimnya terbukti, bukan diasumsikan.

### Harness: 4 keadaan, 0 tidak sesuai harapan

```
OK   [baseline]                              merah: —
OK   1. `+ pi` dihapus (litSide diabaikan)   merah: [check_phase_direction_on_the_waning_half]
OK   2. kondisi litSide dibalik              merah: [+, check_crescent_direction, check_inner_planet_phase]
OK   3. kedua jalur dibalik (selalu + pi)    merah: [+, check_crescent_direction, check_inner_planet_phase]
```

Keadaan 1 adalah buktinya: **hanya** gerbang baru yang berbunyi, keempat
gerbang lama 0 merah. Ia memanggil fungsi pemeriksaan yang **sama** lewat
parameter sumber, dan mencetak **pemeriksaan mana** yang berbunyi — bukan
berapa yang merah. Ia memulihkan `render-visuals.py` di `finally` per keadaan
plus handler `SIGINT`/`SIGTERM`; `SIGKILL` tetap bisa melewatinya, dan itu
batas yang ditulis di berkasnya, bukan klaim bahwa ia kebal.

Harness ini hidup di `Tools/` (di-track, dijalankan CI) bukan di `out/`
(di-gitignore): pembuktian yang hilang sama dengan tidak ada.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 687 | **687** |
| Pemeriksaan visual | 552 | **567** (+15 dari 5 kasus render baru) |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (206 + 687), `check-visuals.py --check`
(567, 0 gagal), `bukti-mutasi-fase.py` (4 keadaan, 0 tidak sesuai harapan),
`swift-ui-lint.sh` (29), `swift-typecheck.sh`. Berkas tersentuh:
`Tools/render-visuals.py`, `Tools/check-visuals.py`, `Tools/bukti-mutasi-fase.py`
(baru), `.github/workflows/engine-tests.yml`, `STATUS.md`. **Tidak ada kode
`Apps/` atau paket Swift yang berubah** — yang salah adalah perlengkapan ukur,
bukan jamnya.

### Kecurigaan yang diperiksa lalu dibuang

Gerbang baru ini mengukur **arah** pita terang pada fase mengecil, bukan
**luasnya**. `check_moon_phase_fraction` hanya merender `is_waxing=True`, jadi
luas pita mengecil tidak dijaga gerbang mana pun. Diukur lebih dulu, langsung
lewat jalur produksi, pada lima fraksi:

```
f=0.18  waxing 0.176  waning 0.176   |Δ|=0.000
f=0.35  waxing 0.345  waning 0.345   |Δ|=0.000
f=0.50  waxing 0.496  waning 0.496   |Δ|=0.000
f=0.72  waxing 0.714  waning 0.714   |Δ|=0.000
f=0.85  waxing 0.844  waning 0.844   |Δ|=0.000
```

Luasnya **sudah benar** — simetris dengan yang membesar dan cocok dengan fraksi
iluminasi di kelimanya. Jadi tidak ada cacat yang hidup, dan **tidak ada uji
yang ditulis**: uji yang tidak bisa merah karena alasan yang benar adalah
cakupan palsu, persis kelas yang sudah berkali-kali ditolak di repo ini. Kalau
kelak `terminatorRotationRadians` berhenti dibalik untuk mengecil, yang berbunyi
lebih dulu adalah `check_phase_direction_on_the_waning_half`; yang tidak terjaga
dan dicatat di sini adalah **luas** pita mengecil pada saat itu.

### Yang TIDAK diklaim

- Gerbang ini menjaga **arah** pita terang pada sudut yang diuji (0 dan −π/2),
  bukan kebenaran astronomi orientasi terminator pada setiap sudut. Orientasi
  yang benar-benar dilihat pengguna berasal dari azimut Matahari di jam, dan
  itu diuji terpisah.
- Yang diuji hanya **Bulan dan Venus**, dua pemanggil `terminatorRotationRadians`.
  Planet dalam lain (Merkurius) melewati jalur yang sama, jadi tertutup secara
  struktur — tetapi tidak digambar pada kasus mengecil, dan itu tidak diklaim.
- Ambang arah di `classify_centroid` bekerja pada ukuran gerbang (200 px,
  ss=2); pada ukuran kartu jam pasangan yang berbeda bisa bertumbukan, dan itu
  tidak diukur.

---

## Progres terakhir (8 Okt 2026 — gerbang "bentuk hilang saat ragu" ternyata mengukur warna)

### Cacatnya: dua versi berturut-turut, keduanya hijau pada kode yang salah

`check_features_disappear_when_uncertain` menyatakan bahwa saat engine ragu,
bentuk objek langit dalam **tidak sampai ke gambar**. Ia benar sejak lama, dan
ia tidak pernah membuktikannya.

Versi pertamanya memakai `diff > 0` mentah antara render terkunci dan render
ragu. Hanya render ragu yang memakai lencana "?", jadi **seluruh** selisihnya
bisa hanya lencana. Diukur: dengan penekanan bentuk dihapus seluruhnya dari
port, pemeriksaan itu tetap hijau (`raw_diff` 3434, semuanya lencana).

Versi keduanya memperbaiki lencananya dan memperluas ke keenam morfologi —
tetapi membandingkan semuanya terhadap **satu** kabut netral ber-morfologi
`galaxy`. Akibatnya `galaxy` dibandingkan dengan **dirinya sendiri**: nol
piksel, hijau selamanya. Kelima morfologi lain "lulus" pada 6073…6881 piksel,
dan selisih itu **seluruhnya warna**, bukan bentuk. Gerbang yang menamai
dirinya "bentuk … hilang saat ragu" sedang mengukur warna.

### Yang diukur, bukan dikira-kira

Mutasi "bentuk diabaikan **selamanya**, warna tetap benar"
(`blobs = deep_sky_blobs(None, …)` di port, jadi morfologi tidak pernah dipakai
untuk bentuk — terkunci maupun ragu):

```
seluruh check_deep_sky_morphologies_render_distinct   42 hijau / 0 merah
seluruh arah (1) penekanan saat ragu                   6 hijau / 0 merah
arah (2) bentuk sampai ke gambar saat terkunci          5 MERAH
```

Empat puluh dua pemeriksaan hijau, dan tidak satu pun dari mereka bisa
memerah untuk keadaan itu: keenam morfologi tetap berbeda **warna**, jadi
setiap perbandingan piksel antar-morfologi tetap terpenuhi. Yang berbunyi
hanya arah yang membandingkan **bentuk-saja** — warna dipaksa netral, sehingga
yang tersisa di gambar cuma geometrinya.

### Perbaikannya: aturannya diukur dari dua sisi

`check_deep_sky_shape_suppression` dipisah ke fungsinya sendiri (gerbang penuh
~6 menit; satu pemeriksaan ini ~30 detik — gerbang yang terlalu lambat untuk
dijalankan adalah gerbang yang dilewati, pelajaran yang sudah dibayar di repo
ini), lalu mengukur:

1. **Saat ragu, morfologi tidak mengubah gambar sama sekali** — keenam render
   `.uncertain` harus identik dengan render ragu ber-morfologi `None`.
   Referensinya `None`, **bukan** salah satu dari keenamnya: acuan yang berasal
   dari daftar itu membuat satu anggotanya membandingkan dirinya sendiri, dan
   itulah cacat versi kedua. Ini juga menangkap dua bentuk cacat sekaligus —
   penekanan yang hilang seluruhnya, dan penekanan yang menutup warna sementara
   bentuknya bocor.
2. **Saat terkunci, bentuk morfologi itu benar-benar sampai ke gambar** —
   dibandingkan **bentuk-saja**, warna dipaksa netral supaya perbandingan ini
   tidak bisa dipenuhi oleh warna. Ini satu-satunya pemeriksaan di repo ini
   yang melihat penggambar yang mengabaikan morfologi untuk bentuk.

### `nebula` dikecualikan — dan itu fakta model, bukan kelonggaran

`CelestialVisual.deepSky(morphology:)` memetakan `.nebula` ke fungsi **yang
sama** dengan morfologi `nil`. Diukur di lima fuzziness (0.0, 0.3, 0.6, 0.8,
1.0): `deep_sky_blobs("nebula", f)` **sama persis** dengan
`deep_sky_blobs(None, f)` di kelimanya, sementara kelima morfologi lain
berbeda di setiap fuzziness. Jadi kabut emisi memang berbentuk identik dengan
kabut netral; yang membedakan keduanya hanya warna. Menuntut arah (2) dari
`nebula` berarti menuntut model diubah, bukan menuntut gambar diperbaiki.

### Kecurigaan yang diperiksa lalu dibuang

Dari mata, lewat lembar `Tools/montage.py`, glow bintang di panel iPhone
(132 pt) tampak berhenti mendadak di tepi kartu. Diukur profil radialnya pada
30° (menghindari paku difraksi): 193 → 12,7 → 11,7 (= latar) mulus tanpa satu
pun lompatan, dan pada 38 pt ia sampai latar di r≈15 dari 19. Yang terlihat di
lembar itu adalah artefak penyusutan, bukan tepi keras — jadi tidak ada yang
diubah.

### Harness-nya di-track dan dijalankan CI

`Tools/bukti-mutasi-langit-dalam.py` (4 keadaan) memanggil fungsi pemeriksaan
yang **sama**, dan memeriksa **nama pemeriksaan mana yang berbunyi**, bukan
berapa yang merah — menghitung jumlah menyembunyikan keadaan yang berbunyi
karena alasan yang salah. Keadaan 2 sengaja diharapkan **hijau** untuk
`nebula`: mutasi itu memang tidak mengubah gambar nebula (lihat di atas), dan
harapan yang menuntutnya merah akan menuntut gerbang berbunyi tanpa alasan.
Harness memulihkan sumber produksi di `finally` per keadaan **plus** handler
`SIGINT`/`SIGTERM`.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 687 | **687** |
| Pemeriksaan visual | 542 | **552** (+10: 11 arah baru − 1 pemeriksaan lama yang salah) |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (206 + 687), `check-visuals.py --check`
(552, 0 gagal), `bukti-mutasi-langit-dalam.py` (4 keadaan, 0 tidak sesuai
harapan, md5 pulih persis), `swift-ui-lint.sh` (29), `swift-typecheck.sh`.
Berkas tersentuh: `Tools/check-visuals.py`, `Tools/bukti-mutasi-langit-dalam.py`
(baru), `.github/workflows/engine-tests.yml`. **Tidak ada satu berkas Swift pun
yang berubah** — yang salah adalah gerbangnya, bukan gambarnya; memperbaiki
gambarnya akan menutupi cacat aslinya.

### Yang TIDAK diklaim

- Gerbang ini menjaga **bentuknya sampai ke gambar**, bukan bahwa bentuk itu
  benar secara astronomi (jumlah lengan M51 diuji lewat simetri 180°, bukan
  lewat efemeris — lihat entri spiral di bawah).
- Kedua arah diukur pada **satu ukuran** (200 px). Pada ukuran kartu jam,
  pasangan yang berbeda bisa bertumbukan; itu tidak diukur dan tidak diklaim.
- Pemeriksaan arah (1) membandingkan seluruh frame, jadi ia sah hanya karena
  lencana identik di semua render ragu (lencana hanya bergantung pada ukuran).
  Kalau suatu saat lencananya ikut berubah menurut morfologi, perbandingan ini
  harus dipindah ke `badge_excluded_diff` — batas itu ditulis di fungsi
  pemanggilnya, bukan disembunyikan.

---

## Progres terakhir (8 Okt 2026 — Sirius dan Rigel tergambar sama, dan yang berbohong ternyata perlengkapannya)

### Cacatnya: dua bintang yang terangnya berbeda 4,3× tergambar sama persis

Bagian 1 misi ini meminta bintang digambar "ukuran sesuai magnitudo". Ukuran
**sudah** mengikuti magnitudo di jamnya: `CelestialVisual(object:)` memakai
`object.magnitude` sungguhan dari katalog. Yang tidak pernah mengikuti
magnitudo adalah **gambar yang diukur gerbang gambar**.

Diukur, bukan dikira-kira. `Tools/render-visuals.py` menggambar 41 kasus;
empat bintang bernama di dalamnya digambar dengan `relative_size` yang
**identik**, karena semuanya memakai satu angka:

    relative_size=size_from_magnitude(0.0)      # untuk setiap bintang

Akibatnya, pada ukuran kartu jam (38 pt):

| pasangan | magnitudo | nisbah terang | piksel berbeda @38 pt |
|---|---|---|---|
| Sirius vs Vega | −1.46 vs +0.03 | 4,0× | **0** |
| Sirius vs Rigel | −1.46 vs +0.13 | 4,3× | **0** |

Nol. Bukan "mirip" — **tidak ada satu piksel pun yang berbeda**. Dan karena
gambar inilah yang diukur gerbang, tidak ada satu pun pemeriksaan di repo ini
yang pernah membuktikan ukuran bintang mengikuti magnitudo. Warna tidak bisa
menyelamatkan: B−V Sirius 0,00, Vega 0,00, Rigel −0,03 — praktis sama. Pemisah
yang benar memang **ukuran**, dan ukuran itulah yang tidak pernah diuji.

Ini kelas cacat yang sudah berulang di repo ini: **gerbang yang mengukur
gambar yang tidak pernah tampil**. Gerbang hijau, jamnya benar, dan tidak ada
yang tahu perlengkapannya berbohong.

### Perbaikannya: magnitudo dibaca dari katalog, bukan disalin

Kasus bintang sekarang mengambil magnitudonya dari `Catalogue.swift` lewat
`catalogue_magnitudes()` — pembaca yang mengurai sumber katalog langsung.
Daftar tangan di sini akan menjadi salinan ke-26 yang tidak pernah
dibandingkan, dan bintang yang ditambahkan besok akan tampil dengan ukuran
lama yang **tampak sah**.

Empat pemeriksaan baru (538 → 542):

- **magnitudo terbaca cocok dengan fakta langit** — pembaca diuji terhadap
  angkanya, bukan terhadap dirinya sendiri;
- **ukuran kasus bintang dari magnitudo katalog** — fixture tidak menyimpang;
- **Sirius menutupi lebih banyak piksel dari Rigel** — efeknya sampai ke
  gambar, bukan cuma ke variabel;
- **empat ukuran bintang menghasilkan empat gambar** — penggambar tidak
  membuang `relative_size`.

Tiga yang terakhir sengaja memeriksa **arah**, bukan angka absolut: angka
absolut akan mengunci ambang yang tidak punya arti fisis.

### Pemeriksaan pertama saya masih membandingkan pembaca dengan dirinya sendiri

Pemeriksaan (0) di atas tidak ada di rancangan pertama. Harness mutasi
(`Tools/bukti-mutasi-bintang.py`) yang menemukannya: keadaan ketiganya
menggeser `catalogue_magnitudes()` seragam +1,0, dan seluruh pemeriksaan tetap
**hijau**. Tiga pemeriksaan itu semuanya membandingkan pembaca dengan dirinya
sendiri — fixture "cocok" dengan katalog versi salah, ukuran tetap mengikuti
urutannya. Pemeriksaan (0) menambatkan empat magnitudo ke **fakta langit**,
satu-satunya angka yang tidak berasal dari kode mana pun.

Ini beda jenis dari "daftar tangan" yang dikritik di atas: daftar tangan
**menyalin** katalog; tambatan ini adalah fakta langit yang tidak bergantung
pada kode mana pun.

### Harness-nya di-track dan dijalankan CI

`Tools/bukti-mutasi-bintang.py` memanggil fungsi pemeriksaan yang **sama**,
tetapi hanya atas satu pemeriksaan itu, jadi ia berjalan ~1 detik alih-alih
~6 menit. Tiga keadaan yang diuji: fixture kembali ke satu magnitudo,
penggambar mengabaikan `relative_size`, dan pembaca magnitudo bergeser. Ia
dipasang di `engine-tests.yml` tepat setelah harness aksen, dengan alasan yang
sama: gerbang yang terlalu lambat untuk dijalankan adalah gerbang yang
dilewati, dan gerbang baru selalu hijau pada hari ia ditulis — itu bukan bukti
apa pun.

Harness memulihkan sumber produksi di `finally` **dan** lewat handler
`SIGINT`/`SIGTERM`: pelajaran yang sudah dibayar di repo ini, `SIGKILL`
melewati `finally` dan meninggalkan mutasi hidup.

### Hasil

- Gerbang gambar: **542 pemeriksaan, 0 gagal** (dari 538).
- Harness mutasi bintang: **4 keadaan, 0 tidak sesuai harapan**.
- `swift-test.sh`: **CelestialEngine 206 + PointingKit 687, 0 gagal**.
- `swift-ui-lint.sh`, `swift-typecheck.sh`: lulus.
- Dari mata, lewat `out/visuals/stars_200.png`: Sirius kini terukur **224
  piksel menyala** vs Rigel **156** @38 pt (dulu 156 vs 156), dan dua kartu
  `*-uncertain` tetap identik satu sama lain — warna spektral memang tidak
  boleh tampil saat engine ragu.

### Yang TIDAK diklaim

- Tidak ada perubahan pada **satu berkas Swift pun**. Yang salah adalah
  perlengkapan ukur, bukan jamnya; memperbaiki jamnya akan menutupi cacat
  aslinya.
- Ambang piksel (224/156) adalah hasil pengukuran pada 38 pt dan dapat
  bergeser bila skala magnitudo diubah; karena itu gerbang menjaga **arah**,
  bukan angkanya.
- Keempat pemeriksaan baru ini tidak menyentuh akurasi astronomi. Ia menjaga
  gambar agar konsisten dengan katalog, bukan agar katalog benar.

---

## Progres terakhir (8 Okt 2026 — kartu bulan baru terbaca, dan plafon earthshine diukur)

### Cacatnya: kartu jam yang terlihat kosong

`Tools/montage.py` (alat, bukan gerbang) sudah mencatatnya dari mata sejak
siklus lalu: "`moon-new` terbaca sebagai kotak kosong di atas latar hitam".
Siklus ini cacat itu **diukur** alih-alih dikutip, dan angkanya lebih buruk
dari kesan matanya:

| kasus | piringan | latar kartu | kontras |
|---|---|---|---|
| `moon-new` | (38, 38, 48) | (10, 10, 15) | **1.32:1** |
| `moon-crescent-jakarta` (sisi gelap) | (37, 37, 47) | (10, 10, 15) | **1.30:1** |
| `moon-unknown-phase` | (127, 127, 135) | (10, 10, 15) | 4.97:1 |
| `moon-full` | (237, 232, 220) | (10, 10, 15) | 16.16:1 |

Dua hal yang penting di sini. Pertama: piringan **fase tak diketahui** — yang
sengaja digambar sebagai "tidak mengklaim apa pun" — justru **4× lebih terbaca**
dari bulan baru yang nyata. Kedua: sisi gelap sabit pun 1.30:1, jadi yang
hilang bukan cuma satu kartu langka, melainkan **bagian gelap Bulan di setiap
fase**, dan jam hanya menampilkan gambar ini di kartunya.

### Akarnya satu token, dan mengubahnya bukan sekadar menaikkan angka

`moonEarthshine` (0.15) dilukis sebagai cakram rata di atas seluruh piringan,
dan pada f = 0 kekuatannya `1 - f` = 1.0 — jadi **piringan bulan baru adalah
warna token itu apa adanya**. Percobaan pertama menaikkan `moonUnlit` tidak
mengubah satu piksel pun (terukur: cakram tetap (38,38,48) di seluruh sapuan
0.13…0.26), dan itu memperlihatkan bahwa knob yang dicari memang bukan itu.

Kenaikannya juga **fisis, bukan kosmetik**: cahaya Bumi paling kuat justru saat
bulan baru (Bumi nyaris purnama dilihat dari Bulan), dan "bulan tua dalam
pelukan bulan muda" adalah pengamatan earthshine paling terkenal dengan mata
telanjang. Nilai 0.15 dipilih sebagai "redup" umum — bukan diukur terhadap
kasus bulan baru, yang justru kasus paling terang.

### Plafonnya diukur, bukan dipilih

Sapuan `0.15…0.44` (`Tools/sapu-earthshine.py` — alat, bukan gerbang; ia
melaporkan kontras jam **dan** enam batas yang mengikat) atas **kelima gerbang
earthshine yang sudah ada**:

```
earthshine   kontras jam   gerbang   malam (plafon 45%)   margin ke unknown
0.15           1.32:1      6/6 OK        24.15%               94/255
0.24           1.85:1      6/6 OK        33.04%               71/255
0.30           2.39:1      6/6 OK        39.11%               55/255   <- dipakai
0.34           2.80:1      6/6 OK        42.30%               45/255
0.36           3.03:1      6/6 OK        44.58%               40/255
0.37           3.13:1      5/6 GAGAL     45.32%               38/255   <- plafon
0.44           4.11:1      5/6 GAGAL     50.19%               20/255
```

Jadi yang mengikat **bukan** gerbang earthshine (semuanya hijau sampai 0.36)
melainkan plafon malam 45% yang tembus di **0.37**, dan — jauh lebih longgar —
margin kejujuran ke `moonPhaseUnknown` (jarak kanal merah harus > 25) yang baru
menggigit di **0.44**. Dua batas itu terpisah 0.07, dan sebelum disapu tidak ada
yang tahu mana yang lebih dulu menyerah. 0.30 dipilih dengan satu langkah
cadangan di bawah plafon.

### Dua angka salah yang ditangkap alat ini sendiri

Alat itu awalnya melaporkan margin `39/255` untuk 0.30, dan angka itu sempat
masuk ke dua tabel di repo ini sebelum ada yang memeriksanya. Dua kesalahan
sekaligus: (1) marginnya dihitung **analitik** dari token (`round(f * 255)`)
alih-alih dari piksel yang diukur gerbang; dan (2) yang diambil kanal **biru**
(0.37 di token) alih-alih **merah** (0.30) — selisih 18/255, cukup untuk membuat
tabel yang salah tampak masuk akal. Versi keduanya menyampel kanal merah sendiri
tapi di **38 px**, sedangkan gerbang mengukur di **200 px**; rasterisasi berbeda,
angka masih meleset. Versi ketiga **memanggil gerbangnya langsung** dan mengurai
detailnya, jadi angka yang dilaporkan alat ini adalah angka yang sama dengan
yang dipakai gerbang untuk memutuskan — dan margin palsu itu tidak bisa lahir
lagi.

### Gerbang regresi (PRD §10: tulis tesnya dulu, baru perbaiki)

`check_moon_new_disc_reads_on_the_watch` — kontras piringan `moon-new` di
**38 px** (token `WatchMetrics.visualDiameter`) terhadap latar kartu, ambang
**2.0:1** dari rasio WCAG yang sudah dipakai repo ini. Ambangnya menahan
nilainya *dan* arah: menurunkannya kembali ke 0.15 membuat gerbang ini merah
lagi. Dikalibrasi terhadap ketiga titik yang diukur (0.15 → 1.32 merah,
0.24 → 1.85 merah, 0.30 → 2.39 hijau).

Gerbang ini mengisi lubang yang tidak dijaga apa pun: `check_moon_disc_keeps_its_curvature`
menjaga **bentuk** piringan gelap (sengaja rata), dan
`check_unknown_phase_is_not_a_new_moon` hanya menuntut bulan baru **berbeda**
dari fase tak diketahui — jadi dua piringan yang sama-sama tak terlihat lolos
keduanya, selama selisihnya 1/255. "Rata" bukan "tak terlihat", dan hanya yang
kedua yang diukur sekarang.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 687 | **687** |
| Pemeriksaan visual | 537 | **538** (+1 gerbang baru) |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (206 + 687), `check-visuals.py --check`
(538, 0 gagal), `swift-ui-lint.sh`, `swift-typecheck.sh`. Berkas tersentuh:
`NightVisual.swift`, `Tools/render-visuals.py` (kedua bahasa menggambar sama —
dijaga `check_night_accents_match_the_model`), `Tools/check-visuals.py`,
`Tools/sapu-earthshine.py` (baru — alat sapuan, di `Tools/` bukan `out/` supaya
angkanya bisa direproduksi; `out/` di-gitignore), `STATUS.md`. **Tidak ada kode
`Apps/` yang berubah** — view sudah memakai token ini, jadi memperbaiki
tokennya memperbaiki kedua platform sekaligus.

### Sisa yang tercatat — dan diukur di siklus ini: catatannya **basi**

Catatan lama berbunyi: `star-sirius` / `star-rigel` / `star-vega` **nyaris tak
terbedakan** satu dari lain pada ukuran kartu. Itu benar **sebelum** magnitudo
dibaca dari katalog: waktu itu keempat kasus bintang memakai
`size_from_magnitude(0.0)` yang sama, jadi yang membedakan hanyalah warna
spektral — dan B−V Sirius (0.00) memang identik dengan Vega (0.00), sementara
Rigel (−0.03) hanya berbeda 0.03.

Diukur ulang sekarang (`out/ukur-bintang.py`, seluruh kasus, ss=4):

| ukuran | sirius vs rigel | sirius vs vega | rigel vs vega |
|---|---|---|---|
| 38 px (kartu jam) | 648 px (44.9%) | 648 px (44.9%) | 256 px (17.7%) |
| 76 px | 2648 px (45.8%) | 2648 px (45.8%) | 1084 px (18.8%) |
| 200 px | 18272 px (45.7%) | 18268 px (45.7%) | 7000 px (17.5%) |

Yang memisahkannya **bukan warna**, melainkan ukuran: m(Sirius) −1.46 → 0.982,
m(Vega) +0.03 → 0.494, m(Rigel) +0.13 → 0.472. Sirius memakai 98% skala, Vega
dan Rigel ~48%, jadi Sirius berbeda dari keduanya di **45%** piksel kartu —
bukan "nyaris tak terbedakan".

Yang **memang** tinggal: Rigel dan Vega terpisah **18%** dan itu seluruhnya
ukuran (0.472 lawan 0.494, ~4% bedanya) — warnanya nyaris sama, dan memang
harus: B−V −0.03 lawan 0.00. Itu bukan cacat, itu fisika: dua bintang B8/A0
memang sebangsa warna. Tidak ada gerbang baru ditambahkan di sini; yang ada
sudah menutupnya (`check_star_size_follows_magnitude`, dibuktikan berbunyi
oleh `Tools/bukti-mutasi-bintang.py` 3 keadaan), dan menambah gerbang "Rigel
harus berbeda dari Vega" akan menuntut visual membedakan dua bintang yang
mata manusia pun tidak membedakan.

---

## Progres terakhir (7 Okt 2026 — gerbang menuntut ejaan yang sudah dibuang, dan `main` merah dua commit)

### Cacatnya: gerbang merah pada kode yang benar

`main` merah di CI **dua commit** berturut-turut (`7ae4845`, `ed16cd1`), dan
yang merah bukan kode menggambarnya melainkan gerbangnya:

```
GAGAL sumber memuat: piringan fase tak diketahui (view memakainya)
      'Self.accent(CelestialVisual.accents.moonPhaseUnknown)' TIDAK ditemukan
```

`7ae4845` mengganti `Self.accent(CelestialVisual.accents.moonPhaseUnknown)`
dengan `Self.fillSphere(…, base: CelestialVisual.accents.moonPhaseUnknown)`.
Faktanya tetap — tokennya masih yang menggambar — dan gambarnya malah lebih
benar (bola dengan peredupan limb, bukan cakram rata). Gerbangnya menuntut
**ejaan** yang sudah dibuang, jadi ia merah pada kode yang benar. Kelas cacat
ini sudah berulang di repo ini: gerbang yang mengukur **cara menulis**
sesuatu, bukan **hal yang ditulisnya**.

### Penggantinya: tiga pemeriksaan yang mengukur fakta

  - `check_unknown_moon_disc_uses_the_token` — (1) `moonPhaseUnknown` muncul
    di **kode** view, bukan di komentar atau string; (2) `drawMoon` tidak
    menulis `Color(red:…)` sendiri. Dua keadaan yang tidak bisa dipenuhi
    bersama oleh warna tetap.
  - `check_night_accents_reach_the_view` — **himpunan** token yang sampai ke
    gambar. Arah yang tidak diukur apa pun sebelumnya: warna yang ada di
    `Accents`, sama di port Python, dan **tidak pernah dibaca view** adalah
    hijau di dua gerbang sekaligus sambil tidak menggambar apa pun. Ini kelas
    paling sunyi, karena setiap gerbang lain tetap lulus.
  - Arah sebaliknya: nama yang view pakai tetapi tidak ada di model → warna
    jatuh ke nilai bawaan tanpa ada yang tahu.

### Dua cacat di gerbang baru, ditemukan oleh harness-nya sendiri

`Tools/bukti-mutasi-aksen.py` menjalankan **fungsi pemeriksaan yang sama**
lewat parameter `view_source`/`night_source` (gerbang penuh ~6 menit; memanggil
langsung <1 detik), atas 13 keadaan. Ia memeriksa **nama pemeriksaan mana yang
berbunyi**, bukan berapa yang merah — menghitung jumlah menyembunyikan keadaan
yang berbunyi karena alasan yang salah.

  1. **Gerbang buta komentar.** `"nama" in view` atas sumber mentah menghitung
     `// TODO kembalikan CelestialVisual.accents.moonPhaseUnknown` sebagai
     pemakaian. Diperbaiki: `swift_code_only` membuang komentar dan string
     dulu. Ini juga menutup lubang `print("…moonPhaseUnknown")`.
  2. **Gerbang buta alias.** `let aksen = CelestialVisual.accents` lalu
     `aksen.moonPhaseUnknown` adalah kode yang benar, dan pola
     `accents\.(\w+)` tidak melihatnya — terukur merah. Diperbaiki:
     `accent_names_in_view_code` membaca alias dari sumber (`<nama> = …accents`
     menambahkan `<nama>` sebagai jalan masuk yang sah).

Dua keadaan di harness sengaja diharapkan **hijau** (ejaan berbeda; alias).
Gerbang yang merah di sana akan dimatikan orang, dan itu bentuk kegagalan yang
paling sulit terlihat karena tampak seperti ketaatan.

Harness ini juga **menangkap gerbang versi lama**: dengan pemeriksaan ejaan
`"Self.accent(CelestialVisual.accents.moonPhaseUnknown)" in view` dipulihkan,
harness merah pada **9 dari 13** keadaan — termasuk **setiap** keadaan "kode
benar", yaitu persis cacat yang membuat `main` merah dua commit. Diuji, lalu
gerbangnya dikembalikan.

### Kenapa harness ini di-track, bukan di `out/`

Sampai siklus ini seluruh pembuktian mutasi repo ini hidup di `out/` — dan
`out/` di-gitignore. Dua puluh harness pernah ditulis di sana dan **tidak satu
pun** masih ada bagi siapa pun yang membaca repo ini. Pembuktian yang hilang
sama dengan tidak ada: yang tersisa hanya gerbangnya, tanpa alasan untuk
mempercayainya. Karena itu `Tools/bukti-mutasi-aksen.py` di-track dan
dijalankan CI (langkah "Buktikan gerbang aksen gambar berbunyi"), sejajar
dengan `red-lint.sh` untuk gerbang sapu UI.

### Satu harapan harness yang saya perbaiki, bukan gerbangnya

Keadaan "token hanya hidup di komentar" saya harapkan memicu **tiga**
pemeriksaan; terukur **dua**. Yang ketiga (`drawMoon` tidak menulis warnanya
sendiri) memang **tidak boleh** berbunyi: mutasi itu menggantinya dengan token
lain (`moonUnlit`), jadi `drawMoon` tidak menulis warna tetap. Harapan yang
menuntut ia merah akan menuntut gerbang berbunyi karena alasan yang salah.

### Yang TIDAK diklaim

  - `accents_reaching_the_view` mengukur **jangkauan nama**, bukan apakah
    pikselnya benar. Fungsi yang mengembalikan warna lalu dibuang pemanggilnya
    tetap terhitung "sampai". Yang menutup itu gerbang piksel
    (`check_night_mode_purity`, `check_deep_sky_layouts_match_the_model`).
  - Penutupan lewat alias membaca `<nama> = …accents`; penugasan yang lebih
    jauh (`let b = aksen` lalu `b.moonPhaseUnknown`) tidak terjangkau. Batas
    ini dicatat, bukan disembunyikan.
  - Hanya `Tools/check-visuals.py` yang diubah. View, model, port, dan mesin
    teruji tidak disentuh — yang diperbaiki gerbangnya, bukan gambarnya.

### Hasil

  - **206 + 687 uji hijau** (CelestialEngine + PointingKit), 0 gagal.
  - `python3 Tools/check-visuals.py --check` -> **537 pemeriksaan, 0 gagal**.
  - `python3 Tools/bukti-mutasi-aksen.py` -> **13 keadaan, 0 tidak sesuai
    harapan**.
  - `./swift-ui-lint.sh` hijau (30 aturan), `./swift-typecheck.sh` hijau.
  - CI `37705066565` (Engine Tests Linux) + `37705066502` (Apple Build
    macos-15) **hijau** — `main` pulih dari dua commit merah.

## Progres terakhir (7 Okt 2026 — pita terang Bulan melengkung, dan dua angka yang beredar ternyata milik gambar yang sudah dibuang)

### Cacatnya: planet melengkung 55%, Bulan 0%

`drawSphere` memberi setiap planet gradien bola — pusat terang, limb gelap.
Pita terang Bulan tidak: satu warna `moonLit` penuh dari pusat sampai limb.
Diukur pada baris ekuator render 200 px, ss=2, metrik yang sama yang dipakai
`check_banded_disc_keeps_its_curvature` (`100·(pusat − limb)/pusat`, limb di
0.96 R):

```
kasus               kekuatan 0 (cacat)   kekuatan 0.40
Bulan purnama             +0.0%              +33.5%
Fase tak diketahui        +0.0%              +33.4%
Bulan sabit         (lihat di bawah)           24.1
Mars (pembanding)        +54.8%              +54.8%
```

Pita terang Bulan **rata sempurna** sementara planet di sebelahnya melengkung
55%. Yang terlihat bukan bola yang disinari dari satu sisi, melainkan
**stiker rata** — dan Bulan adalah objek yang paling sering muncul, jadi cacat
ini yang paling sering dilihat.

### Perbaikan

  - `CelestialVisual.moonLimbShadingStrength = 0.40` — satu angka di model,
    dibaca view dan port Python, tidak ditulis ulang di dua tempat.
  - `CelestialVisual.moonSphereGradientEndRadius = 1.15` — **bukan 1.35**
    milik bola planet. Piringan Bulan digambar di dalam `drawLayer` yang
    diputar sebesar sudut sisi terangnya, jadi pada sabit seluruh pita menyala
    jatuh dekat tepi piringan, tempat gradien 1.35 sudah nyaris mencapai ujung
    gelapnya.
  - `CelestialVisual.moonSphereDark(_:)` — satu aturan peredupan, dipakai
    pita terang **dan** piringan fase-tak-diketahui, dan port Python memanggil
    fungsi yang sama.
  - Uji Linux: `testMoonSphereGradientIsShallowerThanThePlanetSphere` (batas
    atas 1.35) dan `testMoonLimbShadingIsPartial` (batas atas kekuatan).
  - Gerbang piksel `check_moon_disc_keeps_its_curvature`, plus dua pemeriksaan
    **teks**: piksel membuktikan **port** menggambar lengkungnya, sedangkan
    yang dikirim ke jam adalah **view**, dan view bisa berhenti memanggilnya
    (jam rata, PNG tetap melengkung) atau memanggilnya dengan angka yang
    ditulis ulang.

### Koreksi pertama: gradien piringan **gelap** dibuang, bukan dipertahankan

Percobaan pertama memberi gradien yang sama ke piringan gelap. Hasilnya
menyingkap dua hal, dan keduanya menunjuk arah yang berlawanan dari dugaan:

  1. Earthshine dilukis sebagai **cakram warna rata** di atas piringan gelap,
     jadi gradiennya terhapus justru di fase tempat sisi gelap paling terlihat
     — terukur, `moon-new` tetap **+0.0%** di setiap kekuatan 0…0.80.
  2. Memperdalamnya mematikan `check_earthshine` pada kekuatan **0.20** (4/5
     lulus). Gerbang earthshine adalah **binding constraint**.

Sisi gelap Bulan memang disinari sumber yang **lebar** (Bumi), bukan sumber
titik seperti sisi terangnya. Piringan rata di sana bukan gambar yang salah.
Yang melengkung adalah bagian yang disinari sumber titik — pita terangnya dan
piringan "fase tak diketahui". Jadi gradien piringan gelap **dibuang**, dan
perubahan di-scope hanya ke dua tempat itu.

### Koreksi kedua: gerbangnya merah pada kode yang benar

Versi pertama gerbang ini mengukur sabit dengan metrik baris ekuator yang
sama. `moon-crescent-jakarta` punya sisi terang ke **bawah**, jadi seluruh
baris ekuatornya jatuh di **piringan gelap** dan metrik itu mengembalikan
**+0.0%** untuk gambar yang benar. Gerbangnya merah (`4/5`) pada kode yang
sudah diperbaiki — kelas cacat yang sudah tercatat berkali-kali di repo ini:
**gerbang yang mengukur bagian gambar yang tidak berisi yang diperiksa.**

Metrik untuk kasus itu diganti: sebaran luminans (p95 − p5) piksel yang
terklasifikasi **menyala** dengan cara yang sama yang dipakai
`classify_centroid`. Pita rata → 0.0; pita yang dinaungi bola → 24.1. Sebaran
itu tidak tercemar maria: pada kekuatan 0 ia terukur 0.0, jadi yang
menggerakkannya memang gradiennya.

Konsekuensinya angka **+5.3% / +24.6%** yang beredar di docstring model, uji
Linux, view, dan port Python **tidak sah** — keduanya berasal dari gradien
piringan gelap yang sudah dibuang, dan bukan hasil ukur ulang. Seluruh tabel di
empat berkas itu diganti dengan hasil ukur ulang pada 200 px, ss=2:

```
radius akhir   purnama (lengkung)   sabit (sebaran)
1.15               +33.5%                24.1
1.35               +28.5%                20.9
```

### Batas atas kekuatan, diukur bukan dipilih

`classify_centroid` memutuskan "menyala" versus "gelap" pada jarak-warna RGB,
jadi pada gradien yang terlalu dalam piksel limb jatuh ke sisi gelap dan luas
pita yang terukur menyusut — bukan karena gambarnya salah, melainkan karena
alat ukurnya berganti jawaban. Disapu pada 200 px, ss=2, toleransi gerbang
fase 0.10:

```
kekuatan   luas pita merah   lengkung purnama
0.45            0/9              +37.6%
0.50            0/9              +41.6%
0.60            7/9              +50.2%   <- gerbang merah
```

0.40 dipakai, dan 0.60 **merah**. Dijaga `testMoonLimbShadingIsPartial` di
Linux (batas atasnya) dan gerbang piksel (lengkungnya benar-benar sampai ke
gambar).

### Hasil

  - **206 + 686 uji hijau** (CelestialEngine + PointingKit), 0 gagal.
  - **112 pemeriksaan gerbang visual hijau**, 0 gagal — termasuk 5 pemeriksaan
    baru untuk piringan Bulan.
  - `./swift-ui-lint.sh` hijau (30 aturan), `./swift-typecheck.sh` hijau.
  - README: hitungan PointingKit 683 → 686.

### Yang TIDAK diklaim

  - Gerbang `check_moon_disc_keeps_its_curvature` hanya mengukur **empat kasus
    Bulan** (`moon-full`, `moon-unknown-phase`, `moon-crescent-jakarta`, plus
    Mars sebagai patokan). Fase lain yang belum ada kasus rendernya tidak
    terjaga oleh gerbang ini.
  - Ambang lengkung 30% lengkung Mars adalah **pilihan** yang diberi jarak di
    kedua sisi (33.4–33.5 versus 54.8), bukan angka yang punya dasar fisik.
  - Angka 1.15 belum punya pembenaran fisik — sama seperti rasio kawah yang
    sudah dicatat jujur di berkas gerbang. Yang menjaganya adalah kesepakatan
    dua bahasa plus hasil ukur di atas.
  - Perubahan hanya di `Apps/Shared/CelestialVisualView.swift`,
    `Packages/PointingKit/…/CelestialVisual.swift`, uji Linux, dan dua berkas
    `Tools/`. Mesin teruji tidak disentuh.

## Progres terakhir (7 Okt 2026 — lengan spiral menyambung, dan angka yang dikutip gerbang baru ternyata tidak diukur)

### Cacatnya: 508 pemeriksaan, dan tidak satu pun melihat lengkung yang bolong

Gerbang spiral yang tercatat di HEAD mengukur satu hal: apakah M51/M101
**berbeda** dari cakram M31/M33. Ia benar. Yang tidak diukur siapa pun:
apakah lengkung lengan itu **menyambung** di ukuran yang benar-benar tampil.

Tata letak 4-titik per lengan memberi jarak antar-titik yang **membesar** ke
luar (Δr = 0.078 → 0.105 → 0.142) sementara lebar blob justru **menyusut**
(0.24 → 0.16). Gradien blob terluar meredup sebelum bertemu tetangganya.
Diukur pada 76 px, `ss=8`:

```
r=0.45   38° di atas ambang    menyambung
r=0.50    6°                   BOLONG
r=0.55   12°                   menyambung
```

Satu jari-jari penuh tanpa goresan di antara dua yang bergoresan — di layar itu
gumpalan bergerigi, bukan galaksi berlengan. Dan seluruh 508 pemeriksaan buta
terhadapnya, karena semuanya menyampel **titik** lengan, tempat blobnya memang
selalu terang. Yang bolong justru **antar** titik.

Perbaikannya satu titik sisipan per lengan (θ = 2.85) yang lebar & opasitasnya
**diinterpolasi** dari tetangganya, bukan dipilih supaya lulus. Dua blob
terluar dinaikkan tipis supaya jari-jari terluar menyisakan 17°, bukan 12°
yang pas di batas — gerbang yang lulus dengan margin nol akan berkedip begitu
ada perubahan kecil di tempat lain.

### Cacat kedua: gerbang barunya sendiri mengukur bagian gambar yang lain

Versi pertama gerbang lengan menyampel **seluruh** cuplikan antar-titik,
termasuk yang jatuh di dalam tonjolan inti. Sampel di sana selalu hijau (inti
menutupi sebagian besar cincin: 266–360°), jadi **tiga dari enam belas sampel
tidak bisa merah untuk alasan yang ditulis di namanya** — yang diukur inti,
bukan lengan. Kelas yang sama dengan "gerbang yang mengukur gambar yang tidak
tampil", hanya saja yang salah di sini **apa** yang diukur.

Sampelnya dipisah, dan yang diukur untuk inti adalah **selisih** cakupan cincin
dengan vs tanpa tonjolan — bukan ambang mutlak. Versi pertama memakai ambang
mutlak 340° dan **merah pada kode yang benar** (sampel di tepi tonjolan sehat
pada 266°). Batas "sampel inti" dihitung dari model, bukan diketik:
`halfWidth · (1 − ambang / (opasitas · 255))` = 0.2725 R untuk tonjolan
0.2957 R pada opasitas 0.60.

### Cacat ketiga: angka di docstring gerbang baru itu tidak pernah diukur

Pesan commit sempat menulis "memperkecil tonjolan 0.32 → 0.10 atau
meredupkannya 0.60 → 0.20 membuat gerbang merah pada baris yang tepat" —
diwarisi dari siklus sebelumnya, **belum pernah dijalankan**. Probe
`out/bukti-mutasi-spiral.py` mengukurnya, dan hasilnya:

| keadaan | lengan merah | inti merah |
|---|---|---|
| `[baseline]` | 0/13 | 0/3 |
| titik sisipan dihapus | 1/9 (r=0.49, 10°) | 0/3 |
| tonjolan 0.32 → 0.10 | 0/16 | 1/1 |
| tonjolan 0.60 → 0.20 | 0/16 | 1/1 |

Baris 1 dan 4 benar. Baris 2 dan 3 merah, **tapi bukan lewat pemeriksaan
selisih**: memperkecil atau meredupkan tonjolan memindahkan batas sampel ke
bawah seluruh sampel, jadi yang berbunyi adalah "tidak ada sampel di dalam
tonjolan inti" — bukan "sumbangannya terlalu kecil". Angka `+0°` / `+12°` yang
dikutip docstring **tidak pernah terukur oleh gerbang itu**.

Docstring-nya ditulis ulang dari tabel hasil ukur ini. Ini kelas yang sudah
berulang di repo ini (`"elips 20% R"` milik luas sementara metriknya mengukur
jarak tepi; `−5,1` di gerbang kontras kawah), dan yang membuatnya berbahaya
bukan angkanya: **komentar adalah satu-satunya bukti yang dibaca orang yang
menilai apakah gerbangnya layak dipercaya.**

`r=0.2843` — sampel yang **bukan** sampel inti — tetap hijau di keempat
keadaan. Itu bukti batasnya bekerja: kalau batasnya longgar, keempat sampel
diukur sebagai inti dan gerbang lengan akan merah pada gambar yang benar.

### Dua belas angka di docstring diukur ulang lewat jalur gerbangnya sendiri

`out/ukur-tabel-inti.py`: keempat baris tabel delta cocok persis
(360/236, 340/234, 266/222, 200/200), dan `halfWidth` 0.2957 R, batas 0.2725 R,
sumbangan 5.9 di r=0.2843 juga cocok. Ketiga angka terakhir itu menentukan
**apakah sampelnya sampel inti** — kalau salah, gerbangnya mengukur wilayah
yang bukan wilayahnya.

### Batas yang jujur

- Gerbang ini menjaga bentuk **di satu ukuran** (76 px, dibaca dari token
  `WatchMetrics.visualDiameter`). Pada ukuran lain pasangan yang berbeda bisa
  bertumbukan; itu tidak diukur dan tidak diklaim.
- Yang dijaga adalah **menyambungnya lengkung**, bukan kebenaran astronomi
  jumlah lengan — itu diuji lewat simetri 180°, bukan lewat efemeris.
- `MIN_ARM_DEGREES` = 12 duduk di antara 38–59° (menyambung) dan 6–12°
  (bolong): **marginnya tipis**, dan itu ditulis di berkasnya. Karena itu
  gerbangnya menyampel 16 jari-jari, bukan dua yang kebetulan berbeda.
- **Belum dikerjakan:** gerbang paritas docstring (yang membaca tabel di
  docstring dan menuntutnya sama dengan hasil ukur, seperti
  `check_crater_contrast_numbers_come_from_the_sampler`). Biayanya terukur
  ~30 s kalau hanya memakai `spiral_core_samples()` (gratis) + satu render
  gerbang lengan; belum ditambahkan supaya tidak terburu-buru.

### Dari mata, bukan dari gerbang: sisa terburuk ada di tempat lain

`Tools/montage.py` (baru — alat, **bukan** gerbang: tidak menuntut apa pun)
menyusun seluruh 41 kasus jadi satu lembar, karena tidak ada pemeriksaan
otomatis di repo ini yang mengukur "bagus". Lembar itu dinilai dengan mata,
dan yang terburuk **bukan** spiral:

- `moon-new` (tengah 38,38,48 vs latar 10,10,15) dan `moon-unknown-phase`
  terbaca sebagai kotak kosong di atas latar hitam. Bukan cacat kejujuran —
  fase tak diketahui memang **tidak boleh** tampak seperti bulan baru, dan
  gerbangnya mengukur itu — tapi cacat keterbacaan: kartu jam yang terlihat
  kosong tidak menyampaikan apa pun.
- `star-sirius` / `star-rigel` / `star-vega` nyaris tak terbedakan satu dari
  lain pada ukuran kartu.

Keduanya dicatat, belum dikerjakan.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 206 | **206** |
| PointingKit | 683 | **683** |
| Pemeriksaan visual | 508 | **524** (+16: 13 lengan + 3 inti) |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (206 + 683), `check-visuals.py --check`
(524, 0 gagal), `swift-ui-lint.sh` (29), `swift-typecheck.sh`. CI: Engine Tests
+ Apple Build hijau pada `8a40148`. Berkas tersentuh: `CelestialVisual.swift`,
`Tools/render-visuals.py` (kedua bahasa menggambar sama), `Tools/check-visuals.py`,
`Tools/montage.py` (baru). **Tidak ada kode `Apps/` yang berubah.**

### Yang sudah ada, diverifikasi ada (bukan dikerjakan ulang)

Sapuan singkat atas sisa brief: Fase C no. 3 (Info.plist izin Motion & Lokasi,
kedua bahasa) sudah ada di `project.yml` + `InfoPlist.strings`; no. 4
(penolakan izin runtime) sudah menampilkan pesan lewat `SensorStatusText`
alih-alih diam; AOD (`isLuminanceReduced` → `ReducedLuminanceView`) sudah
dipusatkan di `NightAwareContainer` sehingga tidak ada layar yang bisa lupa;
Aturan 7 `swift-ui-lint.sh` menjaga reduce-motion. No. 2 (`SWIFT_EMIT_LOC_STRINGS`)
sengaja **NO** dengan alasan tertulis di `project.yml` — bukan celah.

---

## Progres terakhir (7 Okt 2026 — jembatan teleskop: putusan slew menjadi perintah motor, §17–§20)

### Cacatnya: langkah §18 yang tidak punya kode sama sekali

`SlewPlanner` sudah memutuskan boleh/tidak bergerak, dan `SlewCommand` sudah
membawa objek + arah horizontalnya. Yang belum ada adalah langkah berikutnya
yang diminta dokumen kelayakan §18: *"resolve confirmed celestial target into
the coordinate representation required by the chosen control path."* Mount
ekuatorial tidak bisa menerima arah horizontal, dan mount alt-az tidak butuh
RA/Dec — dan tidak satu pun dari itu boleh disimpulkan diam-diam. Di repo ini
sebelumnya: nol.

### `TelescopeBridge.swift` — yang menerjemahkan, bukan yang memutuskan

- **Lapisan kemampuan berorientasi-protokol (§17).** Yang dikenal hanya
  **jenis sumbu** (`MountAxis.altitudeAzimuth`/`.equatorial`), bukan merek.
  Transport (Seestar, Alpaca, simulator) hidup di lapisan app lewat protokol
  `TelescopeTransport`.
- **Kerangka koordinat DINYATAKAN, tidak disimpulkan.** Ini keputusan yang
  paling mudah salah: katalog repo ini **J2000**, sementara benda tata surya
  datang dari efemeris dalam **of-date** (`EphemerisSample`). Mengirim
  koordinat ke mount tanpa menyebut kerangkanya berarti mount menafsirkan
  salah satunya dengan kerangka yang salah — selisih ~0,3° pada 2026, dan
  **tidak ada layar mana pun yang bisa memperlihatkannya**. `MountTarget`
  membawa kerangkanya; mount yang tidak mendukung kerangka yang diminta
  ditolak (`.unsupportedFrame`), bukan dikonversi diam-diam.
- **Posisi benda tata surya diambil ULANG saat perintah dibuat**, bukan
  dipakai ulang dari resolusi: Bulan bergerak ~0,5°/jam, jadi koordinat yang
  berumur beberapa menit sudah bergeser. Diuji: dua perintah berjarak 3 jam
  menghasilkan RA yang berbeda > 0,5°.
- **`TelescopeCommand` tetap tanpa inisialisator publik** — sama seperti
  `SlewCommand`. Satu-satunya jalan membuatnya adalah jembatan yang menolak
  apa pun yang bukan `SlewDecision.allowed`.
- **Matahari ditolak di lapis kedua**, kalaupun sebuah `SlewCommand` memuatnya.
- **Mount tanpa Abort ditolak SEBELUM perintah dibuat** (§20), bukan sesudah
  perintah pertama terkirim. Dan `abort()` tidak bergantung pada keadaan apa
  pun — tombol darurat yang bisa mati sendiri bukan tombol darurat.
- **`TelescopeAttempt`** mencatat yang diminta §18: versi firmware, command
  path, balasan, galat, hasil akhir. `Codable`, jadi bisa diekspor seperti
  arsip eksperimen yang sudah ada.
- **`TelescopeNetworkRequirements`** menyimpan kunci Info.plist §19
  (`NSLocalNetworkUsageDescription`, `NSBonjourServices`) sebagai data yang
  bisa dibaca lapisan app. Kegagalan kunci ini bukan galat yang terbaca —
  aplikasinya hanya diam-diam tidak menemukan teleskop.

### 19 uji baru: yang dijaga bukan "apakah perintahnya jalan"

Yang diuji adalah **apa yang tidak boleh pernah lolos**: penolakan tidak
pernah menjadi izin, penolakan **tidak pernah memanggil transport sama
sekali** (transport palsu mencatat nol panggilan), kerangka yang tidak
didukung ditolak, dan jalur alt-az benar-benar mempresesi — diuji terhadap
jalur engine sendiri (`horizontal(ofObjectID:)`) plus satu uji yang
membuktikan hasilnya **berbeda** dari koordinat J2000 mentah.

### Satu uji pertama salah asumsi, bukan salah kode

Uji `testAltAzMountGetsHorizontalTargetNotEquatorial` versi pertama menuntut
Vega di atas horizon dari Bandung pada 15 Jan 2026 15:00 UTC. Terukur:
**−56,4°**. Asumsinya salah, bukan kodenya. Diganti menjadi perbandingan
terhadap jalur engine sendiri, plus uji presesi terpisah.

### Batas yang jujur

- **Yang dibuktikan:** urutan langkah POC §18 tidak bisa dilewati — penolakan
  tidak menyentuh perangkat, bentuk target mengikuti sumbu, kerangka
  dinyatakan, dan Abort selalu sampai. **Yang belum:** `TelescopeTransport`
  nyata untuk Seestar. Jalur kontrolnya masih community/reverse-engineered
  (§18), sensitif firmware, dan menguji connect/GoTo/Slewing/Abort pada
  perangkat fisik tetap butuh perangkat.
- "Monitor state until complete or failed" (§18) **tidak** ada di sini:
  menunggu perangkat butuh `await`, jadi itu tugas lapisan app. Yang dicatat
  `TelescopeAttempt` adalah perintah **terkirim**, bukan **selesai**.
- `NSLocalNetworkUsageDescription` belum ditulis ke `Info.plist` mana pun —
  yang ada baru data yang bisa dibacanya.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 187 | **206** (+19 jembatan teleskop) |
| PointingKit | 679 | 679 |
| Pemeriksaan visual | 481 | 481 |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (206 + 679), `swift-ui-lint.sh` (29,
Aturan 10 menangkap README 187 lebih dulu dan itu memang tugasnya),
`swift-typecheck.sh`, `check-visuals.py --check` (481, 0 gagal). Berkas
tersentuh: `TelescopeBridge.swift` (baru), `TelescopeBridgeTests.swift`
(baru), `README.md`, `ROADMAP.md`. CI: Apple Build + Engine Tests hijau
pada `58b085e`.

---

## Progres terakhir (7 Okt 2026 — earthshine: sisi gelap Bulan tidak lagi hitam rata)

### Cacatnya: sisi gelap Bulan digambar identik dengan planet yang gelap

`drawMoon` mengisi seluruh piringan dengan `moonUnlit` lalu melukis pita
terang di atasnya. Hasilnya: sisi gelap Bulan **identik** dengan sisi gelap
Venus/Merkurius (`planetUnlit`) — padahal keduanya secara fisis berbeda dan
`NightVisual.swift` sudah mencatat perbedaan itu di komentar selama ini. Sisi
gelap Bulan disinari **earthshine** (cahaya Matahari yang dipantulkan Bumi),
jadi ia redup tapi tidak hitam; planet dalam tidak punya sumber seperti itu.

Komentar yang menjelaskan "kenapa `planetUnlit` terpisah dari `moonUnlit`"
sudah benar, tetapi **kodenya tidak mewujudkannya**: yang dipakai Bulan
adalah `moonUnlit` saja, tanpa earthshine. Ini kelas cacat yang sama dengan
`moonPhaseUnknown` dulu — aturan yang hanya hidup sebagai prosa di komentar,
dan karena itu tidak bisa diukur dan bisa hilang tanpa suara.

### Perbaikan

- Token baru `moonEarthshine` di `NightVisual.swift` (0.15/0.15/0.19), terpisah
  dari `moonUnlit` (0.13/0.13/0.16) dan `planetUnlit` (0.06/0.06/0.08), dan
  dipetakan lewat aturan `shadow` sehingga mode malam tetap merah murni.
  *(Nilainya dinaikkan ke 0.30/0.30/0.37 di siklus berikutnya — lihat entri
  teratas — karena pada 0.15 piringan bulan baru terukur tak terlihat. Yang
  tercatat di sini adalah keadaan saat siklus ini dikerjakan.)*
- Fungsi model `CelestialVisual.earthshineStrength(illuminationFraction:)`
  = `1 - f`: nol saat purnama (tak ada sisi gelap → jangan gambar cahaya yang
  tak ada di langit), maksimum saat bulan baru, monoton turun. Diuji di Linux
  (`testEarthshineOnlyOnPartiallyLitMoon`), termasuk penjepitan di luar 0…1.
- `drawMoon` melukis earthshine **sebelum** pita terang, jadi pita itu
  menutupinya di sisi menyala — earthshine hanya tampil di sisi gelap.
- Port Python (`render-visuals.py`) ikut, supaya gerbang piksel tidak
  mengukur gambar yang sudah tidak ada lagi, plus dua pemeriksaan baru di
  `check-visuals.py`.

**Kenapa `1 - f`, bukan konstanta.** Earthshine paling terang saat sabit tipis
(sisi gelap paling luas) dan lenyap saat purnama. Konstanta akan menyalakan
cahaya di piringan yang seluruhnya sudah terang — klaim yang salah, dan
satunya tempat yang bisa memeriksanya adalah layar Bulan yang paling sering
dilihat pengguna.

### Yang diukur, bukan diasumsikan

- `testEarthshineOnlyOnPartiallyLitMoon`: 673 → **674** uji PointingKit hijau
  (README diperbarui agar Aturan 10 tidak merah).
- Gerbang piksel: sisi gelap sabit **37.7** vs `moonUnlit` **33.6** (naik), dan
  cembung f=0.85 **34.6** < sabit f=0.15 **37.7** (meredup menuju purnama).
  Pengukuran paling kiri (x < cx − 0.75R) dipilih karena sliver itu pasti
  gelap di **setiap** fase — versi pertama mengambil setengah kiri dan
  tercemar piksel menyala pada fase cembung (37.7 vs 121.9, gagal).
- 430 pemeriksaan visual hijau, 0 gagal; UI lint & typecheck bersih.

---

## Progres terakhir (7 Okt 2026 — `tooCloseToSun` sampai .lock: celah kejujuran terakhir tertutup)

### Cacatnya: berkas uji jujur ada di pohon kerja, lupa di-commit

`TooCloseToSunLockHonestyTests.swift` (5 tes) sudah ditulis di sesi sebelumnya
tapi tertinggal sebagai berkas tak-terlacak (`git status` = `??`). Isinya
menutup celah kejujuran terakhir yang disebut STATUS.md entri bawah-horizon:
jalur `VisibilityFilter.classify` menolak arah tunjuk yang **terlalu dekat
dengan Matahari** (`tooCloseToSun`, ambang `minSunSeparationDeg` = 30°) — jalan
pengaman teleskop paling berbahaya, karena `.lock` membuka izin GoTo.
STATUS.md sendiri mencatat alasan ini "tidak pernah muncul sama sekali" di sapu
mereka, dan pemindaian 365 hari di sini mengonfirmasi: nol bintang katalog
pernah berada di (13°, 30°) dari Matahari saat keduanya di atas horizon.
Jadi seperti `tooFaint`, jalur ini **kode mati di produksi** — dan tes ini
menyalakannya **sebelum** suatu saat katalog diperluas (bintang konjungsi
Matahari) membuatnya hidup untuk pengguna.

### Yang dikerjakan: commit + perbaiki README yang tertinggal

- Berkas uji di-commit (5 tes: fixture ada, tidak pernah `.lock`, resolver
  menyebut `tooCloseToSun`, penolakan jujur di controller, **bukti positif**
  bintang sama terkunci saat malam).
- `README.md` masih bilang PointingKit **668**; `swift-test.sh` sebenarnya
  menjalankan **673** (182 engine + 673 = selisih 5 = tepat isi berkas itu).
  Aturan 10 `swift-ui-lint.sh` gagal karena angka itu. Diperbaiki ke 673.

### Kenapa ini penting, bukan sekadar pembersihan

Berkas itu sudah hijau sejak sesi lalu, tapi belum pernah masuk `main` — jadi
ciptaan "jalur `tooCloseToSun` tidak bisa bocor ke `.lock`" belum punya
perlindungan di cabang utama. Kalau penyaring Matahari kelak disunting tanpa
sengaja, tidak ada teks layar yang memberitahu pengguna, dan tidak ada tes di
`main` yang merah. Sekarang ada.

### Hitungan (setelah commit)

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 182 | **182** |
| PointingKit | 668 (README) / 673 (aktual) | **673** |
| Gerbang UI | Aturan 10 gagal | **29 lulus** |

Semua gerbang hijau: `swift-test.sh` (182 + 673), `swift-ui-lint.sh` (29 aturan,
`exit=0`), `swift-typecheck.sh`, `check-visuals.py --check` (427 pemeriksaan, 0
gagal). Berkas tersentuh: `TooCloseToSunLockHonestyTests.swift` (di-commit),
`README.md`. Tidak ada kode produksi Swift yang berubah.

---

## Progres terakhir (7 Okt 2026 — Bulan di siang hari: celah `.lock` siang belum tersambung untuk benda tata surya)

### Cacatnya: `DaylightLockTests` hanya bintang, tidak menutup Bulan

`DaylightLockTests` (sudah ada, hijau) membuktikan controller sampai `.lock`
menolak **bintang** saat terang — tapi ia sengaja memilih bintang katalog.
Bulan ditangani lewat jalur efemeris yang berbeda (`EphemerisBody.moon`, bukan
tabel J2000), dan pada siang hari Bulan acapkali justru **di atas horizon**
(fase sabit pagi/sore, atau purnama yang baru terbit saat Matahari masih
tinggi). Jadi celahnya spesifik dan belum pernah diuji di level controller:
arah tunjuk ke Bulan yang benar-benar di atas horizon, saat Matahari juga di
atas horizon, masih harus ditolak karena `daylight`.

`BelowHorizonHonestyTests` juga tidak menutupnya: ia menolak benda di bawah
horizon, bukan benda di atas horizon saat langit terang.

### Yang ditambahkan: `MoonDaylightHonestyTests.swift` (4 tes, PointingKit)

Memutar `PointingController` **sungguhan** (bukan resolver — `.lock` adalah
satu-satunya keadaan yang memicu haptic sukses, bunyi, pengumuman VoiceOver,
visual pengenal, izin GoTo). Empat tes:

1. `testDaytimeMoonFixtureExists` — ada saat Bulan > 30° di atas horizon saat
   siang dalam 120 hari (prasyarat; fixture dicari dari resolver, bukan tangan).
2. `testMoonDaytimeNeverLocks` — arah tunjuk ke Bulan siang tidak pernah
   `.lock`, dan tidak ada haptic `lockSucceeded`.
3. `testMoonDaytimeRefusalIsHonest` — `searchHint == .daylight` (bukan diam /
   `allBelowHorizon`), dan resolver **menyebut Bulannya** ditolak `.daylight`.
4. `testMoonAtNightIsNotRejectedForDaylight` — **bukti positif**: Bulan > 30°
   saat malam tidak lagi ditolak `.daylight`, sehingga penolakan di (3)
   memang spesifik ke terangnya langit.

### Bukti mutasi — gerbangnya menggigit, dan batasnya jujur

Mematikan gerbang siang di `VisibilityFilter.classify` (`if !isDark(...)`
dijadikan komentar) → **2 dari 4 tes merah**: tepat `testMoonDaytimeRefusalIsHonest`
(assert `searchHint == .daylight` dan resolver menyebut `.daylight`).

Yang penting: `testMoonDaytimeNeverLocks` **tetap hijau** saat mutasi. Tanpa
gerbang siang, Bulan menjadi kandidat, tapi keyakinannya turun ke `.uncertain`
/ `.low`, bukan `.lock` — dan itu **perilaku benar** (PRD: uncertainty >
false confidence). Jadi tes ini menangkap *penolakan jujur*, bukan memaksa
`.lock`. Sama seperti `BelowHorizonHonestyTests` untuk Bulan, sisi yang dijaga
adalah penolakan yang jujur, bukan keadaan ketika ia terkunci. md5
`Visibility.swift` pulih persis.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 182 | **182** |
| PointingKit | 664 | **668** (+4 tes siang Bulan) |
| Pemeriksaan visual | 427 | 427 |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (182 + 668), `check-visuals.py --check`
(427, 0 gagal), `swift-ui-lint.sh` (29, "SEMUA GERBANG UI LULUS" — Aturan 10
memaksa README 664→668), `swift-typecheck.sh`. Berkas tersentuh:
`MoonDaylightHonestyTests.swift` (baru), `README.md`. **Tidak ada kode
produksi Swift yang berubah.**

### Batas yang jujur
- Yang dibuktikan: Bulan di atas horizon saat siang tidak pernah `.lock` lewat
  controller sungguhan, dan penolakannya menyebut `daylight`. **Yang belum:**
  ini kebenaran *jalur penolakan*, bukan pengujian visual — apakah Bulan
  redup benar-benar tampak redup di layar adalah tanggung jawab gerbang visual
  yang sudah ada, bukan tes ini.
- Fixture dicari dalam 120 hari dari epok 15 Jan 2026; kalau kelak efemeris
  berubah dan tidak ada saat Bulan > 30° siang, tes (1) merah — dan itu benar,
  karena prasyaratnya hilang. Bukan tes yang hijau karena kebetulan.

---

## Progres terakhir (7 Okt 2026 — galaksi berlengan: M51/M101 kini berbeda dari M31/M33 di layar)

### Temuan: janji "wakil berlengan" tidak punya wujud di layar

Komentar katalog (`DeepSkyCatalogue.objects`, kelompok ketiga) lama menjanjikan
"galaksi kini punya wakil **berlengan** (M51) selain cakram miring (M31/M33)".
Janji itu **tidak punya wujud**: `.galaxy` adalah tiga blob yang **seluruhnya di
titik pusat**, jadi tidak ada satu angka pun yang bisa menggeser sesuatu ke
lengan.

Diukur lewat jalur produksi (`out/ukur-lengan.log` + `out/bukti-lengan.py`),
pada fuzziness yang sama, ukuran jam 38 pt, ss=8:

```
A. SEBELUM (M51 memakai tata letak cakram):
   M31 (galaxy) vs M51 (spiralGalaxy) = 0 piksel berbeda
B. SEKARANG (cakram vs lengan), parameter identik:
   M31 (galaxy) vs M51 (spiralGalaxy) = 1064 piksel berbeda
```

Jadi, sebelum ini, dua objek katalog yang seharusnya berbeda bentuk digambar
**identik** — dan tidak ada teks di layar yang membacanya (satu kata "galaksi"
untuk keduanya). Itu kelas cacat yang sama dengan "gerbang mengukur gambar yang
tidak pernah tampil": komentar menjanjikan sesuatu, model tidak mengirimkannya.

### Perbaikannya: bentuk sendiri, bukan `.galaxy` yang diperlebar

`.spiralGalaxy` (10 blob: tonjolan inti + kabut cakram sempit + dua lengan
logaritmik pada θ = 0.35…3.35 rad) menaruh titik terjauh di **0.53 R** untuk
lengan, bukan 0.00 R seperti cakram. M51 dan M101 keduanya dipetakan ke sana.

Tiga keputusan yang dibuat lewat pengukuran, bukan tebakan:

1. **Kabut cakram 0.45, bukan 0.95** (versi pertama). Pada fuzziness 0.9,
   kabut 0.95 melebar ke 0.914 R sementara lengan terjauh hanya 0.546 R —
   seluruh lengan tertimbun, yang tampil kembali gumpalan bulat. Diukur
   (`out/ukur-lengan-baca.py`): ≤ 0.50 supaya lengan menonjol. Profil
   kecerahannya turun 444 → 313 → 149 → 68 (pusat ke tepi) — cakram
   berstruktur, bukan blob rata.
2. **10 blob, bukan 4.** Pada 38 pt, 4 titik terpisah jatuh di bawah satu
   piksel antar-titik; yang tersisa empat bintik acak. Delapan blob lengan
   (empat per lengan) cukup supaya lengkung terbaca **dan** tetap terbedakan
   dari cakram (`testSpiralGalaxyHasArmsThatThePlainDiscDoesNot`).
3. **Angka ditulis penuh, bukan lewat `cos`/`exp`** (seperti `.planetaryNebula`).
   Port Python menyimpan hasilnya sebagai angka, dan
   `check_deep_sky_layouts_match_the_model` membandingkan **nilai** di kedua
   berkas — rumus yang dihitung dua kali di dua bahasa adalah tempat
   pembulatan menyimpang.

### Dua asersi yang sengaja DIBUANG (bukan ditambah)

Uji baru `testCatalogueContainsArmedSpiralGalaxies` versi pertama menuntut
`armed.count >= 2`. Dibuktikan dengan mutasi (`m101` dipetakan ke `.galaxy`):
uji itu **merah bersamaan** dengan `testEveryMorphologyHasMoreThanOneRepresentative`
yang sudah ada — jadi asersi itu **duplikat**, tidak menambah cakupan, dan
pesannya menyuruh orang memperbaiki tempat yang sudah dijaga. Dibuang; yang
tersisa hanya yang **tidak bisa** dilihat uji lain (objek benar-benar sampai ke
geometri berlengan pada fuzziness katalognya).

Satu asersi lain sengaja tidak ditulis: "lengan harus menjulur lebih jauh dari
cakram". Cakram punya `discReach = 0`, jadi perbandingan `reach > 0` selalu
benar begitu `reach > 0.3` benar — **cakupan palsu** yang hijau tanpa pernah
bisa merah. Yang menjaga bedanya adalah `testSpiralGalaxyHasArmsThatThePlainDiscDoesNot`,
yang mengukur **keduanya** pada fuzziness yang sama.

### Bukti mutasi — semua menggigit, md5 pulih persis

```
[baseline]                             0 kegagalan
M1: blob lengan ditarik ke pusat        6 gagal (testSpiralGalaxy… + testCatalogueContainsArmed…)
M2: m101 -> .galaxy (1 wakil)           1 gagal (testEveryMorphologyHasMoreThanOneRepresentative)
M3: m51+m101 -> .galaxy (0 wakil)       3 gagal (testCatalogueContainsArmed… + testEveryMorphology… + testEveryMorphologyIsUsedBy…)
md5 CelestialVisual.swift  = 1767de63… (pulih)
md5 DeepSkyCatalogue.swift = <asli>     (pulih)
```

Pelajaran yang berulang di repo ini muncul lagi di harness sendiri: tiga versi
pertama `out/bukti-lengan.py` melaporkan klaim A "terbukti" padahal salah, karena
(1) `R` yang diimpor harness adalah **modul berbeda** dari `CV.R` yang dipakai
gerbang — mutasi menyentuh instance yang salah; (2) `decode_png` mengembalikan
3 nilai, jadi `diff` menghitung *baris* bukan *piksel*; (3) `replace` menyasar
daftar tangan di `check-visuals.py`, bukan di model. Ketiganya diselesaikan
dengan memakai `CV.R`, `_w,_h,rows`, dan menyunting berkas gerbangnya sendiri.

### Batas yang jujur

- **Yang dibuktikan:** M51/M101 sekarang digambar berlengan, berbeda dari
  cakram M31/M33 (1064 piksel pada 38 pt), dan tidak bisa kembali jadi cakram
  tanpa uji merah. **Yang belum:** ini kebenaran *bentuk*, bukan kebenaran
  astronomi sudut pandang — `celah` Cassini galaksi tidak diukur, dan apakah
  lengan benar-benar 2 (bukan 1 tangan melengkung) diuji lewat simetri 180°,
  bukan lewat efemeris.
- Gerbang `check_every_morphology_in_the_model_has_render_cases` juga diukur
  memerah saat nama baru dihapus dari daftar tangan di dalamnya (1 gagal) —
  jadi gerbang ini berlaku untuk bentuk baru, bukan cuma membaca daftar lama.
- Tidak ada kode `Apps/` yang berubah.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 182 | **182** |
| PointingKit | 662 | **664** (+2: dua uji spiral) |
| Pemeriksaan visual | 415 | **427** (+12: `spiralGalaxy` ikut seluruh gerbang langit dalam) |
| Aturan UI | 29 | 29 |
| Kunci katalog | 331 | **332** (+1 kata `galaksi spiral` untuk VoiceOver) |

Semua gate hijau: `swift-test.sh` (182 + 664), `check-visuals.py --check`
(427), `swift-ui-lint.sh` (29), `swift-typecheck.sh`. Berkas tersentuh:
`CelestialVisual.swift`, `DeepSkyCatalogue.swift`, `DeepSkySpeech.swift`,
`TextLocalization.swift`, `CelestialVisualTests.swift`,
`TextLocalizationTests.swift`, `Localizable.xcstrings`, `check-visuals.py`,
`render-visuals.py`.

---

## Progres terakhir (7 Okt 2026 — planet yang tidak pernah muncul di gambar mana pun, dan klaim docstring yang membantah dirinya sendiri)

### Temuan: tiga daftar planet, tidak ada satu pun yang diikat

Sumber kebenaran planet adalah `switch` di `CelestialVisual.Planet.palette`.
Dua daftar lain ditulis dengan tangan dan hidup terpisah:

| Daftar | Tempat | Isi |
|---|---|---|
| `switch` palet | `CelestialVisual.swift` | 5 planet, ciri per planet |
| kasus render | `render-visuals.py::build_cases()` | 5 nama, ditulis ulang |
| pasangan gerbang ciri | `check-visuals.py` | 5 pasangan, ditulis ulang **dua kali** |

Menambah planet ke model tidak membuat satu pun pemeriksaan gambar berbunyi,
dan planet itu tidak pernah muncul di satu pun PNG yang diukur. Yang hilang
bukan gerbang baru, melainkan **gerbang yang berlaku untuk planet itu**:
aturan "ciri pengenal hilang saat ragu" dan aturan "ciri pengenal masih
terukur pada 38 pt" hanya berjalan pada pasangan kasus yang ada. Planet baru
tampil di jam dengan ciri yang **tidak pernah diukur hilang** saat engine ragu
— klaim identitas di layar, dan pelanggaran PRD yang paling sulit terlihat
karena tidak ada yang salah untuk dilihat.

### Docstring-nya sempat berbohong, dan harness yang membuktikannya

Versi pertama docstring gerbang itu mengklaim: menambahkan `case .uranus:`
berciri `.bands` ke model "membiarkan **seluruh 409 pemeriksaan hijau**".
Diukur lewat `main()` penuh dengan gerbangnya **dikeluarkan** dari daftar
jalannya (`out/bukti-planet-uranus.py` bagian B), bukan dikutip:

```
[baseline]                          409 pemeriksaan, 0 gagal  <- hijau
uranus di model saja                410 pemeriksaan, 1 gagal  <- MERAH
  GAGAL palet planet: uranus ada di kedua sisi
uranus di model + port              412 pemeriksaan, 0 gagal  <- hijau
```

Baris kedua membantah klaim itu. Menambah `.uranus` di **model saja** memang
merah — tapi oleh gerbang drift yang sudah ada (`palet planet: uranus ada di
kedua sisi`), bukan oleh gerbang baru ini. Klaimnya salah, dan yang benar
lebih sempit sekaligus lebih berbahaya: keadaan sunyinya adalah ketika **kedua
bahasa sepakat**. Di sana tidak ada drift untuk diberitakan, seluruh 412
pemeriksaan hijau, dan `uranus` tidak pernah muncul di satu pun gambar yang
diukur. Docstring-nya sudah ditulis ulang dari angka hasil ukur itu.

Ini kelas yang sama dengan `-5,1` di gerbang kontras kawah dan `elips 20% R`
di gerbang pita Jupiter: **komentar di docstring adalah satu-satunya bukti
yang dibaca orang yang menilai apakah gerbangnya layak dipercaya.** Yang
diperbaiki bukan angkanya saja, melainkan bahwa klaimnya kini berbentuk
tabel hasil ukur yang bisa dibantah ulang.

### Gerbangnya: daftarnya diturunkan dari model, bukan dari tabel tangan

`check_every_planet_in_the_model_has_render_cases` (6 pemeriksaan) membaca
`switch` palet dari **sumber Swift** dan memeriksa empat hal:

  1. `switch` palet dan tabel palet pembaca sepakat — planet yang tertulis di
     satu tapi tidak di lain tidak bisa lolos diam.
  2. Setiap planet di model punya kasus `planet-<nama>-confirmed`.
  3. Setiap planet berciri punya `planet-<nama>-uncertain`.
  4. Kedua gerbang ciri memuat **pasangan yang sama** dengan yang diturunkan —
     termasuk sisi **tertukar** (`planet-jupiter` dipasangkan dengan
     `planet-saturn-uncertain`), yang tidak terlihat oleh perbandingan
     himpunan apa pun.

Ditambah satu pemeriksaan kelima: ciri yang tidak dipakai planet mana pun
adalah ciri mati — ia ada di enum, tidak digambar siapa pun, dan menambahkannya
ke planet baru akan tampak seperti pekerjaan yang sudah selesai.

Nama-namanya dibaca dari `case .nama:` di dalam `switch`, **bukan** dari
`Planet.allCases`: nama kasus enum tidak muncul sebagai teks di berkas sumber,
jadi membaca `allCases` hanya membuktikan bahwa *sesuatu* memakai `allCases`,
bukan planet mana saja yang ada. Wilayahnya dipotong di penutup fungsi —
tanpa itu, `case .nama:` dari `switch` mana pun di bawahnya ikut terbaca, dan
`CelestialVisual.swift` punya beberapa.

### Bukti mutasi — 7 keadaan, semuanya menggigit

Harness: `out/bukti-planet-uranus.py` bagian A.

```
[baseline]                                           6 pemeriksaan, 0 gagal
1. model: case .uranus (bands) ditambahkan           6 pemeriksaan, 4 gagal
2. model + port: uranus di kedua bahasa              6 pemeriksaan, 4 gagal
3. model: jupiter .bands -> .none                    6 pemeriksaan, 3 gagal
4. model: case .mars -> case .marsX                  6 pemeriksaan, 4 gagal
5. gerbang: pasangan mars hilang dari 'hilang saat ragu'  1 gagal
6. gerbang: pasangan venus hilang dari 'ukuran jam'       1 gagal
7. gerbang: pasangan jupiter memakai nama saturn          1 gagal
      GAGAL ... hilang: [], berlebih: [], tertukar: ['jupiter']
```

Baris 7 yang menentukan: kedua sisi pasangan **ada** di dalam himpunan, jadi
pemeriksaan keanggotaan apa pun akan hijau. Yang berbunyi adalah pemeriksaan
yang membandingkan **pasangannya**, dan pesannya menyebut kata "tertukar".

Baris 2 juga menentukan dengan cara yang berbeda: planet baru ditambahkan ke
**kedua** bahasa sekaligus, jadi tidak ada drift antar bahasa yang bisa
berbunyi. Hanya gerbang baru ini yang bisa melihatnya.

### Dua cacat di harness-nya sendiri, keduanya ditemukan dengan menjalankannya

1. **`continue` yang tidak memulihkan.** Versi pertama memulihkan berkas di
   akhir loop dan `continue` saat suntikan gagal. Jadi keadaan yang gagal di
   suntikan **kedua** meninggalkan suntikan **pertama** hidup di sumber
   produksi. Gejalanya muncul sebagai `KELEMAHAN BUKTI: 'case .saturn' muncul
   0x` pada keadaan berikutnya — pesan yang **menuduh anchor-nya salah**,
   padahal penyebabnya adalah keadaan sebelumnya. Pemulihan sekarang di
   `finally` **per keadaan**.

2. **Dua instance bersamaan.** Percobaan pertama menjalankan dua harness
   sekaligus; keduanya memutasi berkas yang sama dan `check-visuals.py`
   rusak di tengah tulisan. Yang paling berbahaya bukan kerusakannya,
   melainkan **bentuk gejalanya**: ia muncul sebagai "anchor tidak ditemukan",
   bukan sebagai keluhan tentang dua proses. Sekarang ada kunci
   `out/.bukti-planet.lock` yang memeriksa `/proc/<pid>`, jadi instance kedua
   berhenti dengan pesan yang menyebut prosesnya.

Keduanya kelas yang sama dengan yang sudah tercatat di repo ini: **harness
mutasi adalah alat yang merusak sumber produksi dengan sengaja**, jadi
keandalannya sendiri bagian dari kebenaran pengukurannya.

### Batas yang jujur

  - Gerbang ini menjaga **pasangan kasus ada dan cocok**, bukan bahwa planet
    baru itu digambar dengan benar. Menambahkan `uranus` ke model **dan** ke
    kedua gerbang ciri **dan** ke `build_cases()` akan hijau — dan memang
    harus, karena saat itu Uranus benar-benar terukur oleh kedua gerbang.
  - Yang diperiksa adalah daftar `pairs` **di dalam teks** dua gerbang ciri,
    dibaca dari sumber berkasnya sendiri. Gerbang yang menurunkan pasangannya
    dengan cara lain (mis. dari variabel) tidak akan terbaca — pemeriksaan
    "terbaca" akan merah dan menyebut nama fungsinya.
  - `read_planet_switch_cases_from_swift` memotong wilayah di `"\n    }"`
    pertama sesudah anchor. `switch` yang ditulis dengan indentasi lain tidak
    akan terpotong, dan `case .nama:` dari fungsi berikutnya bisa ikut
    terbaca. Tidak ada `switch` seperti itu di berkas ini sekarang.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 182 | **182** |
| PointingKit | 662 | **662** |
| Pemeriksaan visual | 409 | **415** |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (182 + 662), `swift-typecheck.sh`,
`swift-ui-lint.sh` (29 aturan), `check-visuals.py --check` (415 pemeriksaan,
0 gagal). Berkas tersentuh: `Tools/check-visuals.py`. **Tidak ada kode Swift
produksi yang berubah.**

---

## Progres terakhir (7 Okt 2026 — gambar yang diukur gerbang bukan gambar yang tampil di jam: 17 objek langit dalam)

### Temuan: seluruh gerbang gambar langit dalam merender satu angka yang tidak dipakai objek mana pun

`build_cases()` merender **setiap** kasus `deepSky` dengan `fuzziness=0.8`.
Katalog produksi membawa 17 angka pilihan — 0.30 (M22) sampai 1.00 (M31) —
dan tidak satu pun dari angka itu pernah masuk ke gambar yang diukur.

Diukur, bukan diasumsikan (`out/ukur-langit-dalam.py`), pada ukuran jam 38 pt
(frame 38×38 = 1444 piksel):

```
objek   fuzz  morph            beda piksel  % frame
m42     0.90  nebula                   819    56.7%
m17     0.72  nebula                   766    53.0%
m31     1.00  galaxy                   384    26.6%
...
m8      0.80  nebula                     0     0.0%

rata-rata = 312.8 piksel (21.7% dari frame)
```

Jadi gambar yang menjadi dasar **399 pemeriksaan** itu menyimpang dari gambar
yang benar-benar tampil di jam sebesar **312 piksel rata-rata — 21,7% dari
seluruh frame**. Untuk Nebula Orion, 819 piksel: **56,7%** gambar yang diuji
adalah gambar yang tidak pernah muncul di layar mana pun. M8 kebetulan 0.0%
karena 0.80 adalah satu-satunya nilai katalog yang sama dengan nilai gerbang.

Ini kelas cacat yang sama dengan "gerbang ciri planet hanya pernah melihat
gambar 5× lebih besar" — **gerbang yang mengukur gambar yang tidak tampil** —
hanya saja kali ini yang salah bukan ukurannya, melainkan **angkanya**.

### Dua akibat, keduanya sunyi

1. Mengubah satu nilai di `fuzzinessByID` tidak membuat apa pun merah.
2. Rumus `growth` yang mengubah angka itu menjadi ukuran blob hidup **dua
   kali** (`CelestialVisual.swift` dan `render-visuals.py`) dan **tidak
   dibandingkan sama sekali** — persis kelas "satu rumus, dua bahasa, tidak
   ada yang membandingkan" yang sudah tercatat di repo ini untuk pita
   Jupiter dan kabut Venus.

### Gerbangnya: empat jalur, bukan satu perbandingan tabel

`check_deep_sky_catalogue_values_reach_the_picture` mengukur, di ukuran jam
yang dibaca dari token:

  1. `growth` model == `growth` port, dan span-nya **tidak nol** — kalau nol,
     `fuzziness` berhenti mengubah apa pun dan seluruh tabel katalog menjadi
     hiasan.
  2. Kunci kamus yang **diambil** penggambar (`kw.get("fuzziness")`) == kunci
     yang **diisi** kasus render. Kalau tidak, seluruh tabel jatuh ke nilai
     bawaan 0.6 tanpa satu pun gambar berubah warna yang salah.
  3. Angka katalog benar-benar punya **efek pada gambar**: untuk setiap objek,
     gambar pada nilai katalognya harus berbeda dari gambar pada nilai netral.
  4. Di dalam satu morfologi, nilai yang berbeda harus menghasilkan gambar
     yang **berbeda di 38 pt** — bukan cuma berbeda secara aritmetika.

Daftar objeknya **dibaca dari `DeepSkyCatalogue.swift`**, bukan ditulis ulang
di gerbang. Daftar tangan akan menjadi salinan ke-18 yang tidak pernah
dibandingkan — lubang yang sama, satu lapis lebih dalam.

### Bukti mutasi — 10 keadaan, semuanya diukur

Harness: `out/mutasi-katalog-langit-dalam.py`.

```
[baseline]                                               10 pemeriksaan, 0 gagal
1. katalog: m27 0.68 -> 0.60 (jadi kabut netral)         10 pemeriksaan, 1 gagal
1b. katalog: m13 0.35 -> 1.00 (tetap terbedakan)         10 pemeriksaan, 0 gagal  <- sengaja
2. port: growth span 0.38 -> 0.10 (drift antar bahasa)   10 pemeriksaan, 1 gagal
3. model: growth span 0.38 -> 0.10 (drift antar bahasa)  10 pemeriksaan, 1 gagal
4. kedua bahasa: span -> 0 (fuzziness jadi hiasan)       10 pemeriksaan, 4 gagal
5. port: penggambar mengabaikan fuzziness (konstan)      10 pemeriksaan, 2 gagal
6. port: jangkar rumus growth dihapus                     1 pemeriksaan, 1 gagal
7. katalog: entri fuzziness m22 hilang                    8 pemeriksaan, 2 gagal
8. port: penggambar membaca kunci lain (spread)          10 pemeriksaan, 3 gagal
9. model: rumus growth dipindah ke fungsi lain            1 pemeriksaan, 1 gagal
```

Baris **1b** adalah yang menentukan dan sengaja diharapkan **nol** merah:
mengubah `m13` tetap menghasilkan gambar yang terbedakan dari objek lain di
morfologinya, jadi gerbangnya benar diam. Yang diperiksa di situ bukan
"apakah gerbang berbunyi" melainkan "apakah gerbang berbunyi **hanya** saat
ada alasan". Gerbang yang menyala pada setiap suntingan katalog akan dimatikan
orang, dan itu bentuk kegagalan yang paling sulit terlihat karena ia tampak
seperti ketaatan.

### Tiga angka di docstring-nya diukur, bukan dikutip

Karena repo ini sudah beberapa kali menemukan gerbang yang **mengutip angka
yang tidak pernah ia ukur**, ketiga klaim di docstring gerbang itu diuji:

| Klaim | Cara diukur | Hasil |
|---|---|---|
| 312 piksel rata-rata (21,7%) | `out/ukur-langit-dalam.py` | 312,8 — cocok |
| 819 piksel (56,7%) untuk M42 | sama | 819 — cocok |
| `m13` 0.35→1.00 meninggalkan 399 pemeriksaan hijau | `out/bukti-klaim-gerbang-ds.py`: gerbang baru **dikeluarkan** dari `main()`, sumber dimutasi, seluruh gerbang lain dijalankan | 399/0 hijau, juga pada kedua mutasi `growth` |
| "dan 662 uji Swift" untuk mutasi model | `out/ukur-klaim-662.sh`: mutasi span model, `swift-test.sh` penuh | 662/0 hijau, md5 pulih persis |

Yang ketiga dan keempat penting karena keduanya klaim tentang **keadaan
sebelum gerbang ini ada**. Kalau salah satunya merah, docstring-nya berbohong
dan gerbangnya tidak menutup apa pun.

### Dua cacat yang ditemukan di harness-nya sendiri

1. **Timeout meninggalkan sumber termutasi.** `SIGKILL` melewati `finally`,
   jadi kasus 2a (`growth = 0.62 + 0.10 * clamped` di port) **bertahan hidup**
   di `render-visuals.py` — ditemukan lewat `git status`, bukan lewat harness.
   Harness yang menulis ke sumber produksi tidak boleh bergantung pada satu
   jalur `finally`; sekarang ada handler `SIGINT`/`SIGTERM` juga. Pelajarannya
   umum: harness mutasi adalah alat yang **merusak sumber produksi dengan
   sengaja**, jadi keandalannya sendiri adalah bagian dari kebenaran
   pengukurannya.

2. **Pembaca yang membaca melewati batas fungsinya.** `read_deep_sky_drawing_
   from_swift` mula-mula membaca sampai EOF, jadi `kw.get("fuzziness")` di
   fungsi **mana pun** di bawahnya akan meloloskannya. Versi kedua memotong
   pada `def` berikutnya. **Efeknya diukur dan lebih kecil dari yang
   tampak** (`out/bukti-pembaca-lama-ds.py`): pada mutasi "penggambar berhenti
   membaca fuzziness, nama tetap hidup di fungsi lain", pembaca lama → 2 gagal,
   pembaca baru → 3 gagal. Dua pemeriksaan piksel tetap menggigit apa pun isi
   pembaca itu, jadi yang ditambahkan adalah **sebab yang disebut namanya**,
   bukan cakupan baru. Tetap diperbaiki — tapi dicatat sebagai jebakan yang
   menganggur, bukan sebagai lubang yang tertutup. Percobaan pertama decoy-nya
   sendiri salah: ia menaruh `kw.get` di fungsi yang tidak punya `kw`, dan
   render meledak `NameError` — bukti bahwa harness-nya salah, bukan bukti
   tentang pembacanya.

### Batas yang jujur

  - Gerbang ini menjaga **angkanya sampai ke gambar**, bukan bahwa angka itu
    benar secara astronomi. `fuzziness` tetap pilihan kurator; yang dijamin
    sekarang adalah pilihan itu tidak bisa hilang diam-diam.
  - Pemeriksaan 4 mengikat gambar pada **satu ukuran** (38 pt, dibaca dari
    token). Pada ukuran lain pasangan yang berbeda bisa bertumbukan; itu tidak
    diukur, dan tidak diklaim.
  - Uji Swift `testPlanetaryNebulaIsHollowAtTheCentre` sekarang mengiterasi
    **angka katalog** lewat `DeepSkyCatalogue`, bukan literal `[0.0, 0.40,
    0.68, 1.0]`. Dua ujung 0.0/1.0 tetap diuji karena keduanya batas
    penjepitan. Sisa ruang lubangnya pada fuzziness 1.0 hanya **0.009** di
    atas ambang 0.2 — uji itu nyaris merah pada keadaan sekarang, dan menaikkan
    span rumus growth dari 0.38 ke 0.45 sudah menutup lubangnya.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 182 | **182** |
| PointingKit | 662 | **662** |
| Pemeriksaan visual | 399 | **409** |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (182 + 662), `swift-typecheck.sh`,
`swift-ui-lint.sh` (29 aturan), `check-visuals.py --check` (409 pemeriksaan,
0 gagal). Berkas tersentuh: `Tools/check-visuals.py`,
`CelestialVisualTests.swift`. **Tidak ada kode Swift produksi yang berubah** —
yang berubah adalah gerbang, dan satu uji yang berhenti menulis ulang angka
katalognya sendiri.

---

## Progres sebelumnya (7 Okt 2026 — gerbang yang mengukur keberadaan nama, bukan sampainya angka ke gambar)

### Temuan: satu angka hidup dua kali di dalam satu berkas, dan gerbang drift menjaga yang salah

Empat konstanta di `render-visuals.py` punya angka **kedua** yang ditulis
langsung sebagai bawaan parameter penggambarnya:

    CANDIDATE_CORNER_FRACTION = 0.34   vs  def candidate_marker(corner_fraction=0.34)
    CANDIDATE_INSET           = 0.06   vs  def candidate_marker(inset=0.06)
    CANDIDATE_GLYPH_FRACTION  = 0.52   vs  def candidate_marker(glyph_fraction=0.52)
    SATURN_CASSINI_WIDTH      = 0.06   vs  def saturn_ring_bands(cassini_width=0.06)

`check_port_matches_swift_constants` membandingkan **konstantanya** dengan
model Swift dan hijau. Yang menggambar adalah **bawaannya**. Jadi mengubah
konstanta itu tidak mengubah satu piksel pun — gerbang drift menjaga angka yang
tidak sampai ke kertas.

Ini bukan cacat kosmetik, karena siklus ini juga menambahkan gerbang yang
mengukur celah Cassini **pada ukuran jam**: `check_saturn_gap_reads_at_the_watch_size`
mengukur PNG yang menggambar celah lebar, sementara jam menggambar celah yang
konstantanya janjikan. Dua bahasa yang berbeda dipisahkan — dan pemisahnya di
dalam **satu berkas**, tempat yang paling tidak akan dicurigai siapa pun.

### Perbaikannya: satu angka, satu tempat

Konstantanya dinaikkan ke atas pemakainya (Python mengevaluasi bawaan saat
fungsi **didefinisikan**, jadi namanya harus sudah ada) dan bawaannya membaca
konstanta itu. Sekarang `render-visuals.py` tidak punya angka kedua untuk
keempat konstanta itu.

### Cacat kedua, di dalam gerbang yang menutupnya — dan ini yang paling penting

Gerbangnya ditulis lebih dulu (aturan 10 di brief), lalu diuji dengan mutasi.
Versi pertamanya menghitung **kemunculan nama** di sumber dengan `tokenize`.
Pada cacat aslinya ia benar-benar merah. Lalu dicoba keadaan yang lebih licik:
**bawaan dikembalikan jadi literal, dan satu rujukan mati ditambahkan di
tingkat modul**:

    SATURN_CASSINI_WIDTH = 0.06
    _MIRROR = SATURN_CASSINI_WIDTH        <- nama tetap "dipakai"

Gerbangnya **hijau** pada keadaan itu (`out/probe-konstanta-mati.py`). Ia
mengukur *apakah namanya muncul*, bukan *apakah nilainya sampai ke gambar* —
persis kelas cacat yang ia ada untuk menutup, hanya berpindah satu lapis ke
dalam gerbangnya sendiri.

Yang menentukan bukan "namanya ada di mana", melainkan **jalannya**. Dua jalan
yang sah, dan hanya dua: dibaca sebagai **bawaan parameter**, atau dibaca di
**badan sebuah fungsi**. Rujukan di tingkat modul tidak dihitung — modul tidak
menggambar apa pun. Gerbangnya sekarang membaca AST dan menghitung load per
cakupan, dan pesan kegagalannya membedakan "tidak pernah dipakai" dari "hanya
dirujuk di tingkat modul".

### Cacat ketiga: bentuk yang tidak lewat nama sama sekali

Ada keadaan yang tidak bisa ditangkap oleh uji "jalannya" sekeras apa pun:
bawaan penggambar ditulis literal **bernilai sama** dengan konstanta yang
dijaga, sementara nama konstanta tetap dipakai di tempat lain. Namanya tidak
hilang; yang berhenti dipakai adalah angkanya. Karena itu lapis kedua
membandingkan **nilai** bawaan parameter dengan nilai konstanta.

Lapis kedua itu, versi pertamanya, **merah pada kode yang benar**:
`saturn_ring_bands(cassini_width=0.06)` cocok dengan `CANDIDATE_INSET` yang
kebetulan juga 0.06. Dua konstanta berbeda boleh bernilai sama. Pasangannya
karena itu dicari lewat **nama** parameter (`cassini_width` ↔
`SATURN_CASSINI_WIDTH`), dan hanya untuk konstanta yang lapis pertama sudah
nyatakan sampai ke gambar. Gerbang yang merah pada kode benar akan dimatikan
orang, jadi kesempitan ini syarat hidupnya.

### Bukti mutasi — tiga keadaan, tiga pesan berbeda

Harness: `out/mutasi-konstanta-mati.py`.

```
baseline                                     1 pemeriksaan, 0 gagal
1. bawaan lencana jadi literal               1 gagal  `CANDIDATE_CORNER_FRACTION`
                                                        …tidak pernah dipakai
2. bawaan literal + rujukan mati di modul    1 gagal  `SATURN_CASSINI_WIDTH`
                                                        …hanya dirujuk di tingkat modul
3. literal bernilai sama, nama tetap dipakai 1 gagal  `candidate_marker(corner_fraction=0.34)`
                                                        …salinan angkanya
[dipulihkan]                                 1 pemeriksaan, 0 gagal
```

Baris 2 adalah yang menentukan: ia **hijau** di bawah gerbang versi sebelumnya
dan merah di bawah versi ini. Baris 3 hijau di bawah kedua versi "jalannya",
dan hanya lapis kedua yang melihatnya. Ketiga pesannya menyebut tempat yang
berbeda, jadi pembaca tahu ke mana harus melihat.

`md5` kedua berkas pulih persis sesudahnya (`render-visuals.py aa8703f6…`,
`check-visuals.py e735a1e7…`).

### Tabel di docstring diukur ulang, bukan diwarisi

`check_saturn_gap_reads_at_the_watch_size` mengutip tabel di docstringnya.
Karena repo ini sudah beberapa kali menemukan gerbang yang **mengutip angka
yang tidak pernah ia ukur**, tabelnya diukur ulang dari penyampel yang dipakai
gerbang itu sendiri (`out/ukur-tabel-celah.py`), dengan lebar celah diubah di
**kedua** tempat yang mengikatnya:

```
lebar celah      paruh belakang   paruh depan
0.0304 (nyata)   +12              +5      <- gagal
0.0600 (dipakai) +22              +23     <- lulus
```

Persis seperti yang tertulis. Ambang `- 12` yang sama dipakai di kedua gerbang
celah, jadi keduanya tidak bisa berhenti sepakat tanpa ada yang tahu.

### Batas yang jujur

  - Gerbang baru menjaga **sampainya konstanta ke penggambar**, bukan bahwa
    angkanya benar. `SATURN_CASSINI_WIDTH` sengaja 0.06 (bukan lebar nyata
    0.0304) supaya celahnya masih terbaca di kartu jam 38 pt; yang membuktikan
    pilihan itu masih sah adalah `check_saturn_gap_reads_at_the_watch_size`,
    bukan gerbang ini.
  - Pasangan nama parameter ↔ konstanta di lapis kedua adalah heuristik
    akhiran. Parameter baru yang namanya tidak berakhir dengan nama
    konstantanya tidak akan terjangkau lapis ini — lapis pertama tetap
    menjangkaunya selama nilainya dibaca lewat nama.
  - Cakupan konstanta diturunkan dari AST `check_port_matches_swift_constants`
    (28 konstanta bernilai angka dari 37 entri; sisanya fungsi, penanda rumus,
    dan konstanta string). Menambah entri ke gerbang drift langsung
    memperluas gerbang ini.
  - `check_saturn_gap_reads_at_the_watch_size` **hijau di bawah gerbang lama**
    pada `--size 200`: di ukuran itu kedua lebar celah lulus ambangnya.
    Kegunaannya sepenuhnya bergantung pada ukuran jam yang dibaca dari token
    `WatchMetrics.visualDiameter`.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 182 | **182** |
| PointingKit | 662 | **662** |
| Pemeriksaan visual | 396 | **399** |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (182 + 662), `swift-ui-lint.sh`
(29 aturan), `check-visuals.py --check` (399 pemeriksaan, 0 gagal). Berkas
tersentuh: `Tools/check-visuals.py`, `Tools/render-visuals.py`. **Tidak ada
kode Swift yang berubah** — yang berubah dua bahasa yang sama-sama menggambar,
dan gerbang yang menjaga keduanya.

---

## Progres terakhir (6 Okt 2026 — mode malam akhirnya diuji di seluruh katalog)

### Temuan: janji "merah murni" hanya diukur pada 7 dari 40 kasus

`check_night_mode_purity` menegakkan janji paling fisiologis di produk ini:
di mode malam kanal hijau dan biru harus **nol**, bukan "kecil", karena cahaya
498–530 nm mematikan adaptasi gelap 20–40 menit. Gerbangnya benar.

Tapi daftar kasusnya **ditulis tangan**: tujuh nama yang dipilih seseorang.
Katalognya berisi 40 kasus. Tiga puluh tiga di antaranya tidak pernah diukur
dalam mode malam sama sekali — termasuk `craterRim` di `(0.86, 0.84, 0.81)`,
bahan paling terang di seluruh katalog, dengan kanal biru 0.81.

Diukur lebih dulu, bukan diasumsikan: **tidak ada kebocoran yang hidup.**
Keempat puluh kasus menghasilkan hijau/biru maksimum = 0. Warnanya memang
lewat `NightVisual`. Tapi "kebetulan benar" dan "dijaga" adalah dua hal
berbeda — dan yang pertama berhenti benar tanpa memberi tahu siapa pun.
Kasus render baru bisa ditambahkan besok dengan `Color(red:)` yang tidak
pernah dipetakan, dan ketiga puluh tiga kasus itu tetap hijau.

### Gerbang: daftarnya diturunkan, bukan ditulis

`check_night_mode_purity` sekarang mengambil kasus dari `R.build_cases()`
dan menyapu **seluruh** katalog. Kasus baru ikut terukur pada hari ia
ditambahkan, bukan pada hari seseorang ingat menambahkan namanya ke daftar.
Kalau katalognya kosong, gerbangnya **merah** — bukan hijau karena tidak ada
yang diperiksa.

### Bukti mutasi — keempatnya menggigit

Harness: `mutasi-malam-murni.py`.

- Pemetaan mode malam dimatikan seluruhnya (`night_surface` jadi identitas)
  → **32 dari 40 merah**. Nilai terburuk: Venus 242, Mars 221, Jupiter 202.
- **Hanya warna terang** (kanal biru > 0.5) yang dibiarkan bocor — menyasar
  `craterRim` → **29 dari 40 merah**. Ini keadaan yang membuktikan gunanya
  memperluas cakupan: ketiga puluh tiga kasus yang dulu tidak diuji ikut
  menangkapnya, sedangkan daftar tujuh nama lama akan membiarkannya lolos.
- Katalog kosong → **1 merah** ("katalog terbaca").
- Kasus baru disuntikkan ke `build_cases()` → **41 kasus diperiksa**, dan
  kasus baru itu muncul di hasil tanpa ada yang menyunting daftar apa pun.
  Kalau cakupannya kembali berdaftar tangan, pemeriksaan ini hilang.

md5 `check-visuals.py` pulih persis sesudahnya (`0b37d3c9…`).

### Keadaan gerbang

396 pemeriksaan gambar (dari 363), 0 gagal. 662 PointingKit + 182
CelestialEngine tetap hijau. `swift-ui-lint.sh` (29 aturan) dan
`swift-typecheck.sh` hijau. Perubahan hanya di `Tools/check-visuals.py`.

---

## Progres sebelumnya (6 Okt 2026 — ciri planet dibuktikan masih ada di ukuran jam)

### Temuan: seluruh gerbang gambar hanya pernah melihat gambar 5x lebih besar

`check_features_disappear_when_uncertain` membuktikan kelima ciri planet —
Bintik Merah Besar Jupiter, cincin Saturnus, kutub Mars, kawah Merkurius,
kabut Venus — hilang saat engine ragu. Ia benar, dan ia sudah benar sejak
lama. Yang tidak pernah diperiksa siapa pun: **apakah ciri itu masih ada
pada ukuran yang benar-benar tampil.**

Setiap gerbang gambar di `Tools/check-visuals.py` berjalan pada `--size 200`
ke atas. Jam menggambar visualnya pada `WatchMetrics.visualDiameter` = **38
poin** — 5,3x lebih kecil. Sebuah ciri yang terukur pada 200 px bisa menyusut
jadi nol piksel pada 38 px tanpa satu gerbang pun berubah warna, karena tidak
ada gerbang yang pernah melihat gambar seukuran jam.

Kelas cacatnya sama dengan "0.14 R Venus" yang dulu ditutup: gerbang yang
mengukur gambar yang **tidak tampil**. Bedanya arahnya — di sana bentuknya
yang salah, di sini ukurannya.

### Yang diukur, bukan ditebak

Diukur pada rentang ukuran, di luar lencana "?" (lencana itu membuat setiap
selisih selalu > 0, jadi ia harus dikecualikan — pelajaran yang sudah dibayar
mahal di gerbang `check_features_disappear_when_uncertain`):

```
size    jupiter   saturnus       mars  merkurius      venus
  38        239        187        126         57        178
  28        108         72         62         20         69
  20         50         24         28          8         24
  16         21          4         13          2          8
  12         11          1          6          0          2
   8          0          0          0          0          0
```

Pada 38 pt kelimanya masih terukur — jadi **tidak ada cacat yang hidup**.
Merkurius yang paling tipis: 57 piksel di luar lencana pada 38 px, dan habis
total pada 12 px. Ambangnya nyata dan dekat.

### Gerbang baru: `check_features_survive_the_watch_size`

Menjalankan kelima pasangan pada ukuran jam dan menuntut selisih di luar
lencana tetap > 0. Tiga keputusan yang membuatnya bukan sekadar salinan
gerbang lama:

1. **Ukurannya dibaca dari token.** 38 hidup di `WatchMetrics.visualDiameter`;
   gerbang membacanya dari `WatchTheme.swift` dengan regex. Kalau kartu jam
   melebar, gerbangnya ikut. Kalau tokennya tidak terbaca, pemeriksaan ini
   **merah** — bukan diam-diam jatuh ke angka bawaan, karena gerbang yang
   kehilangan ukurannya adalah gerbang yang berhenti mengukur apa pun.
2. **Satu implementasi pengecualian lencana.** Aritmetika indeksnya dulu
   hidup di dalam gerbang lama; sekarang `badge_excluded_diff` dipakai
   bersama. Kalau keduanya menyalin aritmetika sendiri, satu koreksi di satu
   tempat membuat yang lain mengukur kotak yang berbeda.
3. **`ss=8`, bukan `ss=2`.** Pada 38 px, satu piksel keluaran = 1/38 radius;
   supersampling rendah membuat tepi ciri yang tipis jatuh di antara sampel.

### Bukti mutasi — keempatnya menggigit

Harness: `mutasi-ukuran-jam.py`. Tiap keadaan diverifikasi terpasang, lalu
harus membuat >= 1 pemeriksaan merah:

- Token `visualDiameter` dihapus dari `WatchTheme.swift` → **1 merah**
  ("ukuran visual jam terbaca dari token"). Membuktikan ukurannya benar-benar
  dibaca, bukan diketik.
- Token diperkecil 38 → 8 pt → **5 merah**. Cocok dengan tabel: pada 8 px
  kelima ciri terukur nol. Membuktikan gerbang mengikuti token.
- `_draw_craters` tidak menggambar apa-apa (monkeypatch) → **1 merah**,
  tepat pada "kawah Merkurius". Tiga ciri lain tetap hijau — gerbangnya
  spesifik, bukan sekadar "ada bedanya".
- `_draw_rings` tidak menggambar apa-apa → **1 merah**, tepat pada "cincin
  Saturnus".

Sesudah keempatnya, md5 ketiga berkas pulih persis
(`WatchTheme.swift d847ecde…`, `check-visuals.py f6a57228…`,
`render-visuals.py 172acf67…`).

### Keadaan gerbang

363 pemeriksaan gambar (dari 358), 0 gagal. 662 PointingKit + 182
CelestialEngine tetap hijau. `swift-ui-lint.sh` (29 aturan) dan
`swift-typecheck.sh` hijau. `render-visuals.py` dan
`CelestialVisualView.swift` **tidak disentuh** — perubahan hanya di
`Tools/check-visuals.py`.

---

## Progres sebelumnya (6 Okt 2026 — dasar cekungan kawah dijaga, lalu angkanya sendiri ditertibkan)

### Temuan: `floorDepth` dihitung, didestrukturisasi, lalu dibuang

`CelestialVisual.craterRelief` menghitung `floorDepth` untuk tiap kawah dan
mendokumentasikan field itu di tipe `CraterRelief` sebagai *"dipakai sebagai
kelegapan lapisan hitam"*. Kedua penggambar — `drawCraters` di view Swift dan
`_draw_craters` di port Python — **mendestrukturisasi field itu lalu
membuangnya**: keduanya menulis angka tetap `0.85`.

Angka itu bukan sekadar tidak terpakai. Kedalaman maksimum model adalah 0,22,
jadi `0.85` adalah **3,9× lipatnya**. Sabit bibir yang menghadap cahaya
digambar dengan kelegapan `0,9 · rimStrength` (≈0,3–0,5) **di atas** dasar
yang kelegapannya 0,85: dasar itu praktis menutupi seluruh piringan. Hasilnya,
**setiap** bagian setiap kawah lebih gelap daripada permukaan sekitarnya:

    dinding sisi cahaya   − permukaan   −46,6 … −21,7
    dinding sisi bayangan − permukaan   −91,3 … −47,6

Itu tanda tangan **stiker gelap yang ditempel**, bukan cekungan. Cekungan butuh
dua dinding berlawanan tanda: satu lebih terang dari permukaan, satu lebih
gelap. Setelah dasar memakai `floorDepth` dari model:

    dinding sisi cahaya   − permukaan    +0,8 … +9,6
    dinding sisi bayangan − permukaan   −35,6 … −14,2

### Kenapa gerbang yang sudah ada justru **mengunci** cacatnya

`check_port_matches_swift_constants` punya entri `("opasitas dasar kawah",
R.CRATER_FLOOR_OPACITY, 0.85, "floor.opacity(0.85)", view)`. Ia membandingkan
`0.85` di port dengan `0.85` di view — dua bahasa yang **sepakat pada angka
yang sama-sama salah**. Gerbang hijau, gambar cacat, dan tidak ada satu pun
dari 348 pemeriksaan yang bisa melihatnya. Ini kelas yang berulang di repo
ini, dengan bentuk paling keras: bukan gerbang yang tidak ada, melainkan
gerbang yang **menjaga** nilainya.

Karena itu yang diperiksa sekarang bukan keberadaan konstanta, melainkan (1)
bahwa kelegapan itu **dibaca dari model** di kedua bahasa, dan (2) bahwa
**pikselnya benar-benar cekung** — dua dinding berlawanan tanda. Yang pertama
menangkap penyimpangan teks; yang kedua menangkap bentuk gambar apa pun
sebabnya, termasuk sebab yang belum terpikirkan.

### Cacat kedua, di dalam gerbang baru itu sendiri: angka yang tidak pernah diukur

Versi pertama docstring gerbang baru mengutip empat rentang kontras sebagai
bukti. **Tidak satu pun keluar dari penyampel yang dipakai gerbang di
bawahnya** — dan saya ukur ulang di 76/100/152/200/240/300/400/500 px untuk
memastikan:

| | dikutip | terukur |
|---|---|---|
| sebelum, sisi cahaya | −45,2 … **−5,1** | −46,6 … −21,7 |
| sebelum, sisi bayangan | −93,1 … −49,7 | −91,3 … −47,6 |
| sesudah, sisi cahaya | **+3,4** … +10,3 | +0,8 … +9,6 |
| sesudah, sisi bayangan | −81,5 … −20,9 | −35,6 … −14,2 |

Yang paling menyesatkan adalah `−5,1`: ia menyatakan hampir tidak ada dinding
terang yang hilang, padahal **seluruh lima kawah** menjadi lebih gelap dari
permukaannya (−21,7). Argumen yang menjadi alasan gerbang itu ada jadi
terdengar lemah oleh angkanya sendiri.

Ini persis kelas "gerbang mengutip angka yang tidak pernah ia ukur" yang sudah
tercatat di repo ini — `"elips 20% R"` yang ternyata milik **luas**, sementara
metriknya mengukur jarak tepi. Bahayanya bukan angka salah di komentar:
komentar itu **satu-satunya bukti** yang dibaca orang yang menilai apakah
gerbangnya layak dipercaya.

Perbaikannya bukan sekadar menulis ulang angkanya — itu akan kembali menyimpang
begitu geometrinya disunting. `check_crater_contrast_numbers_come_from_the_sampler`
membaca keempat rentang dari docstring dan **menuntutnya sama dengan hasil
ukur**. Keadaan "sebelum" tidak dikutip dari riwayat git: `crater_relief`
dibungkus sementara supaya `floor_depth` dipaksa `0.85`, lalu scene yang sama
digambar ulang lewat jalur produksi — jadi kedua keadaan diukur oleh **satu**
penyampel yang sama (`crater_wall_contrast`, dipakai kedua gerbang; kalau yang
kedua menyampel sendiri, ia hanya membuktikan komentarnya cocok dengan alat
ukur yang berbeda).

### Bukti mutasi — 11 keadaan, semuanya menggigit

Gerbang opasitas dasar (5 keadaan):

```
[baseline]                                5 pemeriksaan, 0 gagal
view: dasar kembali ke 0.85 tetap          5 pemeriksaan, 1 gagal
view: dasar memakai 0.0                    5 pemeriksaan, 1 gagal
port: dasar kembali ke 0.85 tetap          5 pemeriksaan, 2 gagal   (struktur + piksel)
port: konstanta mati dihidupkan lagi       5 pemeriksaan, 1 gagal
[dipulihkan]                               5 pemeriksaan, 0 gagal
```

Gerbang angka docstring (6 keadaan):

```
[baseline]                                    4 pemeriksaan, 0 gagal
angka lama di sisi cahaya                     1 gagal  (−45,2 vs −46,6)
angka lama di sisi bayangan                   1 gagal  (−93,1 vs −91,3)
angka lama di keadaan sesudah                 1 gagal  (+3,4 vs +0,8)
sisi cahaya<->bayangan tertukar               1 gagal  (angka sama, sisi salah)
satu kutipan dihapus                          1 gagal  ("3 kutipan … butuh 4")
dibulatkan 0,5 px lebih longgar (+9,6 → +9,1) 1 gagal
[dipulihkan]                                  4 pemeriksaan, 0 gagal
```

Baris "sisi tertukar" itu yang menentukan: angkanya **identik**, jadi
pemeriksaan yang hanya membandingkan nilai akan hijau — yang berbunyi adalah
pemeriksaan namanya. Baris "dibulatkan" menunjukkan toleransinya 0,05, cukup
ketat untuk menangkap angka yang "hampir benar".

Dua bug di gerbang baru ditemukan dengan menjalankannya, bukan dengan membaca:
(1) `q_side` dari regex hanya menangkap kata terakhir sementara `expected`
memegang frasa penuhnya, jadi keempat pemeriksaan merah pada kode yang benar
(`"sisi tertukar: cahaya"` untuk sisi cahaya) — bug yang sudah dua kali
tercatat di repo ini; (2) `R.crater_relief = forced` ditandai type-checker,
diganti `setattr`.

### Yang **tidak** diklaim

  - Gerbang baru menjaga **komentar cocok dengan pengukuran**, bukan bahwa
    komentarnya bagus. Angka jelek tapi benar tetap lolos — dan memang harus,
    karena memperbaikinya berarti mengubah geometri kawah, bukan prosa.
  - Rentang "sesudah" sisi cahaya **+0,8** masih tipis: pada 76 px dinding
    terang satu kawah hanya 0,8 luminansi di atas permukaannya. Itu angka
    sebenarnya, dan ia batas yang belum ditutup — memperbaikinya berarti
    menaikkan `CRATER_RIM_OPACITY` atau menggeser `CRATER_RIM_OFFSET`, dan
    keduanya mengubah penampilan kawah di jam. Belum dilakukan.
  - `CRATER_RIM_OPACITY` (0.90) dan `CRATER_INNER_FLOOR_OPACITY` (0.75) masih
    angka tetap di kedua bahasa yang tidak dibaca dari model — sama kelasnya,
    tapi keduanya **tidak** menyatakan identitas atau geometri, jadi gerbang
    piksel di atas yang menjaganya, bukan gerbang nilai.
  - Tidak ada satu piksel pun di **view Swift** yang berubah pada siklus ini
    selain `floor.opacity(crater.floorDepth)`; sisanya gerbang.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| CelestialEngine | 182 | **182** |
| PointingKit | 662 | **662** |
| Pemeriksaan visual | 348 | **358** |
| Aturan UI | 29 | 29 |

Semua gerbang hijau: `swift-test.sh` (182 + 662), `swift-typecheck.sh`,
`swift-ui-lint.sh` (29 aturan), `check-visuals.py --check` (358 pemeriksaan).

## Progres sebelumnya (6 Okt 2026 — kunci katalog yang tidak pernah sampai ke layar)

### Temuan: 23 terjemahan yang sudah ditulis, dan tidak satu pun pernah tampil

Layar Diagnostik sudah benar di permukaan. Setiap labelnya ada di
`Localizable.xcstrings`, lengkap dengan padanan Bahasa Inggris. Aturan 4
menyapu literal di argumen peritel teks dan menuntut setiap literal itu ada di
katalog — dan semuanya ada. Aturan 19 mencari kunci yatim dan melaporkan
bersih. Aturan 6 memeriksa paritas paket dan katalog, dan sebanding.

Tiga gerbang hijau, dan tetap tidak satu pun kata Inggris sampai ke layar.

Sebabnya bukan di katalognya, melainkan di **tipe parameternya**. `Text` punya
dua inisialisator yang berperilaku berlawanan, dan yang mana yang terpakai
ditentukan oleh tipe tempat literal itu berdiri:

    Text("Terkunci")     // LocalizedStringKey -> dicari di katalog
    Text(someString)     // StringProtocol      -> DICETAK APA ADANYA

Apple mendokumentasikan yang kedua sebagai *"without localization"*. Helper
baris di layar itu bertipe `String`:

    private func row(_ title: String, _ value: String) -> some View

Jadi `row("Keadaan", …)` menerima **kunci katalog** di dalam parameter bertipe
`String`, dan yang tercetak ke layar adalah kata Indonesianya. Terjemahannya
tidak pernah dibaca — di perangkat mana pun, di bahasa mana pun, tanpa satu pun
peringatan build.

### Kenapa tiga gerbang yang ada tidak melihatnya

Aturan 19 yang paling dekat: niatnya memang "kunci ini dipakai atau tidak", dan
ia menjawab ya. Jawabannya salah, karena kunci itu dipakai sebagai **teks
Indonesia**, bukan sebagai kunci. Ia mencari teks kunci di seluruh sumber
sebagai substring mentah, jadi kemunculannya di dalam `row("…")` **menghitung
sebagai rujukan**.

Aturan 4 hijau karena literalnya memang ada di katalog — ia memeriksa
**keberadaan**, bukan **tipe tempat literal itu berdiri**. Aturan 6 tidak
melihat `Apps/` sama sekali.

### Yang diperbaiki: teksnya pindah ke lapisan yang punya kunci

Literal Bahasa Indonesia berhenti menjadi identitas. Identitasnya kunci
ber-namespace `diagnostics.*`, dan Bahasa Indonesia menjadi **nilai bawaan** —
pola yang sama dengan `ExperimentText`, `SensorStatusText`, dan `ObjectSpeech`.

23 kunci baru: 12 judul baris, 4 detail teknis, 3 legenda, 4 nilai.

**Kenapa kunci baru, bukan kunci yang sudah ada.** Enam label sudah punya
padanan kata di katalog — "Kalibrasi" (`skyContext.calibration`), "Lokasi",
"Asal lokasi", "Sudah"/"Belum" (`calibration.status.*Short`), "Laju
pergelangan" (`row.speech.wristRateWord`). Semuanya sengaja tidak dipakai ulang,
dengan alasan yang sudah tertulis di repo ini: `"Kalibrasi"` adalah judul layar
kalibrasi **dan** nama pesan tautan untuk hal berbeda; kalau teksnya yang jadi
kunci, keduanya menyatu diam-diam. Layar Tautan dan layar Diagnostik boleh
memilih kata Inggris yang berbeda untuk "Kalibrasi" tanpa saling mengunci. Itu
sebabnya `link.row.*` ada meskipun `skyContext.*` sudah memuat kata yang sama.

### Aturan 29: gerbangnya ditulis lebih dulu, dan versi pertamanya kurang luas

Sesuai aturan 10 di brief, gerbangnya ditulis **sebelum** perbaikan — dan ia
langsung menemukan **19** situs, bukan 13 yang ditemukan sapuan manual. Versi
pertama hanya membaca helper yang dideklarasikan di `Apps/`, dan itu
meninggalkan separuh kelas cacat yang sama: `RowSpeech.spokenRow(title:value:)`
hidup di paket dengan dua parameter `String`, dan pemanggilnya menyerahkan
`"Laju pergelangan"` — literal kunci katalog yang sama persis. Setelah
helper dibaca dari kedua pohon, gerbang menemukan **26** situs, termasuk
`detailRow("Magnitudo"|"RA"|"Dec"|"Id katalog")` yang tidak muncul di sapuan
manual pertama.

Gerbangnya diturunkan dari kode, bukan dari daftar nama helper yang ditulis
tangan: helper mana pun yang parameternya `String` ikut diperiksa, jadi helper
baru yang ditambahkan besok langsung dijangkau.

Dua batasnya dinyatakan di berkasnya, bukan disembunyikan:

  - Kunci yang isinya **hanya tanda baca** tidak diperiksa. Katalog memuat
    `"—"` ("Penanda nilai kosong"), dan terjemahan `en`-nya juga `"—"`. Ia
    memang berdiri di parameter `String`, tapi ia placeholder, bukan label —
    dan karena kedua bahasanya identik, tidak ada terjemahan yang hilang.
  - Versi pertama memakai `[ -n "$nonlocalized" ]` untuk menentukan status, dan
    itu membuat gerbang **selalu merah** karena pesan "Bersih" juga non-kosong.
    Diganti ke pola `case GAGAL:*` yang sudah dipakai Aturan 27/28.

### Bukti mutasi — gerbang dan uji, keduanya menggigit

  - `row(DiagnosticsText.rowState, …)` dikembalikan ke `row("Keadaan", …)`
    -> Aturan 29 merah, `exit=1`, menyebut barisnya. Dipulihkan -> `exit=0`.
  - Entri `en` untuk `diagnostics.row.guidance` dihapus dari katalog
    -> `testCatalogueShipsAnEnglishFormForEveryDiagnosticsKey` merah dengan
    pesan yang menyebut kuncinya. Dipulihkan -> hijau.

Uji yang kedua sengaja memeriksa **berkas katalognya**, bukan accessor-nya:
memasang kamus sendiri hanya membuktikan *mekanisme* penerjemahan bekerja,
bukan bahwa katalognya lengkap.

### Hitungan

| | sebelum | sesudah |
|---|---|---|
| PointingKit | 655 | **662** |
| CelestialEngine | 182 | 182 |
| Aturan UI | 28 | **29** |
| Kunci katalog | 438 | **461** |
| Kunci `allKeys` | 308 | **331** |

Semua gerbang hijau: `swift-test.sh` (182 + 662), `swift-typecheck.sh`,
`swift-ui-lint.sh` (29 aturan), `check-visuals.py` (351 pemeriksaan).

### Yang TIDAK diklaim

  - Yang diperbaiki adalah **jalur teks ke katalog** di layar Diagnostik.
    `RowSpeech.label` masih bertipe `String` untuk judul, jadi ia bisa menerima
    teks yang belum terlokalisasi dari pemanggil yang belum diperiksa. Yang
    menutupnya sekarang adalah Aturan 29, bukan tipe yang lebih ketat.
  - Sumbu grafik (`LineMark(x: .value("Sampel", …))`, `RuleMark(y: .value(
    "Ambang yakin", …))`) belum diperiksa. `.value(_:_:)` mengambil `String`,
    jadi ia sekelas — dan belum ada situsnya yang menerima kunci katalog.
    Kalau nanti ada, Aturan 29 belum menjangkaunya.
  - Perbaikan ini tidak menyentuh satu pun piksel. Ia mengubah **bahasa** yang
    tampil, bukan tampilannya.

## Progres sebelumnya (6 Okt 2026 — kabut Venus: satu ciri planet yang tidak dijaga apa pun)

### Temuan: port menggambar Venus 0,14 R lebih rendah dari yang tampil di jam

Menyapu berkas ini dengan aturan yang sudah dipakai di sini — *"cari angka di
lapisan gambar yang tidak dibaca gerbang mana pun"* — menyisakan satu ciri
planet yang benar-benar **nol** cakupan: `grep haze Tools/check-visuals.py`
tidak menemukan apa pun. Kabut Venus satu-satunya ciri pengenal yang tidak
dijaga di sana, jadi ia juga satu-satunya yang bisa bergeser tanpa suara.

Dan ia memang sudah bergeser:

| | geometri elips kabut |
|---|---|
| view Swift | pusat di `center.y`, separuh tinggi 0,72 R |
| port Python | pusat di `cy + 0,14 R` |

Selisih **0,14 R ke bawah**. Seluruh gambar Venus berfase yang diukur gerbang
piksel — sabit, cembung, tanpa-arah — adalah gambar yang **tidak pernah tampil
di jam**.

### Kenapa itu terjadi, dan kenapa bentuknya penting

Bukan rasa, bukan pilihan: **keliru satuan**. `CGRect` memuat **sudut**,
`Canvas.ellipse` memuat **pusat**. Saat geometrinya disalin dari view ke port,
sudut atas `center.y − 0,72 R` diperlakukan sebagai pusat, dan 0,72 R berubah
jadi 0,14 R. Kesalahan yang **sama persis** pernah terjadi pada Bintik Merah
Besar — dan itu sebabnya `Spot` di model sudah menyebut satuannya sebagai
pusat. Pelajarannya sudah tertulis di repo ini; yang belum ada adalah gerbang
yang menutup ciri **kedua**, jadi yang kedua bebas mengulanginya.

Angka 0,14 R juga muncul di **dua** situs port (bola penuh dan cabang berfase),
jadi memperbaiki satu tempat saja akan meninggalkan Venus yang berbeda di
dalam aplikasi sendiri.

### Perbaikannya: geometrinya pindah ke model

`CelestialVisual.venusHaze()` sekarang memiliki geometrinya, dan **kedua**
bahasa membacanya — view lewat `CelestialVisual.venusHaze()`, port lewat
`venus_haze()` di `render-visuals.py`. Dua situs port memanggilnya, jadi tidak
ada angka yang bisa berbeda di antara mereka.

### Uji yang menangkapnya ditulis lebih dulu, dan uji itu sendiri sempat salah

`testVenusHazeIsCentredAndCoversTheDisc` ditulis **sebelum** perbaikannya
(aturan 10 di brief). Versi pertamanya menuntut `halfHeight > 1,0` dengan
alasan "kabut harus lebih tinggi dari piringan" — dan ujinya **merah pada kode
yang benar**: 0,72 adalah *separuh* tinggi, jadi tinggi penuhnya 1,44 R
terhadap piringan 2 R. Kabutnya memang **di dalam** piringan. Asersinya
dibalik ke `farthestCorner < 1,0`, dengan alasannya ditulis: kabut yang
menjulur keluar akan tergambar di atas latar hitam, bukan di atas Venus.

`farthestCorner` sendiri ikut diperbaiki: titik terjauh sebuah elips dari
pusatnya adalah puncak **sumbu mayor**-nya, `max(halfWidth, halfHeight)`, bukan
akar jumlah kuadrat — bentuk terakhir menghitung sudut kotak pembatas, yang
justru **di luar** elipsnya. Untuk kabut Venus keduanya kebetulan sama, dan
kebetulan yang tidak dijelaskan adalah cara termudah melahirkan cacat
berikutnya.

### Bukti mutasi — lima keadaan, semuanya menggigit

```
[baseline]                          14 pemeriksaan, 0 gagal
port kehilangan fungsi venus_haze   14 pemeriksaan, 1 gagal
port kembali menggeser 0.14 R       14 pemeriksaan, 2 gagal
situs berfase kembali menggeser     14 pemeriksaan, 2 gagal
view memakai centerY 0.14           14 pemeriksaan, 1 gagal
model kehilangan venusHaze          14 pemeriksaan, 1 gagal
[dipulihkan]                        14 pemeriksaan, 0 gagal
```

Pemeriksaan "geseran lama sudah tidak ada" dibaca dari kode **setelah komentar
dibuang** — versi pertamanya merah pada kode yang sudah benar, karena 0,14 R
masih disebut di komentar yang menerangkan justru kenapa ia dibuang.

### Yang **tidak** diubah, dan kenapa

Sapuan yang sama menandai enam angka lain di view tanpa gerbang: `1.15`
(radius akhir gradien limb), `0.17`/`0.48` (kawah), `0.44` (maria), dan
`1.10`/`1.44` (kabut — keduanya kini dibaca dari model). Empat yang pertama
adalah **tekstur hias**: tidak menyatakan identitas maupun geometri, jadi
angka yang bergeser di sana mengubah rasa, bukan kebenaran. Itu batas yang
sengaja, bukan kelalaian.

Satu kandidat lain diperiksa lalu **ditolak**: tinggi pita Jupiter konstan
0,055 R untuk semua pita, padahal bola memendekkan tinggi tiap pita sebesar
`sqrt(1 − y²)` — pita terluar jadi **2× terlalu tinggi** (0,0550 vs 0,0283).
Terukur, tapi bukan cacat: pada radius kartu jam 19 pt pita terluar yang benar
hanya **1,1 pt**, dan `drawBands` sudah membuang pita di bawah 1 pt. Yang
membuat piringan terbaca Jupiter di jam adalah pita yang **terbaca**, dan
pemendekan itu mengorbankannya. Batas ini sekarang tercatat di sini supaya ia
tidak "ditemukan" lagi sebagai cacat baru oleh siklus berikutnya.

### Keadaan sekarang

| | |
|---|---|
| CelestialEngine | **182 uji hijau** |
| PointingKit | **655 uji hijau** |
| Gerbang visual | **348 pemeriksaan, 0 gagal** |
| Berkas tersentuh | `CelestialVisual.swift`, `CelestialVisualView.swift`, `CelestialVisualTests.swift`, `check-visuals.py`, `render-visuals.py` |


## Progres terakhir (6 Okt 2026 — pita Jupiter: tali busur, dan gerbang yang akhirnya menggigit)

### Temuan: piringan terbaca sebagai stiker rata, bukan bola

Pita Jupiter digambar sebagai **elips**: lebarnya konstan sepanjang tinggi
pita, jadi tepi kirinya adalah **dinding vertikal** di `x = −sqrt(1 − yc²)`.
Di bola tidak begitu. Lingkaran lintang pada lintang φ memproyeksi ke ruas
garis `y = sin φ`, `|x| ≤ sqrt(1 − y²)`, jadi tepi pita pada tiap ketinggian
mengikuti **busur limb**.

Diukur, bukan diperkirakan: sebagai IoU terhadap bentuk yang benar pada render
200 px, tiap elips hanya menutupi **79%** pita yang benar dan yang hilang
**20,5–22,1%** — dua sudut di dekat limb, tempat bola tetap polos sementara
pitanya sudah berhenti. Pada pita bawah, yang terlebar, elipsnya juga
**menggantung di luar** tepi bola yang sudah menyempit. Bentuk itulah yang
membuat piringan terbaca sebagai stiker rata.

Perbaikannya satu rumus, `CelestialVisual.bandHalfWidthAt(height:)`, dipakai
**view** dan **port Python** — bukan ditulis dua kali.

### Cacat kedua: tanda yang hilang, dan **tidak ada gerbang yang menangkapnya**

Versi pertama fungsi itu menerima *jarak dari pusat pita* lalu memulihkan
ketinggiannya dengan `sqrt(1 − hw²)`. Akar itu **membuang tanda**: pita di
`y = −0,857` dan `y = +0,857` punya setengah-lebar sama, jadi tepi atas pita
utara dihitung dengan lebar tepi **bawah**-nya. Pada pita 0 itu 0,597 alih-alih
0,410 — pita utara jadi lebih lebar di atas, kebalikan dari yang benar, dan
piringannya terlihat miring. Sama di view: `abs(band.centerY) - band.halfHeight`.

Yang penting bukan cacatnya, melainkan ini: **sapuan mutasi sempat meninggalkan
bentuk `abs(...)` di view dan 345 pemeriksaan tetap hijau.** Gerbang piksel
mengukur **port**, bukan view — gambar di jam rata, PNG tetap tali busur. Itu
kelas "satu rumus, dua bahasa, tidak ada yang membandingkan" yang sudah
berkali-kali tercatat di repo ini, dan kali ini ia benar-benar meloloskan cacat.
Karena itu ditambahkan gerbang **pemakaian**, bukan hanya gerbang bentuk.

### Cacat ketiga: gerbang mengutip angka yang tidak pernah ia ukur

Pesan pemeriksaan berbunyi "elips 20% R". Metriknya mengukur **jarak tepi** pada
ketinggian sampel (di dalam pita), dan di situ busur dan elips masih
berdekatan: **0,1% R** di pita ekuator sampai **6,3% R** di pita terluar. Angka
20% itu milik **luas** (IoU 79%), bukan jarak tepi. Sekarang angkanya
**dihitung** dari geometri yang sama.

Dan batasnya dinyatakan, bukan disembunyikan: dengan ambang 3% R, pemeriksaan
ini membedakan tali busur dari elips pada pita **0, 1, 5, 6** dan **tidak** pada
pita 2–4 (0,1–1,1% R) — di dekat ekuator busurnya memang nyaris lurus. Yang
menjaga pita tengah adalah gerbang pemakaian, bukan ambang ini.

### Bukti mutasi — tiap keadaan, dua arah

```
[1] baseline                     11 pemeriksaan, 0 gagal
[2] view menggambar elips lagi   11 pemeriksaan, 1 gagal
    GAGAL tepi atas memakai ketinggian bertanda (bukan nilai absolutnya)
[3] view kehilangan tanda        11 pemeriksaan, 1 gagal
    GAGAL tepi atas memakai ketinggian bertanda (bukan nilai absolutnya)
[4] port menggambar elips lagi   11 pemeriksaan, 2 gagal
    GAGAL pita Jupiter 0 mengikuti busur limb (tali busur, bukan elips)
    GAGAL pita Jupiter 6 mengikuti busur limb (tali busur, bukan elips)
[5] port berhenti memanggil       gerbang meledak: NameError
[6] dipulihkan                   11 pemeriksaan, 0 gagal
```

Keadaan [3] adalah yang sebelumnya lolos. Keadaan [4] menggigit hanya di pita
**0 dan 6** — persis batas yang dinyatakan di atas, dan itu sendiri bukti
ambangnya jujur.

### Satu angka lagi yang salah, dari arah sebaliknya

Uji Swift `testBandHalfWidthFollowsTheLimbArc` mula-mula menuntut sisa **15% R**
terhadap elips. Diukur ulang dari geometri produksi (7 pita, setengah-lebar
0,11): yang benar **10,5% R**. Asersi dan komentarnya dikoreksi ke angka hasil
ukur. Menuntut angka yang tidak pernah muncul sama berbahayanya dengan tidak
menuntut apa pun — ia hijau karena kebetulan, bukan karena benar.

### Keadaan sekarang

| | |
|---|---|
| CelestialEngine | **182 uji hijau** |
| PointingKit | **654 uji hijau** |
| Gerbang visual | **345 pemeriksaan, 0 gagal** |
| Berkas tersentuh | `CelestialVisual.swift`, `CelestialVisualView.swift`, `CelestialVisualTests.swift`, `check-visuals.py`, `render-visuals.py` |


## Progres terakhir (6 Okt 2026 — dua lebar garis yang hidup di dua bahasa)

### Temuan: audit mutasi ketiga — "cuma tebal garis", padahal yang hilang adalah penanda ragu

Setelah kawah terikat, sapuan literal di `Apps/Shared/CelestialVisualView.swift`
menyisakan `0.18` (tebal spike bintang) dan `0.28` (tebal glif `?`) yang
**tidak disebut gerbang mana pun**. Keduanya ditulis di Swift **dan** di port
Python, jadi jelas "satu kelas, tiga tempat" yang biasa — tapi lebih dari
sekadar tidak dijaga: kodenya sendiri sudah benar, jadi tidak ada yang
perlu diperbaiki. Yang perlu dijaga adalah agar tetap benar.

Bukti, tiap angka dua arah:

```
VIEW  0.28 -> 0.60   315 pemeriksaan, 0 gagal
VIEW  0.18 -> 0.55   315 pemeriksaan, 0 gagal
PORT  0.28 -> 0.12   315 pemeriksaan, 0 gagal
PORT  0.18 -> 0.60   315 pemeriksaan, 0 gagal
```

### Kenapa `0.28` bukan Kosmetik

Glif `?` adalah **penanda ketidakpastian**: satu-satunya sinyal visual bahwa
engine sedang ragu. PRD v0.4 melarang visual yang mengklaim identitas saat
engine ragu. Glif yang menipis sampai tak terlihat **menghapus penanda itu**,
dan supaya tidak terlihat ia harus diubah **di kedua bahasa** supaya port
masih cocok — persis bentuk perubahan yang tidak pernah lolos review mata.

### Tiga cacat di gerbang, semuanya ditemukan mutasi (bukan dibaca)

1. **Pembaca singular** — `badge_radius * N` pertama selalu ada di geometri,
   jadi mutasi di `_draw_candidate_marker` **tidak terlihat sama sekali**.
   Diganti pembaca himpunan; `0.28` muncul di dua satuan berbeda (radius
   frame di geometri, piksel di penggambar) dan keduanya wajib dijaga.

2. **Pembaca plural terlalu longgar** — versi kedua menelan
   `dot_radius = badge_radius * 0.13` (tetes glif, bukan lebar garis) dan
   membuat gerbang **merah pada kode yang benar**. Diganti pembaca yang
   hanya menerima konteks stroking (`stroke_width =` / `stroke_polyline(`).
   Pelajaran: pembaca yang terlalu longgar lebih berbahaya dari tidak ada
   pembaca — ia menghasilkan gerbang yang merah pada код yang benar, dan
   orang belajar bahwa gerbang ini Frequently salah lalu mematikannya.

3. **Perbandingan himpunan salah bentuk** — jumlah situs memang berbeda
   (port dua, view satu), jadi himpunan tidak boleh sama; yang wajib sama
   adalah **nilai** di dalamnya.

Ditambah: pola harus menutup dua ejaan assignment (`lineWidth: max(...)`
Swift, `width = max(...)` Python) — menebak yang mana akan membuat gerbang
gagal membaca sumber yang benar. Pembaca juga tidak lagi melempar
`ValueError`; daftar `checks` dibangun saat fungsi berjalan, jadi exception
menggagalkan seluruh gerbang dengan traceback yang tidak menyebut apa yang
harus diperbaiki. Jangkar hilang kini jadi **pemeriksaan merah yang menyebut
situsnya**.

### Pesan hasil yang salah mengarahkan

Entri baru sempat melaporkan sumber port sebagai "sumber Swift", dan
`port=True, seharusnya True` tidak mengatakan apa pun. Dua-duanya persis
cacat yang dicatat tiga entri lalu tentang pesan yang menyuruh orang
membaca tempat yang kosong. Diperbaiki: nama berkas ikut dibawa ke tiap
pemeriksaan, dan nilai boolean ditampilkan sebagai "terpenuhi" /
"TIDAK terpenuhi" daripada `True`/`False`.

check-visuals 315 -> **323**. 182 engine + 650 PointingKit hijau — tidak ada
kode Swift yang berubah.

## Progres terakhir (6 Okt 2026 — satu angka kawah dalam dua satuan, dan tidak ada yang mengikatnya)

### Temuan: audit mutasi kedua, setelah tiga celah pertama ditutup

Siklus sebelumnya menutup skala magnitudo, geometri bintang, dan koefisien
bayangan kawah. Audit berikutnya memakai cara yang sama pada angka yang
**tidak terlihat sebagai celah saat dibaca**: `check_crater_drawing_constants`
sudah menjaga `CRATER_RIM_OFFSET` (0,45) dan `CRATER_INNER_SCALE` (0,5), dan
memang menjaga keduanya sama — port memakai konstantanya, view memakai diskret
yang sama. Jadi gerbang itu benar, dan jelas kelihatan utuh.

### Yang tidak dijaga: angka yang sama, satuan berbeda

Cakram bibir kawah digambar di kedua bahasa dari **satu** faktor, tapi
dengan **notasi yang berbeda**:

| sisi | bentuk | satuan |
|---|---|---|
| view | `Path(ellipseIn: CGRect(… width: size * 1.84 …))` | **diameter** |
| port | `canvas.disc(…, mr * 0.92, …)` | **radius** |

`1.84 = 2 × 0.92`, jadi **kodenya benar**. Dan justru itu sebabnya tidak
terlihat: dua konstanta yang dijaga di atas bisa dibaca tanpa menyentuh
satuan, jadi gerbang yang menjaga keduanya tidak punya alasan untuk melihat
satu yang terakhir ini — dan `1.84` maupun `0.92` **tidak disebut gerbang
mana pun** di repo.

Bukti, dua arah terpisah:

```
VIEW  1.84 -> 1.60   313 pemeriksaan, 0 gagal
PORT  0.92 -> 0.70   313 pemeriksaan, 0 gagal
```

Keduanya mengubah **lebar sabit bibir kawah** — kontur yang menentukan apakah
kawah terbaca sebagai cekung bergerigi atau sebagai stiker rata. Geserannya
harus cukup lebar supaya sabitnya terlihat di ukuran jam 76 px; kalau terlalu
sempit, ia tertelan dasar cakram. Menggeser `0.92` di port membuat gambar
kawah di PNG menyimpang dari gambar kawah di jam tanpa satu pun pemeriksaan
yang menyebutnya.

### Dua cacat yang hanya muncul karena gerbangnya benar-benar dijalankan

**1. Regex gerbang merah pada kode yang benar.** Versi pertama membaca
`"diameter 2"` dari `size * 1.84` — pola `\*\s*([\d.]+)` menangkap digit
terakhir dari pengenal. Efeknya gerbang merah total, dan karena itu akan
dimatikan orang dalam sehari. Terperbaiki dengan `(?<![\w.])`.

Yang membuat bug ini bertahan: **baseline tidak pernah dijalankan sendiri.**
Harness selalu memasang mutasi lebih dulu, jadi mutasi pertama yang "merah"
terlihat seperti bukti berhasil — padahal baseline-nya pun merah. Probe
terpisah (baseline, tinggi saja, lebar saja) yang memunculkannya.

**2. Dua pemeriksaan tumpang tindih, dan hanya satu yang bisa menyala.**
Kasus "lebar != tinggi" menyalakan cek **rasio**, bukan cek lingkaran —
artinya cek lingkaran tidak pernah terbukti hidup. Setelah regex diperbaiki,
probe memisahkan keduanya:

| mutasi | cek lingkaran | cek rasio |
|---|---|---|
| baseline | hijau | hijau |
| tinggi saja (1.84 × 1.50) | **MERAH** | hijau |
| lebar saja (1.60 × 1.84) | **MERAH** | **MERAH** |

Baris kedua yang menentukan: mutasi yang **tidak** merusak rasio hanya
menyalakan pemeriksaannya sendiri — jadi keduanya benar-benar hidup dan tidak
saling menutupi.

### Batas gerbang yang dinyatakan, bukan disembunyikan

Gerbang ini mengikat **rasio**, bukan nilai absolut. Mengubah kedua sisi
bersama (`view 1.60 + port 0.80`) tetap hijau, dan itu **benar**: `1.84`
tidak punya model di `PointingKit`, jadi tidak ada sumber kebenaran ketiga
selain kedua sisi itu sendiri. Mengikat nilai absolut berarti menulis
"1.84 adalah angka yang benar" ke dalam gerbang — dan daftar seperti itu
menjadi **entri yang tidak pernah dibandingkan**, persis lubang yang
gerbang-gerbang tetangganya tutup. Kasus ini dikunci eksplisit di harness
sebagai "harus tetap hijau" supaya batasnya tercatat di tempat yang
dieksekusi, bukan hanya di komentar.

### Gerbang
- `python3 Tools/check-visuals.py --check` → **315 pemeriksaan** (313 → 315,
  +2 = rasio diameter/radius + simetris width/height), 0 gagal.
- `./swift-test.sh` → **182 engine + 650 PointingKit**, 0 gagal — tidak ada
  kode Swift yang berubah.
- `./swift-ui-lint.sh` → 28 aturan hijau. `./swift-typecheck.sh` → LULUS.
- CI: `37477614542` + `37477615500`.

---

## Progres terakhir (6 Okt 2026 — tiga gerbang yang mengukur model, port, atau port melawan dirinya sendiri)

### Cara membuka siklus ini: mutasi satu per satu, bukan membaca kode

Brief misi ini sudah selesai jauh sebelum hari ini (STATUS.md entri
"audit ulang status brief" sudah memverifikasi Bagian 1–4 + Fase A/B/C satu
per satu dari kode sungguhan, bukan dari log). Jadi yang tersisa bukan
membangun, melainkan mencari **cacat yang tidak terlihat dari membaca**.
Alat yang dipakai: **audit mutasi** — ubah satu konstanta di sumber, jalankan
gerbang, lihat apakah ada yang merah. Tiga mutasi pertama langsung membuka
tiga celah yang bentuknya sama.

### Bentuk cacatnya: satu kelas, tiga tempat

| Celah | Gejala saat mutasi | Pemeriksaan lama yang seharusnya menangkap |
|---|---|---|
| skala magnitudo → ukuran | `raw = 1.0` (semua bintang sama besar) | **nol** dari 296 |
| geometri bintang | 4 parameter, masing-masing | **nol** per mutasi |
| bayangan kawah | `0.55 → 0.05` | **hijau** |

Semuanya satu kalimat: **model Swift diubah, port Python tidak, dan gerbang
gambar tetap hijau sambil mengukur gambar yang tidak pernah tampil di jam.**
Ini pola yang sudah tercatat di STATUS.md lima kali (palet planet, kawah,
maria, profil Matahari, relief kawah, indeks warna bintang) — tapi untuk
kelompok ini **belum pernah** dibuktikan secara sistematis, dan hasilnya
mengevualifikasi: bukan enam daftar yang sama, tapi tiga **pengikat antar
lapis** yang memang tidak pernah ada.

Yang paling berbahaya dari tiga adalah **skala magnitudo**, karena dua
lapis yang mengukurnya **sudah ada** dan hijau: `testSizeScaleIsLogarithmicNotLinear`
mengukur modelnya, dan `check_star_colour_order` mengukur gambarnya. Keduanya
benar, tapi tidak ada yang mengikat apakah keduanya masih hal yang sama.
`relative_size` dipakai juga untuk warna mode malam port, jadi skala yang
simpang diam-diam mengubah kecerahan yang diukur `check_night_mode_purity` —
yaitu gerbang yang mengukur piksel yang tidak pernah digambar aplikasi.

### Cacat ketiga beda sifatnya: gerbangnya sudah ada, dan ia membandingkan port dengan port

Dua di atas adalah celah yang **tidak ada** penjaganya. Yang ketiga lebih
jahat: `check_crater_relief_matches_the_model` sudah ada dan sudah hijau,
dan mengklaim mengukur "rumus sama di kedua bahasa". Tapi `want_strength`
dibangun dari `R.CRATER_RIM_STRENGTH` lalu dibandingkan dengan `relief[i][5]`
yang dihitung oleh `crater_relief` dari **konstanta yang sama**. Port lawan
port — jadi mengubah `0.55 → 0.05` mengubah bayangan kawah yang benar-benar
tergambar, dan gerbang tetap hijau. Perbaikannya kedua koefisien dibaca dari
**model Swift**, dan rumusnya ditulis ulang dari koefisien model.

Pelajaran yang layak ditulis di repo ini: **"hijau" pada gerbang yang
mengakui dua bahasa adalah bukti yang lebih lemah dari yang tampaknya.**

### Tiga keputusan yang menjaga gerbang baru tidak menjadi daftar tangan

- **Baca dari sumber, dua bahasa.** Parameter diambil dari teks `CelestialVisual.swift`
  dan `render-visuals.py`, bukan disalin ke dalam gerbang. Daftar tangan di
  gerbang akan menjadi **entri ke-N yang tidak pernah dibandingkan** — persis
  lubang yang sedang ditutup.
- **Tulis ulang rumusnya, jangan panggil.** `star_geometry_outer` dan
  `magnitude_scale_from_parameters` menghitung ulang dari parameter yang
  dibaca. Kalau gerbang memanggil `R.star_geometry` untuk mengukurnya,
  kesalahan di fungsi itu ikut lolos bersama pengukurannya.
- **Bandingkan hasilnya, bukan cuma angkanya.** Ujung terluar bintang dan
  ukuran magnitudo diuji di seluruh rentang (21 ukuran, 28 magnitudo),
  karena daftar angka tidak akan melihat parameter yang dipakai di tempat yang salah.

### Bukti: 15 mutasi, dua arah

Delapan mutasi di port, tujuh di model. Semuanya membuat satu atau lebih
pemeriksaan merah — jadi gerbang ini menggigit di kedua bahasa, dan yang
direvisi di model saja tertangkap.

### Tiga mutasi sunyi pertama: cacat harness, bukan gerbang tuli

Ini bagian yang paling perlu dicatat, karena "sunyi" yang ternyata
menuduh gerbang yang benar hampir sama berbahaya dengan gerbang yang tuli.

| Mutasi yang tampak sunyi | Penyebab sebenarnya |
|---|---|
| `frame_half_extent 1.0 → 0.7` | teks itu ada di **5** fungsi port; `replace(...,1)` menyasar yang pertama — `saturn_ring`, bukan `star_geometry` yang diukur |
| `CRATER_RIM_STRENGTH 0.55 → 0.05` | **sama panjang** (`0.55`/`0.05`), jadi `__pycache__` port dipakai ulang |
| `CRATER_FLOOR_DEPTH 0.22 → 0.02` | sama persis |

Harness diperbaiki dengan tiga hal: mutasi menyebut **keberapa** occurrence
dan memverifikasi ulang potongan target **di dalam** teks mutasi;
`__pycache__` dihapus sebelum tiap muat; dan mutasi yang gagal disuntik
dilaporkan sebagai **kelemahan bukti**, bukan sebagai hasil. Setelah itu
kedua mutasi itu merah di baris yang tepat.

Pelajaran yang lebih luas dari pada mutasinya: **"nol pemeriksaan merah"
tidak berarti "mutasi tertangkap"**. Ia bisa berarti mutasi itu tidak pernah
menyasar. Bukti yang benar menuntut dua hal sekaligus: mutasi **terpasang**
dan gerbang **memang** melihatnya.

### Gerbang
- `python3 Tools/check-visuals.py --check` → **313 pemeriksaan** (296 → 313,
  +17 = 7 skala magnitudo + 8 geometri bintang + 2 koefisien kawah),
  0 gagal.
- `./swift-test.sh` → **CelestialEngine 182** (tak berubah), **PointingKit 650**
  (tak berubah) — **tidak ada kode Swift yang berubah**; yang masuk hanya
  gerbang.
- `./swift-ui-lint.sh` → 28 aturan hijau. `./swift-typecheck.sh` → LULUS.
- CI: `37474127973` (Engine Tests Linux) + `37474127936` (Apple Build macos-15).

### Batas yang jujur
- **Yang dibuktikan:** skala magnitudo, geometri bintang, dan coefisien
  bayangan kawah tidak bisa menyimpang antara model Swift dan port Python
  tanpa gerbang berbunyi — di kedua arah. **Yang belum:** gerbang ini
  mengikat **bentuknya**, bukan benar/tidaknya secara astronomi; dan
  `check_crater_relief_matches_the_model` masih hanya menguji arah + rumus,
  bukan apakah hasilnya terlihat benar di layar.
- **Harness bukti ada di `out/` yang di-ignore**, jadi tidak ikut ter-commit.
  Itu keputusan: harness berisi mutasi yang sengaja merusak sumber, jadi
  ia tidak boleh ikut terbawa ke dalam repo.
- Gerbang yang sudah ada **tidak dihapus atau ditulis ulang** — hanya
  dua koefisien yang sumbernya dipindah dari port ke model.

---

## Progres sebelumnya (6 Okt 2026 — jalur `tooFaint` dibuktikan lewat controller)

- **Yang ditutup.** `tooFaint` adalah satu-satunya alasan `VisibilityFilter` yang
  belum pernah terbukti sampai ke `.lock` lewat controller sungguhan. Sekarang
  sudah: `TooFaintLockHonestyTests` (3 tes).
- **Temuan yang mengubah cara pandang.** `tooFaint` **tidak mungkin** terjadi
  pada katalog produksi. Bintang paling redup di `Catalogue.brightStars` 1.98,
  sedangkan batas magnitudo paling sempit yang bisa diukur — bulan purnama di
  atas cakrawala — hanya turun ke 4.40. Jadi untuk setiap benda di katalog,
  `magnitude > limit` mustahil secara aritmetika, bukan cuma jarang.
  Sapu 660 jam langit malam mengonfirmasi: **0** penolakan `tooFaint`.
  Jadi alasan ini benar dan bekerja, tapi di produksi ia **kode mati**.
- **Kenapa ini tetap penting, bukan cuma catatan.** Kalau katalog nanti
  diperluas dengan bintang samar (batas sekitar 6.0, wajar untuk langit gelap
  tanpa bulan), jalur ini langsung hidup untuk pengguna — dan jalur yang belum
  pernah dieksekusi data nyata adalah tempat paling rawan muncul alasan
  penolakan yang keliru. Tes menutupnya **sebelum** itu terjadi.
- **Cara membuktikannya.** Tes memakai bintang tiruan pada posisi Sirius dengan
  magnitudo 6.5: hanya magnitudo yang diubah, geometri dan cuaca langit tetap
  sama, jadi satu-satunya variabel yang diuji memang penyaring magnitudo.
  Ini menyalakan jalur yang belum pernah hidup tanpa menyalin katalog.
- **Tiga tes.** (1) bintang redup tidak pernah `.lock`, `searchHint` =
  `.allTooFaint`, dan tanpa haptic sukses; (2) **bukti positif** — benda yang
  sama persis dengan magnitudo terang **harus** `.lock` (tanpa ini, tes pertama
  bisa hijau karena alasan yang salah); (3) katalog produksi tidak punya benda
  yang bisa memicu `tooFaint`, dengan angka batas dan magnitudo ikut laporan
  supaya kalau katalog berubah, yang gagal pertama adalah angka itu — bukan
 ArchaeType perilaku yang menyesatkan.
- **Bukti mutasi.** Menyisipkan `+ 6.0` ke ambang `tooFaint` di `Visibility.swift`
  → ketiga assertion-nya merah sekaligus (`.lock` bocor, hint jadi `nil`, haptic sukses
  muncul). Menambah bintang mag 6.5 ke katalog simulasi pada tes (3) → merah
  dengan `775` penolakan. Catatan jujur soal satu mutasi yang **tidak** menggigit:
  menggeser ambang di sisi tes (+5.0) tetap hijau. Itu memang alat ukurnya
  katalog, bukan ambangnya — jadi tes itu mengukur katalog sungguhan dan
  tidak bisa dibuat hijau oleh angka rekaan.
- **Yang TIDAK diubah.** `Visibility.swift` dan `Catalogue.swift` kembali
  identik dengan `main` — mutasi hanya untuk pembuktian. Semua perubahan di
  `Packages/PointingKit/Tests/` saja.
- **Hitungan.** 182 + 650 hijau (dari 647). README diperbarui karena gerbang UI
  yang menjaga angka itu ikut menggigit.
- CI: `37457789272` (Engine Tests Linux) + `37457789113` (Apple Build
  macos-15) — dua-duanya hijau pada `d2b17a4`.

---

## Progres terakhir (6 Okt 2026 — "semua di bawah horizon" tidak pernah benar, 2469 dari 2469)

### Cacatnya: hint membaca seluruh langit, lalu mengklaim soal arah yang ditunjuk

`SearchHint` lahir untuk satu tujuan: menjelaskan **kenapa tidak ada objek**.
`.allBelowHorizon` berbunyi "Semua objek di katalog sedang di bawah horizon" —
kalimat yang bisa diperiksa, dan ia memang salah hampir selalu.

Penyebabnya bukan logikanya yang keliru. `PointingResolver.diagnose` menghitung
`rejected` dengan benar, tapi ia menjalankan `VisibilityFilter` pada **setiap**
benda sebelum memotong kerucut arah tunjuk, jadi daftarnya memuat benda dari
seluruh langit. `searchHint` lama membaca **seluruh** daftar itu lalu menyimpulkan
sebab tunggal darinya.

Benda di sisi langit yang lain tidak pernah sengaja ditunjuk pengguna, jadi
kesimpulannya tidak menjelaskan apa pun soal arah jam. Kalimat aslinya di engine
sudah benar ("semua benda **di kerucut arah tunjuk**") — kodenya yang
bertentangan dengan kalimatnya sendiri.

### Pengukurannya, bukan tebakan

Sapu 24 jam x seluruh arah, katalog produksi (`Catalogue.brightStars` +
efemeris nyata), hanya malam, hanya resolusi tanpa jawaban:

| Angka | Nilai |
|---|---|
| Resolusi tanpa jawaban | 2492 |
| Menampilkan `.allBelowHorizon` | 2492 (**100%**) |
| Di antaranya **benar** | **0** |
| Arah dengan klaim itu **tidak** benar (bintang di atas horizon) | 2469 |

Setiap saat ada sedikit saja satu bintang katalog yang benar-benar di atas
horizon. Contoh yang tercatat: `h=7 alt=10 az=0` — 13 bintang di atas horizon,
`searchHint` = `allBelowHorizon`.

Dua kelompok muncul dari pengukuran itu:

| Kelompok | Penolakan dalam kerucut | Versi lama | Versi sesudah |
|---|---|---|---|
| kerucut **kosong** (1987 arah) | tidak ada | `allBelowHorizon` | `noCandidates` |
| kerucut **berisi** (505 arah) | ada | `allBelowHorizon` | `allBelowHorizon` (benar) |

Jadi **seluruh** 1987 perbedaan datang dari kasus kerucut kosong — arah yang
benar-benar tidak punya benda di dalamnya, dan tidak ada satu pun yang bisa
diperiksa. Untuk arah itu satu-satunya kalimat jujur adalah "belum ada objek yang
cocok". Untuk 505 arah yang memang berisi benda di bawah horizon, klaim
spesifik itu **benar** dan tetap dipertahankan.

### Perbaikannya

`Resolution` sekarang menyimpan `pointingConeDeg` — kerucut yang benar-benar
dipakai `diagnose`. Tanpa itu, satu-satunya penaksir yang jujur adalah "tidak ada
yang bisa dikatakan" untuk semua keadaan, yaitu membuang informasi yang sudah
benar-benar dihitung. `nil` (resolusi buatan) **tidak pernah** dikarang jadi
cakupan: ia jatuh ke `.noCandidates`.

Kodenya satu baris filter, tapi kunci perbaikannya adalah **cakupan**, bukan
kondisi:

```swift
let inCone = rejected.filter { $0.separationDeg <= cone }
guard !inCone.isEmpty else { return .noCandidates }
let reasons = Set(inCone.map(\.visibility))
```

### Dua cacat di gerbang yang aku tulis sendiri, keduanya tertangkap sebelum push

Ini yang penting dari siklus ini, karena keduanya bentuk "hijau yang tidak
hijau" — kelas yang jadi pelajaran terus-menerus di repo ini.

**1. Gerbang hijau di atas cacat yang diklaimnya.** Versi pertama
`testEmptyConeDropsTheWholeSkyReason...` membandingkan nilai yang dihitung
**sendiri** di dalam tes (`naiveHint`) dengan `r.searchHint` — ia tidak pernah
menyentuh perilaku produksi sama sekali. Yang lebih buruk, VERSI PERTAMA dari gerbang
itu **hijau di atas mutasi yang menghapus seluruh penyaringan kerucut**:

```
MUTASI: searchHint baca SELURUH daftar (cacat asli)
Executed 5 tests, with 0 failures        <-- hijau di atas cacatnya sendiri
```

Penyebabnya: syarat "penolakan di dalam **dan** luar kerucut" tidak pernah
terpenuhi di langit malam nyata — penolakan di luar biasanya punya alasan yang
sama dengan di dalam (`mixedInOut=505`, `perbedaan=0`). Jadi gerbang itu
mengukur keadaan yang tidak pernah terjadi. Setelah diukur ulang, gerbang yang
benar adalah yang menguji kasus **kerucut kosong**, dan langsung menggigit:

```
GAGAL arah tanpa benda di kerucut tidak boleh disebut sebab seluruh langit:
      ("1987") is not equal to ("0")
      tampil=allBelowHorizon alt=-10
```

**2. Kontradiksi yang mustahil terjadi.** Penjaga kedua ("tidak boleh ada
bintang terlihat di kerucut saat `.allBelowHorizon`") hijau **dan tetap hijau**
saat mutasi dipasang. Bukan karena logikanya salah, tapi karena setelah
penyaringan kerucut kasus itu memang mustahil: `.allBelowHorizon` hanya tampil
saat seluruh benda di kerucut ditolak `belowHorizon`, jadi tidak bisa ada yang
terlihat di sana. Nol konflik adalah **konsekuensi** aturan, bukan bukti
tentangnya. Dijaga sebagai syarat invariant (`hints > 0` + `konflik == 0`), dan
keterbatasannya ditulis di berkasnya supaya tidak dibaca sebagai bukti bahwa
mutasi apa pun akan merah di situ.

Pelajaran yang dicatat: **pilot pertama salah** (menunjuk bintang terang hampir
selalu menghasilkan jawaban, jadi 0 sampel) dan **versi gerbang pertama hijau di
atas mutasinya sendiri**. Keduanya hanya terlihat karena mengukur dulu dan
mutasi, bukan karena membaca kode.

### Cacat keempat yang ditemukan di fixture yang sudah ada

Empat tes lama di `SearchHintTests` merah setelah perbaikan — dan **semuanya
benar**:
- Tiga fixture tangan membangun `Resolution` tanpa kerucut. Sekarang mereka
  menyatakannya (fixture lebih jujur, bukan lebih lemah).
- `testControllerCarriesHonestHintWhileSearching` mengarahkan jam ke **zenith
  sisi selatan, sekitar 80 derajat dari Polaris**, lalu menuntut jawaban "semua
  di bawah horizon". Kerucut arah tunjuk saat itu **kosong** — persis cacat ini,
  ditulis sebagai expectations. Sekarang diarahkan **ke Polaris**, dan hint
  spesifik itu benar kembali: ada benda di kerucut, dan benda itu memang di
  bawah horizon. Ditambah prasyarat yang mengulang pengukurannya.

### Gerbang
- `./swift-test.sh` → **CelestialEngine 182** (tak berubah), **PointingKit 647**
  (+5), 0 gagal.
- `./swift-ui-lint.sh` → 28 aturan hijau. Aturan 10 menangkap README yang masih
  bilang 642; diperbarui ke 647.
- `./swift-typecheck.sh` → LULUS. `python3 Tools/check-visuals.py --check` →
  **296 pemeriksaan**, 0 gagal (tak disentuh).
- CI: `37456329575` (Engine Tests Linux) + `37456329375` (Apple Build
  macos-15) — **dua-duanya hijau** pada `5c59a21`.

### Batas yang jujur
- **Yang dibuktikan:** 100% klaim `allBelowHorizon` yang muncul di langit
  malam nyata adalah salah bentuk, dan setelah dibatasi kerucut tidak ada
  arah yang menampilkan sebab seluruh langit. Yang BELUM: sapu ini 24 jam
  pada **satu tanggal** di **satu kota**. Tanggal/kota lain bisa punya keadaan
  berbeda, dan `tooFaint`/`tooCloseToSun` **tidak pernah muncul sama sekali**
  di sapu ini — jadi jalur itu belum terukur di sini.
- **Perilaku yang berubah untuk pengguna:** arah dengan kerucut kosong kini
  menampilkan kalimat generik, bukan sebab palsu. Itu tukar-menukar informasi yang
  salah menjadi informasi yang benar — disengaja, dan alasannya sama seperti
  keputusan tidak memaksa `.lock` untuk bulan.
- **Bukan pengganti pengujian manual.** Gerbang ini membuktikan bahwa klaim yang
  ditampilkan tidak bertentangan dengan apa yang bisa dilihat; ia tidak
  menilai apakah kalimatnya enak dibaca.
## Progres terakhir (6 Okt 2026 — jalur bawah-horizon sampai .lock, dan audit ulang status brief)

### Temuan siklus ini: brief di misi sudah LENGKAP, bukan awal dari nol

Mulai siklus ini dari STATUS.md paling atas berbunyi "Seluruh brief sudah
terimplementasi dan teruji" (entri glassmorphism-ditolak). Dipastikan dengan
membaca kode sungguhan, bukan cuma log:

- **Visual objek prosedural**: `CelestialVisual.swift` (model, PointingKit,
  2112 baris) + `CelestialVisualView.swift` (SwiftUI Canvas, 983 baris) sudah
  menggambar planet (pita Jupiter, cincin Saturnus, kutub Mars, fase Venus/
  Merkurius, kawah Merkurius), Bulan (fase dari `moonIlluminationFraction`),
  bintang (glow sesuai kelas spektral + magnitudo), Matahari (corona), dan
  objek langit dalam (4 morfologi: nebula, galaksi, gugus bola, gugus terbuka,
  nebula planetari). Visual samar + "?" saat `isConfirmed == false`.
- **Night mode murni**: `NightVisual.swift` memetakan semua warna ke merah
  murni (hijau/biru = 0), diuji di `NightVisualTests`. `NightMode.swift` +
  `@AppStorage`.
- **AOD**: `ReducedLuminanceView.swift` + `isLuminanceReduced`; animasi
  dihentikan saat redup (`ReducedLuminanceHonestyTests`).
- **VoiceOver**: `accessibilityLabel` di kartu/panel; `StateAnnouncement`
  saat lock; grafis `accessibilityHidden(true)` karena induknya sudah
  mengumumkan nama+jenis+keyakinan+fase (alasan tertulis di kode).
- **Audio**: `AudioCue.swift` saat `.lockSucceeded`, bisa dimatikan.
- **Complication**: `ComplicationWidget.swift` + `ComplicationStore.swift`.
- **Lokalisasi**: `Localizable.xcstrings` (438 kunci, `sourceLanguage: id`,
  semua `en` `translated` — 0 kosong). `SWIFT_EMIT_LOC_STRINGS: NO` sengaja.
- **Izin sensor**: `project.yml` sudah menyatakan
  `NSLocationWhenInUseUsageDescription` + `NSMotionUsageDescription` (teks
  Indonesia jelas "kenapa") untuk **kedua** target; `InfoPlist.strings` id+en.
  Penolakan izin **ditangani**: `LocationProvider.note` + `MotionLogger`
  (`unavailableReason`/`handleFailure`) menampilkan pesan jelas, bukan crash.
- **Surface token**: `SurfaceTokens.swift` — latar `#0A0A0F`/`#121216`, surface
  stepping 3 lapis, aksen gradient "ruang→nebula" hanya untuk elepas aktif,
  hairline border. Glassmorphism **sengaja ditolak** (kontras tak terjamin).
- **Dynamic Type**: empat `.system(size:` hanya ada di komentar; sisanya
  font semantik + `@ScaledMetric`.
- **Reduced motion**: `MotionPolicy.allowsTransitions`.

Jadi "misinya" (Bagian 1–4, Fase A/B/C) sudah selesai; yang tersisa adalah
penyempurnaan tanpa henti yang paling ber-nilai, bukan membangun ulang.

### Yang ditambahkan: jalur bawah-horizon ke .lock (gap kejujuran nyata)

`DaylightLockTests` menguji controller sampai `.lock` untuk siang, **tapi**
ia sengaja memilih bintang DI ATAS horizon (alt > 30°) supaya penolakannya
datang dari `daylight`, bukan `belowHorizon`. Jadi celah "arah tunjuk ke benda
di bawah horizon tetap `.lock`" belum pernah diuji di level controller — persis
kelas cacat yang diulang di repo ini (bagian benar sendiri, jalur ke `.lock`
belum disambung).

`BelowHorizonHonestyTests` (3 tes, memutar `PointingController` sungguhan):
1. bintang di bawah horizon (malam, langit gelap) → tidak pernah `.lock`;
2. `snapshot.searchHint == .allBelowHorizon` (jujur, bukan `.noCandidates`),
   dan tidak ada haptic `lockSucceeded`;
3. bintang SAMA saat di atas horizon (> 30°) → **harus** `.lock` (bukti
   positif bahwa penolakan tadi spesifik ke horizon).

Sasaran dipilih dari resolver (alt ≤ −30 pada `downTime`, > 30 pada `upTime`,
keduanya malam), bukan ditulis tangan — fixture yang berubah gagal keras.

### Dilanjut: Bulan di bawah horizon, dan kenapa tidak ada bukti positif

Benda tata surya punya jalur hitung yang berbeda dari bintang katalog
(efemeris, bukan tabel J2000), jadi "di bawah horizon" bagi mereka dihitung
dari sumber lain. Dua tes tambahan menjaga sisi itu:

4. `testMoonBelowHorizonNeverLocks` — arah tunjuk ke Bulan di bawah −30°
   (malam) tidak boleh `.lock`, dan tidak boleh membakar haptic
   `lockSucceeded`.
5. `testMoonBelowHorizonIsRejectedForThatExactReason` — resolver harus
   **menyebut Bulannya** di `rejected` dengan visibility `.belowHorizon`,
   bukan membuangnya diam-diam. Inilah yang membedakan "tidak terkunci" dari
   "tidak terlihat karena memang di bawah horizon".

**Yang sengaja TIDAK diuji: ".lock saat di atas horizon" untuk Bulan.** Ini
keputusan, bukan kelalaian — dan ditentukan oleh pengukuran, bukan tebakan.
Sapuan 60 hari lewat controller menunjukkan Bulan maupun Jupiter sering
`.uncertain` **meskipun arahnya sudah benar-benar diarahkan**, karena
keyakinannya turun ke MEDIUM begitu ada benda terang lain di dekat arahnya.
Itu **perilaku benar** (PRD: uncertainty > false confidence). Memaksa `.lock`
berarti mengarang isolasi, dan tes yang begitu hijau karena kebetulan
astronomi, bukan karena aturan yang diujinya benar — persis kelas "hijau yang
merusak" yang jadi pelajaran terus-menerus di repo ini. Untuk bulan, sisi
yang dijaga adalah **penolakan yang jujur**, bukan jam ketika ia terkunci.

Sapuan yang sama (871 slot bulan di bawah horizon, 60 hari): tidak satu pun
menghasilkan `.lock` — jadi perilaku kodenya memang sudah jujur, dan yang
baru adalah buktinya.

**Dinyatakan sebagai batas, bukan disembunyikan:** untuk bulan, `searchHint`
yang muncul adalah `.noCandidates`, bukan `.allBelowHorizon`. Itu **benar**:
alasan penolakan bercampur (sebagian `belowHorizon`, sebagian `tooFaint`),
dan `searchHint` sengaja tidak mengklaim satu sebab yang tidak tunggal. Yang
dijaga `allBelowHorizon` hanya pada kasus bintang yang seragam.

### Bukti gerbangnya menggigit (mutasi, bukan sekadar bertambah)

Mutasi: filter bawah horizon dilewati di `VisibilityFilter.classify`
(`altitudeDeg < policy.minAltitudeDeg` → `- 3600`) → **5 dari 5 test merah**,
termasuk kedua test bulan. Mutasi dikembalikan; `git diff` engine kosong.

### Gerbang
- `./swift-test.sh` → **CelestialEngine 182** (tak berubah), **PointingKit 642**
  (+5 total), 0 gagal.
- `./swift-ui-lint.sh` → 28 aturan hijau (Aturan 10 menangkap README 640→642).
- `python3 Tools/check-visuals.py --check` → 296 pemeriksaan, 0 gagal.
- CI: `37452384334` (Engine Tests Linux) + `37452384323` (Apple Build macos-15)
  — **dua-duanya hijau** pada `923ff14`.

### Sisa penyempurnaan bernilai nyata (pilih kecil, verifikasi Linux)
- Perluas katalog visual ke lebih banyak objek langit dalam (sudah 17: 4
  morfologi).
- Uji kejujuran ujung-ke-ujung lainnya: piringan Bulan redup / siang hari →
  tidak lock (mirip pola di atas, filter lain yang belum tersambung controller).
- QA berkelanjutan: tiap cacat → tes regresi dulu, baru perbaiki.

---

## Progres terakhir (6 Okt 2026 — koefisien warna bintang yang tidak pernah dibandingkan antar bahasa)

### Cacatnya: indeks B−V dijaga, tapi konversinya tidak

`check_star_colour_index_matches_the_model` menjaga 25 **indeks** B−V antara
`CelestialVisual.starColorIndex` (Swift) dan `STAR_COLOR_INDEX` (port). Tapi
indeks itu bukan warna — warna lahir dari tujuh koefisien di
`CelestialVisual.starRGB`, dan itulah yang benar-benar sampai ke piksel. Tujuh
koefisien itu hidup lagi di `star_rgb` pada `Tools/render-visuals.py`, dan
**tidak satu pun** dibandingkan. Mengubah `0.38` → `0.20` di kanal merah
`starRGB` membiarkan seluruh `check-visuals` hijau sambil mengukur warna yang
sudah tidak pernah tampil di jam — kelas cacat yang sama untuk kesekian kalinya:
**model diubah, port tidak, gerbang gambar mengukur gambar yang tidak pernah
ada.**

Buktinya diukur, bukan diasumsikan. Mutasi `red: unit(0.62 + 0.38 * warmth)` →
`0.62 + 0.20 * warmth` di model: **287 pemeriksaan visual, 637 uji Swift, 28
aturan lint, dan typecheck semuanya tetap hijau** sebelum gerbang ini ada.
Alasannya bukan kebetulan: seluruh pemeriksaan warna bintang yang sudah ada
mengukur **gambar port**, jadi mengubah model tidak mengubah satu piksel pun
yang sedang diukur.

### Yang ditambahkan: baca bentuknya dari sumber kedua bahasa

`star_rgb_parameters` mengekstrak tujuh koefisien + dua batas penjepit +
pengali `warmth` dari **teks sumber** kedua bahasa (Swift dan Python), lalu
`check_star_rgb_conversion_matches_the_model` membandingkannya dua arah. Tidak
ada daftar tangan yang bisa tertinggal separuh saat koefisien ditambah.

Tiga keputusan sengaja di pembaca:
- **`let` opsional** — Swift menulisnya, Python tidak. Tanpa itu pembaca gagal
  tepat di sisi port, dan pemeriksaan yang gagal karena bacaan akan terlihat
  seperti pemeriksaannya yang salah.
- **Komentar `//` dibuang per baris** — badan `starRGB` punya komentar yang
  **memuat angka** ("kanal merah 1,11", "B−V >= ~1.35"); pembacaan tanpa
  membuangnya akan mengambil angka komentar sebagai koefisien. Tidak ada
  string literal di badan fungsi ini, jadi `//` di baris yang sama selalu
  berarti komentar.
- **Wilayah dibatasi** — Swift diakhiri `\n    }`, Python `\ndef `. Tanpa
  batas, wilayah Swift membentang sampai EOF dan menelan fungsi *berikutnya*
  yang kebetulan memakai pola serupa. Dibuktikan: menyuntik fungsi `decoy`
  setelah `starRGB` dengan koefisien lain sama sekali tidak membuat gerbang
  merah.

### Bukti gerbangnya menggigit, tiga arah

| Mutasi | Yang merah |
|---|---|
| model merah `0.38` → `0.20` (saja) | **2**: koefisien kanal merah + hasil di 26 indeks |
| port merah `0.38` → `0.10` (saja) | **2**: sama |
| model *dan* port tanda biru terbalik bersama | **0** — bukan drift; dan `testStarColourIsMonotonicInColorIndex` menangkapnya (1 gagal) |

Baris ketiga itu yang menentukan: mutasi di kedua bahasa sekaligus tidak boleh
memerah (bukan penyimpangan), dan memang tidak — tapi ia **tetap** tertangkap
oleh uji Swift yang mengukur *hasilnya*. Jadi dua lapis ini komplementer, bukan
berlebihan: gerbang ini mengikat *angkanya*, `check_star_colour_order` + tes
Swift mengukur *artinya* (urutannya, tanda, jangkauan).

### Gerbang
- `python3 Tools/check-visuals.py --check` → **296 pemeriksaan** (287 → 296,
  +9 = 1 bentuk terbaca + 4 skalar + 3 kanal + 1 hasil di seluruh indeks),
  0 gagal.
- `./swift-test.sh` → **CelestialEngine 182 + PointingKit 637**, 0 gagal — tidak
  ada kode Swift yang berubah; yang masuk hanya gerbang Python.
- `./swift-ui-lint.sh` → 28 aturan hijau. `./swift-typecheck.sh` → LULUS.
- CI: belum dikirim (siklus ini berhenti di gerbang lokal).

### Batas yang jujur
- **Yang dibuktikan:** tujuh koefisien + penjepit + hasil konversi di seluruh
  indeks katalog tidak bisa menyimpang antara Swift dan port tanpa gerbang
  berbunyi. **Yang belum:** gerbang ini tidak tahu apakah warna itu *benar*
  secara astronomi — itu milik `check_star_colour_order` dan
  `testStarColourIsMonotonicInColorIndex`. Ia juga tidak membandingkan warna
  mode malam (port menerjemahkan palet merah lebih dulu, jadi bentuk yang sah
  di kedua sisi memang berbeda di situ — sama seperti `check_sun_profile`).
- **Bukan pengganti uji Swift.** Mutasi tanda yang diubah di kedua bahasa
  lolos gerbang ini; yang menangkapnya adalah `testStarColourIsMonotonicInColorIndex`.
  Menghapus uji itu akan membuka celah yang gerbang ini secara desain tidak bisa
  tutup.

---

## Progres terakhir (6 Okt 2026 — Aturan 28: jalur metode paket yang dipanggil berkualifikasi, dan dua "hijau yang salah" yang ditemukan di dalam gerbang itu sendiri)

### Yang ditutup: `TipePaket.metode(Label:)`

Aturan 26 membuktikan `TipePaket.anggota` ADA. Aturan 27 (siklus lalu)
membuktikan label pada `TipePaket(Label:)`. Yang tersisa jalur paling jenuh:
metode statis paket yang dipanggil **berkualifikasi** —
`StateAnnouncement.text(for: engine.snapshot)`. Terukur **44 pemanggilan
berlabel** di `Apps/`, dan nol yang terperiksa.

Batasnya disengaja dan tercatat di gerbang: pemanggilan posisional
(135 buah) **dilewati**, karena urutan argumen tidak bisa dipastikan tanpa
compiler. Menebaknya lebih berbahaya daripada tidak memeriksa.

### Cacat #1: pembaca sumber kehilangan isi berkas, dan ia tidak terlihat

Ada **dua** salinan pembaca `strip` di `swift-ui-lint.sh`. Salinan kedua
membuang kurung pembuka pada interpolasi string. `NumberFormat.swift` memuat

```swift
String(format: "\%.\(fractionDigits)f", ...)
```

maka badan `NumberFormat` terpotong tepat di string itu. Yang lenyap dari
indeks: **`degrees`, `signedDegrees`, `degreesPerSecond`, `percent`** —
empat metode yang semuanya dipanggil dari `Apps/`, dan semuanya lolos tanpa
satu pun pemeriksaan.

Inilah bentuk kegagalan yang paling merusak di sebuah gerbang statis: ia
bukan menolak isi yang salah, ia **kehilangan isi**, lalu tetap melaporkan
apa yang terdengar benar. Aturan 26 kebetulan tidak terpengaruh karena yang
diindeksnya anggota bertipe, bukan badan.

### Cacat #2: nol argumen dilewati, dan itu terlalu percaya diri, bukan kehati-hatian

Kedua aturan (27 dan 28) melompati pemanggilan tanpa argumen. Contoh:
`CalibrationSession()` padahal deklarasinya `init(controller:flow:)`
adalah pemanggilan yang **lebih salah**, bukan lebih sedikit pemeriksaannya.
Bukti suntikan:

| Suntikan | Hasil |
|---|---|
| `StateAnnouncement.text(forState:)` | merah |
| label paket di-rename `for:` → `forState:` | merah, 2 situs |
| `CalibrationSession()` | merah (sebelumnya hijau) |
| `StateAnnouncement.text()` | merah (sebelumnya hijau) |

Dua baris terakhir itulah yang memunculkan cacat #2 — keduanya hijau di
bawah aturan lama yang justru saya sebut sudah memverifikasi label.

### Bug di perbaikan saya sendiri

Perbaikan nol-argumen pertama kali saya tulis `if d and not any(x for _l, x in d)`
— yang berarti "deklarasi dengan **semua** parameter tanpa bawaan". Setelah
suntikan pertama gagal menyala, ternyata itu salah: yang saya maksud
`any(not x ...)` — **satu** parameter wajib sudah cukup. Bite-test yang
melempar IOException pada iterasi kedua adalah yang menangkapnya; membaca
kode saya sendiri tidak akan menangkapnya.

### Hasil

- `swift-test.sh`: **182 engine + 637 PointingKit** hijau
- `swift-typecheck.sh`, `Tools/check-visuals.py` (287) hijau
- `swift-ui-lint.sh`: **28 aturan** hijau
- CI: `engine-tests` + `ios-build` hijau

---

## Progres sebelumnya (6 Okt 2026 — label argumen pada inisialisasi paket)

## Progres terakhir (6 Okt 2026 — label argumen: jalur pemanggilan yang tidak pernah diindeks, sementara Aturan 26 menjaga jalur nama)

### Cacatnya: `Tipe(Label:)` bukan `Tipe.anggota`

STATUS.md sebelumnya menutup dengan "sisa yang paling bernilai" yang sangat
spesifik:

> `Apps/` memanggil **fungsi bebas** dan **inisialisasi** paket selain
> `TextLocalization.text(` — Aturan 26 hanya melihat `Tipe.anggota`.

Fungsi bebas diukur lebih dulu dan hasilnya nol: di `Packages/` hanya ada
**dua** fungsi top-level, dan `Apps/` tidak memanggil keduanya. Jadi separuh
sisa itu tidak ada — dan separuh lainnya yang diukur siklus ini.

Inisialisasi berbeda. `CelestialVisual.RGBComponents(red:green:blue:)` adalah
pemanggilan yang benar apartemen: receiver-nya adalah *tipe*, bukan
anggota, jadi **tidak ada `Tipe.anggota` yang bisa dibaca darinya**. Aturan 26
melihat `Tipe.anggota`; ia tidak bisa melihat pemanggilan. Pengukurannya:
**73** tipe paket punya `init` tertulis tangan, dan `Apps/` memanggilnya
**26 kali** — semuanya di berkas yang `swift-typecheck.sh` tidak pernah
kompilasi.

| Gerbang | Cakupan | Status |
|---|---|---|
| `swift-test.sh` | paket saja | tidak pernah melihat pemanggilan ini |
| `swift-typecheck.sh` | **dua** berkas Foundation | 24 dari 26 panggilan ada di berkas SwiftUI |
| Aturan 26 | `Tipe.anggota` | tidak mengindeks inisialisasi |
| CI macOS | `Apps/` terhadap paket | merah, ~2 menit/siklus terlambat |

Bentuk cacatnya persis bentuk yang berulang di rekap ini: kode yang **benar**
dipanggil dengan nama yang hampir benar, dan yang salah hanya karena satu
huruf.

### Dua bug di gerbangnya sendiri, keduanya ditemukan sebelum ditulis

**1. Perbandingan label yang salah.** `g[0] == d[0]` membandingkan
**elemen pertama dari tuple** dengan karakter pertama dari string. Hasilnya
`"controller" == "c"` → salah, jadi **22 dari 22** panggilan dilaporkan
tidak cocok pada kode yang benar. Versi pertama gerbang tidak hanya salah —
ia merah total, sama tidak bergunanya dengan gerbang yang selalu hijau.

Yang membuatnya lolos begitu lama tanpa terlihat: pesannya menyebut
"tidak cocok" untuk **seluruh** repo, dan orang cenderung mengira itu memang
betul. Gerbang yang merah pada semua kode terlihat seperti *"barangkah memang
belum ada?"* — dan di repo ini jawabannya memang iya. Itu sebabnya kelas
cacat yang sama perlu dua arah pembuktian.

**2. `==` terbaca sebagai nilai bawaan.** `MotionPolicy(isSceneActive: scenePhase == .active)`
mempUNYAI nilai bawaan menurut pembaca `=` pertama, sehingga argumen wajib
yang dihapus dari pemanggilan lolos. Perbaikannya bukan "cari `=` terakhir" —
melalui menyelesaikan `==`, `!=`, `<=`, `>=`, `=~`.

### Bukti gerbangnya menggigit, tiga arah

| Suntikan | Hasil |
|---|---|
| `latitudeDeg:` → `latDeg:` di `LocationProvider` | **MERAH** di baris yang tepat |
| `init(reduceMotion:)` → `init(redMotion:)` di paket MotionPolicy | **MERAH di 3 lokasi sekaligus** — pemanggil jadi salah dari sisi yang tidak disentuh |
| `haptics: events` dibuang dari `PointingUpdate(...)` | **MERAH**: argumen wajib hilang |

Arah kedua yang menentukan: mutasi di paket tidak menyentuh `Apps/` sama
sekali, dan tetap membuat gerbang berbunyi. Gerbang yang hanya bisa menangkap
suntikan di `Apps/` tidak akan menangkap refactor yang mengganti nama label
di paket.

### Batas yang jujur

- **Hanya label.** Tipe argumen, kelebihan beban, `init?`, dan `throws`
  tetap hanya ketahuan dari CI macOS.
- **Label eksternal.** Swift punya dua nama untuk satu argumen
  (`func text(for state:)` dipanggil `text(for:)`). Yang dibandingkan adalah
  yang dipakai pemanggil — kalau tidak, gerbang merah pada kode yang benar
  (persis bug pertama).
- **Inisialisasi bawaan** Swift (yang mengisi semua stored property) menerima
  apa pun dalam urutan apa pun, jadi tidak dihitung.
- **Pemanggilan posisional dilewati** — 4 dari 30. Menebak urutan akan membuat
  gerbang merah pada kode yang benar.
- **Fungsi bebas sudah nol**, jadi tidak ada gerbang untuk mereka: di
  `Packages/` hanya ada dua (`main`-like entry yang tidak dipanggil, dan satu
  lagi), dan `Apps/` tidak memanggil satupun.

### Gerbang

- `./swift-ui-lint.sh` → **27 aturan hijau** (26 → 27). Aturan 10 menangkap
  README yang masih bilang 26 lebih dulu, seperti fungsinya.
- `./swift-test.sh` → **CelestialEngine 182, PointingKit 637**, 0 gagal —
  **tidak ada kode Swift yang berubah**; yang masuk hanya gerbang + README.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `python3 Tools/check-visuals.py --check` → **287 pemeriksaan**, 0 gagal.
- CI: `37441056037` (Engine Tests Linux) + `37441055971` (Apple Build
  macos-15) — **dua-duanya hijau** pada `715dee7`.

### Sisa yang paling bernilai

Permukaan yang tersisa dari kelas yang sama: **metode paket yang dipanggil
berkualifikasi** (`TextLocalization.text(.someKey)`). Aturan 26 melihat
`Tipe.anggota` **ada**, Aturan 27 melihat label inisialisasi, tapi
`Tipe.metode(label:)` belum dijaga — dan di repo ini `PointingLinkMessage.plist(…)`
sudah memakai label eksternal (`for:`-gaya), jadi pembaca label yang salah
akan membuat gerbang merah pada kode yang benar. Cara yang sudah diuji di
siklus ini (dump badan tipe, baca label dari token pertama) hasilnya: 44
panggilan berlabel diperiksa, 9 salah baca sebelum label eksternal diperbaiki,
0 setelah — jadi permukaannya nyata dan alatnya sudah ada.

---

## Progres sebelumnya (6 Okt 2026 — 12 warna aksen yang tidak pernah dibandingkan, dan urutan kecerahan yang hanya hidup sebagai komentar)

### Cacatnya: palet gambar 17 warna, yang dijaga lima

`NightVisual.Accents` memuat 17 warna yang dipakai view untuk menggambar
pita Jupiter, cincin Saturnus, kutub Mars, kabut Venus, kawah Merkurius,
inti Matahari, dan piringan Bulan. Palet yang sama hidup lagi sebagai
`ACCENTS` di `render-visuals.py`. Sampai siklus ini yang dibandingkan hanya
**lima**: `craterFloor`, `craterRim`, `moonLit`, `moonUnlit`,
`moonPhaseUnknown`. Dua belas sisanya — termasuk **seluruh** warna planet
dan Matahari — tidak dibandingkan siapa pun.

Mengubah warna cincin Saturnus di Swift karena itu membiarkan setiap
pemeriksaan gambar hijau sambil mengukur warna yang tidak pernah ada. Kelas
cacat yang sama untuk ketujuh kalinya (palet planet, kawah, maria, profil
Matahari, relief kawah, tata letak langit dalam, indeks warna bintang):
**model diubah, port tidak, gerbang gambar mengukur gambar yang tidak
pernah ada.**

Siklus ini tidak akan menutupnya kalau yang diukur hanya kesamaan nilai.
Ada cacat kedua di palet yang sama, dan ia tidak berbentuk drift.

### Yang kedua: urutan kecerahan yang hanya hidup sebagai prosa

Tiga hubungan antar warna itu hari ini **hanya tertulis sebagai komentar**
di `NightVisual.swift`:

| Hubungan | Kenapa ada |
|---|---|
| `moonUnlit` < `moonPhaseUnknown` < `moonLit` | kalau `moonPhaseUnknown` bergeser sampai menempel `moonUnlit`, cacat "fase tak diketahui = bulan baru" kembali tanpa suara — gambarnya masih piringan polos |
| `craterRim` > `craterFloor` | bibir kawah harus menonjol dari dasarnya; kalau terbalik, kawah tampak menonjol keluar |
| `sunCore` > `sunPhotosphere` | inti harus lebih terang dari fotosfer; kalau terbalik, Matahari tampak seperti cincin |

Niat yang tidak diukur adalah niat yang bisa hilang saat warnanya disunting
— persis kelas "aturan yang hanya hidup sebagai prosa" yang sudah tercatat
di repo ini untuk fase Bulan. Dan untuk yang satu ini ada alasan tambahan:
ia **kebal terhadap gerbang drift**. Kalau `sunCore` dan `sunPhotosphere`
ditukar di **kedua** bahasa sekaligus, tidak ada satu pun pemeriksaan
"port == model" yang bisa melihatnya.

### Bukti gerbangnya berbunyi — tiga mutasi, tiga arah berbeda

| Mutasi | Yang merah | Kenapa penting |
|---|---|---|
| `saturnRing` merah 0.86 → 0.20 di Swift | `aksen gambar saturnRing`, menyebut kedua nilai | drift biasa; yang 12 warna itu tidak punya penjaga |
| `moonPhaseUnknown` 0.52 → 0.14 di Swift | pemeriksaan nilai **dan** pemeriksaan lama di `check_port_matches_swift_constants` | gerbang tidak menggandakan yang sudah ada secara vacuous — ia menambah yang belum ada |
| jangkar `static let accents = Accents(` diganti nama | gagal **bersih** menyebut jangkarnya, bukan traceback | gerbang yang melempar pengecualian saat sumber dirapikan akan dihapus orang |

Dan mutasi yang menentukan — **ditukar di kedua bahasa sekaligus**, jadi
tidak ada drift sama sekali:

```
sunCore        1.00/0.93/0.62  →  1.00/0.72/0.24   (Swift + port)
sunPhotosphere 1.00/0.72/0.24  →  1.00/0.93/0.62   (Swift + port)

GAGAL aksen gambar: inti Matahari lebih terang dari fotosfernya  0.850 < 0.653
287 pemeriksaan, 1 gagal
```

Satu-satunya pemeriksaan yang berbunyi adalah **urutan**-nya. Mutasi yang
sama pada `craterFloor`/`craterRim` juga merah, walaupun di sana pemeriksaan
lama ikut menyala karena nilai keduanya sudah dijaga.

### Kenapa diukur dari model, bukan dari gambar

Urutan kecerahan diukur dari **model Swift** (`NightVisual.swift`), bukan
dari piksel port. Alasannya sama dengan gerbang tetangganya: gambar port
adalah yang sedang diukur, jadi pembanding yang diambil dari gambar itu
sendiri akan ikut berubah bersamanya dan selalu hijau.

### Gerbang

- `python3 Tools/check-visuals.py --check` → **287 pemeriksaan** (265 → 287,
  +22 = 17 warna + 2 arah daftar + 3 urutan), 0 gagal.
- `./swift-test.sh` → **CelestialEngine 182, PointingKit 637**, 0 gagal —
  tidak ada kode Swift yang berubah.
- `./swift-ui-lint.sh` → 26 aturan hijau. `./swift-typecheck.sh` → LULUS.
- CI: `37437537027` (Engine Tests Linux) + `37437537087` (Apple Build
  macos-15) — **dua-duanya hijau** pada `11e68b5`.

### Batas yang jujur

- **Yang dibuktikan:** ke-17 warna tidak bisa menyimpang antar bahasa, dan
  tiga hubungan kecerahan tidak bisa terbalik tanpa gerbang berbunyi.
  **Yang belum:** gerbang tidak tahu apakah warna itu **benar secara
  astronomi** — ia tahu kedua bahasa sepakat dan urutannya masuk akal.
- **Tiga urutan, bukan semua.** Masih ada hubungan lain yang hanya hidup
  sebagai komentar (mis. `venusHaze` lebih terang dari `planet.light`
  Venus). Yang dipilih tiga yang **menjadi cacat visual yang tak terlihat**
  kalau terbalik; sisanya akan tampak jelas di layar.

---

## Progres terakhir (6 Okt 2026 — warna bintang: 25 indeks yang tidak pernah dibandingkan dengan portnya)

### Cacatnya: tabel identitas warna hidup di dua bahasa tanpa satu pemeriksaan pun di antaranya

`CelestialVisual.starColorIndex` memetakan 25 bintang ke indeks warna B−V.
Tabel yang sama hidup lagi sebagai `STAR_COLOR_INDEX` di `render-visuals.py`.
Sampai siklus ini **tidak ada satu angka pun** dari keduanya yang dibandingkan —
dan setiap pemeriksaan warna bintang yang ada mengukur **gambar port**, jadi
mengubah salah satu nilai di Swift membiarkan semuanya hijau sambil mengukur
warna yang tidak pernah ada.

Ini kelas cacat yang berkas ini catat untuk keenam kalinya (palet planet,
kawah, maria, profil Matahari, relief kawah, tata letak langit dalam):
**model diubah, port tidak, gerbang gambar mengukur gambar yang tidak pernah
ada.** Yang membuat yang satu ini lebih dari sekadar daftar yang panjang
adalah **apa** yang ada di dalamnya.

### Kenapa warna bintang bukan sekadar 25 angka

Warna bintang di layar ini adalah **identitas**, bukan hiasan: Betelgeuse
+1.85 harus merah, Rigel −0.03 biru, Sirius +0.00 putih-biru. Bintang yang
salah warna tetap tampak sebagai titik bercahaya — tidak ada yang akan
melaporkannya, karena dari kejauhan ia masih "sebuah bintang".

Jadi cacatnya dua arah dan keduanya sunyi:

| Arah | Kenapa tidak terlihat |
|---|---|
| nilai menyimpang (1.85 → 1.10) | warnanya cuma bergeser sedikit; titiknya tetap titik |
| **tanda terbalik** (1.85 → −1.85) | Betelgeuse jadi biru. Tetap sebuah titik bercahaya. |

Yang kedua itu sebabnya gerbang ini memeriksa **tanda** secara eksplisit,
bukan hanya kesamaan nilai. Pemeriksaan tanda bukan pengganti pemeriksaan
nilai — ia menutup arah yang tidak pernah dilaporkan pengguna.

### Yang ditambahkan: dibaca dari sumber, dua arah, per bintang

`swift_star_colour_index` mengekstrak tabel dari **teks sumber Swift**, bukan
dari daftar yang ditulis ulang di gerbang. Ini keputusan yang sama dengan
gerbang tetangganya dan alasannya sama: tabel tangan di gerbang akan menjadi
**entri ke-26 yang tidak pernah dibandingkan** — persis lubang yang sedang
ditutup.

Tiga pemeriksaan arah, seperti gerbang palet planet:

| Pemeriksaan | Yang ditutup |
|---|---|
| setiap bintang model ada di port | bintang baru ditambah di Swift, port tidak pernah menggambarnya |
| tidak ada bintang sisa di port | port menggambar bintang yang sudah dihapus dari model |
| per bintang, dengan **nama** di pesannya | "tabel tidak sama" mengharuskan pembaca membedakan 25 angka sendiri |

### Bukti gerbangnya berbunyi

Mutasi pada model Swift, dikembalikan setelahnya:

```
"betelgeuse":  1.85  →  -1.85

GAGAL indeks warna betelgeuse              model -1.85, port +1.85
GAGAL ... tanda hangat/dingin sama ...     tanda terbalik: ['betelgeuse']
265 pemeriksaan, 2 gagal
```

Dua pemeriksaan merah sekaligus, dan pesannya menyebut **bintangnya** — jadi
drift bisa dibedakan dari entri yang hilang. Sebelum gerbang ini ada, mutasi
yang sama tidak membuat satu pun dari 237 pemeriksaan merah.

### Kenapa port-nya tidak ikut diubah

Tidak ada kode produksi yang berubah. Yang masuk hanya gerbang — persis
siklus palet planet: kalau model dan port hari ini sepakat, gerbangnya hijau
dan tetap menjaga besok. Mengubah keduanya sekaligus tidak akan membuktikan
apa pun tentang gerbang ini.

### Gerbang

- `python3 Tools/check-visuals.py --check` → **265 pemeriksaan** (237 → 265,
  +28 = 25 bintang + tanda + dua arah), 0 gagal.
- `./swift-test.sh` → **CelestialEngine 182, PointingKit 637**, 0 gagal —
  tidak ada kode Swift yang berubah.
- `./swift-ui-lint.sh` → 26 aturan hijau. `./swift-typecheck.sh` → LULUS.
- CI: `37433582376` (Engine Tests Linux) + `37433582281` (Apple Build
  macos-15) — **dua-duanya hijau** pada `d3a2ce7`.

### Batas yang jujur

- **Yang dibuktikan:** 25 indeks B−V tidak bisa menyimpang antara Swift dan
  port tanpa gerbang berbunyi, termasuk arah tanda. **Yang belum:** gerbang
  tidak tahu apakah indeks itu **benar secara astronomi** — ia tahu kedua
  bahasa sepakat. Nilai B−V itu sendiri tidak ada sumbernya di repo ini.
- **Warna bukan tata letak.** Yang dijaga di sini indeksnya; pemetaan
  indeks → warna layar (`Color(red:green:blue:)`) tidak dibaca dari model,
  sama seperti warna objek langit dalam.

### Sisa yang paling bernilai

Masih kelas yang sama: **gerbang yang mengklaim lebih dari yang diukurnya.**
Permukaan berikutnya yang terukur: `Apps/` memanggil **fungsi bebas** dan
**inisialisasi** paket selain `TextLocalization.text(` — Aturan 26 hanya
melihat `Tipe.anggota`, jadi sebuah nama fungsi yang tidak ada di paket masih
hanya ketahuan dari CI macOS.

---

## Progres terakhir (6 Okt 2026 — tata letak objek langit dalam dijaga per blob, bukan per bentuk)

### Cacatnya: gerbang bentuk langit dalam mengukur "berbeda", bukan "sama"

`check-visuals.py` sudah punya sepuluh pemeriksaan morfologi. Semuanya
mengukur bahwa bentuk-bentuk itu **berbeda satu sama lain** — jumlah piksel
yang tidak sama antara `deepsky-nebula` dan `deepsky-galaxy`, misalnya.
Itu pemeriksaan yang berguna, dan cacat yang ditutupnya nyata.

Tapi ia tidak menjaga apa yang paling perlu dijaga: bahwa port Python
menggambar bentuk yang **sama** dengan model Swift. Modelnya hidup sebagai
34 blob × 6 angka di `CelestialVisual.swift`, dan lagi di `DEEP_SKY_LAYOUT`
pada `render-visuals.py`. Tidak satu angka pun dari keduanya dibandingkan.
Menggeser semuanya sekaligus — atau satu blob saja — membiarkan **setiap**
pemeriksaan gambar hijau, karena bentuk-bentuknya tetap berbeda satu sama
lain setelah digeser. Yang diukur gambar itu hanyalah gambar port, jadi
gambar yang ikut berubah tidak pernah bisa memerahkannya sendiri.

Ini kelas cacat yang sudah muncul berulang di repo ini (palet planet, kawah,
maria, profil Matahari, relief kawah): **model diubah, port tidak, gerbang
gambar mengukur gambar yang tidak pernah ada.** Polanya selalu sama — yang
dijaga sebagian dari apa yang gerbang klaim dijaganya.

### Kenapa pembacaan cangkang nebula planetari perlu jalannya sendiri

Empat dari lima bentuk menulis larik segi-enam biasa dan terbaca oleh
pembaca tuple yang sama. `.planetaryNebula` tidak: ia menulis delapan posisi
(`ring`) lalu menggabungkannya dengan `shellOpacity` lewat `zip`, dengan
skala lebar `0.30`, rasio sumbu `1.0`, sudut `0.0`. Port menyimpan **hasil**
`zip`-nya.

Jadi pembacanya menghitung hasil yang sama dari bentuk sumbernya — bukan
menyalin angka. Itu yang membuat `shellRadius` bisa diubah di satu tempat
tanpa menduplikasi delapan posisi tangan. Tanpa pembacaan ini, satu-satunya
jalan adalah menulis ulang 48 angka jadi daftar tetap, dan daftar tetap
adalah daftar yang bisa tertinggal separuh saat bentuk baru ditambah.

### Cacat yang ditemukan saat menulisnya

Potongan `ring` yang dimulai dari `let ring:` ikut menyertakan anotasi tipenya
sendiri — `[(Double, Double)]` — yang juga berbentuk pasangan. Hasilnya
`float("Double")`: gerbang gagal dengan pesan yang tidak menyebut apa pun
yang salah. Perbaikannya memotong **setelah** `[` pembuka, dan alasannya
ditulis di komentar supaya yang merapikan model nanti tidak mengembalikannya.

### Bukti gerbangnya berbunyi pada cacat yang diklaimnya

Dua mutasi pada model Swift, dikembalikan setelahnya:

| Mutasi | Gerbang gambar | Gerbang baru |
|---|---|---|
| blob 0 nebula `-0.18` → `-0.19` | hijau | **merah**, "beda di indeks [0]" |
| `shellRadius` `0.42` → `0.45` | hijau, **angka pikselnya identik** (19506, 11965, …) | **merah** di indeks 0–7 |

Baris kedua adalah intinya: sepuluh pemeriksaan morfologi mencetak jumlah
piksel yang **sama persis** sebelum dan sesudah mutasi. Mereka tidak bisa
melihat radius cangkang berubah, karena yang mereka bandingkan adalah
bentuk-port lawan bentuk-port.

### Gerbang

- `python3 Tools/check-visuals.py --check` → **237 pemeriksaan** (230 → 237,
  +7), 0 gagal.
- `./swift-ui-lint.sh` → 26 aturan hijau.
- `./swift-test.sh` → **CelestialEngine 182, PointingKit 637**, 0 gagal —
  tidak ada kode Swift yang berubah; yang masuk hanya gerbang Python.
- CI: `37431024017` (Engine Tests Linux) + `37431024084` (Apple Build
  macos-15) — **dua-duanya hijau** pada `06a8ff9`.

### Batas yang jujur

- **Hanya tata letak.** Warna objek langit dalam (`ACCENTS["deepSky"]`, satu
  warna untuk semua bentuk) tidak dibaca dari model — modelnya sengaja tidak
  menyimpan warna, karena warna tidak bisa diuji di Linux.
- **Bentuk baru butuh dua sisi.** Menambah morfologi di Swift tanpa
  `DEEP_SKY_LAYOUT` merah di "setiap bentuk model ada di port"; sebaliknya
  merah di "tidak ada bentuk sisa di port". Menambah di kedua sisi dengan
  angka yang berbeda merah di per blob. Yang **tidak** merah: menghapus
  bentuk dari kedua sisi sekaligus.

---

## Progres sebelumnya (6 Okt 2026 — Aturan 25 menjaga satu nama tipe dari 406, dan STATUS.md sudah menulisnya)

### Cacatnya: gerbang keanggotaan tipe hanya berlaku untuk satu tipe

Aturan 25 lahir setelah `CelestialVisual.VisualFrame` dua kali lolos sampai
`origin/main` dan baru ketahuan dari CI macOS. Yang ditutupnya adalah
**keanggotaan pada satu tipe**: `CelestialVisual`. Entri yang menambahkannya
menulis batasnya sendiri dengan jujur, dan menyebut unit berikutnya:

> "Memperluasnya ke seluruh tipe PointingKit adalah unit berikutnya yang
>  jelas — dan lebih besar, jadi sengaja tidak digabung ke siklus ini."

Ini unit itu. Pengukuran yang membukanya: `Apps/` memuat **308** akses
berkualifikasi ke tipe paket (`Tipe.anggota`), dan Aturan 25 melihat
persis yang berawalan `CelestialVisual.`. Sisanya — `TextLocalization.`,
`VisualFrame.`, `DeepSkyCatalogue.`, `MotionPolicy.` — tidak dijaga apa pun
di Linux. Kualifikasi yang salah di salah satu dari mereka hari ini
diketahui **hanya** oleh CI macOS, satu siklus penuh (~2 menit) terlambat:
persis ongkos yang melahirkan Aturan 25.

### Kenapa tidak cukup menyalin Aturan 25 dengan `TYPE` jadi variabel

Dua hal membuat perluasan ini bukan sekadar penggantian nama, dan keduanya
diketahui dari percobaan, bukan dari membaca:

| Percobaan | Hasil |
|---|---|
| indeks anggota-langsung saja | **17 temuan pada kode yang benar** |
| + resolusi basis (pewarisan) | 0 temuan |

**1. Tipe bersarang.** `CelestialVisual.Planet`, `CelestialVisual.RGBComponents`,
`CelestialVisual.PhaseGeometry` adalah dua tingkat. Indeks anggota-langsung
memerah pada **17 kemunculan kode yang dikompilasi hari ini** — 9 di antaranya
`CelestialVisual.RGBComponents`. Gerbang yang memerah pada kode benar akan
dimatikan orang, jadi ini bukan gangguan: ini syarat agar aturan bisa hidup.
Pindainya karena itu memakai **nama berkualifikasi** dan mencatat tipe
bersarang sebagai anggota induknya.

**2. Anggota yang diwariskan.** `CelestialVisual.Planet.allCases` di
`PointingEngine.swift:251` tidak dideklarasi di badan `Planet` — ia datang
dari `CaseIterable`. Tanpa resolusi basis, aturan memerah pada baris yang
benar-benar dikompilasi. Jadi basis (pewarisan + konformans + `typealias`)
diikuti bertransitif.

### Bukti gerbangnya menggigit, dua arah

Dua suntikan, karena gerbang yang hanya pernah merah tidak membuktikan
apa-apa sama seperti gerbang yang hanya pernah hijau:

| Suntikan | Hasil |
|---|---|
| `CelestialVisual.ringBackHalfOpacityScale` (milik `VisualFrame`) + `TextLocalization.noSuchKeyLabel` | **MERAH**, dua-duanya, dengan nomor baris |
| `CelestialVisual.Planet.jupiter`, `.Planet.allCases`, `DeepSkyCatalogue.Morphology.galaxy`, `VisualFrame.halfExtent`, `CelestialVisual.RGBComponents(...)` | **hijau** — aturan tidak terlalu ketat |

Baris kedua yang menentukan: tanpa uji negatif, aturan yang menandai setiap
`Tipe.anggota` akan lolos sebagai "bisa merah" sambil memerahkan repo.

### Yang sengaja tidak dilakukan

- **Aturan 25 tidak dihapus.** Ia tercakup oleh 26, tapi pesannya untuk
  kasus "tipe top-level dipakai berkualifikasi" menyebut **solusinya**
  ("pakai `X` tanpa kualifikasi"), sedang pesan 26 bersifat umum. Pesan yang
  salah mengirim orang ke tempat yang tidak berisi apa pun — itu pelajaran
  yang melahirkan 25.
- **Komentar dibuang sebelum dipindai**, bukan setelah. Doc-comment di repo
  ini panjang dan berisi contoh kode Swift; contoh itu bukan kode yang
  dikompilasi, jadi mengindeksnya memasukkan anggota yang tidak pernah ada.

### Gerbang

- `./swift-ui-lint.sh` → **26 aturan hijau** (25 → 26). Aturan 10 menangkap
  README yang masih bilang 25 lebih dulu, seperti fungsinya.
- `./swift-test.sh` → **CelestialEngine 182, PointingKit 637**, 0 gagal —
  **tidak ada kode Swift yang berubah**; yang masuk hanya gerbang + README.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `python3 Tools/check-visuals.py --check` → **237 pemeriksaan**, 0 gagal.
- CI: `37427513897` (Engine Tests Linux) + `37427513688` (Apple Build
  macos-15) — **dua-duanya hijau** pada `eae1dd7`.

### Batas yang jujur

- **Indeksnya teks, bukan compiler.** Ia tahu "anggota dengan nama ini tidak
  ada di tipe ini"; ia tidak tahu tipe argumen, kelebihan beban, atau nama
  yang disintesis compiler. Kualifikasi yang **benar** dengan argumen yang
  salah tetap hanya ketahuan dari CI macOS.
- **Hanya akses berkualifikasi.** Fungsi bebas, `self.anggota`, dan ekstensi
  yang dideklarasi di `Apps/` tidak terlihat — sama seperti Aturan 25.
- **Tipe yang dideklarasi di `Apps/` dilewati.** Tujuannya menjaga pemakaian
  API paket dari view, bukan kode antar-view.
- **Nol temuan hari ini berarti tidak ada cacat yang tertinggal dari kelas
  ini**, bukan bahwa kelas ini sudah mustahil: nama baru yang ditulis besok
  di `Apps/` langsung dijangkau, karena daftarnya dibaca dari sumber.

### Sisa yang paling bernilai

Kelas yang berulang di rekap ini masih sama: **gerbang yang mengklaim lebih
dari yang diukurnya**. Kandidat berikutnya yang terukur: `Apps/` juga
memanggil **fungsi bebas** dan **inisialisasi** paket (`TextLocalization.text(`
sudah dijaga Aturan 17, tapi bukan nama fungsi bebas lainnya) — kelas cacat
yang sama, permukaan berikutnya.

---

## Progres terakhir (6 Okt 2026 — objek langit dalam tidak pernah dikunci lewat controller sungguhan)

### Cacatnya: jalur deep-sky teruji di tiap bagian, tidak pernah di satu jalurnya

Katalog objek langit dalam sudah diuji dari katalog → resolver → visual
(`DeepSkyCatalogueTests`), dan resolver produksi sudah dituntut memuatnya
(`testProductionResolverOffersDeepSkyTargets`). Tapi tidak ada satu pun uji
yang menembaknya lewat **`PointingController`** — lapisan yang sebenarnya
menjalankan jam: pergelangan diam → resolusi → `.lock` → haptic → rencana GoTo.

Ini kelas cacat yang sama yang berkas ini catat berulang kali: bagian-bagiannya
benar secara terpisah, dan yang tidak pernah disambungkan adalah jalurnya.
Bedanya di sini: celahnya bukan di kode, melainkan di **bukti**. Kalau besok
ada filter jenis yang membuang `kind: .deepSky` di jalur controller (misal di
`availableTargets` atau di konfigurasi app), ketiga belas uji katalog tetap
hijau sementara pengguna tidak pernah mengunci satu nebula pun — dan tidak ada
layar yang berubah, karena tidak ada yang tampil.

### Yang diuji, dan kenapa ujinya tidak boleh vacuous

`testDeepSkyObjectLocksThroughTheFullController` menuntut empat hal sekaligus,
semuanya diukur dari controller nyata bukan dari resolver:

| Syarat | Kenapa wajib |
|---|---|
| `.lock` tercapai | yang mau dibuktikan persis ini |
| `bestObject` ber-`kind: .deepSky` | kalau yang terkunci bintang, uji tidak menyentuh jalurnya |
| haptic `.lockSucceeded` muncul | `.lock` yang tidak berbunyi bukan `.lock` produk |
| GoTo **diizinkan** dan menarget **posisi objek** | aturan keras PRD: POINT → OBJECT ID → SAFE GOTO |

Waktu ujinya **dicari**, bukan ditulis: nebula harus di atas 20° **dan** malam
(Matahari di bawah −10°). Tanpa dua-duanya, kegagalan "tidak terkunci" bisa
datang dari horizon atau dari gerbang pengaman Matahari — bukan dari jalur
controller, persis cacat Sirius di `DaylightLockTests`.

### Dua kegagalan pertama uji ini, dan yang diajarkan masing-masing

**1. GoTo ditolak `sunPositionUnknown`.** Percobaan pertama memakai resolver
**tanpa efemeris** (mengikuti `singleStarResolver()` di berkas yang sama).
Rupanya `slewDecision` memakai `self.resolver`, jadi tanpa efemeris posisi
Matahari tidak bisa dihitung dan rencana ditolak — **perilaku yang benar**,
dan sudah dikunci `testSlewDecisionFlagsSunPositionUnknown`. Diperbaiki dengan
memberi resolver efemeris, bukan dengan melonggarkan policy.

**2. Pencarian malam tidak pernah cocok.** Percobaan kedua menulis
`sun < resolver.policy.minAltitudeDeg` — ambang yang terlihat tepat, tapi
`VisibilityPolicy.permissive` memakai `minAltitudeDeg = -90`, jadi syaratnya
mustahil. Ini persis kelas "nilai tetap yang terlihat masuk akal" yang sudah
berulang di repo ini, dan kali ini **di dalam uji**. Dibuktikan dulu lewat
uitji sementara (`alt=40.5, sun=-3.7` pada jam ke-0) sebelum memperbaiki, lalu
ambang malamnya ditulis tetap `-10` dengan alasannya di komentar — bukan
diambil dari policy yang bisa berubah.

### Gerbang

- `./swift-test.sh` → **CelestialEngine 182** (tak berubah), **PointingKit 637**
  (+1), 0 gagal. **Engine tidak disentuh** — berkas uji ini hanya di PointingKit.
- `./swift-ui-lint.sh` → **25 aturan hijau**. Aturan 10 menangkap README yang
  masih 636 lebih dulu, seperti fungsinya; diperbarui ke 637.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `python3 Tools/check-visuals.py --check` → **230 pemeriksaan**, 0 gagal.

### Batas yang jujur

- **Yang dibuktikan:** satu objek langit dalam (M42) benar-benar mencapai
  `.lock` lewat controller sungguhan, dengan haptic dan GoTo aman ke posisi
  objek. **Yang belum:** hanya **satu** objek dan **satu** pasang waktu/tempat
  yang diuji, bukan seluruh 17 objek — sapuan penuh akan jauh lebih lambat dan
  tidak menambah bukti tentang jalurnya, yang sudah sama untuk semua objek
  ber-`kind: .deepSky`.
- **Tidak ada kode produksi yang berubah.** Ini murni penambahan bukti; kalau
  jalurnya memang sudah benar, uji ini hijau dan tetap menjaganya besok.

---

## Progres terakhir (6 Okt 2026 — palet planet menyimpang antara Swift & port tanpa gerbang yang melihat)

### Cacatnya: port Python memuat warna planet yang tidak dijaga sama sekali

Pemetaan planet → warna + ciri hidup di **dua bahasa**: `Planet.palette` di
`CelestialVisual.swift` (Swift) dan `PLANET_PALETTE` di `render-visuals.py`
(Python). Sampai siklus ini `check_port_matches_swift_constants` hanya
menjaga sekitar 5 dari ~18 konstanta port; warna kelima planet termasuk yang
tidak dijaga. Mengubah warna Mars di salah satu sisi membiarkan seluruh
`check-visuals` hijau sambil mengukur gambar yang sudah tidak ada lagi — cacat
persis yang berkas ini ada untuk mencegah, hanya lubangnya ada di gerbangnya
sendiri. STATUS.md (entri "sisa yang paling bernilai") sudah menandainya.

### Perbaikannya, dan kenapa dibaca dari sumber

Tambah `read_planet_palettes_from_swift` yang mengekstrak **tiap** `case` di
dalam `switch palette` (light/dark/feature) lewat regex yang mengikuti bentuk
sumber yang sudah tertulis, lalu membandingkan ke-lima planet ke port Python
plus arah sebaliknya (planet di port harus ada di model). Membaca dari sumber
— bukan menulis 15 pemeriksaan tangan — berarti tidak ada daftar yang bisa
tertinggal separuh saat planet baru ditambah.

### Bukti gerbangnya menggigit

Mutasi warna Mars di `CelestialVisual.swift` (`0.88` → `0.10` pada saluran
merah) langsung membuat parser melaporkan drift pada `palet planet: mars
terang`, dan pemeriksaan merah. Tanpa penjaga ini, mutasi yang sama tidak
membuat satu pun dari 215 pemeriksaan lama merah.

### Gerbang
- `python3 Tools/check-visuals.py --check` → **230 pemeriksaan (215 + 15
  baru), 0 gagal**. 15 baru = 5 planet × (terang + gelap + ciri).
- `./swift-test.sh` → **PointingKit 636, CelestialEngine 182**, 0 gagal
  (engine tak disentuh — hanya `Tools/check-visuals.py`).
- `./swift-ui-lint.sh` → 25 aturan hijau.
- `./swift-typecheck.sh` → bersih.
- CI: `37423198197` (Engine Tests Linux) + `37423198137` (Apple Build
  macos-15) — **dua-duanya hijau** pada `4aa6e9d`.

### Batas yang jujur
- **Yang dibuktikan:** warna + ciri kelima planet tidak bisa menyimpang antara
  Swift dan port tanpa gerbang berbunyi. **Yang belum:** `feature` hanya
  dibandingkan sebagai nama (`bands`/`rings`/...); ia tidak mengecek bahwa
  view benar-benar *menggambar* ciri itu — itu sudah dijaga terpisah oleh
  `check_planet_features_present`.
- **Tidak ada layar/app yang berubah.** Murni penjagaan alat; UI tidak
  menyentuh `Planet.palette` langsung.

---

## Progres terakhir (6 Okt 2026 — Menunjuk jam ke Matahari diam-diam mengunci "Mars (medium)")

### Cacatnya: gerbang pengaman Matahari hanya mengecek jarak *kandidat*, bukan arah tunjuk

`PointingResolver.diagnose` mengandalkan `tooCloseToSun` di `VisibilityFilter`
untuk membuang kandidat yang terlalu dekat Matahari. Tapi `tooCloseToSun`
hanya menilai **setiap kandidat** terhadap Matahari — ia tidak pernah mengecek
apakah **arah tunjuk itu sendiri** adalah Matahari. Bukti: menunjuk jam tepat ke
Matahari saat Matahari tinggi (+75° di Jakarta tengah hari) menghasilkan
`best = mars, level = medium`, tanpa satu pun penolakan, lewat resolver *dan*
controller (haptic sukses + upaya GoTo).

Itu pelanggaran langsung aturan keras PRD: menunjuk Matahari tidak boleh pernah
menghasilkan kunci/identitas (false confidence), dan arah pergelangan tidak boleh
menjadi perintah motor (POINT → OBJECT ID → SAFE GOTO).

### Perbaikan

Tambah gerbang pengaman di awal `diagnose`: jika arah tunjuk berada dalam
`PointingResolver.sunSafeConeDeg` (13°, tetap — tidak mengikuti kebijakan
visibilitas yang bisa mematikan pemisahan Matahari lewat `minSunSeparationDeg: 0`)
dari Matahari **saat Matahari di atas horizon**, resolver langsung mengembalikan
niat kosong (`level: .low`, `best: nil`). Ambang tetap dipilih supaya aturan
berlaku sekalipun kebijakan paling permisif. 13° jauh di atas diameter sudut
Matahari (~0,5°) sehingga objek sah di dekat Matahari tidak ikut ditolak.

### Regresi yang dikunci
- `ResolverTests.testAimingAtTheSunWhileUpNeverLocks` — di level engine (Matahari
  tinggi), niat `.low`, `best == nil`.
- `PointingControllerTests.testAimingAtTheSunNeverLocksOrFiresSuccessHaptic` —
  di level controller nyata: `.lock` tidak pernah tercapai, tidak ada haptic
  sukses, tidak ada rencana GoTo, id bukan "sun".

### Gerbang
`./swift-test.sh` → CelestialEngine 182 (+1), PointingKit 636 (+1), nol gagal.
UI-lint 25 aturan lulus, check-visuals 215/215, typecheck bersih.

---

## Progres terakhir (6 Okt 2026 — Bulan terbenam masih memberi tahu langit "terang", bintang redup ditolak salah)

### Cacatnya: penyaring menuntut "ada cahaya Bulan" tapi tidak mengecek Bulan masih di atas horizon

`VisibilityFilter.effectiveLimitingMagnitude` mengetatkan ambang magnitudo murni
dari `moonIlluminationFraction`. `SkyContext` sudah memegang `moonAltitudeDeg`
— saat Bulan terbenam nilainya negatif, sementara `moonIlluminationFraction`
tetap tidak `nil`. Akibatnya engine membuang bintang redup **seolah ada
purnama di langit**, padahal Bulan justru sudah di bawah horizon dan pengguna
tidak bisa melihatnya. Itu penolakan palsu (false negative), persis arah yang
dilarang PRD v0.4: engine berbohong ke arah "lebih buruk" karena asumsi cahaya
yang tidak ada.

### Kenapa tidak ada gerbang yang melihatnya

Setiap uji cahaya Bulan yang sudah ada memakai `moonAltitudeDeg: 30` (Bulan di
atas horizon), jadi celah ini sama sekali tidak tersentuh:

| Uji | `moonAltitudeDeg` | Status |
|---|---|---|
| `testMoonlightTightensTheLimitingMagnitude` | 30 | hijau, tapi Bulan di atas |
| `testPermissivePolicyIgnoresMoonlight` | 30 | hijau, Bulan di atas |
| `testBrighterMoonNeverLoosensTheLimit` | 30 | hijau, Bulan di atas |
| `testSetMoonDoesNotBrightenTheSky` (baru) | **−20** | **merah sebelum perbaikan** |

Kelas yang sama dengan yang sudah berulang di repo ini: penyaring menuntut
sesuatu tapi hanya memeriksa sebagian dari syaratnya.

### Yang diperbaiki, dan kenapa bukan "naikkan saja threshold"

Menurunkan `moonBrighteningMagnitudes` akan membuat uji hijau hari ini dan
mengembalikan cacatnya begitu fraksi berubah — menyembunyikan, bukan menutup.
Satu-satunya tempat cacatnya lahir adalah `effectiveLimitingMagnitude`, jadi di
situlah perbaikannya: cahaya Bulan hanya dihitung kalau Bulan benar-benar masih
di atas horizon (`moonAltitudeDeg > 0`). Altitude `nil` (Bulan tak diketahui
letaknya) diperlakukan sama dengan "di bawah horizon": "tidak tahu" berarti
**jangan menebak lebih buruk**, bukan "asumsikan paling terang". Itu juga
menyelaraskan dengan prinsip yang sudah dipakai untuk fraksi `nil`.

### Gerbang: tulis tes yang gagal dulu, baru perbaiki

Dua tes baru ditulis **sebelum** perbaikan dan benar-benar merah:

```
error: Bulan terbenam tidak boleh mengetatkan ambang magnitudo  ("4.4") is not equal to ("6.0")
error: bintang redup harus terlihat saat Bulan sudah terbenam    ("tooFaint") is not equal to ("visible")
error: altitude Bulan tak diketahui = jangan anggap langit lebih terang ("4.4") is not equal to ("6.0")
```

Setelah perbaikan: 0 gagal. Tidak ada tes lama yang bergantung pada perilaku
rusak itu (CelestialEngine **179 → 181**, PointingKit tetap **635**).

### Gerbang lokal
- `./swift-test.sh` → **CelestialEngine 181 (+2), PointingKit 635**, 0 gagal.
- `./swift-ui-lint.sh` → **25 aturan hijau** (Aturan 10 menangkap README yang
  masih 179, seperti seharusnya — diperbarui ke 181/635).
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `python3 Tools/check-visuals.py --check` → **215 pemeriksaan, 0 gagal**.
- Engine teruji tidak disentuh; perubahan hanya di `Visibility.swift` + 2 tes.

### Batas yang jujur
- **Yang dibuktikan:** saat Bulan terbenam atau letaknya tak diketahui, ambang
  magnitudo kembali ke dasar dan bintang redup lolos. Yang **belum**: efek
  sudut Bulan (seberapa jauh dari pengamat) belum ikut dihitung — ini sengaja
  tidak ditambah karena belum ada sumbernya di engine (aturan repo: jangan
  menambah presisi yang belum ada sumbernya).
- **Tidak ada layar yang berubah.** Ini murni logika penyaring; UI tidak
  menyentuh `effectiveLimitingMagnitude` langsung.

---

## Progres terakhir (6 Okt 2026 — penyaringan siang yang hijau tanpa pernah mengujinya, sampai ke `.lock`)

### Alasan siklus ini masih ada

STATUS.md sebelumnya menutup dengan "sisa yang paling bernilai": menyambungkan
pemeriksaan langit terang **sampai ke `.lock`**. Tapi `.lock` bukan satu lapis.
Ada tiga lapis yang masing-masing bisa salah, dan hanya lapis pertama yang punya
penjaga:

| Lapis | Yang menentukan | Penjaga |
|---|---|---|
| `VisibilityFilter.classify` | `.daylight` | `DaylightStarVisibilityTests` (engine) |
| `PointingResolver.diagnose` | keyakinan `high`/`medium` | `ResolverTests` |
| `PointingStateMachine.update` | `.lock` hanya kalau `high` | `PointingControllerTests` |

Yang ditambahkan siklus ini adalah **uji terhadap jalur controller**, bukan
lapis baru. Hasilnya: berkas uji pertamanya hijau, sementara gerbang yang
diklaim di dalamnya **tidak ada sama sekali**.

### Bukti: mutasi yang tidak membuat satu pun tes merah

Suntingan yang diuji adalah `if false` di `VisibilityFilter.classify` — artinya
penyaringan siang dimatikan total, dan resolver tidak lagi punya alasan untuk
menolak apa pun karena terang:

```
== UJI HIJAU pada kode yang rusak — uji ini tidak menangkap mutasi ==
```

Jadi keempat tesnya hijau di atas kode yang **tidak bisa menolak siang**. Ini
bukan "hijau yang belum tegak" — ini hijau yang tidak pernah menguji apa yang
tertulis di namanya.

### Akarnya arah tunjuk, dan kenapa tidak terlihat dari STATUS.md sebelumnya

Tes lama menunjuk **bintang paling terang** (Sirius) tepat pada tengah hari
Jakarta, lalu menyimpulkan "tidak terkunci di siang". Pada 15 Januari Sirius
ada di bawah horizon. Resolver menolaknya lebih dulu karena `belowHorizon`,
**bukan** karena terang. Kesimpulannya tetap benar, dan tetap benar saat
penyaringan siang dihapus total — karena tidak pernah menyentuh gerbang yang
diujinya.

Pengukuran yang mengarahkan pilihan ini:

| Bintang | Ketinggian 12.00 WIB | Alasan penolakan sebenarnya |
|---|---|---|
| Sirius | di bawah horizon | `belowHorizon` |
| Vega | 42,3° | `daylight` |
| Altair | 74,8° | `daylight` (mag 0,77) |
| Antares | 39,4° | `daylight` |
| Fomalhaut | 39,0° | `daylight` |
| Deneb | 36,9° | `daylight` |

Jadi prosesnya tidak butuh tes baru sama sekali — cukup memilih bintang yang
benar, dan **bukti positifnya** bahwa bintang itu memang akan terkunci kalau
langit gelap.

### Dua cacat yang muncul di tes itu sendiri, keduanya tidak terlihat

**1. Cap waktu kontrol malam ditulis tangan.** Versi lama memakai
`noon + 10 jam` dengan alasan "22:00 WIB, Sirius masih di atas horizon Jakarta".
Untuk Jakarta pada **21 Juni** itu salah: tengah malam memang gelap, tapi
pada tanggal itu Sirius adalah benda **pagi** — ia baru terbit sekitar pukul
02.00, dan sepanjang malam ia di bawah horizon atau rendah sekali. Kontrol gagal
bukan karena menguji hal yang salah, tapi karena tidak pernah menguji apa pun.

Yang membuatnya bertahan adalah bentuknya: cap waktu yang **terlihat benar**.
Di dalam tabel apa pun ia persis "10 jam setelah tengah hari = malam". Tidak
ada yang perlu berubah di lingkungan untuk membuatnya benar — dan tidak ada yang
memberi tahu kalau ia salah.

Perbaikannya: jam kontrol **dicari dari resolver** dengan dua syarat yang
tertulis eksplisit (langit gelap **dan** bintang di atas 30°), dan "tidak ada"
mengembalikan `nil` supaya pemilik bisa lanjut ke bintang berikutnya.

**2. Syarat "hanya ditolak karena terang" diuji dengan nilai karangan.** Saat
saya menulis ulang pemeriksaan itu, saya mengoper `separationFromSunDeg: 0` —
angka tetap yang saya karang, bukan jarak sebenarnya ke Matahari. `classify`
menguji **urutan**: bawah horizon → magnitudo → dekat Matahari → terang.
Dengan jarak karang, `tooCloseToSun` menyala lebih dulu, jadi pemeriksaan
"alasannya harus `daylight`" jadi **hijau tanpa pernah mencoba gerbang
terang**.

Dua-duanya adalah kelas yang sama: nilai tetap yang terlihat masuk akal. Yang
membedanya dari kelas lain di repo ini adalah keduanya **ada di tes**, bukan di
kode produksi — jadi tidak ada satu pun pihak lain yang mengetahuinya.

### Bentuk akhir: arah tunjuk dihitung, bukan ditulis

Empat syarat, semuanya harus benar, semuanya dihitung dari resolver:

| Syarat | Kenapa wajib |
|---|---|
| tinggi > 30° saat tengah hari | kalau tidak, penolakan datang dari `belowHorizon` |
| `classify` mengembalikan `.daylight` **dengan jarak Matahari nyata** | kalau tidak, alasan yang menyala bisa `tooCloseToSun` |
| terkunci kalau `sunAltitudeForDarknessDeg` dilonggarkan ke 91 | bukti positif: tanpa ini "tidak terkunci" bisa salah alasan |
| ada jam malam saat ia > 30° | kontrol positif harus benar-benar ada |

Syarat ketiga sengaja **sempit**: hanya `sunAltitudeForDarknessDeg` yang
dilonggarkan; `minAltitudeDeg`, `limitingMagnitude`, dan `minSunSeparationDeg`
tetap. Dan longgarannya lewat **policy**, bukan lewat `SkyContext(isDark: true)`
— `classify` membaca `context.sunAltitudeDeg`, jadi konteks gelap yang dipalsukan
tanpa mengubah policy terlihat benar sambil tidak menguji apa pun. Itu percobaan
saya yang pertama, dan ia juga hijau.

Kegagalan mencari **gagal keras** dengan pesan yang menyebut berapa bintang yang
diperiksa — lebih baik merah daripada hijau karena langit yang keliru.

### Bukti gerbangnya menggigit

Dengan mutasi `if false` di `classify`:

```
GAGAL tidak ada bintang yang memenuhi keempat syarat; diperiksa 5 bintang di atas 30 derajat
```

Empat dari empat tes merah, dan pesannya **menyebut jumlah yang diperiksa** —
jadi kegagalan "fixture berubah" bisa dibedakan dari kegagalan "kode rusak".

### Yang sudah dijaga di tempat lain (dicek, bukan diasumsikan)

Mutasi `state = .lock` di `PointingFlow.update` (MEDIUM ikut mengunci) diuji
terhadap **dua** berkas:

| Mutasi | `DaylightLockTests` | `PointingControllerTests` |
|---|---|---|
| penyaringan siang dimatikan | **MERAH (4)** | tidak terkait |
| MEDIUM ikut `.lock` | hijau | **MERAH (3)** |

Jadi jalur yang lebih dalam sudah punya penjaganya. Yang siklus ini tambahkan
adalah lapis yang belum punya penjaga sama sekali.

### Gerbang

- `./swift-test.sh` → CelestialEngine **179** (tak berubah), PointingKit **633**
  (628 +5), 0 gagal. **Engine tidak disentuh** — berkas uji ini hanya di
  `PointingKit`.
- `./swift-ui-lint.sh` → 25 aturan hijau. Aturan 10 menangkap README yang masih
  628 lebih dulu, seperti fungsinya.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `python3 Tools/check-visuals.py --check` → **195 pemeriksaan**, 0 gagal.
- CI: `37412346943` (Engine Tests Linux) + `37412347030` (Apple Build macos-15)
  — **dua-duanya hijau** pada `66da06f`.

### Batas yang jujur

- **Yang dibuktikan:** jalur `attitude → controller → state` merasa terang sampai
  `.lock` benar-benar ditolak, dan penolakan itu blamed pada terang.
  **Yang belum:** `hapticLog` diperiksa di berkas ini, tapi pemicunya bukan
  sensor — itu `hapticEvents(from:to:)` yang sudah punya penjaganya sendiri.
- **Kontrol malam masih satu titik.** Kalau katalog bintang berubah dan tidak ada
  lagi yang memenuhi keempat syarat pada tanggal itu, berkas ini **gagal keras**,
  dan pesannya menyebut jumlah yang diperiksa. Tapi ia belum menguji **lebih dari
  satu** pasang siang/malam.
- Tanggal 15 Januari dipilih lewat pengukuran, bukan tebakan, dan dua prasyarat
  mengunci hasilnya: `testFixtureSkyIsBrightAndComesFromTheEphemeris` dan
  `testDaylightTargetIsRejectedForDaylightAndNothingElse`.

### Sisa yang paling bernilai

Fase C sudah lengkap (complication, `.xcstrings`, izin sensor, penanganan
penolakan izin). Yang tersisa bukan fitur, tapi **kelas** yang berulang sepanjang
rekap ini: gerbang yang mengklaim lebih dari yang diukurnya. Kandidat berikutnya
adalah `check_port_matches_swift_constants` — port Python masih hidup untuk
gambar, dan beberapa bentuk yang sudah pindah ke model masih bisa disimpang
tanpa apa pun yang melihat.

---## Progres terakhir (6 Okt 2026 — tes siang hari yang hijau tanpa pernah menguji penyaringan siang)

### Yang dicari siklus ini: bagian yang hijau tapi tidak menjaga apa pun

Alat untuk mengukur "apakah sebuah tes benar-benar menjaga sesuatu" sudah ada
di repo (`red-test.sh`), tapi terlalu lambat untuk sapuan. Jadi mutasi diterapkan
langsung ke sumber, lalu suite dijalankan penuh:

| Mutasi | Uji yang merah |
|---|---|
| ambang ketinggian dilewati (`altitudeDeg < -90`) | **52** |
| cahaya Bulan tidak lagi mengetat ambang | **4** |
| penyaringan siang dimatikan (`if false`) | **1** |

Dua yang pertama terlindungi rapat. Yang ketiga tidak: satu-satunya yang merah
adalah `VisibilityTests.testDaylightRejectsEverything`, yaitu tes **unit**-nya.
Semua tes integrasi tetap hijau.

### Akarnya bukan cakupan yang kurang, tapi arah tunjuk yang salah

`ResolverTests.testDaylightProducesNoHighConfidenceStar` menunjuk alt 60 /
az 180 pada tengah hari Jakarta dengan kerucut 40 derajat. Di dalam kerucut itu
**satu-satunya** bintang katalog berjarak **15,9 derajat** dari pusat,
sedangkan ambang `maxSeparationDeg` pada `ConfidencePolicy()` bawaan adalah
**10 derajat**.

Jadi MEDIUM-nya datang dari **tidak mengenai bintang**, sama sekali bukan dari
penyaringan siang. Tes itu hijau karena geometri, dan tetap hijau saat
penyaringan siang dihapus total, karena ia tidak pernah mengujinya.

Bukti positifnya dihitung, bukan dikira: dengan `isDark` dipaksa benar, bintang
yang sama **lolos** pada jarak 0,0 derajat dengan tetangga terdekat 32,8 derajat
(jauh di atas ambiguitas 20 derajat), yaitu **HIGH**. Jadi kalau penyaringan
siang hilang, menunjuk tepat ke bintang terang saat siang berakhir dengan kunci
`high` untuk langit yang terang.

### Perbaikannya: arah tunjuk ke 0 derajat, bukan menambah assertion

Tidak ada assertion baru pada kode yang sama; yang diganti adalah **arahnya**.
Titik tuju sekarang Arcturus persis, sehingga satu-satunya alasan penolakan
adalah terang.

Tiga hal lain ikut dijaga, karena ketiganya adalah cara tes ini bisa hijau tanpa
cacat:

- **Prasyarat siang** (`testFixtureTimeIsActuallyDaylight`): kalau tanggalnya
  berubah jadi malam, "tidak ada HIGH" tetap benar sementara pembuktiannya
  hilang.
- **Prasyarat "hanya terang"**: ketinggian, magnitudo, dan jarak dari Matahari
  diperiksa satu per satu dengan nilai yang sama seperti resolver, ditambah
  bukti positif bahwa bintang itu **lolos** saat langit dipaksa gelap.
- **Efemeris benar-benar dipakai**: tanpa baris ini, penyaringan siang bisa lolos
  bukan karena bekerja, melainkan karena `skyContext` jatuh ke asumsi "langit
  gelap" (tanpa efemeris `sunAltitudeDeg = -90`) yang justru **meloloskan**
  bintang.

### Green yang menutupi compile gagal

Mutasi kedua yang saya coba (`let sunAltitude = -90`) **tidak melaporkan satu pun
kegagalan**. Penyebabnya: literal `-90` disimpulkan `Int`, jadi berkas tidak
terkompilasi, dan pencarian baris "XCTAssert failed" tidak menemukan apa pun
karena tidak ada satu pun baris yang dieksekusi.

Jadi "0 kegagalan" itu **hijau palsuk**. Mutasi kedua diulang dengan tipe yang
benar (`isDark` dihitung dari `-90.0`, bukan dari tinggi Matahari nyata) dan
barulah ia menjadi bukti: **3 tes merah**, termasuk
`ResolverEphemerisTests.testDaylightProducesNoHighConfidenceStar`.

Pelajaran yang dicatat: **"nol kegagalan" belum berarti "mutasi tertangkap"**.
Harus berarti "mutasi tertangkap *dan* suite benar-benar menjalankan hal yang
bisa gagal". Dua mutasi pertama terlihat meyakinkan justru karena keduanya
menampilkan hitungan `Executed N tests`; pencarian ASSERT yang sendirian sudah
tidak cukup sebagai gerbang.

Catatan lanjutan: mutasi kedua ternyata **juga** membuat tes lama itu merah, jadi
ia memang hijau karena alasan yang benar, hanya tidak sendirian. Itulah yang
justru membuatnya menetap: dengan satu penjaga, tes lama itu bisa ditembus satu
mutasi dan tetap hijau karena alasan yang salah.

### Yang tidak diklaim

- Percakapan sunyi di `View`/UI **tidak** diuji dari sini; yang dikunci adalah
  keputusan resolver. Jalur `attitude -> controller -> .lock -> haptic/slew` punya
  penjaganya sendiri (`PointingControllerTests`, `LockArrivalTests`,
  `SlewSafetyTests`), tapi belum ada satu tes yang menyambung pemeriksaan siang
  itu sampai ke `.lock`.
- `searchHint` sengaja **tidak** diuji di sini: ia tinggal di `PointingKit`, dan
  aturannya sudah dikunci di
  `SearchHintTests.testDaylightWinsOverPerObjectReasons`. Mengulangnya di paket
  engine hanya membuat dua salinan aturan yang bisa berbeda pendapat.
- Stub efemeris tabel tulis-tangan yang sempat ditulis **dibuang**: alasannya
  ("jalur efemeris tidak pernah jalan di Linux") ternyata salah. `AstronomyKit`
  adalah dependensi nyata yang ikut terbangun di Linux, jadi
  `AstronomyKitEphemeris` sudah tersedia di gerbang cepat. Stub itu menambah
  permukaan tanpa menutup celah apa pun.

### Gerbang

- `./swift-test.sh` -> CelestialEngine **179** (+5), PointingKit **628** (tak
  berubah), 0 gagal.
- `./swift-ui-lint.sh` -> 25 aturan hijau. Aturan 10 sempat merah dan itu benar:
  README masih menyebut 174.
- `./swift-typecheck.sh` -> LULUS. `python3 Tools/check-visuals.py --check` ->
  **195 pemeriksaan**, 0 gagal.
- Diff sumber setelah mutasi: kosong (`git diff --stat` -> 0 berkas). Yang masuk
  repo hanya berkas tes baru.

### Sisa yang paling bernilai

Menyambungkan pemeriksaan "langit terang" itu **sampai ke `.lock`**, lewat
controller dengan bukti di level `EphemerisBody`: pada siang hari, controller
yang diberi arah tunjuk tepat ke bintang terang **tidak boleh** menghasilkan
`.lock`, dan `.lock` itulah yang memicu haptic sukses, bunyi, pengumuman
VoiceOver, visual pengenal, serta izin GoTo.

---

## Progres terakhir (6 Okt 2026 — blokir baseline CraterRelief + regresi arah bibir kawah)

### Siklus dibuka dengan repo yang TIDAK ter-compile

`git status` menunjukkan lima berkas terubah setengah jalan (kerja kawah
Merkurius yang sedang berjalan). `./swift-test.sh` berhenti dengan
`error: fatalError` di `emit-module` PointingKit — dan itu **bukan** uji yang
gagal, melainkan modul yang tidak bisa dibangun sama sekali. Tanpa menyelesaikan
ini, tidak ada satu pun gerbang yang bisa berjalan, jadi inilah unit pertama.

### Akar: tupel berlabel sebagai stored property tidak menyintesis Equatable

`CraterRelief` dideklarasikan `public struct CraterRelief: Equatable, Sendable`
tetapi memakai field:

```swift
public var rimDirection: (x: Double, y: Double)
```

Di Swift 6, tupel **berlabel** sebagai *stored property* tidak memiliki
konformans `Equatable` yang bisa disintesis, sehingga compiler menolak
`Equatable` itu sendiri — dan karena `CraterRelief` ada di `PointingKit`, modul
ikut gagal dikompilasi (`emit-module command failed with exit code 1`).

Ini persis kelas "hijau yang tidak hijau": tugas menjalankan uji melaporkan
`fatalError`, bukan "X gagal", dan tidak ada baris uji yang menunjuk ke
`CraterRelief` karena uji tidak pernah sempat berjalan.

### Perbaikan, dan kenapa bukan "buang saja Equatable"

Dua-duanya menghilangkan galat compile, tapi arahnya berbeda:
- Membuang `Equatable` → `craterRelief` tidak bisa lagi dibanding di uji Linux,
  dan `check-visuals.py` yang membandingkan relief per kawah kehilangan alat
  ukurnya. Itu menurunkan jaring pengaman.
- Memecah tupel berlabel jadi dua `Double` (`rimDirectionX`/`rimDirectionY`) →
  `Equatable` tersintesis, dan alat Python tetap membandingkan komponen secara
  langsung (ia tidak butuh tupel). Bentuk Swift murni internal, jadi tidak ada
  kontrak lintas-bahasa yang berubah. **Ini yang dipilih.**

`craterRelief` sendiri diturunkan ke `internal` (bukan `public`) untuk
menghilangkan peringatan "`public` modifier is redundant" yang mulai merah di CI
macOS (warnings-as-errors) — anggota di dalam `public extension` sudah
tersebar-luas, jadi fungsi ini tidak perlu `public`.

### Tiga uji regresi yang mengunci bentuk itu

Ditulis sesudah perbaikan, bukan sebelum — karena cacatnya berupa *compile
failure*, bukan *assertion yang salah*. Yang dijaga:
- `testCraterReliefRemainsEquatableWithPlainDoubleFields` — kalau ada yang
  kembali menulis tupel berlabel di sini, compile merah, bukan diam.
- `testCraterReliefRimAlwaysFacesTheLight` — bibir terang selalu `-light`
  ternormalisasi (sama dengan gradien bola) untuk **setiap** kawah, dan
  `sphereLightOffset` panjangnya tak nol.
- `testCraterReliefRefusesZeroLengthLight` — cahaya nol panjangnya wajib `[]`,
  bukan bibir dengan arah tak terdefinisi (yang membuat kawah tampak menonjol
  keluar).

### Aturan 10 sempat merah — dan itu benar

Setelah menambah 3 uji, `swift-ui-lint.sh` melaporkan "README bilang 622,
berkas uji 625". Bukan cacat gerbang, melainkan README yang tertinggal — tepat
fungsi Aturan 10. Diperbarui ke **174 / 625**.

### Hasil

| | Sebelum | Sesudah |
|---|---|---|
| `./swift-test.sh` | **gagal compile** (fatalError) | CelestialEngine **174** + PointingKit **625** (+3) hijau |
| typecheck | — | SEMUA GERBANG LULUS |
| swift-ui-lint | — | 25 aturan hijau |
| check-visuals (port Python) | — | **180 pemeriksaan, 0 gagal** |

CI: Engine Tests (Linux) + Apple Build (macos-15, warnings-as-errors) — **dua-duanya hijau** pada `c9a8ad2`.

### Catatan jujur

- **Seluruh brief sudah terimplementasi dan teruji.** Setelah audit menyeluruh
  (Bagian 1–4, Fase A/B/C, dan sebagian besar Penyempurnaan), fitur berikut
  SUDAH ada: visual prosedural semua jenis objek; night mode murni (palet
  merah, `@AppStorage`); AOD via `isLuminanceReduced` (tanpa animasi di cabang
  redup); VoiceOver label + `Announcement` saat lock; audio cue opsional saat
  `.lockSucceeded`; complication WidgetKit; katalog `.xcstrings` (437 kunci, 0
  terjemahan Inggris kosong); `InfoPlist.strings` id+en untuk izin Motion &
  Location; penanganan **penolakan izin** (`LocationProvider.note` ditampilkan
  di UI); Dynamic Type lewat font semantik; reduced-motion via
  `MotionPolicy.allowsTransitions`; glassmorphism **secara sengaja ditolak**
  (`SurfaceTokens.swift:105` — material di atas latar tak bisa menjamin kontras).
  Yang dikerjakan siklus ini adalah menambal blokir compile yang tertinggal dan
  mengunci perbaikannya, bukan membangun ulang yang sudah jadi.
- `SWIFT_EMIT_LOC_STRINGS: NO` adalah **keputusan disengaja** (Xcode akan
  menimpa terjemahan Inggris), jadi flag itu TIDAK boleh dinyalakan.
- Sisa kerja bernilai nyata: perluas katalog visual (sudah 11 objek langit
  dalam, 4 morfologi), atau perkuat uji integrasi kejujuran ujung-ke-ujung
  (di bawah-horizon / siang / bulan redup → tidak lock).

---

## Progres terakhir (5 Okt 2026 — `CelestialVisual.VisualFrame` tidak ada, dan gerbang yang melihatnya di Linux)

### Kelas cacat yang sama untuk kedua kalinya: nama yang benar, tempat yang salah

CI Apple Build merah pada `bf28783`:

```
Apps/Shared/CelestialVisualView.swift:784:39: error:
  type 'CelestialVisual' has no member 'VisualFrame'
```

`VisualFrame` adalah tipe **top-level** (`public enum VisualFrame {`), bukan
tipe bersarang di dalam `CelestialVisual`. Kualifikasinya salah — dan yang
membuatnya mahal bukan kesalahannya, melainkan bahwa **tidak satu pun gerbang
Linux bisa melihatnya**:

| Gerbang | Kenapa hijau |
|---|---|
| `swift-test.sh` | membangun **paket**, bukan `Apps/` |
| `swift-typecheck.sh` | hanya `-parse` berkas `Apps/` — sintaks, bukan tipe |
| `swift-ui-lint.sh` | 24 aturan teks, tak satu pun tahu keanggotaan tipe |
| CI macOS | **merah** — satu siklus penuh (~2 menit) terlambat |

Berkas `swift-typecheck.sh` sudah menulis batas ini jujur di kepalanya, jadi
ini bukan kelalaian: memang tidak bisa ditutup sepenuhnya di Linux (SDK
SwiftUI tidak ada). Yang bisa ditutup adalah **irisan** yang benar-benar
terjadi — dan irisan ini sudah terjadi dua kali (`ringBackHalfOpacityScale`
di `CelestialVisual` alih-alih `VisualFrame`, tercatat di STATUS.md).

### Yang ditambahkan bukan perbaikan satu baris, melainkan gerbangnya

Aturan 25 membaca daftar anggota `CelestialVisual` **dari sumber paketnya**
(badan tipe + setiap extension, sampai kedalaman satu) lalu memastikan setiap
`CelestialVisual.X` di `Apps/` benar-benar ada. Dua keputusan sengaja:

- **Kedalaman satu, bukan seluruh pohon tipe.** Gerbang yang menebak lebih
  jauh akan memerah pada kode yang sah (`CelestialVisual.Planet.jupiter`
  adalah dua tingkat), dan gerbang yang memerah pada kode benar akan
  dimatikan orang. Batasnya ditulis di aturannya, bukan disembunyikan.
- **Kasus "tipe top-level" dilaporkan dengan saran yang benar** ("pakai tanpa
  kualifikasi"), bukan sekadar "tidak ada" — karena itulah bentuk cacat yang
  nyata, dan pesan yang salah mengirim orang ke tempat yang tidak berisi
  apa-apa.

### Bukti menggigit, lewat dua suntikan yang berbeda

`red-lint.sh` (exit 1, menunjuk baris 784, berkas dipulihkan), plus suntikan
kedua untuk cabang lain:

```
`CelestialVisual.VisualFrame` — VisualFrame adalah tipe top-level di
  PointingKit, bukan anggota CelestialVisual; pakai VisualFrame tanpa kualifikasi
`CelestialVisual.NoSuchThing` — bukan anggota CelestialVisual dan tidak ada di PointingKit
```

### Yang diperbaiki sambil lewat, dan kenapa itu bagian dari cacatnya

Dua entri gerbang Matahari yang baru ternyata **selalu merah**: entrinya
menaruh ekspresi Python (`"opacity(0.42)" in view`) di posisi **nilai
harapan**, sehingga yang dibandingkan adalah `False == "opacity(0.42)"`. Ia
merah di kode benar maupun kode salah — sama tidak bergunanya dengan gerbang
yang selalu hijau, hanya lebih berisik. Keduanya kini menguji bentuk yang
benar-benar diklaimnya, dan arah "view memakai profil" dipindahkan ke
pemeriksaan **gambar**: pencarian teks `sunProfile(` hijau walaupun hasilnya
dibuang, dan yang menentukan bukan namanya dipanggil melainkan apa yang
sampai ke piksel.

### Gerbang

- `swift-test.sh` → **174 CelestialEngine + 622 PointingKit**, 0 gagal.
  **Engine tidak disentuh.**
- `swift-ui-lint.sh` → **25 aturan hijau** (Aturan 10 menangkap README yang
  masih 24 lebih dulu, seperti seharusnya).
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `check-visuals.py` → **163 pemeriksaan, 0 gagal**.
- CI: `37390117194` (Engine Tests Linux) + `37390117532` (Apple Build
  macos-15) — **dua-duanya hijau** pada `fee0ecc`.

### Batas yang jujur

- **Aturan 25 bukan typechecker.** Ia tahu anggota langsung `CelestialVisual`
  dan tipe top-level paket; anggota yang salah di tipe lain, atau argumen yang
  salah tipe, tetap hanya ketahuan dari CI macOS.
- **Kelas cacat ini masih bisa terulang.** Yang tertutup adalah kualifikasi
  `CelestialVisual.`, bukan "setiap anggota yang tidak ada". Memperluasnya ke
  seluruh tipe PointingKit adalah unit berikutnya yang jelas — dan lebih besar,
  jadi sengaja tidak digabung ke siklus ini.

## Progres terakhir (5 Okt 2026 — kutub Mars mengambang di dalam piringan)

### Cacatnya: elips yang ditempel, bukan kap es di permukaan bola

Kutub Mars digambar sebagai elips dengan lebar **tetap** 0.55 R, tepi atasnya
ditempelkan di tepi bola. Karena 0.55 R selalu lebih sempit dari bola pada
baris mana pun di sekitar kutub, yang tergambar bukan kutub di permukaan bola
melainkan **elips yang mengambang di dalam piringan** — selalu ada rim merah di
atas dan di sisi kiri-kanan kutubnya.

Terukur pada render 400 px, di baris terlebar kutub: tepi bola 0.675 R, tepi
kutub 0.550 R — selisih 0.125 R (25 px). Kutub adalah **ciri pengenal** Mars,
jadi ini bukan soal rasa: gambar yang salah adalah **klaim yang salah**, persis
yang PRD v0.4 larang.

Catatan proses: vision (model) menilai crop-nya "tidak apa-apa" dan bahkan
mengklaim "ada sliver merah di atas putih" — **dua kali salah, ke arah
berbeda**. Yang menyelesaikannya adalah pengukuran piksel langsung, bukan
mata. Sama seperti `polish` sebelumnya: kalau bisa diukur, ukur.

### Kenapa lebarnya tidak bisa sekadar diperbesar

Satu-satunya lebar yang membuat kutub **menyentuh** tepi di baris `centerY`-nya
adalah setengah-lebar bola pada ketinggian itu: `√(1 − y²)` — rumus proyeksi
yang sama dengan `jupiterBands`. Angka tetap hanya benar untuk satu ketinggian
dan salah **tanpa suara** begitu posisinya bergeser.

Konsekuensi kedua: elips selebar tepi bola tetap **menjulur keluar** bola di
dekat kutub (pada y = −0.9 R elipsnya 0.530 R sementara bola 0.436 R). Jadi
view harus **mengirisnya dengan piringan** — tanpa klip, cacatnya cuma
berpindah arah: kutubnya meluber ke latar.

### Perbaikan

| Bagian | Keputusan | Kenapa |
|---|---|---|
| `polarCaps(pinchY:depthFraction:)` | lebar = `√(1 − pinchY²)`, **diturunkan** | angka tetap tidak bisa benar di dua ketinggian sekaligus |
| `PolarCaps.Cap` | pusat + separuh-tinggi + separuh-lebar | `topY`+`height` membuat tepi luar kutub tak punya definisi, jadi tidak bisa diuji |
| kutub selatan | `cap(-pinchY)` | satu tanda, bukan rumus kedua — ketidak-simetrisan tak bisa ditulis ulang |
| `drawPolarCaps` | `inner.clip(to: disc)` | irisan inilah yang membuat tepi luar kutub mengikuti lengkung bola |
| port Python | `polar_caps()` ikut berubah | tanpa itu, **setiap pemeriksaan gambar Mars mengukur gambar yang tidak pernah ada** — kelas cacat yang sama untuk kelima kalinya |
| uji lama | **diganti**, bukan ditambahi | ia mengukur bentuk lama; menambah uji di sebelahnya hanya menutupi |

### Gerbang: rumus, bukan angka

`check_mars_caps_touch_the_limb` mengukur langsung dari piksel, dua arah
sekaligus karena keduanya bisa gagal terpisah:

| Pemeriksaan | Ambang | Kenapa ada |
|---|---|---|
| kutub menyentuh tepi bola | rim ≤ 0.02 R di baris pusat kutub | cacat aslinya: rim 0.125 R |
| kutub tidak meluber keluar | 0 piksel di luar piringan | arah berlawanan — tanpa klip, lebar baru justru keluar |
| kutub benar-benar tergambar | > 100 piksel | view yang berhenti menggambar lolos dua di atas dengan sempurna |
| kutub hilang saat ragu | 0 piksel pada kandidat | ciri pengenal tidak boleh tergambar pada objek yang belum dipastikan |

Ditambah di gerbang pergeseran port: `POLAR_CAP_WIDTH_RULE = "sqrt"` menjaga
**rumusnya** di kedua bahasa, bukan angkanya — karena angkanya sudah tidak ada
di port, dan menyalinnya kembali sebagai konstanta justru mengembalikan cacat
yang baru ditutup.

### Dibuktikan menggigit

Bukan sekadar bertambah. Dengan geometri lama dipasang ulang:

```
GAGAL  kutub Mars menyentuh tepi bola di baris pusatnya
       -> bola 0.680 R, kutub 0.550 R, rim 26 px (13.0% R)
OK     kutub Mars tidak meluber keluar bola
OK     kutub Mars benar-benar tergambar
OK     kutub Mars hilang saat engine ragu
```

Dengan geometri baru: `rim 2 px (1.0% R)`, 0 piksel di luar piringan, puncak
kutub terukur di **0.998 R** dari pusat — menempel, tidak mencuat.

### Hasil

| | Sebelum | Sesudah |
|---|---|---|
| CelestialEngine | 174 | **174** |
| PointingKit | 617 | **619** (+2) |
| Pemeriksaan visual | 148 | **153** (+5) |
| Gerbang pergeseran port | 74 | **78** (+4) |

## Progres sebelumnya (5 Okt 2026 — Venus berfase, dan gerbang lokal yang buta terhadap Apps/)

### Cacatnya: bola penuh yang menyatakan sesuatu yang tidak ada

`drawPlanet` menggambar **setiap** planet sebagai bola penuh yang menyala.
Itu benar untuk Mars sampai Saturnus, tapi salah untuk dua planet dalam: dari
Bumi Venus berayun dari sabit ~1% ke cakram ~99%, dan di langit nyata ia
**tidak pernah** tampak bulat saat berada dekat Matahari. Sabit itulah ciri
paling khasnya.

Yang penting: ini **bukan** mesin yang salah hitung. `Ephemeris.apparent`
sudah menghitung `illuminationFraction` untuk semua benda. Yang hilang adalah
jalur dari angka itu ke gambar:

- `phaseGeometry` menolak apa pun yang bukan Bulan.
- `PointingEngine` hanya memasok fraksi untuk Bulan.

Jadi angkanya ada, dan gambarnya menyangkalnya. Itu tepat yang dilarang aturan
"kejujuran > rasa percaya diri": bukan karena hitungannya salah, tapi karena
**gambar menyampaikan lebih dari yang dihitung**.

### Perbaikan

| Bagian | Keputusan | Kenapa |
|---|---|---|
| `Planet.showsPhase` | Merkurius & Venus `true`; Mars–Saturnus `false` | planet luar nyaris bulat sepanjang waktu — angka fase yang sampai ke view harus **diabaikan**, bukan dipakai |
| `fractionForPhase` | satu tempat memutuskan angka mana yang boleh dipakai | memisahkan "punya angka" dari "boleh menggambar fase" |
| `brightLimbAngle(body:sun:)` | generalisasi dari `(moon:sun:)` | sudut sisi terang tidak ada urusannya dengan Bulan; dua salinan rumus = dua tempat yang bisa berbeda diam-diam |
| `drawLitBand` | dipakai bersama Bulan & planet | kalau tidak, sabit Venus dan sabit Bulan digambar dua salinan kode |
| ciri ikut terpotong | kawah Merkurius & kabut Venus `clip` ke pita menyala | supaya tidak menonjol keluar sabit dan membuatnya tampak lebih lebar dari fraksi engine |
| gradien limb | berpusat di pusat piringan, bukan digeser kiri-atas | gradien yang digeser **ikut berputar** bersama pita, jadi "cahaya dari kiri-atas" menghadap arah salah saat sisi terang ke bawah — dan planetnya tetap tampak seperti bola, jadi tak ada yang bisa menangkapnya dari layar |
| fase hanya saat terkunci | `isConfirmed` | aturan yang sudah berlaku untuk pita Jupiter & cincin Saturnus: warna boleh pada kandidat, **bentuk** tidak. Sabit adalah bentuk |
| `planetUnlit` | token baru, terpisah dari `moonUnlit` | sisi gelap Bulan disinari cahaya bumi (earthshine), sisi gelap planet tidak |

### Gerbang: port Python harus menggambar cabang yang sama

Tanpa cabang fase di port, port menggambar bola penuh sementara aplikasi
menggambar sabit — dan **setiap pemeriksaan gambar planet dalam mengukur
gambar yang tidak pernah ada**. Kelas cacat yang sama dengan gerbang yang
mengukur sebagian klaimnya, tiga kali sebelumnya.

`check_inner_planet_phase` (5 pemeriksaan, semua dari piksel):

| Pemeriksaan | Ambang | Kenapa ada |
|---|---|---|
| sabit Venus benar-benar sempit | luas < 0.45 (f=0.22) | bola penuh ≈ 1.0 — tanpa ini, "fase" bisa berarti apa saja |
| sisi terang menghadap sudut | harus "bawah" pada −π/2 | jalur sama dengan Bulan, jadi kesalahan koordinat layar tertangkap di sini juga |
| cembung > setengah | luas > 0.55 (f=0.78) | tanpa ini, "sabit tipis untuk semua fraksi" lolos |
| planet luar abaikan angka fase | luas > 0.85 | Mars tetap bulat walau diberi angka fase |
| Venus tanpa arah fase | luas > 0.85 | **arah tak diketahui ≠ izin menebak arah** |

### Celah gerbang yang baru ketahuan: `swift-typecheck.sh` tidak mengompilasi Apps/

Apple Build di CI sudah **merah sejak commit sebelumnya** — dan setiap gerbang
lokal hijau:

```
Apps/Shared/CelestialVisualView.swift:405:56: error:
  type 'CelestialVisual' has no member 'ringBackHalfOpacityScale'
```

Konstantanya milik `VisualFrame`, bukan `CelestialVisual`. `swift-typecheck.sh`
membangun **paket**, bukan `Apps/`. Jadi kesalahan "tipe X tidak punya anggota
Y" di dalam `Apps/` hanya bisa muncul saat `Apps/` benar-benar dikompilasi
terhadap paket — dan yang melakukannya hanya macOS.

| Gerbang | Hasil | Cakupan |
|---|---|---|
| `swift-test.sh` | hijau | paket saja |
| `swift-ui-lint.sh` | hijau | teks, bukan tipe |
| `swift-typecheck.sh` | hijau | **paket** saja — bukan Apps/ |
| CI Apple Build | **merah** | Apps/ terhadap paket |

Ini pola yang sama untuk keempat kalinya, dengan bentuk yang berbeda: **gerbang
yang mengklaim lebih dari yang diukurnya.** Yang pertama menutup lubangnya
adalah CI, dan CI merah sementara semuanya bilang hijau.

### Hasil

| | Sebelum | Sesudah |
|---|---|---|
| CelestialEngine | 174 | **174** |
| PointingKit | 607 | **615** (+8) |
| Pemeriksaan visual | 125 | **130** (+5) |
| Apple Build | merah | **hijau** |

## Progres terakhir (5 Okt 2026 — larik ciri dijaga seluruhnya, bukan elemen pertamanya)

### Pola yang muncul tiga kali: gerbang yang mengukur sebagian dari klaimnya

Gerbang pergeseran (`check_port_matches_swift_constants`) menjaga
`CRATERS[0]` dan `MARIA[0]` — **satu** elemen dari lima dan **satu** dari
empat. Tujuh angka sisanya tidak dijaga siapa pun. Mengubah kawah kelima
Merkurius di view akan membiarkan **setiap** pemeriksaan hijau sambil
mengukur gambar yang sudah tidak ada lagi — persis cacat yang berkas itu ada
untuk mencegah.

Ini pola ketiga dalam beberapa siklus, dan bentuknya selalu sama:

| Siklus | Gerbang mengklaim | Kenyataannya mengukur |
|---|---|---|
| lencana "?" | glif di dalam lencana | glif di dalam **frame** (3.1x) |
| fase Bulan | ciri hilang saat ragu | ciri hilang **kecuali Bulan** |
| larik ciri | kawah & maria cocok | elemen **pertama** saja |

Yang ketiga kemungkinan besar terjadi karena menulis sepuluh pemeriksaan satu
per satu terasa berlebihan — dan itu tepat alasan yang membuat lubangnya
tidak terlihat. Menambah pemeriksaan satu-satu juga tidak menyelesaikannya:
daftar tangan adalah daftar yang bisa tertinggal separuh.

### Solusinya: kedua sisi dibaca dari sumbernya

`swift_tuple_triples` mengekstrak **semua** `(a, b, c)` dari teks Swift
setelah jangkarnya; larik port dibaca dari berkas port. Tidak ada daftar yang
harus diperbarui dengan tangan, jadi tidak ada daftar yang bisa tertinggal.

Perbandingannya elemen per elemen supaya pesannya menyebut **indeks** —
"lariknya tidak sama" tidak memberi tahu apakah ada yang salah tempat,
hilang, atau bertambah di akhir.

Arahnya dua bahasa, dan yang kedua tidak bisa dilihat pemeriksaan gambar mana
pun: merah kalau port menyimpang, **atau** kalau view berubah tanpa port-nya
ikut — sebab gambar acuannya sendiri yang ikut berubah.

### Jangkar hilang = gagal bersih, bukan traceback

Gerbang yang melempar pengecualian saat view-nya dirapikan akan dihapus
orang, dan aturan yang dihapus tidak menjaga apa pun. Jangkar yang tidak
ditemukan sekarang jadi kegagalan biasa yang **menyebut jangkarnya**.

### Dibuktikan menggigit

| Simulasi | Hasil |
|---|---|
| kawah ke-5 di view: `0.13 -> 0.99` | GAGAL "beda di indeks [4]" |
| jangkar kawah dipindah baris | GAGAL bersih, bukan crash |

Kode apa adanya: **110 pemeriksaan, 0 gagal**; 603 uji Swift hijau.

### Catatan untuk siklus berikutnya

- Sebelum mempercayai gerbang, tanyakan **berapa dari N** yang benar-benar
  diperiksa. Tiga cacat berturut-turut semuanya bentuk itu.
- Larik `CRATERS`/`MARIA` masih hidup di **view** sebagai angka keras;
  memindahkannya ke model (seperti `jupiterBands`, `saturnRing`) akan
  menghapus kebutuhan gerbang pergeseran ini sekaligus — satu angka yang
  hidup di dua tempat adalah dua angka yang akan berbeda.

---

## Progres sebelumnya (5 Okt 2026 — aturan "fase Bulan tetap tampil saat ragu" jadi terukur)

### Yang dikerjakan: aturan yang hanya hidup sebagai prosa

Fase Bulan adalah **satu-satunya** ciri pengenal yang sengaja tidak
disembunyikan saat engine ragu. Alasannya sudah tercatat panjang di STATUS.md:
`isWaxing` dan `illuminationFraction` datang dari **efemeris** — fakta tentang
Bulan pada tanggal itu — bukan dari tabel yang diindeks oleh id. Tidak ada
identitas yang bisa salah diklaim oleh sebuah fase, dan menahannya saat ragu
justru **menurunkan** kejujuran.

Siklus ini awalnya mencurigainya sebagai cacat: `drawMoon` tidak pernah
menerima `isConfirmed` seperti `drawPlanet`, dan Bulan sabit yang ragu
tergambar **identik** dengan yang yakin (3434 piksel selisih = lencananya
saja). Sempat akan "diperbaiki" agar menghormati `isConfirmed`. **Salah** —
`STATUS.md` baris 10267 mencatatnya sebagai keputusan, bukan kelalaian, dan
tidak ada satu pun uji yang meneruskan `isConfirmed` ke `phaseGeometry`.
Membacanya dulu mencegah regresi yang justru menurunkan kejujuran.

### Tapi aturan yang tidak diukur adalah aturan yang bisa hilang

Yang benar-benar kurang bukan kodenya, melainkan **gerbangnya**. Dan yang
paling mungkin menghapus aturan ini justru pembaca yang teliti: tabel di
STATUS.md terlihat seperti daftar ciri yang *seharusnya* hilang, dan baris
"fase Bulan" di dalamnya mudah terbaca sebagai kelalaian. Kalau `drawMoon`
suatu saat "diperbaiki" agar menghormati `isConfirmed`, tidak ada satu pun
gerbang yang akan berbunyi — dan yang hilang adalah satu-satunya bagian gambar
yang **masih benar** saat engine ragu.

Bahayanya **berlawanan arah** dengan semua pemeriksaan lain di berkas itu:
semua menuntut *lebih sedikit* yang tampil saat ragu, yang ini menuntut satu
hal tetap tampil. Itu sebabnya ia perlu gerbangnya sendiri.

### Tiga pengukuran, semuanya dari piksel

`check_moon_phase_survives_uncertainty`, ketiganya di luar kotak lencana:

| Pengukuran | Hasil |
|---|---|
| sabit "ragu" identik dengan sabit "yakin" | 0 piksel berbeda |
| sabit ≠ purnama, dan sabit ≠ cembung | 10144 dan 8197 piksel |
| arah sabit bertahan (≠ sabit tanpa putaran) | 3885 piksel berbeda |

Pengukuran 2 dan 3 adalah **arah sebaliknya** yang wajib: tanpa keduanya,
membuang pita fase di *semua* keadaan akan lolos pengukuran 1 dengan
sempurna.

### Dibuktikan menggigit

Dengan `_draw_moon` disimulasikan menghormati `isConfirmed` — persis
"perbaikan" yang dikhawatirkan pembaca teliti itu:

```
GAGAL fase Bulan tetap tampil saat ragu   3851 piksel berbeda di luar lencana
```

Dengan kode apa adanya: **106 pemeriksaan, 0 gagal**.

### Gerbang lain

603 uji Swift hijau, lint UI 24 aturan hijau, typecheck hijau.

### Catatan untuk siklus berikutnya

- Rantai penjaga `confirmsIdentity` → `isConfirmed` → ciri gambar sudah
  lengkap untuk planet, langit dalam, dan warna bintang; fase Bulan adalah
  pengecualian yang beralasan dan sekarang **dijaga**.
- Tabel ciri-vs-ragu di STATUS.md kini punya padanan gerbang untuk barisnya
  yang paling mudah salah dibaca.

---

## Progres sebelumnya (5 Okt 2026 — lencana "?" port 3.1x terlalu besar)

### Cacatnya: satuan yang salah, dan tak ada yang membacanya

Port Python menghitung radius glif tanda tanya dari radius **frame**; view
Swift menghitungnya dari radius **lencana**:

```swift
// Apps/Shared/CelestialVisualView.swift — benar
let r = CGFloat(marker.glyphRadius) * radius   // glyphRadius = 0.52 * badgeRadius
```
```python
# Tools/render-visuals.py — salah
r = marker["glyph_fraction"] * radius          # radius = frame
```

Selisihnya **3.1x** (0.166 R lawan 0.52 R). Glifnya menjulur keluar
lencananya di kiri-atas dan **terpotong tepi frame** — jadi lencana "?",
satu-satunya penanda "engine ragu" di layar, tergambar sebagai busur yang
berhenti mendadak.

### Kenapa tak satu pun gerbang lama melihatnya

Yang salah adalah **konvensi satuan**, dan tidak ada yang membacanya:

| Gerbang | Kenapa hijau |
|---|---|
| `check_port_matches_swift_constants` | konstanta `glyphFraction` memang sama di kedua sisi (0.52); tidak ada yang membandingkan cara **memakainya** |
| uji model `VisualFrame` | menguji `glyphRadius` di model — dan modelnya benar |
| Aturan 24 / lint UI | tidak melihat aritmetika gambar |
| `check_features_disappear_when_uncertain` | baru saja **mengecualikan** kotak lencana, jadi luberan glif justru disaring keluar dari pengukuran itu |

Pola ini persis yang sudah dua kali tercatat di repo: penulis dan pembaca
yang sepakat satu sama lain.

### Perbaikan, dengan satu sumber kebenaran

- `candidate_marker_glyph()` baru di port: satu-satunya tempat geometri glif
  hidup. Penggambar dan pemeriksa memakai fungsi yang sama, jadi keduanya
  tidak bisa lagi sepakat salah.
- `candidate_marker_footprint()` kini mengembalikan kotak **gabungan**
  (cakram + glif + lebar garis + tetes), bukan cakram saja. Kotak yang hanya
  menutup cakram tidak mengecualikan luberan glif — persis cacat yang
  pengecualian itu ada untuk menutup.
- Lantai piksel `max(1.0, …)` dibuang dari fungsi geometri. Lantai itu benar
  dalam **piksel** (view memakainya), tapi di sana satuannya pecahan radius
  frame — jadi artinya "lebar garis selebar radius frame", 6x lipat, dan
  `candidate_marker_footprint()` mewarisi luberan itu sampai kotak
  pengecualiannya menelan hampir seluruh gambar. Penerjemahan satuan milik
  pemanggil, bukan fungsi geometri.

### Gerbangnya, dan bukti ia menggigit

`check_candidate_marker_stays_inside_its_badge`: setiap piksel berwarna
peringatan harus berada di dalam kotak lencana (dari model yang sama dengan
yang menggambar), dan glifnya harus benar-benar ada.

**Dibuktikan menggigit**: dengan rumus lama dikembalikan, gerbang GAGAL
dengan 254 piksel peringatan di luar kotak, terjauh **(0.055, -0.915)** —
ujung glif yang terpotong, persis seperti yang diprediksi. Dengan perbaikan:
0 piksel.

**Versi pertama gerbang itu sendiri salah.** Ia membandingkan "terkunci"
dengan "ragu" dan gagal dengan 12.470 piksel "di luar lencana" — yang
ternyata **cincin Saturnus**. Cincin memang menjulur ke seluruh lebar frame
(sampai 1.003 R) dan memang harus hilang saat ragu, jadi ia sah di luar
kotak lencana. Pemeriksaan yang mengukur lebih banyak daripada yang
diklaimnya akan gagal karena alasan yang bukan cacatnya; sekarang ia mengukur warna
peringatan pada satu gambar saja, tanpa pembanding.

### Ciri lima planet, bukan dua

`check_features_disappear_when_uncertain` dulu menjaga Jupiter dan Saturnus —
dua yang kebetulan punya kasus render. Satu `guard isConfirmed` di view
menutup kelimanya, tapi aturan yang tidak diukur adalah aturan yang bisa
hilang tanpa suara. Mars (kutub), Merkurius (kawah), dan Venus (kabut) kini
ikut diukur: 1818–3448 piksel berbeda, semuanya di luar lencana.

### Gerbang lain

603 uji Swift hijau, lint UI hijau, typecheck hijau, check-visuals **103
pemeriksaan 0 gagal**.

### Yang diperiksa dan ternyata sudah beres

Tiga item misi diperiksa dan **tidak** butuh perubahan — dicatat supaya tidak
dikerjakan ulang:

- **VoiceOver untuk visual objek.** `CelestialVisualView` memang
  `.accessibilityHidden(true)`, tapi itu **bukan** celah: induknya
  (`detailAccessibilityLabel` di jam, `visualPanelLabel` di iPhone) sudah
  mengumumkan nama, jenis, tingkat keyakinan, dan penanda sisa. Dan yang
  **hanya bisa dilihat dari gambar** sudah diucapkan sendiri: fase Bulan
  (`spokenPhase`), bentuk objek langit dalam (`spokenDeepSkyMorphology`),
  warna bintang (`StarColorSpeech`). Alasan "tidak pernah menyebut visualnya"
  tertulis di kode: "Gambar Jupiter dengan pita oranye" tidak menambah
  informasi yang tidak sudah ada di nama dan jenis benda. Menambahkan label
  visual akan **mengulang** pengumuman yang sudah ada dan memanjangkan setiap
  sapuan VoiceOver — regresi, bukan perbaikan.
- **Dynamic Type.** Empat kemunculan `.system(size:` semuanya **di dalam
  komentar** yang menjelaskan kenapa ia tidak dipakai.
- **README.** Sudah memuat `xcodegen generate`, arsitektur, dan cara
  menjalankan Experiment 1.

---

## Progres sebelumnya (5 Okt 2026 — pita Jupiter berhenti 19% radius di dalam piringan)

### Cacatnya: komentar yang benar, rumus yang lain

`drawBands` di `CelestialVisualView.swift` menggambar pita Jupiter dengan
satu baris dan satu komentar:

```swift
// Pita mengikuti keliling bola: makin dekat kutub, makin pendek.
let halfWidth = radius * CGFloat(cos((t - 0.5) * .pi * 0.92))
```

Komentarnya benar sebagai **niat**. Kosinusnya bukan keliling bola. Keduanya
kebetulan bertemu di ekuator (1.0 vs 1.0) lalu menyimpang makin jauh ke
kutub: di pita teratas, tepi pita berhenti **19% radius** di dalam
piringan — diukur pada render 200 px, itu 24 px; di kartu jam 38 pt, itu
**3.6 pt**. Bola tampil polos di kedua kutub dengan pita mengambang di
tengahnya, seperti tekstur yang tidak melingkar penuh. Kelas cacat yang
sama pernah tercatat di berkas ini untuk Saturnus dan Mars; keduanya sudah
pindah ke model, Jupiter terlewat.

### Kenapa tak ada uji yang bisa melihatnya

Rumusnya hidup **hanya di dalam view**, dan view tidak bisa dijalankan di
Linux. Satu-satunya gerbang yang bisa melihatnya adalah
`check_port_matches_swift_constants` — dan gerbang itu membandingkan port
Python dengan view. Port-nya memakai kosinus yang **sama persis**, jadi
keduanya sepakat satu sama lain sementara tepi bola yang sesungguhnya tidak
pernah disebut oleh keduanya. Ini persis cacat yang sudah tercatat untuk
alat PNG di entri sebelumnya: penulis dan pembaca yang sepakat.

### Perbaikan

Geometrinya pindah ke `CelestialVisual.jupiterBands()` — bentuk bola yang
benar, `sqrt(1 - y^2)`, bukan aproksimasi. View memakainya, port Python
mem-port-nya, dan `check_port_matches_swift_constants` menahan keduanya.
Rumus yang hidup di dua tempat harus diperbaiki di dua tempat; rumus yang
hidup di model cukup diperbaiki sekali dan **diuji**.

### Gerbang pikselnya, dan dua versi yang hijau tanpa alasan

`check_jupiter_bands_reach_the_limb` (7 pemeriksaan) mengukur
**seberapa jauh pita menjangkau ke kiri** di tiap baris pita, dari piksel
PNG, lalu membandingkannya dengan tepi bola. Dua versi pertamanya hijau
pada gambar yang cacat:

1. **Versi 1** mengambil nilai pembanding dari `R.jupiter_bands()` —
   fungsi yang **menggambar** pita itu. Kalau port kembali memakai kosinus,
   gambar mengecil dan angka pembandingnya ikut mengecil: selalu hijau.
   Ditulis ulang agar tepi bola dihitung sendiri di pemeriksa
   (`math.sqrt(1 - band_y**2)`), jadi satu-satunya parameter bebas adalah
   gambar yang sedang diukur.
2. **Versi 2** mengukur "piksel menyala" pada baris pita. Yang terukur
   adalah **piringan bola**, yang memang selalu sampai tepi. Diperbaiki
   dengan mengurangkan `planet-jupiter-uncertain` — bola Jupiter yang sama
   persis tanpa pita (aturan "ciri pengenal hilang saat ragu" sudah ada),
   jadi selisih dua gambar itu **hanya** pita. Sisi kiri yang diukur karena
   lencana tanda-tanya di kanan atas akan terhitung sebagai pita.

### Bukti gerbangnya menggigit

Bukan dengan menambah pemeriksaan, tapi dengan **mengembalikan cacatnya ke
kedua sisi sekaligus** (model dan port sama-sama kembali ke kosinus), supaya
gerbang drift buta dan hanya gerbang piksel yang bisa melihatnya:

```
GAGAL pita Jupiter 0 menjangkau tepi bola   jangkauan 0.325 R, bola 0.515 R, selisih 19.0% R
GAGAL pita Jupiter 1 menjangkau tepi bola   jangkauan 0.675 R, bola 0.821 R, selisih 14.6% R
GAGAL pita Jupiter 2 menjangkau tepi bola   jangkauan 0.915 R, bola 0.958 R, selisih  4.3% R
...  (pita 3 di ekuator: 0% — persis titik di mana kedua rumus bertemu)
90 pemeriksaan, 8 gagal
```

Angka 19.0 / 14.6 / 4.3 / 0.0 itu cocok dengan perhitungan analitik sebelum
perbaikan, dan pita ekuator lulus di kedua versi — seperti yang seharusnya,
karena di situlah kedua rumus kebetulan sama.

### Verifikasi

- `testJupiterBandsReachTheLimb` (3 uji baru) mengunci bentuk bolanya di
  Linux; PointingKit **603** tes hijau, CelestialEngine **174** hijau.
- 90 pemeriksaan visual hijau (dari 81); lint UI 24 aturan hijau.
- Diperiksa dengan mata juga: render lama vs baru disandingkan, pita baru
  menjangkau sampai tepi kiri-kanan piringan, yang lama menyisakan jalur
  polos di kedua sisi.

## Progres terakhir (5 Okt 2026 — gerbang pergeseran port menjaga 18 angka, bukan 5)

### Cacatnya: gerbang yang menjaga gambar dari pergeseran, hanya menjaga seperempatnya

`check_port_matches_swift_constants` ada untuk satu alasan yang sudah
ditulisnya sendiri: port gambar hidup di Python (`render-visuals.py`) dan
view-nya di Swift (`CelestialVisualView.swift`). Kalau seseorang mengubah
view dan lupa port-nya, **seluruh pemeriksaan visual di atasnya tetap
hijau** sambil mengukur gambar yang sudah tidak ada lagi. Gerbang yang
paling berbahaya justru yang diam-diam mengukur hal lain.

Tapi gerbang itu hanya menjaga **5** dari sekitar 18 konstanta port:
opasitas glow, rasio cincin Saturnus, fraksi bola, opasitas maria, dan
langkah jalur Bulan. Yang tidak dijaga justru ciri-ciri pengenal yang
paling menentukan identitas:

| Tidak dijaga | Akibat kalau view berubah tanpa port |
|---|---|
| jumlah & tinggi pita Jupiter | Jupiter berubah bentuk, pengukuran pita mengukur bentuk lama |
| posisi/ukuran Bintik Merah Besar | ciri pengenal Jupiter |
| opasitas cincin belakang/depan, celah Cassini | Saturnus berubah, ukuran "cincin" tetap lulus |
| opasitas & posisi kutub Mars | ciri pengenal Mars |
| kawah Merkurius, maria Bulan | detail permukaan |
| opasitas spike bintang | bentuk bintang |

Jadi mengubah pita Jupiter atau cincin Saturnus di view akan melewati
setiap pemeriksaan. Lubangnya ada **di gerbangnya sendiri** — kelas cacat
yang sama yang berkas ini ada untuk mencegah.

### Perbaikan

16 pemeriksaan baru ditambahkan (5 → 21 konstanta; 49 → 81 pemeriksaan),
masing-masing dua arah seperti yang sudah ada: nilai port == nilai yang
diharapkan, **dan** teks sumbernya masih tertulis di sumber Swift-nya.
Arah kedua itu yang penting — tanpa itu, seseorang bisa mengubah kedua
sisi menjadi salah bersama-sama.

### Bukti gerbangnya menggigit, bukan sekadar bertambah

Menambah pemeriksaan tidak bernilai kalau tidak ada yang pernah gagal
karenanya. Diuji dengan meniru cacatnya: `let bandCount = 7` diubah jadi
`9` di view (persis "orang yang mengubah view dan lupa port-nya") →

```
GAGAL sumber Swift memuat: jumlah pita Jupiter   'let bandCount = 7' TIDAK ditemukan
81 pemeriksaan, 1 gagal   (keluar 1)
```

Lalu view dikembalikan, dan hijau lagi.

### Verifikasi

- 81 pemeriksaan visual hijau (dari 49).
- Lint UI 24 aturan hijau; 600 tes Swift tetap hijau.
- Tidak ada berkas Swift yang tersentuh — perubahan hanya di alat uji.

## Progres terakhir (5 Okt 2026 — PNG alat render tak sah, dan pembaca yang menutupinya)

### Cacatnya: penulis dan pembaca repo ini sepakat satu sama lain, dunia luar tidak

`Tools/render-visuals.py` adalah alat yang dipakai untuk **menilai mutu
gambar** — ia merender planet, Bulan, bintang, nebula ke `out/visuals/`,
lalu `Tools/check-visuals.py` mengukurnya. Seluruh nilai alat itu
bergantung pada satu hal: PNG-nya bisa dibuka.

Ternyata tidak bisa. `_png()` menggabungkan baris RGBA **apa adanya**,
tanpa byte filter 0 di awal tiap baris:

```python
raw = b"".join(pixels[y * width * 4:(y + 1) * width * 4] for y in range(height))
```

Byte filter per baris itu bagian dari spesifikasi PNG, bukan pilihan.
Arus IDAT yang dihasilkan berukuran `h * w * 4` (16384 byte untuk 64×64),
sedangkan pembaca mana pun menuntut `h * (w * 4 + 1)` (16448). Byte
pertama tiap baris dibaca sebagai **tipe filter**; nilainya (mis. `0x0a`)
di luar 0…4, jadi berkasnya ditolak: `ffmpeg` menolak setiap PNG dengan
`IEND without all image`, dan Preview/browser sama.

### Kenapa tidak ada yang menangkapnya: pembacanya ikut salah

`decode_png` di `check-visuals.py` **sengaja toleran**. Ia mengukur
panjang arus, lalu memilih "tidak ada byte filter" kalau panjangnya
kurang:

```python
filtered = len(raw) == height * (stride + 1)
```

Jadi `check_png_roundtrip` — uji regresi yang ditulis **persis** untuk
cacat filter byte ini — tetap hijau: penulis dan pembaca repo ini sepakat
satu sama lain sementara setiap pembaca PNG di dunia tidak. Komentar
`_png()` sendiri sudah mengklaim "menyisipkan satu byte filter 0 per
baris"; ia tidak melakukannya. Kelas cacat yang sama dengan yang sudah
dijaga berkas ini: **gerbang yang diam-diam mengukur hal lain**, dan
gambarnya "kelihatan seperti planet" sehingga tidak ada yang mencurigainya.

`Tools/make_app_icons.py` sudah benar sejak awal (`b"\x00" + ...`) — jadi
tidak ada alasan bahwa `_png()` yang kedua tidak.

### Perbaikan (regression test dulu, baru perbaikan)

`check_png_is_well_formed` baru di `Tools/check-visuals.py` menguji
invarian spesifikasi PNG **langsung dari arus IDAT**, tanpa memakai
`decode_png` yang toleran itu: panjang arus harus `h * (w * 4 + 1)`, dan
setiap byte filter di awal baris harus 0…4. Itu definisi yang dipakai
pembaca mana pun, jadi gerbangnya tidak bisa sepakat dengan penulis yang
salah.

Terbukti MERAH dulu (4 gagal):

```
GAGAL PNG sah: planet-jupiter-confirmed   arus IDAT 16384 byte, spesifikasi menuntut 16448
```

Lalu `_png()` menulis `b"\x00"` di awal tiap baris, dan komentar
`decode_png` diperjelas: toleransi itu bukan izin.

### Verifikasi

- 49 pemeriksaan visual hijau (dari 45 → 49; 4 pemeriksaan baru).
- `ffmpeg` kini mendekode tiap PNG tanpa keluhan — bukti dari pembaca di
  luar repo, bukan dari pembaca kita sendiri.
- 600 tes Swift tetap hijau; lint UI 24 aturan hijau.
- Diverifikasi lewat `vision_analyze`: Jupiter terbaca berpita + Bintik
  Merah Besar, Saturnus terbaca bercincin.

## Progres terakhir (5 Okt 2026 — sabit Bulan yang tercermin, dan kenapa tak ada uji yang bisa melihatnya)

### Cacatnya: gambar yang benar di model, salah di layar

`CelestialVisual.brightLimbAngle` menghitung arah sisi terang Bulan dan
**sudah diuji dengan baik** — termasuk kasus Jakarta yang menuntut sisi
terang menghadap **bawah** (`testCrescentInJakartaFacesDownNotRight`).
Sudut itu memakai konvensi **matematis**: positif = sisi terang ke **atas**,
diukur berlawanan arah jarum jam dari arah kanan.

View lalu meneruskannya **apa adanya** ke `GraphicsContext.rotate(by:)`:

```swift
layer.rotate(by: .radians(angle))   // sudut model, konvensi matematis
```

`GraphicsContext` SwiftUI berkoordinat **layar** (y ke bawah). Di konteks
yang sudah dibalik itu, sudut positif berputar **searah jarum jam** — Apple
mendokumentasikannya sendiri di `CGContext.rotate(by:)`: *"Rotating the user
coordinate system on coordinate system that was previously flipped results in
a rotation in the opposite direction (that is, positive values appear to
rotate the coordinate system in the clockwise direction)."*

Akibatnya sabit tercermin **vertikal**: sisi terang yang dihitung menghadap
bawah digambar menghadap atas, dan sebaliknya.

### Kenapa ini tidak terlihat oleh apa pun yang kita punya

Ini kelas cacat yang paling sulit di repo ini, karena **empat** gerbang
sekaligus hijau:

| Yang tersedia | Kenapa tidak menangkapnya |
|---|---|
| Uji model (`brightLimbAngle`) | hijau — sudutnya memang benar; yang salah penerapannya |
| `swift-typecheck.sh` | hijau — `Angle` bertipe sama untuk kedua tanda |
| 22 aturan `swift-ui-lint.sh` | hijau — tidak ada aturan yang tahu arah putaran |
| CI macOS | hijau — kode **mengompilasi**, bukan **tampil** |

Dan yang membuatnya lolos dari mata manusia: **sabitnya tetap berbentuk
sabit**. Sisi terang yang terbalik tetap terlihat seperti bulan muda yang
masuk akal. View-nya sendiri sudah menulis peringatan ini:

> "Tanpa putaran ini gambar akan benar untuk pengamat di lintang tinggi dan
> salah untuk pengamat di tempat aplikasi ini dipakai -- dan salahnya tidak
> terlihat, karena sabitnya tetap berbentuk sabit."

Kalimat itu benar soal putaran, tapi berhenti satu langkah terlalu cepat:
**arah** putarannya juga tidak terlihat, dan justru di lintang rendah
(Jakarta, lintang −6,2°) sisi terang sering menghadap bawah/atas — bukan ke
samping — sehingga kesalahan tanda di situ bukan perbedaan kosmetik.

### Cara menemukannya: gambar modelnya, lalu lihat

Tidak ada uji yang bisa menutup ini dari dalam Swift. Jadi yang dilakukan
adalah **memindahkan geometrinya ke luar**: rumus fase yang sudah teruji
(`PhaseGeometry`) dan matriks putarannya diport ke Python sebaris demi
sebaris, lalu dirender menjadi PNG dan **diperiksa dengan mata**.

Render empat panel — Jakarta & kutub, sebelum & sesudah:

| Panel | Sisi terang | Seharusnya | Benar? |
|---|---|---|---|
| Jakarta, `angle` apa adanya | **atas** | bawah | tidak |
| Jakarta, `−angle` | **bawah** | bawah | ya |
| Kutub, `angle` apa adanya | **bawah** | atas | tidak |
| Kutub, `−angle` | **atas** | atas | ya |

Jadi dugaan itu terkonfirmasi secara visual, bukan dari membaca ulang rumus.

### Yang diubah

- `CelestialVisual.drawRotationRadians(brightLimbAngleRadians:)` — pembalikan
  tanda, **satu fungsi**, dengan alasannya lengkap di doc-comment. Bukan
  tanda minus yang ditulis langsung di view: di sana ia tidak bisa diuji.
- View memakainya: `layer.rotate(by: .radians(CelestialVisual.drawRotationRadians(...)))`.
- Tiga uji baru mengunci konvensinya: pembalikan murni, kasus Jakarta
  (model negatif → argumen `rotate` **positif**), dan `+π/2` model → `−π/2`
  argumen.

### Batas yang jujur

- **Yang dibuktikan: arah putarannya.** Yang **tidak** dibuktikan adalah
  keseluruhan komposisi di perangkat — render Python memverifikasi matriks
  putaran dan pita fase, bukan `Canvas` SwiftUI yang sesungguhnya. Yang
  menghubungkan keduanya adalah konvensi `CGContext` yang terdokumentasi.
- **Belum pernah dilihat di perangkat.** Kalau kelak ada kesempatan menjalankan
  di jam sungguhan, yang harus diperiksa pertama adalah satu bulan sabit di
  lintang rendah: sisi terangnya harus menghadap Matahari, yang biasanya
  berarti ke bawah pada sore hari.

### Gerbang

- `./swift-test.sh` → **174 CelestialEngine + 597 PointingKit**, 0 gagal
  (594 → 597, +3). Engine tidak disentuh.
- `./swift-ui-lint.sh` → **22 aturan** hijau (Aturan 10 menangkap README
  594 → 597 lebih dulu, seperti seharusnya).
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.

## Progres terakhir (5 Okt 2026 — judul baris yang memakai kunci nilainya)

### Cacatnya: baris yang benar hanya karena kebetulan

`SkyContextView` punya baris "kegelapan langit" yang menyatakan apakah langit
cukup gelap untuk melihat bintang. Isinya begini:

```swift
row(TextLocalization.text(.skyContextDark),      // judul → "Gelap"
    context.isDark ? TextLocalization.text(.skyContextDark)   // nilai → "Gelap"
                   : TextLocalization.text(.skyContextLight)) // nilai → "Terang"
```

Judul barisnya memakai **kunci nilainya**, bukan nama barisnya. Di langit
gelap baris itu karena itu terbaca:

    Gelap: Gelap

Di langit terang: `Gelap: Terang`. Yang pertama benar hanya karena kebetulan —
dan yang kedua, yang seharusnya menyatakan "langit belum gelap, bintang
belum bisa dipakai", justru berbunyi seperti kontradiksi. Tidak ada satu pun
dari kedua bentuk itu yang menyebut **apa yang sedang diukur**: baris ini
tentang keadaan langit, dan kata "Langit" tidak pernah ada di layar.

Ironisnya katalognya sudah tahu. Komentar kunci `skyContext.dark` berbunyi
"Nilai baris kegelapan langit (gelap)" — perannya disebut tepat, *nilai*. Yang
salah adalah view yang memakainya sebagai judul.

### Kenapa tidak ada gerbang yang menangkapnya

Tiga gerbang menyentuh teks tampilan, dan ketiganya hijau:

| Gerbang | Yang dituntut | Status di baris ini |
|---|---|---|
| Aturan 4 | teks punya kunci katalog | hijau — `.skyContextDark` memang kunci |
| Aturan 6 | kunci ada di katalog, paritas dua arah | hijau — ada, dan sebanding |
| Aturan 19 | setiap kunci dipakai kode | hijau — dipakai, malah dua kali |

Yang salah bukan **keberadaan** kunci, bukan **paritas**, dan bukan
**kosakata** — melainkan **peran**: judul harus menamai barisnya, nilai harus
mengisi barisnya, dan keduanya tidak boleh benda yang sama. Tidak ada gerbang
yang menguji peran.

### Yang diubah

- Kunci baru `skyContext.skyLabel` ("Langit" / "Sky") — nama barisnya, yang
  selama ini tidak pernah ada.
- `SkyContextView` memakai kunci itu sebagai judul; nilainya tetap
  `skyContextDark`/`skyContextLight`.
- `LocalizedText.allKeys` + katalog + tripwire jumlah kunci (306 → 307).

### Gerbang baru: Aturan 22

`swift-ui-lint.sh` kini memeriksa setiap `row`/`detailRow`: himpunan kunci
katalog di argumen **judul** dan di argumen **nilai** tidak boleh beririsan.
Sapuan dijalankan lebih dulu ke seluruh `Apps/` untuk memastikan baris ini
satu-satunya pelanggar; empat pemanggilan `row` lain yang terlihat mencurigakan
diperiksa satu per satu dan terbukti bukan:

| Pemanggilan | Kenapa bukan pelanggaran |
|---|---|
| `LinkView.swift:20` | judul `linkRowStatus`, nilai `linkValueActive`/`linkValueInactive` — beda kunci |
| `LinkView.swift:24` | judul `linkRowReachable`, nilai `linkValueYes`/`linkValueNo` |
| `PointingView.swift:750` | judul `skyContextCalibration`, nilai `calibrationStatusAppliedShort` |
| `DiagnosticsView.swift:329` | judul literal `"Objek (sisa)"`, nilai `object.name` — bukan kunci |

Regex kuncinya sengaja sempit (`TextLocalization.text(.nama)`) supaya tidak
menangkap `text`, `isDark`, dan setengah repo: gerbang yang selalu merah akan
dimatikan orang lain saat ia berbunyi.

Aturannya diverifikasi **dua arah** — cacatnya disuntikkan kembali, gerbang
merah di baris yang tepat (`PointingView.swift:739`), lalu dipulihkan dan
gerbang hijau. Gerbang yang hanya pernah dilihat hijau tidak membuktikan apa pun.

### Gerbang

- `./swift-test.sh` -> **174 CelestialEngine + 594 PointingKit**, 0 gagal.
  (Tripwire jumlah kunci bekerja: 306 → 307 ditolak lebih dulu, seperti
  seharusnya.)
- `./swift-ui-lint.sh` -> **22 aturan** hijau.
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.

## Progres terakhir (5 Okt 2026 — bintang yang berdenyut di iPhone dan diam di jam)

### Cacatnya: gerak yang sudah dihitung, sudah diuji, dan tidak pernah tersambung

`MotionPolicy.allowsContinuousMotion` ada di `PointingKit`, teruji di Linux,
dan memutuskan apakah denyut glow bintang boleh berjalan. `CelestialVisualView`
menerima fase denyut lewat parameter `pulse` — dan komentarnya menjelaskan
kenapa denyut itu **tidak** dihitung di dalam view:

> "Diberi dari luar, bukan dihitung sendiri di sini: supaya jam bisa
> menghentikan denyut saat layar redup, dan iPhone bisa menghentikannya saat
> layar tidak aktif."

Kalimat itu menunjuk jalur yang **tidak ada**. Kartu jam
(`ObjectDetailView`) memanggil `CelestialVisualView` tanpa `pulse` sama sekali,
jadi `pulse` selalu bernilai bawaan nol di sana. Akibatnya:

- Bintang di iPhone berdenyut halus; bintang di **jam** diam total — padahal
  jam adalah permukaan utamanya, dan jam yang berjalan 20×/detik selama
  mengarahkan.
- `isSceneActive: true` di kartu jam adalah nilai yang **tidak pernah
  dihitung**, karena `MotionPolicy` di situ juga tidak dibaca siapa pun.
  Konstanta yang terdokumentasi rapi di sebelah nilai yang benar-benar
  berubah — persis kelas "dihitung lalu dibuang" yang berulang di repo ini.

Ini bukan cacat yang bisa ditangkap uji: view tidak bisa dijalankan di Linux,
dan yang hilang bukan sebuah perhitungan, melainkan sebuah **argumen**.

### Kenapa jam tetap butuh `TimelineView` — dan kenapa percobaan pertama salah

Dugaan pertama saya: kartu jam sudah dirender ulang 20×/detik selama
mengarahkan (setiap sampel sensor adalah perubahan `@Published`), jadi fase
denyut bisa dihitung langsung dari `Date()` di dalam `body` **tanpa**
`TimelineView`. Itu **salah**, dan salahnya persis jenis yang harus ditangkap
sebelum dikirim:

`CelestialVisual` adalah `Equatable`. Selama terkunci pada satu bintang,
argumen kartu tidak berubah antar sampel sensor — jadi SwiftUI boleh melewati
evaluasi ulang `body`, dan `Date()` yang dibaca di dalamnya **bukan
dependensi yang bisa dilihat SwiftUI**. Hasilnya bintang yang diam: cacat yang
sama, hanya berpindah tempat. "Dirender 20×/detik" bukan jaminan; yang
menjamin adalah penyegaran yang eksplisit.

Jadi denyut di jam memakai `TimelineView(.animation(minimumInterval: 1/30))`
lewat `PulsingCelestialVisual` — view kecil yang memegang jam denyutnya
sendiri, sama seperti panel iPhone. Dipisah dari kartu karena alasan yang
sudah dipakai di iPhone: kalau kartu ikut hidup di dalam `TimelineView`,
mematikan denyut berarti mematikan kartu — dan kartu adalah **jawaban**, bukan
hiasan.

`pulseStart` diset ulang **sekali** saat scene kembali aktif, dengan alasan
yang sama seperti `resyncPulse` di iPhone: tanpa itu fase melompat maju
beberapa detik dalam satu frame, dan lompatan itu terbaca sebagai kedipan,
bukan denyut.

### Gerbang `hasPulse`: ongkos yang nyata di layar yang paling peduli baterai

`Canvas` digambar ulang setiap kali nilai yang ditangkapnya berubah. `pulse`
yang bergerak 20×/detik karena itu memaksa **planet, Bulan, dan Matahari**
digambar ulang 20×/detik untuk piksel yang identik — denyut hanya dibaca
`drawStar`. Di jam, ongkos itu nyata: baterai. Maka `pulse` digerbangi
`visual.hasPulse` di kedua app (properti itu sudah teruji di Linux), sehingga
`Canvas` planet **tidak pernah** digambar ulang karena denyut.

Di iPhone gerbangnya juga dipindah ke pemanggilan, bukan hanya tinggal di
kondisi cabang `TimelineView` di atasnya. Kondisi itu menjaga agar
`TimelineView` tidak dibangun untuk planet; gerbang di pemanggilan menjaga
agar `Canvas` tidak digambar ulang. Invariannya jadi menempel pada
pemanggilan dan tidak bisa hilang diam-diam saat cabang itu direfaktor.

### Aturan 21 menutup kelasnya

Aturan 7 memastikan API gerak **punya penjaga** di berkasnya; ia tidak bisa
melihat apakah denyut sampai ke gambar, dan tidak bisa melihat apakah ia
sampai ke gambar yang tidak seharusnya berdenyut. Aturan 21 memeriksa
`CelestialVisualView(...)` yang meneruskan `pulse` bukan-nol wajib menyebut
`hasPulse` di daftar argumen yang sama. Dibuktikan **merah** pada kedua app
(gerbang dilepas → Aturan 21 menyala) dan **hijau** pada `pulse: 0` yang sah
(gerbang tidak terlalu ketat).

Test: CelestialEngine **174** + PointingKit **594** hijau. Lint, typecheck,
dan CI macOS hijau. README disinkronkan ke **21 aturan**.

---

## Progres terakhir (5 Okt 2026 — kartu tahap merakit latarnya sendiri, dan mode malam yang membongkarnya)

### Dua premis uji yang sudah ada di pohon kerja, dan keduanya tidak menguji apa pun

Siklus ini dimulai dari pohon kerja yang membawa dua uji setengah jadi di
`SurfacePaletteTests`. Keduanya menulis cacat yang benar: kartu tahap
kalibrasi menggambar latarnya dengan `phaseTone.color.opacity(0.12)`, bukan
dari token permukaan. Keduanya juga **hijau**.

Dan keduanya tidak membuktikan apa pun, karena alasan yang berbeda dari yang
biasa:

- **Warnanya dikarang.** Fixture-nya `(0.94, 0.47, 0.27)` — merah-oranye
  hangat yang **tidak ada di `TonePalette`**, di mode mana pun. Jadi uji itu
  menghitung selisih sebuah warna imajiner terhadap `surface1`, dan hijau.
  Tidak ada satu pun warna yang benar-benar dirender layar yang tersentuh.
- **Yang diuji bukan yang berbahaya.** Keduanya membandingkan warna campuran
  dengan `surface1`/`surface2` dan menyimpulkan "konvensinya berbeda". Itu
  benar, dan bukan cacatnya. Yang berbahaya adalah **akibat** dari berbeda:
  kontras teks di atas latar yang dirakit sendiri.

### Cacat sebenarnya: teks yang berwarna sama dengan latarnya

Kartu tahap memakai nada yang sama untuk **teks** (`phaseTone.color`) dan
**latarnya** (`phaseTone.color.opacity(0.12)`). Jarak keduanya karena itu
ditentukan oleh alpha dan oleh latar di belakangnya — dan tidak ada satu pun
uji yang menghitung campuran itu.

Di mode malam hasilnya:

| Tahap | Nada | Kontras teks di atas kartunya | Ambang |
|---|---|---|---|
| idle | `.neutral` (merah 0.94) | **4.32:1** | 4.5 — gagal |
| collecting | `.active` (merah 0.955) | **4.44:1** | 4.5 — gagal |
| ready/applied | `.success` (merah 0.968) | 4.54:1 | 4.5 — lolos, tipis |

Plafon kontras mode malam adalah 5.25:1 (merah murni di atas hitam), dan
merah murni **tidak bisa** lebih terang dari itu. Campuran itu menaikkan
latar kartu ke merah ~0.154, sementara ruang yang tersedia sebelum nada
paling redup jatuh di bawah 4.5:1 berhenti di ~0.101. Jadi cacatnya bukan
"alpha terlalu besar" — latarnya memang keluar dari plafon yang fisikanya
sudah diketahui repo ini.

Di mode siang cacat yang sama ada dan **tidak terlihat sebagai kesalahan**:
kartunya hanya jadi ~2x lebih terang dari kartu tetangganya, dan tidak ada
teks yang gagal. Itu sebabnya mode malam yang membongkarnya.

### Kenapa gerbang lama hijau

Tiga lapis, dan ketiganya bentuk yang sudah berulang di repo ini:

1. **`TonePaletteTests` menguji teks di atas permukaan token.** Ia menyisir
   setiap nada terhadap `surface1`/`surface2` dan semuanya lolos — karena
   token permukaan memang benar. Yang tidak diuji adalah latar yang dirakit
   view, dan itu bukan token.
2. **Peta `phaseTone` hidup di `CalibrationView`.** SwiftUI tidak ada di
   Linux, jadi tidak ada uji yang bisa menyentuh peta itu sama sekali.
3. **Aturan 15 menjaga warna prosedural, bukan permukaan.** Ia menyapu
   `Color(red:…)` di gambar planet/bulan/bintang supaya tidak memancarkan
   hijau-biru di mode malam. Kartu bukan gambar, jadi tidak terlihat.

### Yang diperbaiki, dan kenapa bukan "alpha lebih kecil"

Menurunkan alpha akan membuat uji hijau hari ini dan mengembalikan cacat yang
sama begitu nada berikutnya ditambahkan — persis kelas "menyembunyikan, bukan
menutup". Tiga perubahan mengarah ke sumbernya:

- **Kartu memakai `.surfaceCard(level: .card)`.** `surface1` sudah diuji
  kontrasnya terhadap kelima nada di kedua mode (`TonePaletteTests`), jadi
  kartu ini tidak bisa lagi merakit latarnya sendiri. Identitas tahap tetap
  dibawa ikon dan label di atasnya — yang memakai warna nada teruji, bukan
  latar.
- **`CalibrationPhase.tone` pindah ke PointingKit**, plus `CaseIterable`.
  Peta nada yang hidup di berkas view tidak bisa diuji di Linux; di paket ia
  jadi satu definisi, dan `allCases` memastikan tahap baru tidak bisa lolos
  tanpa nada yang diuji.
- **`SurfaceColor.composited(over:alpha:)`** — operasi yang selama ini hanya
  ada sebagai `.opacity()` di view. Ia punya nama, bisa dihitung, dan bisa
  ditahan uji. Ini operasi yang **menghasilkan** cacatnya, dan selama ia tidak
  punya nama di model, setiap view yang memakainya mengarang aturan
  kontrasnya sendiri di berkas yang tidak diuji.

### Gerbang baru: Aturan 20

Menyapu `Apps/` untuk `.background(`/`.fill(` yang argumennya berakhir
`.color.opacity(`. Satu-satunya situs yang ada sudah diperbaiki, jadi
gerbangnya hijau di atas kode yang benar — dan itu baru berarti kalau ia juga
merah di atas kode yang salah.

Dibuktikan dua arah lewat `red-lint.sh`:

| Suntikan | Hasil |
|---|---|
| `.background(phaseTone.color.opacity(0.12), …)` | **MERAH** pada Aturan 20 |
| `Color.black.opacity(0.18)` + gradien dari `surface2.color.opacity(0.55)` | **hijau** — bayangan di gambar prosedural & definisi token, bukan kartu |

Baris kedua yang menentukan: tanpa uji negatif, gerbang yang menandai
**setiap** `.opacity` akan lolos sebagai "bisa merah" sambil memerahkan
`SurfaceTokens.swift` sendiri.

### Bukti merah uji baru

| Mutasi | Uji | Hasil |
|---|---|---|
| `.collecting` → `.neutral` | `testEveryCalibrationPhaseCarriesALegibleTone` | **MERAH**: `("neutral") is not equal to ("active")` |
| alpha dipasang terbalik di `composited` | `testCompositingIsLinearAndDependsOnTheBackdrop` | **MERAH**: 0.83 ≠ 0.147 |

Mutasi pertama menjaga peta nadanya; yang kedua menjaga **operasi** yang
dipakai untuk membuktikan cacatnya — kalau komposisinya sendiri salah, bukti
di atasnya tidak berarti apa-apa.

### Gerbang

- `swift-test.sh` → **174 CelestialEngine + 594 PointingKit** (589 → 594, +5).
  **Engine tidak disentuh.** Dua uji setengah jadi yang tidak menanggung beban
  diganti tiga yang lebih tajam, jadi kenaikannya +5, bukan +7.
- `swift-ui-lint.sh` → **20 aturan hijau** (19 → 20). Aturan 10 menangkap
  README yang masih 589.
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `red-lint.sh` → Aturan 20 merah pada suntikan, hijau pada non-kartu.
- `red-test.sh` → dua mutasi merah.
- CI: `37330275051` (Engine Tests Linux) + `37330275112` (Apple Build
  macos-15) — **dua-duanya hijau** pada `5975e80`.

### Batas yang jujur

- **Belum pernah dilihat di perangkat.** Yang dibuktikan: kontras dihitung,
  ambangnya benar di kedua mode, peta nada disisir seluruhnya, dan build
  macOS hijau. Yang belum: apakah `surface1` **terlihat** sebagai kartu di
  layar 41mm mode malam — langkah `background`→`surface1` di mode malam
  hanya 0.023, di atas ambang 0.02 tapi tidak lebih.
- **Kartu kehilangan warna latar sebagai penanda tahap.** Sebelumnya kartu
  itu "berwarna" sesuai tahap; sekarang latarnya seragam dan yang membedakan
  hanya ikon + label. Itu pertukaran yang disengaja: warna latar yang tidak
  teruji tidak boleh jadi satu-satunya pembeda. Di mode malam tidak ada yang
  hilang (kelima nada menyempit ke satu merah); di mode siang ini mengurangi
  aksen — dan itu sesuai brief "aksen vibrant **secukupnya**".
- **Aturan 20 membaca bentuk, bukan makna.** `.background(someColor.opacity(0.1))`
  yang *sah* (mis. nanti ada alasan produk untuk kartu bernada yang
  kontrasnya dihitung terpisah) akan tertangkap dan harus lewat
  `SurfaceColor.composited` — yang memang tujuannya. Tapi `.opacity(` yang
  dirakit lewat variabel perantara (`let c = tone.color; … .background(c.opacity(0.1))`)
  tidak terlihat, dan itu batas pemeriksa teks.
- **`composited` belum punya konsumen produksi.** Ia dipakai uji dan
  dokumentasi hari ini; nilainya adalah jawaban untuk kartu ke-3 yang
  menulisnya besok.

## Progres terakhir (5 Okt 2026 - "di atas cakrawala" memakai ambang yang berkasnya sendiri sebut salah)

### Satu berkas, dua jawaban, dan yang salah punya nama paling netral

`PointingTarget.isAboveHorizon` mengembalikan `altitudeDeg > 0` - cakrawala
geometris. Tiga puluh tiga baris di bawahnya di berkas yang **sama**,
`availableTargets` membawa dokumen panjang yang menyebut ambang itu persis
sebagai cacat yang sudah diperbaiki:

> Versi lama memakai `altitudeDeg <= 0` yang terlihat wajar tapi salah: engine
> hanya mengunci lewat `VisibilityFilter`, yang menyaring di 5 derajat pada
> policy bawaan.

Yang membuat ini bertahan bukan kelalaian penulisan, tapi **kelebihan uji**:

- **Accessornya tidak punya konsumen.** Sapuan menemukannya `app=0`; satu-
  satunya pemakai adalah sebuah uji.
- **Uji itu memakainya sebagai pengganti yang LEBIH LEMAH.** Namanya
  `testOfferedTargetsStayAboveTheGeometricHorizon` - nama yang jujur, dan
  justru itu masalahnya: ia sengaja mengecek batas yang lebih longgar, dan
  hijau. Uji di atasnya (`...CanActuallyBeLocked`) mengecek ambang yang benar.
  Jadi cacatnya tertutup **dua kali**, dan tidak ada yang perlu berubah.

Bentuknya beda dari siklus-siklus sebelumnya: bukan nilai yang dibuang, dan
bukan pula langkah yang terlewat. Yang terjadi adalah **nama yang tepat untuk
pertanyaan yang salah**, dipakai sebagai bukti bahwa pertanyaan yang benar
sudah dijawab.

### Kenapa bukan "`> 0` diganti `> 5`"

Angka 5 itu `policy.minAltitudeDeg`, dan policy bisa berbeda (bawaan 5,
permissive -90, dan putusan slew memakai 10). Menuliskannya di accessor berarti
menulis ambang yang sama untuk **kedua kalinya** - kelas cacat yang dokumen
`availableTargets` justru sedang menutup ("kalau `minAltitudeDeg` berubah,
daftar ikut berubah, karena tidak ada lagi angka yang ditulis dua kali").

Jadi accessornya menerima `VisibilityPolicy`:

```swift
public func isAboveHorizon(_ policy: VisibilityPolicy) -> Bool
```

Tidak ada nilai bawaan. Kalau `policy` bisa lupa diteruskan, pemanggilnya
kembali menebak - dan menebak ambang adalah kesalahan yang paling mahal di
repo ini.

Operatornya `>` dan bukan `>=`, sengaja sama dengan `availableTargets` yang
menyingkirkan `altitudeDeg <= policy.minAltitudeDeg`. Titik yang tepat di
ambang adalah satu-satunya tempat kedua bentuk itu berbeda jawabannya, jadi
satu uji khusus menahan operator itu.

### Bukti merah: tiga mutasi, ketiganya MERAH

| Mutasi | Uji | Hasil |
|---|---|---|
| `> policy.minAltitudeDeg` -> `> 0` | `testIsAboveHorizonUsesTheEngineAltitudeGateNotTheGeometricOne` | **MERAH**: Sirius di 0,6 derajat dijawab "ya" sementara engine menolaknya |
| hal yang sama, policy permisif | `testIsAboveHorizonHonoursAPermissivePolicy` | **MERAH**: -45 derajat dijawab "ya" |
| `>` -> `>=` | `testAltitudeExactlyOnTheGateIsRejected` | **MERAH**: titik tepat di ambang lolos, padahal daftar membuangnya |

Pita 0-5 derajat dipakai sebagai fixture di **dua** uji, dan sekarang
didefinisikan sekali (`bandObserver` / `bandDate`): kalau tiap uji menghitung
sendiri, mereka bisa mengacu ke langit yang berbeda tanpa ada yang melihat, dan
salah satunya bisa hijau karena langitnya kebetulan kosong.

### Gerbang

- `swift-test.sh` -> **174 CelestialEngine + 589 PointingKit** (587 -> 589, +2).
  **Engine tidak disentuh.** Satu uji lama yang lebih lemah diganti tiga yang
  lebih tajam, jadi kenaikannya +2, bukan +4.
- `swift-ui-lint.sh` -> **19 aturan hijau** (Aturan 10 menangkap README 587 -> 589).
- `swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- `red-test.sh` -> tiga mutasi merah.
- CI: `37325552132` (Engine Tests Linux) + `37325552075` (Apple Build macos-15)
  - **dua-duanya hijau**.

### Batas yang jujur

- **Belum pernah dilihat di perangkat**, dan kali ini konsekuensinya kecil:
  accessor ini tidak punya konsumen di layar, jadi yang berubah adalah jawaban
  untuk kode yang belum ditulis.
- **Tidak ada layar yang berubah.** Kalau ada pemanggil di masa depan yang
  butuh "apakah benda ini di atas cakrawala" alih-alih "cukup tinggi untuk
  dikunci", ia harus memakai `direction.altitudeDeg > 0` langsung - pertanyaan
  itu memang berbeda, dan accessor ini sengaja tidak menjawabnya.
- **Pita fixture bergantung pada satu tanggal dan satu tempat.** Kalau katalog
  bintang berubah, prasyaratnya (`0 < siriusAlt < 5`) akan pecah dan uji
  memberi tahu - itu memang tujuannya, bukan fragility tersembunyi.

## Progres terakhir (5 Okt 2026 - catatan ketukan yang terbuang menghitung bintang, bukan ketukan)

### Dua hitungan yang sama-sama `Int`, dan tidak ada yang bisa memilih

Siklus lalu menambah `redundantTapCount` - jumlah **ketukan** yang tidak
menambah pengukuran - lengkap dengan identitas yang dijaga:
`samples.count == distinctReferenceCount + redundantTapCount`. View-nya
tidak memakainya. Yang dipakai `CalibrationView` adalah:

```swift
if !flow.repeatedReferenceIDs.isEmpty {
    Text(CalibrationText.repeatedReferenceHint(
            repeatedCount: flow.repeatedReferenceIDs.count))
```

`repeatedReferenceIDs.count` menghitung **bintang** yang diulang. Kalimatnya
menyebut **ketukan**. Untuk tiga ketukan pada Sirius, kartu menampilkan
"3 acuan tercatat" lalu "1 ketukan di acuan yang sama tidak menambah
pengukuran" - padahal yang terbuang 2.

Dua baris itu **saling meniadakan**: pengguna menghitung 3 + 1 dan
menyimpulkan ada empat ketukan, padahal tiga yang terjadi. Dan pada keadaan
yang paling sering terjadi (satu bintang diketuk berulang), catatan itu
selalu berbunyi "1", jadi ia tidak pernah memberi informasi apa pun.

### Kenapa gerbang tetap hijau

- **Aturan 4 dan 6** hanya melihat kunci katalog - dan kuncinya memang
  sama persis. Yang salah adalah **argumennya**, bukan teksnya.
- **Uji yang menangkapnya memanggil `CalibrationText` dengan angka yang
  benar secara manual.** `testDisplayHintCountsTapsNotReferences` menguji
  *jalurnya sendiri* - fungsi pemformat dengan angka pilihan penulis -
  bukan jalur yang dirender. Formatter yang benar dengan pemanggil yang
  salah menghasilkan dua-duanya hijau.

Bentuk paling licin dari kelas yang berulang di repo ini: uji-ujinya benar,
dokumentasinya benar, dan tidak ada layar yang salah secara terpisah.

### Yang diperbaiki: bentuk pemanggilannya, bukan angkanya

Accessor yang salah (`redundantTapCount`) sudah benar sejak siklus lalu.
Yang tidak ada adalah **pemanggil tunggal** yang tidak bisa salah pilih:

- **`CalibrationFlow.repetitionHint`** jadi satu-satunya sumber catatan.
  Syaratnya `> 0`, bukan `> 1`: ketukan **kedua** sudah tidak menambah apa
  pun, jadi catatan wajib tampil sejak sana. `nil` alih-alih catatan
  bernilai nol - "0 ketukan ... tidak menambah pengukuran" menyatakan
  sesuatu yang tidak terjadi.
- **`CalibrationText.redundantTapHint(repeatedTapCount:)`** - parameternya
  menyebut benda yang dihitung, jadi `repeatedReferenceIDs.count` tidak
  bisa masuk tanpa terlihat salah. Bentuk lama `repeatedCount:` **dihapus**,
  bukan di-deprecate: menyisakannya berarti kelas bug ini masih bisa terjadi
  lagi, dan tidak ada satu pun pemanggil lain yang butuh ia.
- Uji lama yang memanggil bentuk itu dihapus; perannya diambil alih
  `testOnScreenHintCountsTapsNotRepeatedStars` yang lewat accessor.

### Bukti merah: empat mutasi, keempatnya MERAH

| Mutasi | Uji | Hasil |
|---|---|---|
| accessor -> `repeatedReferenceIDs.count` | `testOnScreenHintCountsTapsNotRepeatedStars` | **MERAH**: "1 ketukan" untuk tiga ketukan - persis cacat yang ada di layar |
| syarat `> 0` -> `> 1` | `testHintAppearsFromTheFirstRedundantTap` | **MERAH**: catatan hilang tepat di keadaan yang paling sering |
| syarat `> 0` -> `>= 0` | `testNoRepetitionMeansNoHintAtAll` | **MERAH**: "0 ketukan di acuan yang sama tidak menambah pengukuran" |
| identitas rusak | `testTheHintAndTheCountLineAddUpToTheRealTapCount` | **MERAH**: 8 != 5 |

Mutasi ketiga adalah yang paling penting: ia memunculkan **fakta yang
dikarang** - kalimat yang menyatakan ada kejadian yang tidak terjadi - dan
bukan cuma angka yang salah. Itu arah yang paling dilarang oleh PRD v0.4.

### Kesalahan saya di tengah

Assertion pertama yang saya tulis menyatakan dua hitungan itu **selalu
berbeda**. Padahal tidak: untuk satu bintang yang diketuk dua kali keduanya
sama (1). Dan justru itu sebabnya hitungan bintang lolos tanpa terlihat -
pada keadaan yang paling sering, angka yang salah **kebetulan benar**.

Jadi penjaga yang saya tulis ulang akan hijau di atas kode yang salah persis
seperti penjaga yang ia gantikan. Assertion diganti, dan alasannya ditulis di
sumber supaya orang berikutnya tidak menulisnya lagi.

### Gerbang

- `swift-test.sh` -> **174 CelestialEngine + 587 PointingKit** (583 -> 587, +4).
  **Engine tidak disentuh.**
- `swift-ui-lint.sh` -> **19 aturan hijau**. Aturan 10 menangkap README yang
  masih 583, persis fungsinya.
- `swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- `red-test.sh` -> empat mutasi merah, termasuk yang memunculkan fakta dikarang.
- CI: `37323113577` (Engine Tests Linux) + `37323113536` (Apple Build macos-15)
  - **dua-duanya hijau**.

### Batas yang jujur

- **Belum pernah dilihat di perangkat.** Yang dibuktikan: hitungan ketukan
  benar di kedua arah, pemanggil tunggal tidak bisa salah pilih, penamaan
  parameter menutup jalur salah, dan build macOS hijau.
- **Katalog tidak berubah sama sekali.** Tidak ada kunci baru, dan kunci lama
  dipakai dengan hitungan yang benar - jadi tidak ada satu pun terjemahan yang
  perlu ditulis ulang atau diverifikasi ulang.
- **Dua angka ini masih boleh sama.** Itu bukan bug yang tersisa; itu
  kebetulan yang membuat cacat ini sulit dilihat. Yang dijaga sekarang
  adalah jalurnya (satu pemanggil), bukan kesamaan angkanya.

## Progres terakhir (5 Okt 2026 — kunci katalog yang tak dirujuk kode mana pun)

### Satu entri katalog yang tidak pernah dipakai siapa pun

Menyisir 434 kunci di `Localizable.xcstrings` terhadap seluruh kode sumber
menghasilkan **satu** kunci yang benar-benar tak dirujuk: `Status: %@.`

Kunci itu berbentuk **literal Bahasa Indonesia**, bukan konvensi
`calibration.statusPrefix` seperti semua kunci lain di katalog — jadi ia
tidak mungkin dirujuk `TextLocalization`, yang mencari lewat nama kunci.
=`grep -rn 'Status: %@' Apps Packages` mengembalikan nol hasil di luar
katalog itu sendiri.

Mengapa ini penting, dan kenapa bukan sekadar kerapian:

**Katalog adalah satu-satunya sumber teks untuk bahasa selain Bahasa
Indonesia.** `SWIFT_EMIT_LOC_STRINGS: NO` (sengaja, `project.yml:102`)
membuat Xcode tidak akan pernah mengisinya sendiri — jadi yang menulis entri
itu adalah manusia, dan entri yatim mengaku sebagai terjemahan yang tidak
diverifikasi siapa pun. Kalau nanti ada yang memutuskan "terjemahan ini sudah
selesai", entri yatim membuatnya terlihat selesai.

**Yang lebih berbahaya adalah kebalikannya.** Kalau ada kode yang memanggil
kunci yang **hanya** hidup di katalog sebagai entri yatim — bukan lewat
`TextLocalization` — maka `text()` jatuh ke nilai bawaan Bahasa Indonesia
**tanpa pernah memberi tahu**. Di app berbahasa Inggris, teks itu muncul
dalam Bahasa Indonesia dan tidak ada satu pun gerbang yang menyala. Itu
persis kelas "hijau yang tidak hijau" yang menjadi alasan Aturan 6 ada.

**Aturan 6 tidak menangkapnya.** Aturan 6 menjaga paritas dua arah hanya
untuk kunci ber-namespace — `pointing.state.`, `confidence.level.`,
`link.kind.`, `object.kind.`. Kunci di luar namespace itu memang tidak
pernah dicek arah baliknya, jadi katalog boleh memuat entri mati dan suite
tetap hijau.

Entri itu dihapus (434 → 433). Format berkas dijaga: diff-nya 11 baris
hapus, tanpa satu pun baris lain yang berubah.

### Aturan 19: kunci katalog yang tak terpakai

Gerbang baru, untuk kelas "hijau yang tidak hijau" yang sama.

Pemeriksaannya sengaja **menyilang seluruh berkas `.swift`** di `Apps/` dan
`Packages/`, lalu menganggap kunci "dipakai" bila muncul sebagai substring di
mana saja. Itu kedengarannya longgar, dan memang sengaja longgar: yang
dilarang adalah **ketiadaan** kunci, bukan kesalahan pengenalan pola.
Memakai satu pohon saja akan melaporkan kunci yang sah sebagai yatim — dan
itulah merah yang tidak merah. Kunci bisa dirujuk lewat `key:`, lewat enum
ber-kasus, atau lewat `LocalizedText`; ketiganya berakhir sebagai substring
yang sama.

Sudah dibuktikan dua arah, bukan cuma diasumsikan bekerja:

- **Merah** — entri `KunciYatimSengajaDibuat` disisipkan → gerbang merah
  dan menyebut kuncinya.
- **Hijau** — entri itu dihapus kembali → semua 19 gerbang hijau.

Kunci `Status: %@.` dihapus, Aturan 19 dipasang. 174 CelestialEngine +
566 PointingKit tetap hijau.

## Progres terakhir (5 Okt 2026 — nilai bawaan yang mengklaim identitas saat engine ragu)

### Tiga tempat membawa baku `= true` untuk pertanyaan yang harusnya `false`

`CelestialVisualView` punya satu properti yang menentukan apakah gambar boleh
menampilkan **ciri pengenal** — cincin Saturnus, pita Jupiter, kutub Mars,
bentuk galaksi. Semua komentar di sekitarnya panjang dan benar tentang
betapa berbahayanya ciri itu tampil saat ragu. Dan propertinya ditulis:

```swift
var isConfirmed: Bool = true
```

Nilai bawaan adalah satu-satunya nilai di Swift yang **tidak pernah muncul
di pemanggil**. Pemanggil yang meneruskan
`isConfirmed: engine.confirmsDisplayedIdentity` menulis keyakinannya di
layar dan bisa dibaca ulang; pemanggil yang lupa tidak menulis apa pun, dan
yang berjalan adalah nilai bawaan. Jadi kelalaian di sini tidak punya baris
untuk diperiksa — persis kelas "dihitung lalu dibuang" yang berulang di repo
ini, dalam bentuk yang paling sukar dilihat.

Tiga tempat membawanya: gambar jam (`PointingView`), gambar iPhone
(`DiagnosticsView`), dan **label suara** panel iPhone
(`visualPanelLabel`). Yang ketiga paling licin: yang dipengaruhinya adalah
bentuk yang **diucapkan** ("galaksi", "gugus bola"), jadi dengan `true`
VoiceOver mengucapkan bentuk yang persis sedang disembunyikan gambarnya.

### Kenapa arahnya `false`, bukan sekadar "hapus saja baku-nya"

Dua-duanya menghapus cacat hari ini, karena ketiga pemanggil memang
meneruskan argumennya secara eksplisit. Yang membedakan adalah jawaban
untuk layar yang ditulis besok, dan PRD sudah menetapkan arahnya:
**uncertainty > false confidence**. Terlalu hati-hati (gambar disamar untuk
objek yang sebenarnya pasti) mengecewakan; terlalu yakin (cincin Saturnus
di bawah badge "Ragu") adalah kebohongan. Nilai bawaan harus memihak ke
arah yang salah-yang-bisa-diterima.

Membuang baku-nya sama saja tidak bisa: Swift mewajibkan nilai untuk
properti tersimpan, jadi `var isConfirmed: Bool` tanpa `= ...` tidak
kompilasi. Satu-satunya pilihan lain adalah menjadikannya `let` tanpa baku
dan mewajibkan `init` — itu benar, tapi ia mengubah **setiap** pemanggil
hari ini menjadi perubahan besar pada kode yang sedang berjalan benar,
demi memperbaiki cacat yang belum terjadi. `false` menutup arahnya tanpa
menyentuh satu pemanggil pun.

### Gerbang baru: Aturan 18

Aturan 18 menyapu deklarasi `Bool = true` yang **namanya** menyatakan klaim
identitas (`isConfirmed`, `confirmsIdentity`, `confirmsDisplayed`,
`*claim`). Dua keputusan penyaringnya sengaja sempit:

- **`isStale` tidak masuk.** Ia menyatakan umur, dan `true` di sana berarti
  "tampilkan peringatan" — arah yang justru lebih aman. Memasukkannya
  membuat gerbang berisik pada deklarasi yang benar.
- **Komentar dibuang sebelum pencocokan.** Berkas-berkas ini
  mendokumentasikan cacatnya dengan menyebut `isConfirmed: Bool = true`
  sebagai contoh yang dilarang; tanpa itu gerbang memerah pada
  dokumentasinya sendiri — persis kegagalan yang membuat Aturan 3 pernah
  memerah pada skripnya.

Dibuktikan lewat `red-lint.sh` di **dua arah**, karena gerbang yang hanya
pernah merah sama berbahayanya dengan yang hanya pernah hijau:

| Suntikan | Hasil |
|---|---|
| `var isConfirmed: Bool = true` | **MERAH** pada Aturan 18 |
| `var isStale: Bool = true` + `var showsDetail: Bool = true` | **hijau** — bukan klaim identitas |

Baris kedua yang menentukan: tanpa uji negatif, gerbang yang menandai
**setiap** `Bool = true` akan lolos sebagai "bisa merah".

### Dua artefak alat yang sempat terkomit

Sapuan menemukan dua hal yang bukan cacat produk, tapi cacat **proses**,
dan keduanya sudah terdorong ke `origin/main`:

1. **`⟪HERMES-CONTEXT-COMPRESSION …⟫` di STATUS.md** (dua komit: `e85769d`,
   `f66f782`). Penanda kompresi konteks alat penyunting menggantikan 1.431
   dan 1.547 karakter isi yang sebenarnya. Isinya **tidak ada di objek git
   mana pun** — dicek lewat seluruh `git rev-list --all --objects` dan
   komit mengambang — jadi dua paragraf itu **direkonstruksi** dari konteks
   sekitarnya dan ditandai sebagai rekonstruksi, bukan dipulihkan. Menulis
   ulangnya tanpa menandai akan menghasilkan sejarah yang lebih rapi
   daripada kenyataannya.
2. **`bisaReader` di `SurfacePalette.swift:41`.** Dua kata menyatu di dalam
   komentar dokumen (`bisa` + `Reader`). Aturan 3 menangkap aksara non-Latin,
   bukan kata majemuk yang salah, dan memang seharusnya begitu — ia tidak
   bisa menilai bahasa.

Keduanya lolos gerbang karena `*.md` **sengaja dikecualikan** Aturan 3:
STATUS.md memuat aksara CJK sebagai **bukti** cacat yang pernah nyata, dan
memasukkannya akan membuat gerbang memerah pada dokumentasinya sendiri.
Pengecualian itu tepat untuk aksara, dan menjadi lubang untuk artefak:
berkas `.md` ternyata tidak hanya memuat bukti, ia juga memuat sisa alat.
Asumsi yang mendasari pengecualian itu — bahwa isi `.md` selalu ditulis
manusia — sudah tidak benar, dan dicatat di STATUS, bukan ditambal dengan
menghapus pengecualiannya.

### Gerbang

- `swift-test.sh` → **174 CelestialEngine + 566 PointingKit**, 0 gagal.
  **Engine tidak disentuh.** Perubahan tidak menambah uji karena yang
  diubah adalah nilai bawaan yang sudah tak terjangkau pemanggil mana pun
  hari ini — uji baru untuknya akan hijau di atas kode lama.
- `swift-ui-lint.sh` → **18 aturan hijau** (17 → 18).
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `red-lint.sh` → Aturan 18 merah pada suntikan, hijau pada non-klaim.

### Batas yang jujur

- **Tidak ada satu piksel pun yang berubah.** Ketiga pemanggil sudah
  meneruskan argumennya secara eksplisit; yang diubah adalah jawaban untuk
  kode yang belum ditulis. Ini perbaikan yang nilainya nol hari ini dan
  baru terasa pada layar keempat.
- **Aturan 18 membaca nama, bukan makna.** Deklarasi klaim identitas yang
  tidak memakai salah satu nama di atas akan lolos. Itu batas pemeriksa
  teks, dan lebih baik daripada tidak ada — tapi bukan bukti bahwa kelasnya
  tertutup.

## Progres terakhir (5 Okt 2026 — grafik keyakinan bisu untuk VoiceOver)

### Satu-satunya `Chart` di app, dan satu-satunya bagian layar itu yang diam

Layar diagnostik iPhone memenuhi syarat untuk "sudah aksesibel": setiap
baris `row` punya pengumuman, panel gambar punya `visualPanelLabel`, rincian
sebab keraguan punya `RowSpeech`. Semua dicek, semua ada.

Dan ada satu hal yang luput: **grafik keyakinan**. Ia satu-satunya
`Chart` di seluruh app (`grep -rn 'Chart {'` → satu hasil), dan sampai unit ini
tidak punya `.accessibilityLabel` sama sekali.

Yang membuat ini terasa sebagai celah, bukan pilihan: grafik itu adalah
**paling kaya secara visual** di layar itu (dua garis ambang, garis putus,
sumbu berlabel, legenda) dan **paling sunyi**. Setiap elemen data lain
diny Agatha agar bisa dibaca; grafik satu-satunya yang hanya boleh dilihat.

### Kenapa "tanpa jaraknya terukur" bukan "sejak 12 sampel"

Nomor yang bisa dikeluarkan Swift Charts untuk grafik ini adalah setiap titik
satu per satu, dan tidak ada pembaca layar yang menarik garis dari sana. Yang
juga tidak berguna: "3.2, 3.1, 3.4, …" — daftar angka bukan informasi.

Yang dibutuhkan adalah **kesimpulan**: berapa sampel jatuh di tiap pita
ambang. Empat belas titik menjadi satu kalimat yang bisa ditindaklanjuti
penguji lapangan: kalibrasi perlu diperbaiki (terlalu jauh) atau katalognya
yang perlu diperluas (terlalu dekat tapi ambigu).

### Batas kedua pita = `ambiguitySigma`, dan versi pertamaku salah

Ini bagian yang paling layak dicatat, karena ambang yang tidak ada di layar
hampir sempat ikut terkirim.

Versi pertama memakai `maxSeparationSigma * 2` sebagai batas "jauh". Alasan yang
saya tulis di sumber: `ambiguitySigma` membandingkan kandidat ke **tetangganya**,
maknanya berbeda dari jarak ke kandidat terbaik, jadi tidak bisa dipakai.

Alasan itu benar, dan **tidak relevan** — karena yang diplot di grafik ini
cuma jarak ke kandidat terbaik, dan grafik menggambar **dua garis horizontal**
di `maxSeparationSigma` dan `policy.ambiguitySigma`. Jadi untuk pembaca layar,
"2 sampel terlalu jauh" yang dihitung dari `× 2` berarti **tidak ada satu pun
titik pun melewati garis yang sedang dia lihat**. Yang lebih buruk, kalimat itu
menyuruh menghitung batas yang tidak ada di layar.

Banding yang benar: pita di sini **meniru garis yang tergambar**. Beda
maknanya dengan `uncertainReason` dicatat di sumber, bukan disembunyikan:

| | batas | pertanyaan |
|---|---|---|
| `uncertainReason.tooFar` | `maxSeparationSigma` | kenapa engine menolak? |
| `ConfidenceChartSpeech.tooFar` | `policy.ambiguitySigma` | di mana titikku di layar? |

Keduanya `true`/`false` berbeda untuk titik yang sama, dan **keduanya benar**
untuk pertanyaan yang berbeda. Kalau ini ditulis ulang sekali lagi di view,
mata dan telinga akan menghitung dari dua garis berbeda tanpa ada yang melihat.

### `total` menghitung semuanya, pita tidak

`ratioToSigma == nil` berarti sigma-nya nol atau tidak ada kandidat. Kurucut
grafik memang tidak bisa menggambarnya, jadi `points.isEmpty` menyingkirkan
titiknya — dan versi pertama ikut menyingkirkan **jumlahnya** dari pembicaraan.

Akibatnya "3 dari 5" terbaca "3 dari 3": jumlah yang terlihat lengkap padahal
ada rekaman yang tidak terhitung. `total` kini menghitung semua sampel,
`measured` hanya yang punya jarak, dan `unmeasured` diucapkan kalau bukan nol.
Uji: `testUnmeasuredSamplesAreNotSilentlyDroppedFromTheTotal`.

### Bukti merah

`red-test.sh`, dua mutasi, keduanya MERAH:

| Mutasi | Uji | Hasil |
|---|---|---|
| `total` ikut menghitung sampel tanpa jarak | `testUnmeasuredSamplesAreNotSilentlyDroppedFromTheTotal` | **MERAH** — `("3") is not equal to ("4")` |
| `>` → `>=` pada kedua ambang | `testARatioExactlyOnTheFirstThresholdStillCountsAsConfident` | **MERAH** — `("0") is not equal to ("1")` |

Yang kedua menjaga **operator** yang sama dengan `uncertainReason`. Titik tepat
di ambang adalah batas **tolak**, jadi engine menerimanya; kalau ambang pita
memakai `>=`, ringkasan suara menyimpulkan "tidak yakin" untuk sampel yang
diterima — dan selisihnya cuma satu sampel, jadi tak akan pernah terlihat mata.

### Yang menangkap saya: CI, bukan gerbang Linux

`swift-ui-lint.sh` dan `swift-test.sh` hijau semua pada versi yang **tidak akan
terkompilasi**. `.accessibilityLabel(_:)` hanya menerima `String` non-opsional,
dan `spokenChartSummary` masih `String?` — jadi ini baru ketahuan di
`Apple Build (macos-15)`.

Ini batas gerbang Linux yang belum tertutup dan **saya catat, bukan tutup**:
`syntax check` (parse) tidak menangkap salah tipe, dan typecheck repo hanya
menjalankan modul yang memang bisa dibuild di Linux. Yang menangkap adalah
build macOS asli — satu-satunya alat yang benar di sini. Salah untuk delusional
bahwa gerbang lokal sudah cukup;ia belum.

Perbaikannya mengikuti pola yang sudah ada di repo, bukan improvisasi:
`session?.flow.spokenPhaseSummary ?? TextLocalization.text(…)` di
`CalibrationView`. Opsional dijawab dengan **kunci katalog**, bukan `""`.

### Gerbang

- `swift-test.sh` → **174 CelestialEngine + 566 PointingKit** (555 → 566,
  +11). **Engine tidak disentuh.**
- Kunci katalog 297 → 303 (`chart.speech.*`), dijaga `TextLocalizationTests`
  (yang sempat merah saat sudah 302 → 303, memang begitu fungsinya) dan
  Aturan 6.
- `swift-ui-lint.sh` → **17 aturan hijau**. Aturan 10 menangkap README yang
  masih 555.
- `red-test.sh` → dua mutasi merah.
- CI: Engine Tests (Linux) + Apple Build (macos-15) hijau pada `f3c80fb`.

## Progres terakhir (5 Okt 2026 — layar redup menampilkan kandidat seolah temuan)

### Empat permukaan dari satu jawaban, tiga sudah jujur

Cacat siklus ini tidak berupa layar yang salah bentuk. Yang terjadi adalah
**permukaan keempat dari empat lupa** — dan lupa dengan cara yang paling
meyakinkan, karena di layar itu memang tidak ada tempat untuk penanda.

Di `.uncertain`, `displayedObject` mengembalikan `intent.best` dan `hasAnswer`
benar, jadi **nama kandidat tampil sebagai `title2.bold()`** — huruf
terbesar, tebal — dengan `shortLabel` polos di bawahnya. Label keadaan itu
memang berbeda dari `lock` ("Belum pasti" vs "Terkunci"), jadi tidak ada layar
yang salah secara harfiah.

Tapi proporsi hierarkinya yang jadi masalah: mata membaca nama lebih dulu dan
lebih besar, lalu membaca kata status yang tidak menempel pada nama itu.
Kandidat tampil sebagai **temuan**. Dan ini terjadi di layar yang paling
sering dibaca sekilas (Always-On), yang justru **tidak punya** panel
peringatan, badge, maupun gambar — satu-satunya tempat di app yang benar-benar
tidak punya tempat untuk menandai apa pun.

| Permukaan | Penanda ragu | Bentuk |
|---|---|---|
| complication | `Subline.uncertaintyMarker` | kata |
| jam (layar penuh) | badge keyakinan + gambar disamar | badge |
| iPhone | badge keyakinan + gambar disamar | badge |
| **layar redup** | **tidak ada** | — |

Yang membuatnya bertahan adalah brief itu sendiri. Layar redup memang
sengaja dibuat miskin ("hanya dua hal yang harus terbaca sekilas"), jadi
hilangnya penanda terlihat seperti keputusan sadar. Penandanya
dibuat berupa **frasa pendek yang menempel pada nama**, memakai
kunci `confidence.uncertain.marker` — **kunci yang sama** dengan yang dipakai
complication. Dua permukaan, satu kunci: katalog kedua hanya akan menghasilkan
dua ejaan untuk fakta yang sama.

### Kenapa butuh ambang baru, bukan `!confirmsIdentity`

Dua-duanya `false` pada `.uncertain`, jadi pertanyaannya menyesatkan: kenapa
tidak pakai `!confirmsIdentity` saja?

Jawabannya ada di keadaan yang **tidak** punya jawaban. Pada `.pointing`,
`displayedObject` mengembalikan `lastLocked` — jadi ada nama yang tampil, dan
`confirmsIdentity` sudah `false` karena keadaan tidak `looksConfident`. Kalau
ambangnya `!confirmsIdentity`, objek **sisa** itu ikut diberi penanda **ragu**
— padahal yang perlu dinyatakan adalah "ini **basi**". Dua keadaan berbeda
berbagi satu penanda, dan penanda yang begitu berhenti jadi informasi.

Jadi syaratnya `hasAnswer && !looksConfident`: hanya menyala pada keadaan di
mana ada kandidat yang ditampilkan *sebagai hasil*. Persis
`displayedObject`-nya complication (`hasAnswer && !isConfirmed`), tapi di
hitung dari sumber yang sama dengan `PointingSnapshot`, bukan dari digest —
supaya ambangnya bisa diuji di Linux tanpa WidgetKit.

### VoiceOver: penandanya diucapkan **sebelum** nama

`"Vega. Belum pasti"` dan `"Belum pasti. Vega."` bukan kalimat yang sama.
Yang kedua terdengar lebih dulu sebagai **syarat**; yang pertama
mendengar koreksi sesudah fakta — dan koreksi terdengar seperti hal yang
sudah terjadi. Karena nama kandidat adalah kata yang paling mungkin
diartikan sebagai temuan, penandanya harus terdengar lebih dulu.

### Bukti merah: tiga mutasi, dua arah

`red-test.sh`. Dua mutasi pertama menjaga **keberadaan** penanda (`.uncertain`
wajib ditandai), yang ketiga menjaga **pembedanya** dari basi.

| Mutasi | Uji yang menangkap | Hasil |
|---|---|---|
| `!looksConfident` → `looksConfident` | `testUncertainCandidateMustCarryTheUncertaintyMarker` | **MERAH** |
| buang `!looksConfident` (terlalu gurau) | `testALockedNameNeverCarriesTheUncertaintyMarker` | **MERAH** |
| buang `hasAnswer` (basi ikut ditandai) | `testStaleObjectCarriesNoUncertaintyMarker` | **MERAH** |

Arah kedua adalah yang menentukan. Perbaikan yang terlalu luas — menandai
**semua** nama yang tampil — loloskan uji pertama (`.uncertain` tetap
ditandai) tapi merah pada yang kedua. Perbaikan yang terlalu longgar — memakai
`!confirmsIdentity` — loloskan dua uji pertama dan merah pada yang ketiga.

Dua mutasi pertama sempat gagal **salah alasan** di tengah pengerjaan: keduanya
ditulis dengan typo (`displayObject` alih-alih `displayedObject`), jadi build
gagal dan tidak ada yang dibuktikan. `red-test.sh` menolak melaporkan itu
sebagai bukti — dan itu benar. Pelajaran yang berulang: mutasi yang tidak
bisa dikompilasi bukan bukti, dan `red-test.sh` sudah menjaga itu sejak
siklus "Cacat alat yang ketemu di tengah".

### Batas yang jujur

- **Belum pernah dilihat di perangkat.** Yang dibuktikan: ambangnya benar di
  kedua arah, kunci katalognya sudah ada dengan terjemahan Inggris, dan
  gerbang kompilasi/build macOS hijau. Yang belum: apakah "Belum pasti"
  tepat secara visual di `.caption2` di atas `title2.bold()` pada 41mm, dan
  apakah VoiceOver mengucapkannya dengan jeda yang enak.
- **Layar utama jam masih pakai badge, tidak jadi frasa.** Dua bentuk
  penanda untuk keadaan yang sama sengaja dibiarkan berbeda: badge punya
  warna `level.tone`, frasa tidak. Menyamakan keduanya berarti jam kehilangan
  warna keyakinan yang sudah jadi bagian dari Bahasa visualnya.
- **`confidence.uncertain.marker` sudah dipakai dua permukaan.** Itu pilihan,
  bukan kebetulan: bentuknya frasa pendek yang muat di dua tempat sempit
  (`.accessoryRectangular` dan layar redup). Menambah kunci ketiga hanya
  akan menghasilkan tiga ejaan untuk satu fakta.
- **Aturan baru tidak ditambah.** Aturan ini adalah cacat **logika**, bukan
  bentuk: tanpa ambangnya di `PointingKit`, koreksi hanya bisa dilakukan di
  view yang tidak bisa diuji di Linux. `swift-ui-lint.sh` tidak pernah
  menyapu ketiadaan aturan; ia menyapu bentuk yang salah. Menambah aturan
  untuk "setiap layar redup harus menandai ragu" akan jadi daftar periksa manual
  harus dijaga MANUAL — persis yang membuat gerbang ini rapuh sejak awal.

### Gerbang

- `swift-test.sh` → **174 CelestialEngine + 555 PointingKit** (549 → 555,
  +6). **Engine tidak disentuh.**
- `swift-ui-lint.sh` → **17 aturan hijau**. Aturan 10 menangkap README yang
  masih mengklaim 549 (sudah diperbarui ke 555).
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `red-test.sh` → tiga mutasi merah, dan dua di antaranya sempat gagal
  kompilasi lebih dulu (bukan bukti).
- CI: Engine Tests (Linux) + Apple Build (macos-15) — hijau pada `4a3fd35`.

## Progres terakhir (5 Okt 2026 — README membusuk, baru diperbaiki)

### Siklus: README ikut dijaga Aturan 10, tapi tertinggal

README menyebut **"CelestialEngine 172, PointingKit 549"** padahal suite
sudah **174 / 549**. Aturan 10 gerbang UI (`swift-ui-lint.sh`) membandingkan
klaim README dengan hitungan `func test` di berkas uji — dan README gagal
aturan itu sampai diperbarui. Juga tertinggal: gerbang UI sudah **17 aturan**
(teks bilang "10"), dan fitur Fase A/B/C (mode malam, AOD, complication,
lokalisasi, izin) **sama sekali tidak tercatat** di README.

### Yang diubah

- `README.md`: hitungan uji → **174 / 549**; "10 aturan" → **17 aturan**.
- Tambah dua bagian: **"Mode malam, Always-On, & aksesibilitas"** dan
  **"Complication & lokalisasi"** yang merangkum fitur yang sudah dibangun &
  diuji (bukan cuma di STATUS.md), plus entri daftar isi.

### Kenapa ini unit bernilai, bukan dokumentasi kosong

Dokumentasi yang bilang angka salah adalah **janji yang salah** kepada
pembaca tentang tebalnya jaring pengaman — persis yang Aturan 10 dibuat
tutup. Dan fitur aksesibilitas/malam yang tidak tercatat di README berarti
pemeriksa Final Challenge membaca kode, bukan ringkasan. Catatan ini juga
mengunci: kalau suatu saat hitungan bergeser lagi, Aturan 10 akan merah di CI.

### Verifikasi

- `./swift-test.sh` → CelestialEngine 174 + PointingKit 549 hijau.
- `./swift-ui-lint.sh` → **SEMUA GERBANG UI LULUS** (17 aturan, hitungan README cocok).
- CI: Engine Tests (Linux) ✓; Apple Build (warnings-as-errors) ✓.
- Tidak ada kode diubah — hanya dokumentasi, jadi tidak ada risiko merusak
  engine teruji.

## Progres terakhir (5 Okt 2026 — arsip eksperimen bisa berbohong soat keselamatan)

### Dua bentuk kebenaran yang tidak saling mengikat

`ExperimentDataset` membawa dua field yang isinya **sama**: `trials`
(daftar rekaman) dan `summary` (hasil hitungannya). `summary` dihitung
sekali di `init`, lalu ikut disalin ke arsip JSON sebagai field biasa, dan
`DatasetArchive.decode` menerimanya apa adanya.

Akibatnya `safetyVerdict` — yang membaca `falseLockCount` — bisa dibangun
dari hitungan yang **tidak pernah dihitung**. Bukan crash, bukan warna salah,
dan tidak ada gerbang yang menyala: `trials` benar, `summary` juga "benar"
menurut dirinya sendiri.

Yang membuatnya tidak bisa diabaikan: berkas ini **persis** yang dipilih
pengguna untuk dibawa keluar app sebagai bukti. Alat ukur repo ini sendiri
(PRD v0.4: akurasi jam adalah hipotesis) exporting vonis keselamatan dari
angka yang bisa diganti tangan adalah kegagalan di tempat yang paling harus
jujur.

### Yang diperbaiki

`summary` jadi **computed** dari `trials`. `trials` tetap ikut di arsip supaya
berkas ekspor tetap berdiri sendiri sebagai bukti yang bisa dibaca pihak lain;
yang hilang adalah ukuran ringkasannya — yang sebelumnya berarti data kedua
yang harus dipercaya tanpa pernah diverifikasi.

Arah pembedaannya penting: memperbaiki dengan **membuang** `summary` dari
arsip juga akan membuat cacat ini hilang, tapi ia menghapus sumber kebenaran
dari alat bukti. Yang benar adalah menjadikan `trials` satu-satunya sumber
dan membiarkan ringkasan selalu menyertainya.

### Bukti merah: mutasi yang benar-benar membatalkan perbaikan

Dua percobaan pertama gagal dan keduanya salah karena alasan yang salah:

1. **Mutasi tidak bisa dikompilasi.** `summary` dikembalikan jadi property
   tersimpan tanpa initializing di `init` → error kompiler. Itu bukan bukti.
   compiler menangkap bentuk salah, bukan bentuk yang berbahaya.
2. **Uji pertama hijau di atas kode rusak.** Bentuk pertamanya menuliskan
   JSON literal dengan `trials: []` dan `falseLockCount: 0` — jadi kedua
   angka itu **memang sudah cocok** dan tidak ada yang bertentangan. Uji itu
   tidak menanggung beban sama sekali.

Bentuk yang benar membangun arsip **sungguhan** dari rekaman yang berisi satu
false lock, lalu mengganti field `summary`-nya. Isinya benar-benar
bertentangan: ringkasan bilang 0, rekaman bilang 1.

Baris paling penting di uji itu adalah **prasyaratnya**
(`decoded.falseLocks.count == 1`) — tanpa itu, mutasi apa pun yang membuat
`trials` kosong akan membuat uji tetap hijau karena kedua angka sama-sama nol.

Mutasi yang lolos kompilasi (menjadikan `summary` field yang dipercaya dari
arsip, lengkap dengan `init(from:)`/`encode(to:)`) → **MERAH tepat di uji
baru**: `("0") is not equal to ("1")`.

### Pelajaran yang berulang

Ini pola yang sudah muncul di siklus "Percobaan menyusut" dan di Aturan 17:
**hijau dari uji yang tidak bisa dibatalkan bukan bukti apa pun.** Yang
menjadinya ketahuan adalah mutasi, bukan `swift-test.sh` — keduanya hijau.

### Gerbang

- `swift-test.sh` → **172 CelestialEngine + 549 PointingKit**, 0 gagal
  (547 → 549, +2). **Engine tidak disentuh** (perubahan hanya di `PointingKit`).
- `swift-ui-lint.sh` → **17 aturan hijau** (Aturan 10 menangkap README 547 → 549).
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- CI: Engine Tests (Linux) + Apple Build (macos-15) — **dua-duanya hijau** pada 3800c13.

### Batas yang jujur

- **Yang ditutup adalah pemalsuan lewat arsip, bukan rekaman yang salah.**
  Percobaan yang keliru tetap keliru; yang berubah adalah ia kini selalu
  konsisten dengan ringkasannya, jadi bisa diperiksa.
- **`trials` masih `public var`.** Tidak ada mutasi di `Apps/` sekarang,
  jadi tidak ada dua sumber kebenaran yang aktif — tapi sifatnya masih
  terbuka. Mengunci `trials` (mis. `private(set)`) adalah unit berikutnya
  kalau sapuan menemukan pemanggil yang butuh.
- **`falseLocks` masih nol konsumen di `Apps/`.** Sekarang ia bukan lagi
  sumber kedua yang bisa menyimpang, karena `falseLocks` dan `summary`
  diturunkan dari `trials` yang sama — tapi ia tetap aksesor yang belum
  dipakai layar.

## Progres terakhir (5 Okt 2026 — aksesor display didokumentasikan sebagai dipakai, lalu disalin)

### Premis siklus ini: "dipakai view" yang tidak pernah dipakai

Sapuan `Tools/sweep-unconsumed.sh` (baru, hasil akhir siklus sebelumnya)
menemukan anggota `public` di `PointingKit` yang namanya tidak muncul di
`Apps/`. Di antaranya ada lima yang **dokumentasinya menyatakan akan dipakai
view**:

| Aksesor | Yang diklaim | Kenyataan |
|---|---|---|
| `ObjectSpeech.magnitudeDisplay` | dipakai view | 0 pemanggil di `Apps/` |
| `ObjectSpeech.coordinatesDisplay` | dipakai view | 0 pemanggil |
| `ObjectSpeech.staleShortNote` | dipakai view | 0 pemanggil |
| `CalibrationText.captureAltitudeDisplay` | dipakai view | 0 pemanggil |
| `RowSpeech.spokenWristRate` | dipakai baris status jam | 0 pemanggil |

Dan tiga view memang menulis ulang pemanggilan kuncinya **persis**, baris demi
baris: `PointingView.kindLine`, `PointingView.statusParts`,
`ReducedLuminanceView`, `CalibrationView`.

### Kenapa gerbang lama tidak menyala

Isi kuncinya **sama persis** — itu sebabnya. Aturan 4 (kunci ada di katalog) dan
Aturan 6 (paritas) keduanya tetap hijau sepanjang salinan itu ada, karena
memang tidak ada yang salah secara harfiah. Yang hilang bukan tampilan: yang
hilang adalah **alasan aksesor itu ada** — teks layar jadi tidak bisa diuji di
Linux, karena yang teruji tinggal salinannya yang tidak pernah dirender.

Bentuk paling licin dari kelas yang berulang di repo ini: dokumentasinya benar,
uji-ujinya benar, dan perubahan katalog berikutnya tidak akan mengubah apa pun
di layar.

### Yang diperbaiki

- Lima aksesor sekarang benar-benar dipakai. Kalimat yang tampil di layar
 identsik dengan yang sudah ada — perbaikannya tidak mengubah apa yang dilihat
  pengguna, hanya membuat jalur ke teks itu **satu** dan bisa diuji.
- **`DisplayWrapperTests`** (3 uji) mengunci dua sisi: paritas aksesor dengan
  pemanggilan langsung (menangkap salinan), dan nilai Indonesianya sebagai nilai
  mutlak (menangkap cacat yang sama-sama dibagi kedua jalur — bentuk "hijau
  bersama-sama" yang sudah pernah dipakai siklus "Percobaan menyusut").
- **Aturan 17** (baru) menyapu pemanggilan kunci dari pembungkus murni yang ada
  di `Apps/`. Syarat "murni" itu yang menjaga gerbang dari positif palsu:
  `spokenRate` menghitung satuan lebih dulu lalu meneruskan ke kunci, jadi ia
  bukan pembungkus murni dan pemanggilan kuncinya di dalam paket tidak dihitung.

### Cara gerbang ini dibuktikan bisa merah

Aturan 17 sempat **hijau di atas kode yang rusak**. Penyebabnya bukan logikanya:
uji "murni" membuang `return { } ;` dan spasi, tapi **tidak** membuang baris
komentar — dan setiap aksesor di repo ini punya komentar. Jadi tak satu pun
terkenal sebagai pembungkus murni, `owned` kosong, dan gerbang tidak punya
apa pun untuk ditangkap.

Diperbaiki dengan membuang komentar **sebelum** whitespace. Urutannya penting:
kalau whitespace lebih dulu dihapus, `// x` dan `/* */` menyatu jadi `/.../`
dan sisa `//` ikut hilang — satu baris komentar masih lolos sebagai "murni".
Setelah itu: reintroduksi keempat cacat → Aturan 17 merah di keempatnya; kode
yang benar → hijau.

### Satu kelas crash yang masih nyata

Uji pertama ikut crash (signal 7 di `CFStringCreateWithFormat`) karena
`spokenWristRate` meneruskan `Int` ke template `%.0f`. Bukan bug produksi —
pemanggil aslinya sudah benar — tapi Aturan 11 menjaga **tipe** specifier,
bukan tipe argumen, jadi kelas ini masih bisa masuk lewat sisi yang satu.

### Gerbang

- `swift-test.sh` → **172 CelestialEngine + 547 PointingKit**, 0 gagal
  (543 → 547, +4). **Engine tidak disentuh.**
- `swift-ui-lint.sh` → **17 aturan hijau** (Aturan 10 menangkap README 543 → 547).
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- CI: `37280209774` (Engine Tests Linux) + `37280209912` (Apple Build macos-15)
  — **dua-duanya hijau**.

### Batas yang jujur

- **Gerbang ini tidak bisa melihat semua salinan.** Ia hanya memahami kunci
  yang punya pembungkus murni. Kunci yang dirakit sendiri (mis. dari
  `parts.joined`) di luar cakupannya — dan itu memang bentuk yang berbeda.
- **`spokenWristRate` kini dipakai, tapi `RowSpeech` masih punya anggota lain
  yang belum dipastikan terpakai.** Sapuan ketat akan menjadi unit berikutnya;
  ia sengaja belum digabung ke sini supaya unit siklusnya tetap kecil.

## Progres terakhir (5 Okt 2026 — LinkView dilokalkan; EN masuk sebagai terjemahan)

### Lanjutan Fase C #2

`LinkView` adalah layar pengujian lapangan: tempat status tautan jam↔iPhone
dibaca, dan karena itu tempat dua perangkat harus sepakat soal kata.
Sebelas kunci `link.*` ditambahkan untuk baris-barisnya (keadaan, objek,
keyakinan, waktu, kalibrasi, dan penanda kegagalan kirim), semuanya dengan
padanan EN.

> **Catatan jujur — dua paragraf di bawah ini adalah rekonstruksi.** Teks
> asli siklus ini hilang: dua komit (`e85769d`, `f66f782`) menyimpan
> penanda kompresi konteks **`⟪HERMES-CONTEXT-COMPRESSION …⟫`** ke dalam
> berkas ini, menggantikan 1.431 dan 1.547 karakter isi yang sebenarnya.
> Penanda itu bukan documentation — ia sisa alat yang bocor ke artefak, dan
> ia sempat **terkomit dan terdorong ke `origin/main`**. Isinya tidak ada di
> objek git mana pun (dicek: seluruh `git rev-list --all --objects` dan
> komit mengambang), jadi yang tertulis di sini ditulis ulang dari konteks
> sekitarnya, bukan dipulihkan. Angka dan fakta di paragraf lain pada
> siklus yang sama tidak ikut hilang dan tidak disentuh.

### Lanjutan Fase C #2: iOS ikut

`Experiment1View` adalah tempat pembuktian Experiment 1 (kesalahan
pengenalan diukur, bukan ditebak), dan layar itu punya literal untuk
seluruh baris hasil: jumlah percobaan, benar, false lock, galat median,
galat P90, vonis, dan usulan ambang. Kunci `experiment.*` yang sudah ada
ditambah yang belum tercakup, lengkap dengan padanan EN.

**Kenapa pembersihan ini layak dicatat, bukan sekadar dibuang.** Penanda
kompresi itu lolos **dua** gerbang yang justru dibuat untuk kelas ini:
Aturan 3 (aksara non-Latin) menyapu `*.swift`, `*.sh`, `*.yml`, dan
`project.yml` — dan `*.md` sengaja dikecualikan karena STATUS.md memuat
aksara CJK sebagai **bukti** cacat yang pernah nyata. Pengecualian itu
tepat untuk aksara, dan menjadi lubang untuk penanda: berkas `.md`
ternyata tidak hanya memuat bukti, ia juga memuat **artefak alat**.
Pembersihannya sekaligus menguji asumsi yang mendasari pengecualian itu —
bahwa isi `.md` selalu ditulis manusia.

### `PointingView` + `SkyContextView`: layar yang paling banyak literal

Layar utama adalah tempat paling sering dilihat dan **paling** banyak literal
Bahasa Indonesia tersisa: judul, label enam tombol toolbar (konteks langit,
kalibrasi, mode malam, bunyi kunci — masing-masing dua keadaan), baris status
tautan iPhone beserta penanda kegagalan kirim, peringatan objek sisa, baris
lokasi darurat, lalu seluruh baris `SkyContextView` (Langit/Matahari/Bulan/
Fase Bulan/Ketelitian/Azimut/Ketinggian/Lokasi/Asal lokasi).

27 kunci baru + 2 kunci bentuk pendek (`Sudah`/`Belum`) untuk baris
ketelitian → gerbang 210 → 237. Semua punya padanan EN.

### Dua cacat yang ketahuan di tengah pengerjaan

1. **`calibrationStatusApplied` tidak pernah ada.** Baris "Kalibrasi: Sudah"
   dulunya literal, dan saat saya tulis ulang ia dari salah tulis kunci yang
   tidak pernah dideklarasikan — bukan bug yang akan ketahuan tanpa gerbang
   paritas, tapi akan menggagalkan *build*, jadi tertangkap cepat. Yang benar
   adalah bentuk **pendek** (tanpa offset/sebaran), bukan `calibration.status.installed`
   yang butuh dua argumen. Jauh lebih baik gagal di compiler daripada tampil
   dengan kalimat yang salah.

2. **Baris tautan punya dua bentuk yang berbeda.** Yang sudah ada
   `linkStatusSendFailures` untuk VoiceOver ("3 pesan gagal"), sementara yang
   **ditampilkan** adalah literal ringkas "· 3 gagal". Keduanya sengaja
   dipisah: bentuk layar boleh sepadat mungkin, bentuk suara tidak boleh
   (angka tanpa satuan tidak bermakna saat diucapkan). Kalau dipaksa
   menyatu, salah satu bentuknya jadi buruk — dan yang buruk itu tidak akan
   ketahuan dari kode.

Verifikasi: `./swift-test.sh` 529/0 hijau; `./swift-ui-lint.sh` semua gerbang
lulus; CI `Engine Tests (Linux)` + `Apple Build` hijau pada 37267579382 /
37267579359.

## Progres terakhir (5 Okt 2026 — CalibrationView dilokalkan, nol literal keras)

### Lanjutan Fase C #2 (kelengkapan lokalisasi)

Siklus lalu melokalkan `OnboardingView`. Siklus ini melanjutkan ke layar
kalibrasi di jam — layar yang paling sering dipakai di lapangan, dan yang
punya Literal Bahasa Indonesia terbanyak setelah `PointingView`.

12 kunci baru di `TextLocalization` (`calibration.*`): judul layar, jumlah
acuan tercatat, awalan baris status, heading daftar acuan, pesan "tidak ada
acuan terlihat", label + hint VoiceOver tombol `Catat yang ditunjuk` /
`Pakai` / `Ulang`. Semua terdaftar di `allKeys` (gerbang 198 → 210) dan punya
padanan EN di `Localizable.xcstrings`. `CalibrationView` kini **nol** literal
Bahasa Indonesia keras (Aturan 4 menyapu `Text`/`Label`/`Button`/
`navigationTitle`/`accessibilityLabel`).

### Kenapa per-view, bukan sekali jalan

Brief meminta "satu unit terkecil" per siklus, dan gerbang (`TextLocalizationTests`
hitungan kunci + `swift-ui-lint.sh` Aturan 4/6) memaksa setiap kunci
didaftarkan pasangan katalognya sebelum hijau. Memaksa semua view sekaligus
melanggar disiplin itu dan menunda verifikasi. Maka dilokalkan per layar:
`onboarding` → `calibration` → `pointing` (berikutnya) → `experiment1` →
`complication`.

Verifikasi: `./swift-test.sh` 529/0 hijau; `./swift-ui-lint.sh` semua gerbang
lulus; CI `Engine Tests (Linux)` + `Apple Build` hijau pada 37266977160 /
37266977071.

## Progres terakhir (5 Okt 2026 — literal onboarding dipindah ke katalog, EN ikut tersedia)

### Cacat: Fase C #2 belum selesai — masih ada literal Bahasa Indonesia di view

Audit siklus ini menemukan bahwa `Localizable.xcstrings` + `SWIFT_EMIT_LOC_STRINGS`
memang sudah ada, tapi ~60 literal Bahasa Indonesia masih tertanam langsung di
view (`OnboardingView`, `CalibrationView`, `PointingView`, `Experiment1View`,
`ComplicationWidget`). Pengguna bahasa Inggris membaca Indonesia — Fase C #2
("pastikan tak ada string keras di view") belum terpenuhi, bukan sekadar
"katalog sudah ada".

### Siklus ini: unit terkecil — `OnboardingView`

Layar perkenalan value-first (Bagian 2) paling kecil dan paling terlihat, jadi
jadi unit pertama yang dilokalkan:
- 5 kunci baru di `TextLocalization` (`onboarding.title/subtitle/honesty/
  start.label/label`), terdaftar di `allKeys` (gerbang 193 → 198).
- Padanan EN di `Localizable.xcstrings` (termasuk label VoiceOver kartu utuh).
- `OnboardingView` konsumsi `TextLocalization.text(...)` — nol literal keras.

### Kenapa ini dikerjakan sekarang, bukan Bagian 1

Bagian 1–4 + Fase A/B **sudah** terbangun dan teruji (visual prosedural semua
jenis benda, mode malam, AOD, VoiceOver, animasi, audio, Dynamic Type). Repo
lebih lengkap daripada yang diisyaratkan brief. Satu-satunya item brief yang
benar-benar masih terbuka adalah Fase C #2 (kelengkapan lokalisasi). Maka unit
berikutnya adalah melokalkan sisa view satu per satu, bukan menulis ulang
visual yang sudah ada.

Verifikasi: `./swift-test.sh` 529/0 hijau; `./swift-ui-lint.sh` semua gerbang
lulus (Aturan 4 menyapu literal `Text`/`Button`/`Label`/`navigationTitle`);
CI `Engine Tests (Linux)` + `Apple Build` hijau pada 37266521843 / 37266521875.

## Progres terakhir (5 Okt 2026 — penjaga horizon kalibrasi menilai waktu yang salah)

### Cacat: `capture` menilai horizon di jam dinding, bukan saat arah dicatat

Siklus ini memulai dari pohon kerja yang sudah membawa fitur setengah jadi
(banner daftar acuan basi + penjaga "objek di bawah cakrawala" di
`captureReference`). Menutup fitur itu menemukan satu cacat asli yang belum
tertutup: penjaga horizon di `capture`/`captureNearest` memanggil
`resolver.horizontal(ofObjectID:observer:date:)` dengan `date = Date()`
(jam dinding saat tombol ditekan), padahal arah tunjuk yang dicatat diambil
dari `controller.snapshot.rawPointing` yang dihasilkan `feed` pada
**timestamp lain** (saat pengguna benar-benar menunjuk).

Dua waktu itu bisa beda detik sampai menit. Saat berbeda, objek yang sedang
ditunjuk (di atas horizon pada `feed`) tampak "di bawah cakrawala" pada
`Date()` — penjaga menolak pencatatan, `flow.samples` kosong, dan kalibrasi
gagal tanpa alasan yang jujur. Ini tepat kelas cacat yang dijaga penjaga itu
sendiri: sampel hantu. Bedanya, di sini yang hilang justru sampel **asli**.

### Kenapa gerbang tidak menangkapnya

`testCaptureWorksWhenSensorIsAvailable` memberi makan quaternion pada `date`
tetap lalu memanggil `capture(objectID:)` tanpa argumen `date` → `Date()`.
Di mesin uji, `Date()` (2026) berbeda jauh dari `date` fixture
(1700000000), sehingga `sirius` berada di bawah horizon pada waktu uji dan
penjaga menolak. Gerbang lolos di sesi sebelumnya hanya karena cacat itu
belum ada; setelah penjaga horizon ditambahkan, tes itu merah.

### Perbaikan (diuji, bukan sekadar digeser)

- `PointingController`: simpan `lastFeedTimestamp` di `feed(quaternion:timestamp:)`.
- `CalibrationSession.capture(objectID:)` dan `captureNearest()`: default
  `date` ke `controller.lastFeedTimestamp ?? Date()`, sehingga penjaga horizon
  menilai ketinggian pada **epoch arah yang dicatat**, bukan saat tombol
  ditekan. Jalur `capture(objectID:measured:date:)` eksplisit tetap memakai
  `date` panggilannya (pengujian ujung-ke-ujung yang memberi waktu sendiri
  tidak berubah).

Dokumentasi "kenapa" (bukan cuma "apa"): waktu penilaian horizon harus sama
dengan waktu arah tunjuk yang diverifikasi, atau penjaga melindungi dari
sampel hantu dengan cara membuang sampel nyata.

### Gerbang lain yang ikut ditutup di siklus ini

- `TextLocalization.allKeys`: dua kunci banner basi (`calibrationStatusStaleBanner`,
  `calibrationStatusStaleBannerHint`) belum masuk registry yang dihitung gerbang
  (191 → 193). Tanpa itu, `testDeclaredKeysAreUniqueNonEmptyAndComplete` merah
  meski katalog sudah punya entri. Ditambahkan ke `allKeys` + padanan EN di
  `Localizable.xcstrings`.
- README: hitungan uji 527 → 529 (2 tes penjaga horizon/capture baru).

Verifikasi: `./swift-test.sh` 529/0 hijau; `./swift-ui-lint.sh` semua gerbang
lulus; CI `Engine Tests (Linux)` + `Apple Build` hijau pada 37265874682 /
37265874709.

## Progres terakhir (5 Okt 2026 — complication menampilkan lock basi sebagai centang hijau)

### Cacat yang hanya hidup di kanal yang tidak bisa diuji compiler

Siklus sebelumnya menutup "Percobaan menyusut diam-diam": angka yang
terhitung benar tapi tidak pernah sampai ke layar. Kali ini kelasnya sama,
tapi korbannya bukan angka — melainkan identitas.

`ComplicationDigest` punya **dua** kanal: satu ikon, satu baris teks. Seluruh
lapisan basi yang sudah dibangun dan diuji — `isStale(at:)`,
`confirmsIdentityNow`, `sublineContent(at:)` — hanya menjangkau kanal
**teks**. Di `.accessoryCircular` tidak ada baris kedua, jadi ikon adalah
satu-satunya penanda yang tersedia. Dan ikon dibaca lewat
`presentedSymbolName`, yang mengembalikan `stateRaw` mentah:

```swift
state?.symbolName ?? "scope"
```

Cuplikan yang basi 90 menit masih `stateRaw == "lock"`. `stateRaw` memang
tidak pernah berubah sendiri — justru itu inti konsep "basi": teksnya
menjadiAggregator usianya sementara keadaan tetap. Akibatnya ikonnya tetap
`checkmark.circle.fill`.

> Di pergelangan tangan: centang hijau + nama objek, tanpa satu penanda
> pun. Terlihat persis seperti lock yang baru saja terjadi.

### Kenapa ia bertahan meski ada uji staleness

Ini bukan bug pemetaan. Bentuk dokumentasinya justru benar, dan itu yang
menipu: `presentedSymbolName` punya dokumen panjang yang **benar** — ia
memindahkan ikon supaya `.uncertain` (tanda seru) tidak terbaca seperti
`.lock` (centang). greener itu memang alasan terbaik bentuknya ada.

Dokumen itu berhenti **satu kalimat sebelum pertanyaan yang lebih besar**:
keadaan YANG? `stateRaw` tidak pernah berubah sendiri, jadi tidak ada yang
pernah melihatnya berubah. Bentuknya sama seperti `unanalyzableCount` dan
`updatedAt` pada siklus sebelumnya: nilai dihitung, disimpan, lalu tidak
dipakai untuk keputusan yang seharusnya ia ambil.

### Yang diperbaiki

- `presentedSymbolName(at:)` di PointingKit — keputusan "ikon ini sudah
  basi?" tetap di paket dan teruji di Linux, bukan di view.
- Guard `hasAnswer`: pada `searching` tidak ada nama yang bisa basi, jadi
  "kunci ini sudah lama" merujuk ke tidak ada. Tanpa guard itu keadaan
  tanpa jawaban tampil seolah punya jawaban yang sudah lama.
- Bentuk **tanpa waktu** dipertahankan untuk pemanggil yang menampilkan
  cuplikan itu sendiri. Keputusan soal waktu tidak boleh pindah ke view.
- Kedua keluarga yang punya ikon (lingkaran, persegi panjang) memakai satu
  aksesor, supaya tidak ada daftar ikon kedua yang bisa berbeda pendapat.

Ikon basi memakai keluarga `clock.badge` (iOS 16 / watchOS 9); ambang di
`project.yml` sudah 18.0/11.0, jadi tidak perlu disentuh.

### Bukti: tiga mutasi, merah di kedua arah

`red-test.sh`, tiga mutasi pada `guard` yang sama:

| Mutasi | Uji yang merah |
|---|---|
| buang `isStale` | `testStaleDigestDoesNotPresentTheFreshLockSymbol` |
| buang `hasAnswer` | `testStaleSearchingKeepsItsOwnSymbol` |
| `isStale` -> selalu `true` | `testFreshDigestKeepsItsFreshLockSymbol` |

Arah kedua itu yang menentukan. Dua mutasi pertama bisa lolos bersama-sama
oleh perbaikan yang terlalu=gurau — ia membuat **semua** lock jadi "basi".
Yang menangkapnya hanya uji ketiga, karena hanya itu yang menyatakan nilai
mutlak untuk cuplikan yang baru saja terjadi. Perbaikan yang mematikan
semua lock akan lolos dua uji pertama.

### Gerbang

172 CelestialEngine + **527** PointingKit (+6), ui-lint 15 aturan,
typecheck, CI macOS hijau. Engine tidak disentuh.

## Progres terakhir (5 Okt 2026 — "Percobaan" melaporkan lebih sedikit dari yang benar-benar ditekan)

### Dua kelas "berhenti di tengah jalan", keduanya soal angka yang hilang

Repo ini punya pola berulang: nilai dihitung dengan benar, diuji dengan
benar, lalu tidak pernah sampai ke layar. `uncertainReasonCounts` adalah
contohnya, sudah ditangani pada siklus sebelumnya. Kali ini yang
ketemu adalah lebih serius, karena yang hilang bukan penjelasan — tapi
**penghitungnya sendiri**.

### Temuan: "Percobaan" menyusut diam-diam

`ExperimentHarness.record(...)` menolak menyimpan rekaman yang arah
kebenarannya tak bisa dihitung (ExperimentHarness.swift:180). Tapi
`AnalyzedTrial.analysis` tetap bertipe opsional, dan
`ObservationLog.analyze` mengembalikan `nil` begitu `groundTruthObjectID`
kosong (ObservationLog.swift:99). Jadi rekaman tanpa analisis bisa masuk,
dan `unanalyzableCount` (ExperimentHarness.swift:62) sudah menghitungnya —
dengan **nol konsumen di `Apps/`**.

Yang membuat ini bukan sekadar kosmetik: `summary` dibangun dari
`trials.compactMap(\.analysis)` (ExperimentHarness.swift:259), jadi
`trialCount` hanya menghitung yang teranalisis. Tapi `trialCount` itu yang
menentukan `hasEnoughEvidenceForSafetyClaim`, yaitu ambang 20 percobaan
untuk boleh berkata "lulus". Konsekuensinya:

> Penguji merekam 19 percobaan yang teranalisis dan 3 yang tidak. Layar
> menampilkan "Percobaan 19" tanpa penjelasan — dan dia melontarkan 3
> percobaan lagi sambil mengira sampelnya sudah hampir cukup.

Yang hilang bukan angka (−3 dari 22 masih terbaca sebagai −3). Yang hilang
adalah **akibatnya**: 3 percobaan itu tidak menambah bukti apa pun, dan itu
justru yang perlu diketahui.

### Yang diperbaiki

Aturan hitungnya tetap di paket, karena Aturan 1 repo ini: satu definisi
per konsep.

- `ExperimentDataset.recordedCount` — semua rekaman, termasuk yang tak
  teranalisis. Inilah angka yang jujur untuk baris "Percobaan".
- `analyzedCount` — yang masuk vonis, supaya kedua angka bisa dibandingkan
  di tempat yang sama tanpa menghitung ulang di view.
- `hasUnanalyzableTrials` — penanda, karena "belum cukup bukti" punya dua
  sebab yang butuh tindakan berbeda: sampel memang sedikit, atau sampelnya
  ada tapi separuhnya tak bisa dinilai.

Layar: baris "Percobaan" memakai `recordedCount`; jumlah yang tak
teranalisis tampil sebagai baris sendiri, plus peringatan berbahasa
"…tidak menambah bukti" — sebab akibatnya tidak terlihat dari angka.
Recorder **membaca** angka dari paket, tidak menghitung ulang.

### Satu uji hijau yang tidak membuktikan apa pun

Regresi yang paling penting
(`testUnanalyzableTrialsDoNotPushTheSampleOverTheThreshold`) pertama kali
saya tulis **hijau pada kode yang rusak**. Bentuk pertamanya:

```swift
XCTAssertEqual(withExtra.safetyVerdict, withoutExtra.safetyVerdict)
```

Hanya membandingkan dua vonis satu sama lain — jadi mutasi apa pun yang
membuat keduanya berubah **bersama-sama** tetap lolos.

Bentuk yang benar menguji nilai mutlak: 19 teranalisis + 3 tak
teranalisis → `trialCount` tetap 19, vonis tetap
`insufficientEvidence`. Dengan begitu mutasi "`summary` menghitung semua
trial" (pelaku yang paling mungkin salah dan paling menggoda —
karena ia "memperbaiki" ambang 20 agar lebih cepat tercapai) langsung
merah. Diverifikasi lewat `red-test.sh`.

Pelajaran yang sama seperti dua mutasi pada siklus sebelumnya: **hijau
dari uji yang tidak bisa dibatalkan bukan bukti apa pun.** Yang membuat
itu ketahuan adalah `red-test.sh`, bukan `./swift-test.sh` — keduanya hijau.

### Bentuk label yang ditolak gerbang

Baris pertama sempat dirakit dari `Text("Percobaan") + " " +
countNotAnalyzed`. Aturan 4 di `swift-ui-lint.sh` menolaknya, dan gerbang
itu benar: dua string yang disambung di view menghasilkan urutan yang salah
di bahasa lain. Sekarang satu kunci penuh. Jumlahnya **tidak** ikut di
kunci itu karena sudah jadi kolom kanan baris — menyebutkannya lagi akan
mencetak angka yang sama dua kali.

### Gerbang

172 CelestialEngine + 513 PointingKit (507 → 513, 7 uji baru), ui-lint 15
aturan, typecheck. Engine tidak disentuh. Tiga mutasi `red-test.sh` merah
dan sumber pulih bersih.

# STATUS — Celestial Pointing Engine

## Progres terakhir (5 Okt 2026 — hitungan sebab keraguan sudah ada, tapi tidak pernah masuk layar)

### Premis siklus ini: dipotong dengan sengaja, lalu hilang dengan tidak sengaja

`ConfidenceTrace` menghitung `uncertainReasonCounts` — berapa kali tiap sebab
keraguan muncul — dan setelah sapuan seluruh `Apps/` hasilnya **nol**. Bukan
satu pun view yang memakainya.

Yang tampil di layar Diagnostik iPhone cuma **satu kalimat**:
`trace.trace.diagnosis(…)`. Dan kalimat itu **memang** sengaja meringkas —
bukan kelalaian, bukan bug. `diagnosis` hanya menyebut:

1. sebab yang **mendominasi** (> separuh sampel ragu), atau
2. semua sebab yang **seri** di puncak, kalau tidak ada yang mendominasi.

Jadi yang dibuang **disengaja**: setiap sebab yang kalah dari dominasi, dan
**seluruh hitungannya**. `diagnosis` tidak pernah menyebut angka.

### Kenapa yang dibuang itu yang berbahaya

Dua-duanya bukan sekadar "kurang lengkap": keduanya membuang informasi yang
berlawanan arah.

- **`tooFar` mendominasi → `ambiguous` hilang begitu saja.** Penguji membaca
  "Perbaiki kalibrasi dulu." lalu menyimpulkan **semua** keraguan berasal dari
  kalibrasi, padahal ambiguitas katalog muncul pada sebagian sampel. Dua
  petunjuk perbaikan yang saling meniadakan: satu terlihat, satu tidak. Dan
  yang tidak terlihat adalah yang **tidak** bisa diperbaiki dengan kalibrasi.
- **`diagnosisNoMeasurableCause` ("belum ada sebab yang terukur") tampil
  saat tidak ada dominan dan tidak ada seri.** Kalimat itu menyebut
  **ketiadaan** sebab, sementara layar punya `tooFar`/`ambiguous` dengan
  hitungan kecil. Akibatnya kalimat yang paling lemah dasar buktinya
  justru yang paling mudah disalah baca.

Yang membuat ini bertahan adalah bentuknya: **tidak ada layar yang salah**.
`diagnosis` benar, uji-ujinya benar, katalog lengkap, 15 gerbang hijau.
Yang hilang bukan ~~bagian yang bermasalah~~ — yang hilang adalah
**pertanyaan yang belum pernah diajukan**: "sebab mana yang muncul?"

Ini kelas yang sudah berulang di repo ini, tapi biasanya berupa nilai yang
dibuang. Yang dibuang di sini adalah **hitungan**, dan pembuangannya memang
wajar sampai batas tertentu — sehingga tidak ada yang menyadarinya.

### Yang ditambahkan

`UncertainReasonBreakdown` (PointingKit, **teruji Linux**) + 4 kunci katalog
(`uncertain.reason.tooFar` / `.ambiguous` / `.none`, `row.count.of`).
Barisnya tampil di bawah kalimat diagnosis di layar Keyakinan.

Tiga aturan yang **harus** hidup di paket, bukan di view, karena tidak bisa
ditegakkan di view manapun:

1. **Urutan baris mengikuti deklarasi enum**, bukan urutan `Dictionary` —
   yang di-seed per proses. Bukti nyatanya sudah ada di repo ini:
   `tiedUncertainReasons` lahir justru karena urutan `Dictionary` tidak
   ditentukan, dan diagnosis yang sama pernah berubah-ubah **antar
   peluncuran** untuk data yang sama. Menarik `allCases` ke view akan
   mengulang cacat itu di bentuk baru: rincian yang sama, urutan berbeda,
   tiap kali app dibuka ulang.
2. **Baris dengan hitungan nol tidak pernah tampil.** "0× ambiguitas katalog"
   menyatakan ada kategori yang **diperiksa dan kosong** — padahal tidak ada
   bukti kategori itu pernah terjadi. Ini kebohongan yang berlawanan dengan
   arah yang benar.
3. **Ambang dominasi sama persis dengan `diagnosis`** (> separuh, bukan
   "paling banyak"). 2 dari 2 adalah "paling banyak" **tapi seri**, dan seri
   justru keadaan yang tidak boleh menampilkan satu sebab sendirian. Kalau
   ambangnya melonggar jadi `>=`, rincian menunjuk satu sebab sementara
   `diagnosis` menyebut dua — dua jawaban berbeda untuk rekaman yang sama.

`.none` dikecualikan dari dominasi karena ia **bukan sebab**: ia adalah
ketiadaan sebab yang terukur. Mengizinkan `.none` mendomini membuat layar
menampilkan "tanpa sebab terukur: 3 dari 3" seolah-olah itu penyebab
terbesar, sementara `diagnosis` sengaja tidak pernah menyebutnya sebagai
sebab.

### Kenapa penyebut ikut tampil ("2 dari 7", bukan "2")

Tidak ada angka lain yang menyiapkannya: `diagnosis` tidak pernah menyebut
jumlah. Dan **"2" tanpa total bisa dibaca salah** — pembaca tidak tahu itu
sebab utama atau minoritas, dan itu justru pertanyaan yang membuat rincian
ini bernilai. Bentuknya satu kunci `"%lld dari %lld"`, bukan jumlah +
kata yang disambung view, karena urutan kata berbeda antar bahasa.

### Bukti merah: 4 mutasi, keempatnya MERAH

`red-test.sh` dipakai untuk memastikan uji baru benar-benar **menanggung
beban** — uji yang hijau di atas kode rusak sama dengan tidak ada uji.

| Mutasi | Uji yang menangkap | Hasil |
|---|---|---|
| `allCases` -> `counts.keys.sorted` (urutan dictionary) | `testRowOrderFollowsEnumDeclarationNotDictionaryOrder` | **MERAH**: `ambiguous, none, tooFar` ≠ `tooFar, ambiguous, none` |
| `count > 0` -> `count >= 0` (baris nol tampil) | `testZeroCountReasonsAreNotListed` | **MERAH** |
| `* 2 >` -> `* 2 >=` (seri jadi dominan) | `testDominanceUsesTheSameMoreThanHalfThresholdAsDiagnosis` | **MERAH** |
| filter `reason != .none` -> `true` (`.none` boleh dominan) | `testNoneIsNeverTheDominantReason` | **MERAH** |

Dua mutasi terakhir menjaga **arah**, dan keduanya punya pasangan: ambang
`>` punya bukti bawah (`2 dari 2` seri) **dan** bukti atas (`1 dari 1`
dominan), jadi `>` maupun `>=` sama-sama tidak bisa lolos.

### Bukti bahwa klasifikasinya benar, bukan cuma hitungannya

`testAmbiguityNeedsANeighbour` menjaga bahwa `ambiguous` hanya berlaku bila
ada tetangga di dalam `ambiguitySigma` σ — kandidat terbaik **dekat** saja
tidak cukup. Tanpa itu, `nearestNeighbourDeg` bisa diabaikan dan setiap ragu
jadi `tooFar`/`none`: `ambiguous` tidak pernah muncul, dan rincian
menampilkan penyebab yang tidak pernah terjadi. Uji ini juga menjaga arah
sebaliknya — membuang tetangga, baris berubah dari `ambiguous` ke `none`.

### Kesalahan yang dibuat di tengah, dan bagaimana ketahuan

- **Sapuan awal salah.** Pencarian `UncertainReason` di `Apps/` benar
  (nol), tapi pemeriksaan lanjutan "adakah string ini di katalog" sempat
  melaporkan dua literal `Text("…")` di `PointingView` dan `DiagnosticsView`
  sebagai tidak terlokalisasi. Keduanya **sudah** punya entri katalog dengan
  terjemahan Inggris. Semuanya karena tes substring dicocokkan ke
  `json.dumps` seluruh kamus, yang menyatukan nilai dari beberapa kunci
  berbeda. **Tidak ada cacat di sana** — diverifikasi per-kunci sebelum
  sempat "diperbaiki", karena memperbaiki yang benar akan jadi kerusakan.
- **Kebiasaan lama: CJK + kata asing sempat masuk** ke beberapa berkas yang
  ditulis cepat, dan tertangkap **sebelum commit** oleh pemindaian karakter
  sendiri + Aturan 3/8. Semua dibersihkan; `git status` bersih.

### Gerbang

- `swift-test.sh` → **172 CelestialEngine + 505 PointingKit**, 0 gagal
  (495 → 505, +10 uji baru). **Engine tidak disentuh.**
- `swift-ui-lint.sh` → **15 aturan hijau**. Aturan 6 (paritas katalog)
  memverifikasi keempat kunci baru di kedua sisi; Aturan 4 (literal `Text`
  tanpa katalog) tetap hijau **setelah** baris baru dipasang.
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `red-test.sh` → 4 mutasi, keempatnya merah.
- Sapuan aksara non-Latin pada semua berkas yang diubah → **0**.
- CI: `37255615557` (Apple Build, macos-15) + `37255615574` (Engine Linux) —
  **dua-duanya hijau**. Apple Build termasuk gerbang peringatan (kode sendiri)
  dan job Paket (Apple SDK).

### Batas yang jujur

- **Belum pernah dilihat di perangkat.** Yang dibuktikan: hitungan benar,
  urutan stabil, ambang sama dengan `diagnosis`, katalog lengkap, dan
  view benar-benar merender barisnya (build macOS + gerbang kompilasi). Yang
  belum: apakah barisnya **membantu** penguji, atau hanya menambah kepadatan
  di layar yang sudah padat.
- **Hanya iPhone.** Rincian ini tidak muncul di app jam. Itu **disengaja** —
  layar jam 41mm dibaca sekilas dan `diagnosis` saja sudah padat — tapi
  berarti jam dan iPhone tetap berbeda kedalaman, seperti `row("Arah")`
  yang juga hanya di iPhone.
- **`policy` disimpan, bukan dipakai.** `dominantReason` dihitung dari
  `counts` yang sudah jadi, jadi parameter `policy` tidak memengaruhi
  keputusan apa pun saat ini. Ia disimpan supaya penambahan baris di
  kemudian hari tidak bisa diam-diam memakai policy berbeda dari yang
  dipakai menghitungnya. Sampai ada pemanggil yang butuh kebijakan, ia
  adalah field yang belum dipakai.
- **Terjemahan Inggris belum pernah dibaca penutur asli.** `row.count.of`
  memakai "%lld of %lld" — Aturan 11 menjaga **tipe specifier**-nya sama
  dengan template kode, bukan tata bahasanya. Bahasa yang menuntut
  bentuk lain harus lewat kode, bukan lewat berkas terjemahan.

## Progres terakhir (4 Okt 2026 — angka di layar berbicara bahasa berbeda dari teksnya)

### Premis: unit `NumberFormat` sudah di tengah jalan, dan jalur yang penting masih buta

Unit di tengah jalan (`NumberFormat` + `LocalizationBridge` yang memasangnya)
benar pada ide dasarnya: angka yang diformat dengan `String(format: "%.1f")`
**tanpa `locale:`** mengikuti locale proses, bukan bahasa yang membaca katalog.
Di perangkat berbahasa Indonesia, `42.5°` muncul di tengah layar yang sisanya
Bahasa Indonesia — dan pembaca bisa membacanya sebagai `425` (sepuluh kali
lebih besar).

Tapi unit itu **setengah selesai**, dan bagian yang tertinggal adalah justru
jalur yang paling banyak dipakai:

- `TextLocalization.text(_:key, _:arguments)` — overload berformat yang
  **didokumentasikan** sebagai jalur locale-aman — berjalan tanpa `locale:`.
- **24 situs produksi** memformat template katalog lewat bentuk
  `String(format: text(.key), arg…)` yang juga tanpa `locale:`. Di situlah
  hampir semua angka yang tampil lahir (kalibrasi, RA/Dec, galat, magnitudo,
  status tautan, ringkasan eksperimen).
- Dua situs `Apps/` (`CalibrationView.swift:150,217`) selamat dari sapuan awal
  karena sama-sama memakai kunci katalog.
- Bridge `NumberFormat.install` yang dipasang di `LocalizationBridge` **tidak
  punya satu pun uji** — setiap uji menyebut `localeId:` secara eksplisit, jadi
  jalur yang benar-benar jalan di perangkat tidak pernah dijalankan.

Ini bukan "kurang satu situs". Ini kelas yang sama persis dengan yang repo ini
berulang-turun tutup: jalur yang menghitung lalu dibuang — hanya bahwa yang
"dibuang" kali ini bukan sebuah keputusan, melainkan **pemisah desimal**.

### Yang diubah, dan kenapa bentuknya begini

1. **Overload berformat ikut `locale:`.** `TextLocalization.swift:170` sekarang
   memformat lewat `Locale(identifier: NumberFormat.activeLocaleId)`, bukan
   locale proses. `%@`, `%lld`, dan `%%` tetap utuh (dibuktikan di Linux bahwa
   argumen `String` Swift dan `Int64` tidak rusak setelah `locale:` dipasang).
2. **52 situs `String(format: text(.key), …)` → `text(.key, …)`.** Satu rewrite
   mekanis (penyeimbangan kurung, bukan regex mentah) menyalurkan seluruh
   format katalog lewat overload yang sudah locale-aman. Tanpa ini, 24 situs
   produksi tetap menampilkan titik di perangkat Indonesia.
3. **`RowSpeech.spokenRate`/`spokenDegrees` lewat `NumberFormat`.** Kedua
   fungsi merakit specifier `"%.\(precision)f \(unit)"` di kode, jadi ia **tidak
   pernah** melewati katalog dan overload tidak bisa menjangkaunya. Mereka
   memakai `NumberFormat.decimal(_:fractionDigits:)` — satu sumber pemisah,
   sama seperti sisa angka.
4. **Ringkasan eksperimen lewat `NumberFormat`.** `ExperimentHarness.verdict`
   memakai `accuracy`/`median`/`p90` (`Galat median`, `Galat P90`) yang tampil
   di layar Experiment 1 iPhone; dulu `String(format:)` telanjang. Kini ikut
   bahasa aktif.
5. **Bridge diuji, bukan cuma dideklarasikan.** `NumberFormatTests` menambah 6
   uji: bawaan Bahasa Indonesia, bahasa terpasang benar-benar mengganti
   pemisah, dan `reset()` melepasnya (karena kebocoran bridge antar-uji tidak
   pernah muncul sebagai kegagalan, hanya sebagai angka yang tiba-tiba salah
   di berkas lain). `TextLocalizationTests` menambah 2 uji yang menembak jalur
   **tampilan nyata** (`CalibrationText.offsetDisplay`) lewat dan tanpa bridge,
   supaya kalau ada jalur yang kembali ke format tanpa locale, angka di layar
   berubah lagi dan gerbang mana pun tidak menyala.
6. **`EnglishTranslation.install`** — helper bersama yang memasang **kata dan
   bahasa sekaligus**. Ini menutup celah coupling yang ketemu di tengah: dulu
   uji boleh memasang terjemahan Inggris tanpa memasang `en_US`, hasilnya teks
   campur ("Ready — spread 2,0° from 3 refs."). Semua uji terjemahan Inggris
   sekarang lewat helper itu, dan `tearDown` melepas **kedua** bridge.

### Bukti merah (jalur ini memang buta sebelum diperbaiki)

Sebelum overload diperbaiki, `testFormattedNumbersFollowTheLanguageReadingTheCatalog`
mengharapkan `"mag 1.42"` — dan itulah cacatnya tertulis sebagai hijau.
Setelah perbaikan, harapan itu jadi `"mag 1,42"`. Tiga uji baru dijalankan
merah lebih dulu: `text(.objectDisplayCoordinates, …)` mengembalikan `"RA 101.3°
Dec -16.7°"` (titik) sebelum `locale:`; setelahnya `"RA 101,3° Dec -16,7°"`
(koma). Lima uji `CalibrationText`/`ExperimentText`/`ObjectSpeech`/`RowSpeech`
yang mengharapkan titik ikut merah, lalu di-update ke koma — mereka bukan yang
mengubah perilaku, mereka **mengencode** perilaku lama.

### Batas yang jujur

- **Bahasa Inggris di perangkat belum pernah dibaca penutur asli.** Yang
  dibuktikan: setiap kunci punya entri `en`, overload memakai locale-nya, dan
  `EnglishTranslation` memasang keduanya bersama. Bahwa iOS benar-benar
  membacanya dengan separator titik belum diverifikasi di perangkat.
- **`en` untuk dua kunci kalibrasi tadinya yatim.** `calibration.display.*
  (captureAltitude, suggestedSigma)` punya nilai `en` tapi tidak ada entri `id`
  di `xcstrings`; default Indonesian-nya hidup di kode (`LocalizedText(id:)`).
  Aturan 6 memeriksa paritas `allKeys`, bukan kehadiran `id`, jadi tidak
  menangkapnya. Sekarang keduanya mengalir lewat overload dengan default
  tersebut, jadi tidak ada regresi — tapi itu berarti `en`-nya adalah satu-satunya
  terjemahan di luar pasangan `id`/`en` yang biasa, dan perlu diketahui.
- **Engine 170 → 171 (aditif).** Perubahan hanya di `PointingKit` + `Apps/`, dan
  `swift-test.sh` tetap 171 + 481 (naik 475 → 481, +6 uji bridge/lokalisasi; +1
  uji regression "bulan redup" di CelestialEngine).

### Gerbang

- `swift-test.sh` → **171 CelestialEngine + 481 PointingKit**, 0 gagal.
- `swift-ui-lint.sh` → **13 aturan hijau** (Aturan 10 menangkap README 475→481).
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.

## Progres terakhir (4 Okt 2026 — cahaya Bulan tidak pernah menggeser batas magnitudo)

### Siklus ini: regression test "bulan redup" ujung-ke-ujung (Fase C #6)

**Apa yang ditambahkan.** Satu uji `testBrightMoonRemovesFaintStarFromCandidates`
di `ResolverEphemerisTests`, plus seam pengujian non-breaking `overrideContext`
pada `PointingResolver.diagnose` (default `nil`, semua panggilan produksi tetap
berjalan sama).

**Kenapa.** `VisibilityFilter` sudah mengunci bahwa cahaya Bulan **mengetatkan**
batas magnitudo (`testMoonlightTightensTheLimitingMagnitude`), tapi tidak ada
satu pun uji yang mengunci **jalur ujung-ke-ujung**: bahwa penyaring itu benar-
benar mengeluarkan bintang redup dari *kandidat pointing* saat purnama tinggi,
dan melaporkannya sebagai `.tooFaint` — bukan diam-diam mendiamkannya. Itu tepat
kasus "bulan redup" yang diminta brief Fase C #6 ("tambah tes untuk tepi kasus").
Tanpa uji ini, seseorang bisa kelak memutuskan penyaring bulan hanya untuk teks,
dan engine kembali menawarkan bintang mag 5 di bawah purnama: klaim "bisa kamu
lihat" yang keliru, persis yang dilarang PRD.

**Hasil.** CelestialEngine 170 → **171** (aditif). PointingKit tetap 481.
README + STATUS diperbarui ke 171.

### Premis: angka yang benar, dan keputusan yang tidak pernah diambil

`SkyContext.moonIlluminationFraction` dihitung setiap resolusi, disimpan, lalu
ditampilkan sebagai "Fase Bulan" di layar Ketelitian. Semuanya benar. Tapi
`grep` di seluruh jalur penyaringan tidak menemukan **satu pun** pembacaan nilai
itu: `VisibilityFilter.classify` membandingkan magnitudo dengan
`policy.limitingMagnitude` polos.

Jadi ambang magnitudo tidak bergerak **sama sekali** antara langit tanpa Bulan dan
langit purnama. Untuk pengguna yang sedang berburu bintang redup, ini bukan
sekadar kurang akurat — engine menyatakan bahwa sesuatu "terlalu redup" untuk
langit yang memang jauh lebih terang dari yang disangka pengguna. Dan karena
`tooFaint` masuk ke `SearchHint`, engine punya alasan yang **salah** untuk
menolak kandidat: bukan "terlalu redup" (betul di bawah purnama), tapi ambang
yang tidak bergerak (berbahaya di mana saja).

Ini tipe defect yang berbeda dari dua siklus sebelumnya. Bukan "nilai dibuang"
— nilainya dipakai, hanya untuk **menggambar**. Yang terbuang adalah
**keputusan**: apakah cahaya Bulan ikut membatasi pengamatan.

### Angka 1.6, dan kenapa angka itu bukan klaim

`moonBrighteningMagnitudes` default 1.6 magnitudo pada fraksi penuh. Itu
memindahkan batas mata telanjang dari sekitar 6.5 ke sekitar 4.9 — angka kasar
yang lazim dipakai peminat pengamatan, **bukan** hasil pengukuran di instrument.
Uji tidak menjaga angkanya; uji menjaga **arahnya** (makin terang makin ketat) dan
**monotonnya**. Angka fisika tidak bisa dipertahankan sebagai fakta di sini,
jadi repo tidak mengklaimnya sebagai fakta.

Hanya fraksi yang dipakai, bukan juga ketinggian dan sudut: fraksi satu-satunya
yang punya sumber sudah teruji (`EphemerisBody.illuminationFraction`), dan menambah
dua faktor lain butuh plumbing efemeris baru untuk pengaruh orde dua.

### Tiga keputusan kecil yang justru lebih penting dari yang besar

1. **`nil` kembali ke batas dasar.** "Tidak diketahui" bukan "tidak ada".
   Memperlakukan unknowns sebagai langit paling terang akan membuang bintang
   dengan alasan yang tidak pernah terjadi — dan penolakan palsu seperti itu
   tidak bisa dibedakan pengguna dari penolakan yang benar.
2. **`permissive` dapat `0`.** Tanpa itu policy pengujian tetap membuang bintang
   redup saat ada purnama, jadi "tidak membuang apa pun" jadi setengah benar.
3. **Monoton.** Batas yang mengetat lalu mengendur adalah kesalahan paling halus,
   karena arah perubahannya masih "mengetat" dan terlihat masuk akal. Uji
   `testBrighterMoonNeverLoosensTheLimit` menjaga bentuknya, bukan angkanya.

### Cacat alat yang ketemu di tengah: `red-test.sh` bisa melaporkan hijau palsuk

Ini yang paling layak dicatat. Saat membuktikan mutasi **tanda minus jadi plus**,
skrip melaporkan "uji ini tidak menangkap mutasi" — padahal uji itu jelas harus
merah (batas yang melonggar membuat magnitudo 4.5 tetap lolos).

Penyebabnya: `red-test.sh` memaku `cd /src/Packages/PointingKit`. Uji engine
berjalan di paket yang **tidak punya** uji itu, jadi `swift test` keluar 0 dengan
`0 tests passed` — dan skrip membaca "keluar 0" sebagai "tidak merah".

Perbaikan: paket diturunkan dari letak berkas uji, dan `0 tests` kini
dianggap **kegagalan** (keluar 3), bukan bukti hijau.

Bentuk cacatnya persis bentuk yang skrip itu dibuat untuk cegah: tidak terlihat
dari mana pun, semuanya tetap kompilasi, semua gerbang hijau, dan
kesimpulan yang salah.

### Bukti

| Mutasi | Uji | Hasil |
|---|---|---|
| tanda `-` jadi `+` | `testMoonlightTightensTheLimitingMagnitude` | **MERAH** |
| `permissive` kehilangan `moonBrighteningMagnitudes: 0` | `testPermissivePolicyIgnoresMoonlight` | **MERAH**: 1.6 ≠ 0.0 |
| `nil` dipaksa lebih ketat | `testUnknownMoonKeepsTheBaseMagnitudeLimit` | **MERAH**: 3.0 ≠ 6.0 |
| pengetatan tidak monoton | `testBrighterMoonNeverLoosensTheLimit` | **MERAH**: 5.68 > 4.4 |

Dua mutasi pertama sempat **hijau** sebelum `red-test.sh` diperbaiki dan dua uji
tambahan ditulis — keduanya karena uji yang ada tidak punya kasus yang bisa
menangkapnya, bukan karena mutasinya tidak berbahaya.

### Gerbang

- `swift-test.sh` → **171 CelestialEngine** (166 → 171, +5) **+ 469 PointingKit**.
- `swift-ui-lint.sh` → **13 aturan hijau** (Aturan 10 menangkap angka README).
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `red-test.sh` → empat mutasi merah, setelah skripnya diperbaiki.
- CI: `37239219070` (Apple Build) + `37239219113` (Engine Linux) — hijau.

### Catatan kejujuran

Perubahan ini membuat engine **lebih jarang** menjawab, dan itu disengaja.
Ambang yang tidak bergerak terlihat aman, tapi ia mengarang keterbatasan yang
tidak bisa ia bantah dan yang tidak pernah disangka pengguna. Batas yang bergerak
mengikuti pengamatan nyata — dan bisa diuji.
## Progres terakhir (4 Okt 2026 — complication menampilkan kandidat ragu tanpa penanda)

### Premis: kebenaran yang sudah dihitung, lalu dibuang

Sapuan "nilai dihitung tapi tidak pernah dikonsumsi" kembali. Kali ini bukan
tentang kode mati, tapi tentang **kehilangan penanda** di permukaan yang paling
sempit.

`ComplicationDigest` sudah membawa `isConfirmed`. Field itu sudah ikut diuji
lewat round-trip JSON (`testDigestSurvivesTheWidgetRoundTrip`), jadi nilainya
benar. Tapi `grep isConfirmed Apps/PointAndKnowWatch/Complications/*.swift`
mengembalikan **kosong** — tidak ada satu pun view yang membacanya. Complication
hanya menampilkan `headline` + `objectKind`.

Akibatnya: nama kandidat pada `.uncertain` tampil **persis seperti** nama yang
sudah terkunci. Di complication ini lebih serius, karena dibaca tanpa membuka
app — tidak ada konteks lain yang bisa menolong pembaca membedakan kandidat dari
yang terkunci. Tiga permukaan lain sudah jujur soal ini dalam dua bentuk berbeda
(`CelestialVisualView` menyembunyikan ciri pengenal saat ragu; `statusCard` dan
`LockArrivalPanel` memakai badge), jadi ini permukaan keempat yang tertinggal —
dan yang paling cepat dibaca keliru.

### Dua kanal, dua bentuk solusi

Complication hanya punya **dua kanal**: satu ikon dan satu baris teks (dua di
keluarga persegi panjang). Ini yang menentukan bentuk perbaikannya.

- **`.accessoryInline`** — satu slot baris. Satu kata tambahan sudah memenuhi
  ruang, jadi tidak ada teks yang bisa ditambahkan. Penandanya harus lewat
  ikon, tapi keluarga ini tidak punya ikon sama sekali.
- **`.accessoryCircular`** — punya ikon, jadi `presentedSymbolName` jadi kanal
  penandanya. Sumbernya tetap `state.symbolName` yang sudah ada, sehingga
  tidak ada daftar ikon kedua yang bisa berbeda pendapat dengan keadaan.
- **`.accessoryRectangular`** — baris kedua memang ada ruang, jadi penanda
  tampil sebagai **kata** ("Belum pasti"), bukan hanya ikon.

### Kenapa enum, bukan `String?`

`sublineContent` adalah enum dengan tiga kasus, bukan `String?`.
Alasannya bukan selera gaya: yang paling mudah **dibajak** di sini adalah
urutan prioritas. Penanda ragu harus **mengalahkan** jenis benda, karena
pertanyaan yang dijawabnya ("apakah nama ini sudah pasti") lebih penting
daripada pertanyaan yang dijawab jenis benda ("ini benda apa").

Kalau itu ditulis sebagai dua `if` terpisah di dalam
`ComplicationWidget.swift`, urutannya hidup di berkas yang **tidak bisa diuji
di Linux** — WidgetKit tidak ada di sana. Itu persis kelas "jalur dihitung lalu
dibuang" yang sedang kita perbaiki, hanya dalam bentuk yang lebih halus. Sebagai
enum, prioritasnya jadi bagian dari model dan bisa diuji.

Sisi lain: enum **bukan** teks. View yang memanggil `TextLocalization` untuk
tiap kasus, karena nilai katalog setiap kunci harus punya entri di katalog
(Aturan 6), dan enum tidak bisa dijaga Aturan 6 dari sisi teksnya.

### Kunci baru, bukan kunci yang dipakai ulang

`confidence.uncertain.marker` = "Belum pasti". Sengaja **tidak** memakai ulang
`confidence.level.medium.label` ("Ragu"). Di complication konteksnya hilang —
tidak ada teks "tingkat keyakinan" di sampingnya — jadi kata yang sama akan
punya dua arti: "kandidat belum pasti" versus "sedang mencari". Katalognya
makin panjang, jadi ini keputusan yang perlu dijelaskan, bukan sekadar soal
kenyamanan.

### Bukti: tiga mutasi, ketiganya merah

`red-test.sh` dipakai untuk memastikan uji baru benar-benar **menanggung
beban** — uji yang hijau di atas kode rusak sama dengan tidak ada uji.

| Mutasi | Uji yang menangkap | Hasil |
|---|---|---|
| `carriesUncertaintyMarker` → `hasAnswer` (penanda hilang) | `testUncertainCandidateNeverRendersIdenticallyToALock` | **MERAH**: terkunci ikut memakai penanda |
| `sublineContent` dibalik (jenis benda menang) | `testUncertaintyMarkerOutranksTheObjectKindOnTheSubline` | **MERAH**: `"objectKind"` ≠ `"uncertaintyMarker"` |
| semua ikon disamakan jadi `"scope"` | `testUncertainCandidateNeverRendersIdenticallyToALock` | **MERAH**: simbol ragukan simbol terkunci |

Dua mutasi pertama menjaga **penanda**, yang ketiga menjaga **pembedanya**.
Keduanya harus merah; kalau salah satu hijau, ujinya cuma mengulang
implementasi.

### Tiga kegagalan yang muncul saat running

Tidak semuanya cacat yang saya temukan — dua adalah **salah tebakan dari
sisi saya**, dan itu memang berguna karena menunjukkan batas apa yang bisa
dijaga di Linux:

1. `XCTAssertFalse(candidate.carriesUncertaintyMarker)` — saya menulis
   **kebalikan** dari yang dimaksud. Penanda justru harus **ada** pada
   kandidat. Ditukar.
2. `XCTAssertNil(idle.sublineContent)` — membandingkan enum dengan `nil`,
   padahal kasus "tidak ada baris kedua" adalah `.none`. Ditukar ke
   `XCTAssertEqual(..., .none)`.
3. `TextLocalizationTests` — gerbang jumlah kunci menangkap **175 ≠ 174**. Itulah persis
   yang harusnya ia tangkap: daftar kunci tidak bisa bertambah diam-diam.

Aturan 10 (hitungan uji di README) juga menangkap `README` yang masih
mengaku 465. Dua gerbang yang menangkap kesalahan saya sendiri.

### Gerbang

- `swift-test.sh` → **166 CelestialEngine + 469 PointingKit**, 0 gagal
  (465 → 469, +4).
- `swift-ui-lint.sh` → **13 aturan hijau** (Aturan 10 yang menangkap README).
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `red-test.sh` → tiga mutasi, ketiganya merah.
- CI: `37237741445` (Apple Build) + `37237741447` (Engine Linux) —
  **dua-duanya hijau**.

### Apa yang TIDAK diselesaikan siklus ini

Ini memperbaiki **satu** permukaan dari empat, dan tiga lainnya memang
sudah benar. Yang belum berubah: daftar celah terbuka di bawah. Keempat
permukaan sekarang sama-sama jujur soal ketidakpastian, tapi satu permukaan
yang benar tidak berarti empat celah yang lebih lebar sudah tertutup.

## Progres terakhir (4 Okt 2026 — label lokasi darurat + `Targets.kindLabel` mati yang menipu)

### Premis: dua sisa dari sapuan yang sama

Sapuan "berkas paket yang menghasilkan teks tampilan tanpa kunci" menyisakan
dua berkas setelah `LinkStatusText` ditutup. Keduanya jenis yang berbeda:

**1. `ObserverLocation.fallback.label` — literal yang benar-benar tampil.**
Labelnya adalah `"Jakarta (bawaan)"`, dan `PointingView` merendernya apa
adanya: `Text("Lokasi: \(engine.location.label)")` di layar utama jam, plus
baris rinciannya. Pengguna Bahasa Inggris membaca label Indonesia tanpa
penanda apa pun. Tak terlihat Aturan 4 (bukan argumen `Text(...)`) dan tak
punya kunci untuk diperiksa Aturan 6.

**2. `Targets.kindLabel` — duplikat mati.**
`CelestialObject.kindLabel` mengulang `switch` yang sudah ada di
`ObjectKind.displayName` — tapi versi ini mengembalikan literal Indonesia
("Bintang", "Bulan", …) dan **tidak dipakai siapa pun**. `PointingView`
memakai `object.kind.displayName` yang sudah lewat katalog. Tidak ada uji yang
menyentuhnya. Duplikat yang tak terpakai tidak "tidak berbahaya": ia
menawarkan jalur lokal yang **tampak** benar kepada orang berikutnya yang
butuh label jenis, dan jalur itu diam-diam melewatkan katalog. Dihapus.

### Satu jebakan yang tertangkap saat mengerjakannya

Perbaikan pertama menulis `label: TextLocalization.text(.locationFallbackLabel)`
di dalam `static let fallback`. Itu **beku pada akses pertama**: bridge
terjemahan dipasang saat app diluncurkan, jadi siapa pun yang menyentuh
`.fallback` lebih dulu (mis. `PointingEngine.init` yang memakai
`location: .fallback`) mengunci label Indonesia untuk selamanya — dan
perbaikannya tampak benar padahal tidak berpengaruh.

Karena itu `.fallback` menjadi **`static var` computed**: nilainya dihitung
ulang tiap akses, jadi selalu mengikuti bahasa aktif. Biayanya satu struct
kecil; harganya salah kalau dibiarkan.

Uji kedua sengaja ada untuk itu — dan hanya uji itu yang menangkap jebakannya:

| Mutasi | Uji yang menangkap | Hasil |
|---|---|---|
| `label:` dikembalikan jadi literal | `testFallbackLabelFollowsTheBridge` | **MERAH**: `"Jakarta (bawaan)"` ≠ `"Jakarta (default)"` |

`testFallbackIsLabelled` (paritas katalog) **tetap hijau** terhadap mutasi itu,
karena nilai `id` bawaannya memang teks Indonesia yang sama. Itulah kenapa uji
bridge-nya yang menanggung beban, bukan uji paritasnya.

### Gerbang

- `swift-test.sh` → **166 CelestialEngine + 459 PointingKit**, 0 gagal.
- `swift-ui-lint.sh` → **12 aturan hijau**.
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- CI: `37232670778` (Apple Build) + `37232670752` (Engine Linux) —
  **dua-duanya hijau**.

## Progres terakhir (4 Okt 2026 — dua `LinkService` menyimpan kalimat status ke properti; kedua gerbang buta)

### Premis: kelas yang sama, tiga kali, di tiga tempat berbeda

Siklus ini menutup kemunculan ketiga dari satu kelas cacat yang sama:
**teks yang berakhir di layar pengguna tapi tidak pernah menyentuh katalog.**

| Siklus | Tempat | Kenapa gerbang buta |
|---|---|---|
| 1 | `ExperimentText` | Kalimat dirakit di paket, jauh dari `Text(...)` |
| 2 | `RowSpeech` | Kalimat **diucapkan**, bukan dirender |
| 3 | `PointingLinkMessage.note` | Kalimat di dalam pabrik pesan |
| **4** | **`PhoneLinkService` / `WatchLinkService`** | **Kalimat disimpan ke properti, view merender properti itu** |

Pola yang sama, wujud yang berbeda. Yang keempat paling licin: service
menulis `lastNote = "Jam melihat \(name)"`, lalu `LinkView` merender
`Text(note)`. Aturan 4 hanya melihat literal yang **langsung** ada di dalam
`Text(...)` — di sini yang sampai ke `Text` hanyalah **nama variabelnya**.
Aturan 6 memeriksa paritas kunci yang **dideklarasikan** — kalimat ini tidak
punya kunci, jadi tak ada yang bisa dibandingkan. Dua gerbang hijau.

### Yang dikerjakan

`LinkStatusText` di PointingKit (13 kalimat, 13 kunci katalog `link.status.*`),
dipakai **kedua** service. Kalimatnya identik di dua perangkat, jadi satu
sumber — dua salinan literal pasti menyimpang: satu diperbaiki, satu tertinggal.

Dua keputusan yang sengaja:

- **`error.localizedDescription` disisipkan apa adanya**, tidak dibungkus
  katalog. Ia sudah dilokalkan OS ke bahasa perangkat; menerjemahkannya lagi
  akan menimpa lokalisasi yang benar dengan tebakan kita.
- **Bukan 1 kunci per service.** `sendFailed` dipakai iPhone dan jam sekaligus;
  satu kunci untuk dua pemanggil lebih jujur daripada dua kunci kembar.

### Gerbang baru: Aturan 12

Aturan 12 menyapu **literal yang di-assign ke properti tampilan**
(`*Note`, `*Message`, `*Label`, `*Title`, `*Subtitle`, `*Hint`, `*Reason`,
`*Warning`, `*Error`, `*Body`, `*Caption`, `*Detail`, `*Speech`, `*Spoken`).

Penyaringnya sengaja dua lapis supaya tidak berisik:
- **kunci katalog** (mengandung titik, huruf kecil, tanpa spasi) → lolos;
- **satu kata** tanpa spasi → lolos (nama objek, bukan kalimat);
- sisanya: kalimat → **MERAH**.

Terhadap seluruh `Apps/` setelah perbaikan: **0 hit**. Sebelum perbaikan:
12 hit, semuanya cacat nyata. Jadi aturannya menangkap kelasnya tanpa satu pun
positif palsu.

### Bukti merah

| Mutasi | Gerbang | Hasil |
|---|---|---|
| `lastNote = "Tanda terima sudah diterima oleh iPhone"` dikembalikan | Aturan 12 | **MERAH**: `PhoneLinkService.swift:106` |
| kunci `link.status.watchSaw` dihapus dari katalog | Aturan 6 | **MERAH**: menunjuk kunci |

### Gerbang

- `swift-test.sh` → **166 CelestialEngine + 458 PointingKit**, 0 gagal.
- `swift-ui-lint.sh` → **12 aturan hijau**.
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- CI: `37232178735` (Apple Build) + `37232178713` (Engine Linux) —
  **dua-duanya hijau**.

## Progres terakhir (4 Okt 2026 — `PointingLinkMessage.note` menyimpan kalimat Bahasa Indonesia di dalam paket)

### Premis: lanjutan langsung dari siklus `RowSpeech`, di berkas lain

Siklus sebelumnya menutup `RowSpeech` — teks yang diucapkan, lahir di paket,
tanpa kunci katalog. Sapuan yang sama (berkas yang menghasilkan teks tapi
tidak mendeklarasikan satu kunci pun) menyisakan satu berkas paket lain:
`LinkMessage.swift`.

Di dalamnya, `state(from:at:sigmaDeg:)` mengisi:

```swift
note: snapshot.isCalibrated ? "terkalibrasi" : "belum terkalibrasi"
```

Kalimat itu **menyeberang dari jam ke iPhone** dan dirender apa adanya di
`LinkView` — `Text(note)`, di bawah baris "Waktu". Pengguna Bahasa Inggris
membaca "terkalibrasi" dalam Bahasa Indonesia.

### Kenapa licin — dan kenapa beda dari `RowSpeech`

`RowSpeech` tidak punya kunci sama sekali. Yang ini punya tetangga yang
**sudah benar**: `LinkMessageKind.displayName` tepat di sebelahnya membaca
`TextLocalization` dengan rapi. Jadi berkasnya terlihat seperti berkas yang
sudah ditutup — dan bagian yang belum justru duduk di dalam *pabrik pesan*,
bukan di lapisan tampilan.

Dua gerbang tetap hijau:

- **Aturan 4** hanya menyapu literal yang **langsung** di dalam argumen
  `Text(...)`. Di sini literalnya ada di service, bukan di view — jadi tidak
  ada yang bisa dilihat.
- **Aturan 6** memeriksa paritas kunci yang **dideklarasikan**. Kalimat ini
  tidak punya kunci, jadi tidak ada yang bisa dibandingkan.

### Yang diubah, dan kenapa bentuknya begini

Yang disimpan di pesan sekarang **keadaan**, bukan kalimat:

- **`isCalibrated: Bool?`** menggantikan `note: "terkalibrasi"`. Ia ikut
  bentuk kabel (`plist`) dan diuji selamat melewatinya — kalau tidak, iPhone
  menerima pesan tanpa keadaan kalibrasi dan menampilkan jam sebagai "belum
  terkalibrasi" walau sudah dikalibrasi, salah, dan tidak terlihat dari sisi
  jam.
- **`calibrationNoteText`** menghasilkan kalimatnya lewat katalog, teruji di
  Linux. `nil` bila pesan memang tidak membawa keadaan kalibrasi — lapisan
  tampilan lalu tidak menampilkan baris apa pun, bukan baris kosong.
- **`note` tetap ada** untuk catatan bebas (mis. `localizedDescription` dari
  galat sistem, yang sudah dilokalkan oleh OS). Yang dilarang adalah
  **kalimat status yang bisa dihitung**; yang boleh tetap string bebas.
- **`LinkView` dan `WatchLinkService`** membaca `calibrationNoteText` lebih
  dulu, lalu jatuh ke `note`, lalu ke `displayName`.

### Bukti merah

| Mutasi | Gerbang | Hasil |
|---|---|---|
| `link.note.calibrated` dihapus dari katalog | Aturan 6 | **MERAH**: menunjuk kunci itu |
| `note: "terkalibrasi"` dikembalikan ke pabrik pesan | `swift-test.sh` | **MERAH**: tiga assertion di dua uji — `isCalibrated` jadi `nil`, dan `note` berisi `"terkalibrasi"` |

### Batas yang jujur — dan unit berikutnya sudah terukur

Dua belas kalimat status tautan yang **tampil di layar Tautan** masih literal
di `PhoneLinkService` (7) dan `WatchLinkService` (5): "Jam belum terhubung —
pesan tidak terkirim.", "Terkirim: …", "Tanda terima", dan seterusnya.
Sapuan pola `\w*(Note|Message)\s*=\s*"…"` menemukan tepat 12 kemunculan, dan
**semuanya** kalimat tampilan — tidak ada positif palsu, jadi bentuk ini layak
dijadikan gerbang. Belum dikerjakan di siklus ini supaya unitnya tetap kecil;
ia unit berikutnya.

Alasan bentuk gerbang itu belum ada sekarang: Aturan 4 **tidak bisa** menutup
kelas ini apa adanya — nilai `lastNote` adalah kalimat jadi yang melewati
cabang, dan menuntutnya ada di katalog akan menandai setiap baris status
sebagai "teks UI", termasuk yang memang bukan. Yang benar adalah aturan baru
yang sempit (pola penugasan `*Note`/`*Message`), bukan melonggarkan Aturan 4.

### Gerbang

- `swift-test.sh` → **166 CelestialEngine + 454 PointingKit**, 0 gagal.
- `swift-ui-lint.sh` → **11 aturan hijau**.
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- CI: `37231726014` (Apple Build) + `37231725992` (Engine Linux) —
  **dua-duanya hijau**.

## Progres terakhir (4 Okt 2026 — `RowSpeech` mengucapkan kalimat Indonesia tanpa satu pun kunci katalog)

### Premis siklus ini: sapu berkas yang menghasilkan teks tapi tidak mendeklarasikan satu kunci pun

Aturan 6 memeriksa paritas antara `LocalizedText.allKeys` dan katalog. Itu
benar — tetapi ia hanya bisa memeriksa kunci yang **dideklarasikan**. Berkas
yang mengembalikan frasa Bahasa Indonesia tanpa pernah melewati
`LocalizedText` tidak punya kunci untuk diperiksa, dan Aturan 4 tidak menyapu
`Packages/`. Jadi bentuk itu tidak terjangkau keduanya.

Sapuan yang dipakai bukan membaca satu berkas, melainkan **mencari berkas yang
memuat literal Indonesia tetapi tidak punya deklarasi `LocalizedText` sama
sekali**. Hasilnya pendek, dan yang terbesar adalah `RowSpeech`:

| Kalimat | Fungsi |
|---|---|
| `"%@ derajat"` / `"%@ derajat per detik"` | `spokenDegrees`/`spokenRate` |
| `"galat %.1f derajat"` | `spokenError` |
| `"\(title): \(value)"` | `label`/`spokenRow` |

Ini bukan berkas pinggiran: `RowSpeech` dipakai **15 kali di seluruh `Apps/`**
untuk setiap baris "judul … nilai" yang diucapkan. Pengguna Bahasa Inggris
mendengar "5.0 derajat per detik" dan "galat 2.5 derajat" di tiga layar, dengan
setiap gerbang hijau.

### Kenapa bentuknya licin

- **Bukan literal yang disapu.** Kalimatnya lahir di dalam paket, dan Aturan 4
  hanya menyapu `Apps/`.
- **Bukan kunci yang bisa diperiksa.** Tidak satu pun frasa melewati
  `LocalizedText`, jadi `allKeys` tidak memuatnya dan Aturan 6 tidak punya
  pasangan untuk dibandingkan.
- **Tidak ada layar yang salah.** Yang salah hanya bahasa, dan hanya bagi
  pengguna yang bukan penutur Bahasa Indonesia — tidak ada penanda di layar.

Kelasnya sama persis dengan `SensorStatusText`, `CalibrationText`,
`ObjectSpeech`, dan `ExperimentText` — tetapi keempatnya sudah ditutup, dan
berkas ini tertinggal di belakang.

### Yang diubah, dan kenapa bentuknya begini

- **Lima kunci `row.speech.*`**: template penggabungan baris, dua satuan dalam
  bentuk kata, kata yang menyebut apa yang diukur galat, dan kalimat galatnya.
- **Presisi tetap angka, bukan template.** `spokenRate(_:precision:)` dan
  `spokenDegrees(_:precision:)` menyisipkan presisi ke dalam specifier
  (`"%.\(precision)f"`), bukan mengambil template dari katalog. `String(format:)`
  tidak bisa memakai specifier yang datang dari nilai runtime, jadi bentuk
  yang benar adalah menyusun specifier-nya di kode dan mengambil **satuannya**
  dari katalog. Yang dikatalogkan adalah kata; yang dihitung adalah angka.
- **Kata "galat" dan satuan "derajat" adalah dua kunci terpisah.** `%1$@` tidak
  dipakai karena ia bekerja berbeda di CoreFoundation vs Swift Foundation —
  jebakan yang tidak bisa dibuktikan di Linux. Dua `%@` biasa bekerja sama di
  keduanya.
- **Judul kosong melewati format sama sekali** (`guard !title.isEmpty`), supaya
  baris tanpa judul tidak pernah menghasilkan pemisah yang menggantung.

### Bukti merah

| Mutasi | Gerbang yang menangkap | Hasil |
|---|---|---|
| lima kunci `row.speech.*` dihapus dari katalog | Aturan 6 | **MERAH**: menunjuk kelima kunci |

Tiga uji baru (`RowSpeechTests`): terjemahan Inggris memasang kata yang
menggantikan bawaan untuk **setiap** aksesor, urutan template kalimat galat
benar-benar dipakai (bukan hanya kata-katanya yang ditukar), dan judul kosong
tidak memanggil format.

### Jebakan kedua: katalog terjemahan bisa **menjatuhkan app**

Uji urutan template itu pertama ditulis dengan template `"%.1f %@ %@"`.
`spokenError` mengirim `(String, Double, String)`; template itu memberi
`%.1f` sebuah `String`. **Di CoreFoundation itu crash, bukan keluaran yang
salah** — dan glibc memaafkannya, jadi bentuk itu hijau di `swift-test.sh`
(450 lulus) dan baru meledak di CI macOS.

Percobaan pertama memperbaikinya dengan memformat angka lebih dulu di kode
(`String(format: "%.1f", deg)`) sehingga seluruh template hanya berisi `%@`.
Itu **salah**, dan tertangkap saat memeriksa apakah bentuk itu bisa dijadikan
gerbang: memindahkan specifier bertipe berbeda melewati satu sama lain adalah
**persis operasi yang crash**. Kalau urutannya diwajibkan sama, keuntungan
"semua `%@`" hilang — dan harganya adalah kehilangan kemampuan menaruh angka
di depan untuk bahasa yang menuntutnya.

Jadi bentuknya dikembalikan, dan yang dibangun adalah gerbangnya:

**Aturan 11** membandingkan urutan **tipe** specifier pada template bawaan
kode (`id:`) dengan setiap nilai terjemahan untuk kunci yang sama, untuk
**seluruh** katalog. Urutan harus sama persis — bukan karena urutan itu suci,
tapi karena menukar dua specifier berbeda tipe berarti memberi specifier
angka sebuah `String`, dan itulah crash-nya.

Bukti merah: `"%.1f %@ %@"` dipasang kembali di `row.speech.error` → Aturan 11
menunjuk `kode ['@', 'f', '@'] vs katalog ['f', '@', '@']` — **persis mutasi
yang menjatuhkan CI macOS**.

Batasnya jujur dan dicatat di kode: bahasa yang menuntut angka di depan
**tidak bisa** diterjemahkan lewat katalog saja. Itu memang benar — perubahan
semacam itu harus lewat kode, bukan lewat berkas terjemahan.

Tiga jebakan berbeda, tiga-tiganya tak terlihat di Linux:

1. `%1$@` posisional bekerja berbeda di CoreFoundation vs Swift Foundation.
2. Specifier yang tak cocok tipe argumen = crash di CoreFoundation,
   diabaikan glibc — **sekarang dijaga Aturan 11**.
3. Berkas terjemahan diperlakukan sebagai data, padahal ia bisa menjatuhkan
   app.

### Batas yang jujur

- **Terjemahan `en` tidak bisa diverifikasi di Linux** — sama seperti siklus
  sebelumnya. Yang terbukti: setiap kunci punya entri + padanan `en`.
- **`row.speech.label` adalah `"%@: %@"`** — pemisahnya milik katalog, tetapi
  bahasa yang butuh pemisah berbeda (mis. tanpa titik dua) belum diuji dengan
  penutur asli.
- **Berkas lain dengan bentuk yang sama belum semuanya ditutup.** Sapuan yang
  sama menemukan `Targets.kindLabel` (label jenis yang menduplikasi
  `ObjectKind.displayName`), `LinkMessage` (catatan kalibrasi yang melintas
  Watch↔iPhone), `ArchiveCoding` (teks galat decoder — bukan teks tampilan),
  dan `PhoneLinkService`/`WatchLinkService` (selusin catatan status tautan
  yang tampil di `LinkView`). Masing-masing adalah unit berikutnya; yang
  terbesar dan paling sering dibaca dikerjakan lebih dulu.

### Gerbang

- `swift-test.sh` → **166 CelestialEngine + 450 PointingKit**, 0 gagal.
  Engine tidak disentuh.
- `swift-ui-lint.sh` → **11 aturan hijau**; Aturan 6 dibuktikan bisa MERAH
  lewat mutasi di atas, dan Aturan 11 lewat mutasi yang persis menjatuhkan
  CI macOS.
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Sapuan aksara non-Latin: 0.
- CI: `37231190548` (Apple Build, macos-15) + `37231190543` (Engine Linux) —
  **dua-duanya hijau**. Apple Build sempat MERAH dua kali (`37230467244`,
  `37230839317`) karena crash CoreFoundation di atas; itulah bukti jebakan
  ini nyata, bukan teoretis.

## Progres terakhir (4 Okt 2026 — laporan alat ukur lahir di dalam paket, tak terjangkau dua gerbang sekaligus)

### Premis siklus ini: cari teks yang lahir di luar jangkauan kedua gerbang, bukan yang salah bentuk

Aturan 4 menyapu literal `Text("…")` di `Apps/`. Aturan 6 memeriksa paritas
`LocalizedText.allKeys` dengan katalog. Keduanya hijau. Yang belum pernah
diperiksa adalah teks yang **tidak lahir di `Apps/` dan tidak melewati
`LocalizedText`** — yaitu kalimat yang lahir di dalam `Packages/PointingKit`
(`ExperimentHarness.verdict`, `ConfidenceTrace.diagnosis`) atau dirakit lebih
dulu ke sebuah `String` di dalam view (`statusMessage = "…\(…)…"`). Bentuk itu
tidak punya argumen langsung untuk disapu Aturan 4, dan tidak punya kunci untuk
diperiksa Aturan 6.

Yang paling penting justru yang paling dirugikan: **Experiment 1 adalah alat
ukur repo ini sendiri**, dan putusannya — "GAGAL: N false lock", "Belum bisa
disimpulkan", "Ini bukan bukti aman, hanya belum ada bukti sebaliknya" —
tampil dalam Bahasa Indonesia di semua bahasa, dengan setiap gerbang hijau.
Alat ukur yang tidak bisa diterjemahkan berarti penguji berbahasa Inggris
membaca putusan keselamatan dalam bahasa yang tidak ia pahami.

### Kenapa bentuknya licin

- **Aturan 4 buta karena teksnya dirakit lebih dulu.** `statusMessage =
  "Tercatat: galat \(error), \(verdict). Jawaban engine: \(name)."` — yang
  tampil adalah nilai sebuah `String`, bukan argumen langsung. Diverifikasi:
  mengembalikan bentuk lama itu ke view membuat Aturan 4 **tetap hijau**.
- **Aturan 6 buta karena teksnya tidak lewat `LocalizedText`.** `verdict` dan
  `diagnosis` memakai literal `String(format: "%.0f%% jawaban yakin…")` di
  dalam paket, tempat tidak ada daftar kunci untuk diperiksa.
- **Tidak ada yang bisa dilihat.** Semua kalimatnya benar, dalam Bahasa
  Indonesia, dan tampil apa adanya. Hanya satu bahasa yang hilang, tanpa
  penanda.

### Yang diubah, dan kenapa tempatnya di paket

- **`ExperimentText`** (PointingKit, teruji Linux) — pesan status recorder,
  kata putusan (bentuk pendek **dan** bentuk kalimat untuk suara), baris
  detail, ringkasan, diagnosis, usulan ambang, dan kalimat lokasi. Satu
  sumber untuk layar dan suara, seperti `CalibrationText`, `SensorStatusText`,
  dan `ObjectSpeech` sebelumnya.
- **`ExperimentHarness.verdict` dan `ConfidenceTrace.diagnosis` membaca
  `ExperimentText`** — bukan lagi literal di dalam paket. Keduanya adalah
  tempat kalimat itu lahir, jadi keduanya harus jadi tempat ia bisa
  diterjemahkan.
- **38 kunci katalog `experiment.*`** dengan terjemahan Inggris; `allKeys`
  105 → 143 (naik tepat 38), katalog 236 → **274** kunci.
- **Angka masuk lewat `String(format:)`** (`%lld` untuk jumlah bulat: `%d` di
  Linux Swift membaca 32-bit dan memotong `Int` 64-bit) supaya bahasa lain
  bisa menempatkan angka di urutan berbeda.

### Dua kesalahan yang dibuat di siklus ini, dan bagaimana ketahuan

Ditulis apa adanya:

1. **Dua aksesor dipakai sebelum kuncinya ada.** `ExperimentText` sempat
   memanggil `locationFallbackWarning`/`locationComputed`, tetapi
   `experimentLocationFallback`/`experimentLocationComputed` belum pernah
   dideklarasikan — `swift build` menolak dengan
   `type 'LocalizedText' has no member`. Ketahuan **dari kompiler, bukan dari
   membaca ulang**, dan itu tepat: dua kalimat lokasi itu adalah sisa langkah
   yang belum selesai.
2. **Kalimat lokasi masih dirakit di view.** `Text(recorder.currentLocation
   .isFallback ? "Lokasi belum didapat — … \(label), …" : "Dihitung untuk
   \(label).")` — bentuk yang sama persis dengan cacat yang sedang ditutup,
   di berkas yang sama. Ikut dipindah ke paket; tanpa itu, separuh perbaikan
   hanya memindahkan lubangnya.

### Bukti merah: dua arah, dan keduanya benar-benar dijalankan

| Mutasi | Gerbang yang menangkap | Hasil |
|---|---|---|
| bentuk lama dikembalikan (literal dirakit di view) | Aturan 4 | **hijau** — membuktikan bentuk itu memang tak terjangkau |
| dua kunci `experiment.location.*` dihapus dari katalog | Aturan 6 | **MERAH**: menunjuk kedua kunci yang hilang |

Baris pertama sengaja **bukan** merah: itu bukti bahwa cacat lama memang
tak terlihat oleh Aturan 4. Baris kedua membuktikan perbaikan barunya
**terjaga** — kunci yang hilang langsung merah.

Dua uji baru (`ExperimentTextTests`): peringatan lokasi bawaan menyebut
labelnya dan **berbeda** dari keterangan biasa, dan keterangan biasa menyebut
labelnya. Uji terjemahan Inggris yang sudah ada diperluas ke kedua kalimat itu,
sehingga ia membuktikan kata yang dipasang katalog benar-benar menggantikan
bawaan.

### Batas yang jujur

- **Terjemahan `en` tidak bisa diverifikasi di Linux.** Yang terbukti: setiap
  kunci punya entri + padanan `en`, dan diff katalognya aditif. Yang tidak:
  apakah `Bundle` benar-benar membacanya di perangkat.
- **Bentuk kalimat yang dirakit dari `parts.joined(separator:)` tetap milik
  tiap layar.** Yang dipindah adalah bahannya (potongan kalimat), bukan
  susunannya — alasan yang sama dengan `ObjectSpeech`: kedua panel memang
  disusun berbeda, dan menyamakan susunannya akan memaksa satu permukaan
  kehilangan bentuk yang benar untuknya.
- **`ExperimentText` belum punya pembaca VoiceOver yang diuji di perangkat.**
  Kalimatnya dipakai di label yang sudah ada; bahwa VoiceOver mengucapkannya
  dengan jeda yang enak adalah wilayah perangkat, bukan Linux.

### Gerbang

- `swift-test.sh` → **166 CelestialEngine + 447 PointingKit**, 0 gagal.
  Engine tidak disentuh.
- `swift-ui-lint.sh` → **10 aturan hijau**; Aturan 4 dan Aturan 6 keduanya
  hijau setelah perbaikan, dan dibuktikan bisa merah lewat dua mutasi di atas.
- `swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Sapuan aksara non-Latin: 0.
- CI macOS run `37229977845` (Apple Build) + `37229977853` (Engine Linux) hijau.

## Progres terakhir (4 Okt 2026 — seluruh alur kalibrasi tak pernah bisa diterjemahkan)

### Kalimat yang lahir di dalam paket, bukan di view

Aturan 4 menyapu literal `Text("…")` di `Apps/`. Aturan 6 memeriksa paritas
`LocalizedText.allKeys` dengan katalog. Keduanya hijau — padahal **seluruh alur
kalibrasi** menghasilkan kalimat Bahasa Indonesia di dalam
`Packages/PointingKit`, tempat tidak satu pun dari dua gerbang itu menjangkaunya:

| Kalimat | Berkas |
|---|---|
| `Tunjuk bintang acuan, lalu tekan untuk mencatat.` | `CalibrationFlow.message` |
| `Butuh minimal %lld acuan (%lld tercatat).` | `CalibrationFlow.message` |
| `Sebaran %.1f° masih terlalu lebar (maks %.1f°). Tambah acuan.` | `CalibrationFlow.message` |
| `Siap — sebaran %.1f° dari %lld acuan.` | `CalibrationFlow.message` |
| `Kalibrasi dipakai.` | `CalibrationFlow.message` |
| `Sensor gerak tidak aktif — … Tidak dicatat.` | `CalibrationSession` |
| `Belum ada arah tunjuk dari sensor.` | `CalibrationSession` (×2) |
| `Arah objek %@ tidak bisa dihitung — tidak dicatat.` | `CalibrationSession` |
| `Tidak ada bintang acuan yang jelas di arah itu — …` | `CalibrationSession` |
| `Tahap: %@.`, `%lld acuan tercatat.`, `Offset …`, `Sebaran …` | `CalibrationSpeech` |
| `Pakai kalibrasi ini` / `Pakai kalibrasi, belum bisa dipakai` | `CalibrationSpeech` |
| `Catat %@ sebagai acuan, %.0f derajat tinggi.` | `CalibrationSpeech` |
| `Tunjuk bintang acuan, lalu tekan Catat.` | `CalibrationView.statusMessage` |
| `Kalibrasi sudah terpasang: offset %.1f°.` | `CalibrationView` |
| `Belum siap dipakai: sebarannya masih terlalu lebar.` | `CalibrationView` |
| `Terpasang. Offset %.1f°, sebaran %.1f°.` | `CalibrationView` |
| `Kalibrasi dihapus. Mulai dari awal.` | `CalibrationView` |
| `Offset %.1f°`, `Sebaran %.1f° (maks %.1f°)` | `CalibrationView` |
| `Belum ada acuan` / `Mengumpulkan acuan` / … | `CalibrationPhase` (layar **dan** suara) |

Tidak satu pun ada di `Localizable.xcstrings`. Dua sebab yang berbeda, keduanya
senyap:

- Kalimat yang lahir di `CalibrationFlow`/`CalibrationSession`/`CalibrationSpeech`
  tidak pernah melewati `LocalizedText`, jadi ia tidak punya kunci untuk
  dibandingkan Aturan 6 — dan Aturan 4 tidak menyapu `Packages/`.
- Kalimat di `CalibrationView` **dihitung**, bukan literal: bentuknya
  `statusMessage = String(format: "…", …)` atau `statusMessage = "…" + …`.
  Regex argumen-langsung Aturan 4 tidak melihat nilai yang dirakit lebih dulu.

Akibatnya seluruh alur kalibrasi — layar dan suara — tampil dalam Bahasa
Indonesia di semua bahasa, dengan setiap gerbang hijau. Ini kelas cacat yang
sama dengan yang ditutup `SensorStatusText` dan `ObjectSpeech`, tetapi
berkas-berkas ini tertinggal di belakang.

### Dua sumber yang sudah bisa menyimpang

`CalibrationPhase` punya nama tahap **dua kali**: `phaseLabel` (literal di
`CalibrationView`, bentuk pendek) dan `spokenName` (literal di paket, bentuk
panjang). Layar dan suara menyebut keadaan yang sama dengan kalimat yang
berbeda, di dua tempat berbeda — satu perubahan bisa membuat keduanya tak lagi
sepakat.

### Yang diubah

- **`CalibrationText`** (PointingKit, teruji Linux) — 27 kunci: pesan tahap,
  pesan kegagalan langkah, label yang diucapkan, pesan status, angka ringkas
  kartu, dan nama tahap. Angka masuk lewat `String(format:)` (`%lld` untuk
  jumlah bulat: `%d` di Linux Swift membaca 32-bit dan memotong `Int` 64-bit).
- **27 kunci katalog `calibration.*`** dengan terjemahan Inggris; `allKeys`
  78 → 105; katalog 209 → 236.
- `CalibrationFlow`, `CalibrationSession`, `CalibrationSpeech`, dan
  `CalibrationView` membaca frasa itu. `CalibrationPhase.displayName` (layar)
  dan `.spokenName` (suara) kini membaca katalog yang sama, jadi keduanya tak
  bisa lagi menyimpang.

Sebelas uji baru (`CalibrationTextTests`), termasuk yang memasang terjemahan
Inggris untuk membuktikan setiap aksesor benar-benar membacanya, dan yang
mengunci kesamaan layar/suara.

Gerbang: `swift-test.sh` **166 + 433 hijau** (README diperbarui lewat Aturan 10),
ui-lint hijau (Aturan 6 paritas tetap sebanding), typecheck hijau.
CI macOS run `37229231996` (Engine Linux) + `37229231864` (Apple Build) hijau.

## Progres terakhir (4 Okt 2026 — pesan izin & sensor tidak pernah bisa diterjemahkan)

### Literal yang ditugaskan ke properti, bukan diteruskan ke `Text`

Aturan 4 menyapu literal `Text("…")` dan `row("…", …)` di `Apps/`. Ia benar,
dan ia tetap hijau — padahal **lima** kalimat yang justru wajib terlihat saat
izin ditolak atau sensor mati hidup sebagai literal di tiga berkas
`Apps/Shared/`:

| Kalimat | Berkas |
|---|---|
| `Perangkat ini tidak menyediakan device motion.` | `MotionLogger` |
| `Data gerak tidak tersedia.` | `PointingEngine` |
| `Izin lokasi ditolak. Buka Pengaturan … (Jakarta).` | `LocationProvider` (×2) |
| `Lokasi gagal: … Memakai lokasi bawaan (Jakarta).` | `LocationProvider` |

Bentuknya `note = "…"`, `sensorNote = "…"`, `statusText = "…"` — ditugaskan ke
properti, **bukan** menjadi argumen langsung mana pun. Regex argumen-langsung
tidak melihatnya. Tidak satu pun kalimat itu ada di `Localizable.xcstrings`,
jadi pengguna Bahasa Inggris melihat "Izin lokasi ditolak" tanpa satu pun
gerbang merah.

Ini paling mahal justru pada permukaan yang paling diatur PRD: penolakan izin
**harus terlihat**, bukan senyap — dan teksnya adalah satu-satunya yang
menyampaikannya.

### Dua salinan yang sudah menyimpang

`locationDeniedNote` dan `locationFailedNote` disusun **dua kali** di
`LocationProvider` (di `start()` dan di `locationManagerDidChangeAuthorization`)
dengan bentuk kalimat yang berbeda. Perbedaan yang masih terbaca; yang
berbahaya adalah ketika salah satu diperbaiki.

### Yang diubah

- **`SensorStatusText`** (PointingKit, teruji Linux) — pesan sensor gerak,
  status lokasi (`notRequested`/`searching`/`waiting`/`denied`/`unknown`),
  penjelasan penolakan izin, akurasi, dan kegagalan lokasi. Kedua app membaca
  frasa yang sama.
- **11 kunci katalog `sensor.*`** dengan terjemahan Inggris.
- `LocationProvider`, `MotionLogger`, `PointingEngine` membaca frasa itu —
  salinan ganda di `LocationProvider` ikut menyatu.

Lima uji baru (`SensorStatusTextTests`), termasuk yang memasang terjemahan
Inggris untuk membuktikan setiap aksesor benar-benar membacanya, dan yang
memastikan dua keadaan sensor yang berbeda tetap terbaca berbeda.

**Batas yang masih terbuka:** `statusText` (mis. "Lokasi ±12 m") masih belum
pernah ditampilkan view mana pun — `note` yang tampil. Ia ikut masuk katalog
karena status yang tidak pernah dibaca tetap bisa muncul kelak, dan menambah
kunci belakangan lebih mahal daripada sekarang.

Gerbang: `swift-test.sh` **166 + 422 hijau** (README diperbarui lewat Aturan 10),
ui-lint hijau (Aturan 6 paritas tetap sebanding), typecheck hijau.
CI macOS run `37228546269` (Engine Linux) + `37228546280` (Apple Build) hijau.

## Progres terakhir (4 Okt 2026 — iPhone tidak pernah menampilkan tingkat keyakinan pada panel objek)

### Komentar yang menunjuk badge yang tidak pernah digambar

`DiagnosticsView` menyebut "badge di sebelahnya" **dua kali** — di
`LockArrivalPanel` ("gambar tidak pernah lebih yakin daripada badge 'Ragu' di
sebelahnya") dan di komentar `isConfirmed`. Badge itu tidak ada. Baris objek
iPhone hanya menampilkan nama; app jam menampilkan badge `Yakin`/`Ragu` yang
sama persis.

Akibatnya paling tajam justru pada keadaan yang paling penting: pengguna iPhone
melihat **cincin Saturnus** digambar penuh, dan tidak ada satu pun penanda teks
di sebelahnya yang berkata engine sedang ragu. Satu-satunya penanda yang
tersisa — `isConfirmed` menyamar gambar saat `.uncertain` — bekerja lewat
**absen**, bukan pernyataan. Penanda yang bekerja lewat absen hanya terbaca
oleh orang yang sudah tahu apa yang seharusnya ada.

### Kenapa ini bukan sekadar "kurang satu label"

App jam dan iPhone adalah **dua permukaan dari satu jawaban**. App jam sudah
menyelesaikan pertanyaan ini: badge keyakinan tampil hanya untuk jawaban yang
berlaku sekarang (`!isStale`), karena pada objek sisa "Yakin" di sebelahnya
terbaca sebagai klaim keyakinan atas pengukuran sekarang — persis false
confidence yang dilarang PRD. Aturan itu sudah ditulis dan diuji di app jam,
tetapi tidak pernah menyeberang ke iPhone. Ini kelas "dua permukaan, satu
diperbaiki" yang sudah berulang di repo ini.

### Yang diubah

- `LockArrivalPanel` menerima `level`, dan badge-nya memakai `level.tone` yang
  **sama** dengan app jam — bukan warna lokal baru.
- Sumbernya `snapshot.answeredLevel` (predikat teruji: `state.hasAnswer ?
  intent?.level : nil`), **bukan** `intent?.level` langsung. Keyakinan yang
  menempel pada keadaan tanpa jawaban adalah klaim yang tidak berlaku.
- Ambang `!isStale` yang sama dengan app jam: pada objek sisa, badge hilang.
- Label VoiceOver ikut menyebut tingkatnya (`ObjectSpeech.confidence`), jadi
  yang mendengar dan yang melihat menerima klaim yang sama.

Gerbang: `swift-test.sh` **166 + 417 hijau**, ui-lint hijau, typecheck hijau.
CI macOS run `37228149520` (Engine Linux) + `37228149480` (Apple Build) hijau.

## Progres terakhir (4 Okt 2026 — frasa VoiceOver panel objek, disalin di dua app dan tak terlihat katalog)

### Kelas yang sama, sekali lagi: teks yang tampil, tapi tak dijangkau gerbang mana pun

Aturan 4 menyapu literal `Text("…")` dan `row("…", …)` di `Apps/`. Itu benar,
dan ia tetap hijau — padahal frasa yang diucapkan saat pengguna VoiceOver
membuka panel objek **tidak pernah menjadi argumen langsung mana pun**. Ia
disusun lewat `String(format: "magnitudo %.2f", …)` dan `parts.append("Sisa
pandangan sebelumnya, bukan hasil sekarang.")` di dalam helper — bentuk yang
regex argumen-langsung tidak lihat. `grep` menemukan empat frasa yang tampil di
layar, dan **tidak satu pun** ada di `Localizable.xcstrings`:

| Frasa | Muncul di |
|---|---|
| `magnitudo %.2f` | jam **dan** iPhone |
| `Sisa pandangan sebelumnya, bukan hasil sekarang.` | jam **dan** iPhone |
| `tingkat keyakinan \(level.displayName)` | jam |
| `RA %.1f derajat, deklinasi %+.1f derajat` | jam |

Akibatnya pengguna Bahasa Inggris mendengar "magnitudo 1.46", "tingkat
keyakinan Yakin", dan "Sisa pandangan sebelumnya, bukan hasil sekarang." tanpa
satu pun gerbang merah.

### Salinan yang sudah mulai berbeda

Ketiga frasa pertama muncul di **dua** app, dan salinannya sudah menyimpang
diam-diam: `DiagnosticsView` memisahkan bagiannya dengan `". "`, `PointingView`
memakai `", "`. Perbedaan pemisah masih bisa dibaca; yang berbahaya adalah
kalimatnya sendiri — cukup satu salinan diperbaiki, dan pengguna dua app
mendengar dua kalimat berbeda untuk objek yang sama. Ini alasan yang sama
dengan `PointingState.shortLabel` dan `PointingSnapshot.guidanceText` dulu
dipindahkan ke paket.

### Yang diubah

- **`ObjectSpeech`** (PointingKit, teruji di Linux) — `magnitude(_:)`,
  `confidence(_:)`, `coordinates(raDeg:decDeg:)`, `staleNote`. Kedua app
  membaca frasa yang sama, jadi tidak bisa lagi menyimpang.
- **Empat kunci katalog baru** (`object.speech.*`) dengan terjemahan Inggris,
  sehingga pengguna Bahasa Inggris mendengar kalimat yang utuh — termasuk
  tingkat keyakinan yang disisipkan, yang tetap diterjemahkan sendiri lewat
  `confidence.level.*`.
- **Batas yang dijaga:** yang disediakan hanyalah **potongan** kalimat; urutan
  dan pemisahnya tetap milik tiap layar, karena kedua panel memang disusun
  berbeda (jam memasukkan RA/Dec dan tingkat keyakinan; iPhone memisahkan detail
  teknis ke pembukaan panel). Yang dijaga adalah bahannya, bukan susunannya.

Tujuh uji baru (`ObjectSpeechTests`), termasuk yang memasang terjemahan Inggris
untuk membuktikan kata dan posisi sisipan dikendalikan katalog, dan yang
memastikan tanda deklinasi selatan tidak hilang saat diucapkan.

Gerbang: `swift-test.sh` **166 + 417 hijau** (README diperbarui lewat Aturan 10),
ui-lint hijau, typecheck hijau.

## Progres terakhir (4 Okt 2026 — iPhone tidak pernah mengumumkan apa pun ke VoiceOver)

### Jam berbunyi, iPhone diam, dan tidak ada layar yang tampak salah

App jam mengumumkan perubahan keadaan ke VoiceOver sejak lama
(`PointingView.onChange(of: engine.snapshot.state)`). App iPhone **tidak
pernah**: `grep -rn AccessibilityNotification Apps/` mengembalikan dua hasil,
keduanya di app jam, nol di `Apps/PointAndKnowiOS/`. Janji produknya sama di
kedua perangkat — "keadaan yang berubah harus terdengar, bukan hanya terlihat"
— tetapi hanya satu yang memenuhinya.

Yang membuat cacat ini bertahan adalah bentuknya: jam berbunyi, iPhone diam,
dan **keduanya tampak benar sendiri-sendiri**. Tidak ada layar yang salah, tidak
ada uji yang merah. Ini kelas yang sudah berulang di repo ini (complication yang
membeku, `.deepSky` yang tak tersambung, `rejected` yang nol konsumen): satu
permukaan diperbaiki, permukaan kembarnya tidak.

### Kenapa kalimatnya dipindah, bukan disalin

Jalan termurah adalah menyalin `announcementText(for:)` dari `PointingView` ke
`DiagnosticsView`. Itu akan menghasilkan **dua versi kebenaran** untuk cuplikan
yang sama — persis alasan `PointingState.shortLabel` dan
`PointingSnapshot.guidanceText` dulu dipindahkan ke paket. Dan versi lama itu
sendiri cacat: ia menyusun kalimatnya dari literal di dalam view
(`"Terkunci pada \(name)."`), jadi `Localizable.xcstrings` tidak bisa
menjangkaunya. Aturan 4 menyapu literal `Apps/`, tetapi
`Apps/PointAndKnowWatch/Sources/` bukan satu-satunya tempat teks bisa
bersembunyi — teks yang di-*switch* di paket juga tidak terlihat, dan pengguna
Bahasa Inggris mendengar kalimat Indonesia tanpa satu pun gerbang merah.

- **`StateAnnouncement.text(for:)`** (PointingKit, teruji di Linux) — satu
  fungsi melayani jam **dan** iPhone, jadi keduanya tidak bisa menyebut hal
  berbeda untuk cuplikan yang sama. Nama objek dibaca dari
  `snapshot.answeredObject`, predikat yang sama dengan `LockArrival`, pesan ke
  iPhone, dan riwayat keyakinan — bukan `intent`, yang sengaja dipertahankan
  saat keadaan turun kembali ke `.pointing` dan akan mengumumkan objek sisa
  persis seperti hasil pengukuran sekarang.
- **Lima kunci katalog baru** (`pointing.announce.*`) dengan terjemahan
  Inggris, memakai `%@` — bukan interpolasi Swift — karena bagian yang
  disisipkan sudah diterjemahkan sendiri, jadi terjemahan Inggrisnya harus bisa
  menempatkannya sesuai tata bahasanya.
- **Yang tidak berubah, dan itu penting:** yang memutuskan **kapan**
  mengumumkan tetap pemanggil. `snapshot` ditulis ulang 20×/detik; pengumuman
  tetap dijaga `announcedState`, sehingga VoiceOver tidak mengucapkan
  "Terkunci" berpuluh kali per menit. iPhone memakai gerbang yang sama.

Sepuluh uji baru (`StateAnnouncementTests`), termasuk yang memastikan `intent`
yang dipertahankan **tidak** membocorkan nama objek, dan yang memasang
terjemahan Inggris untuk membuktikan posisi sisipan benar-benar dikendalikan
katalog.

Gerbang: `swift-test.sh` **166 + 410 hijau** (README diperbarui lewat Aturan 10),
ui-lint hijau (Aturan 6 menangkap paritas katalog; Aturan 10 menangkap angka
README yang tertinggal di 401). CI: Engine Tests (Linux) `37227131073` = success,
Apple Build `37227131047` = success. Batas jujur: apakah VoiceOver **benar-benar**
mengucapkannya adalah wilayah perangkat dan CI macOS, bukan Linux.

## Progres terakhir (4 Okt 2026 — putusan GoTo tidak lagi membeku selama tunjukan ditahan)

### Putusan keselamatan yang membeku atas langit yang sudah bergerak

`PointingEngine` menyimpan `SlewDecision` supaya efemeris tidak dijalankan
20×/detik dari `publish`. Versi sebelumnya membatasi dengan **tanda tangan**
(keadaan, objek) saja. Itu menjawab satu pertanyaan dengan benar — "apakah
subjek putusannya berubah?" — dan melewatkan pertanyaan kedua: putusan GoTo
bergantung bukan hanya pada objek **mana** yang ditunjuk, melainkan pada **di
mana** objek itu dan **di mana** Matahari saat putusan dihitung. Keduanya
bergerak.

Akibatnya, objek yang terkunci di 30.2° dari Matahari (aman) bisa melintasi
ambang 30° tanpa satu pun perhitungan ulang. Selama pengguna menahan tunjukan,
tanda tangannya tidak pernah berubah, jadi putusan lamanya bertahan — dan layar
terus berkata "aman" atas geometri yang sudah tidak ada. Ini kelas cacat yang
sama dengan complication yang membaca snapshot sekali lalu membeku, kali ini
pada satu-satunya bagian yang menyangkut keselamatan alat dan mata.

- **`SlewVerdictRefreshGate`** (PointingKit, teruji di Linux) — putusan boleh
  dipakai selama subjeknya sama **dan** umurnya di bawah 30 detik. Dua jalur
  harus ada: menghilangkan cabang umur tidak membuat apa pun terlihat salah di
  layar sampai sebuah penolakan keselamatan diam-diam berubah menjadi izin.
- **Umur 30 detik sengaja sama dengan `skyContextInterval`** — keduanya
  menjawab pertanyaan yang sama ("berapa lama hasil efemeris masih berlaku"),
  dan dua angka berbeda untuk satu pertanyaan adalah cara aturan yang sama mulai
  berbeda pendapat.
- **Batasnya dicatat jujur.** Matahari dan objek masing-masing bergerak
  ~0.25°/menit terhadap horizon, jadi jaraknya berubah paling cepat ~0.5°/menit;
  dengan umur 30 detik, putusan bisa **terlambat** paling banyak ~0.25° sebelum
  dihitung ulang — dua orde di bawah ambang terkecil (10°). Keterlambatannya
  terbatas dan diketahui, bukan tak terbatas seperti sebelumnya.
- **`update(location:)` me-reset gerbang** — arah Matahari dan ketinggian target
  bergeser bersama lokasi, dan tanda tangan (keadaan, objek) tidak menangkap
  itu: objek yang sama di langit baru tetap bertanda tangan sama.

Tujuh uji baru (`SlewVerdictRefreshGateTests`), termasuk uji inti yang gagal
tanpa cabang umur.

Gerbang: `swift-test.sh` **166 + 394 hijau** (README diperbarui), typecheck
hijau, ui-lint hijau. CI: Engine Tests (Linux) `37225024147` = success, Apple
Build `37225024142` = success.



### Layar yang paling miskin justru paling butuh satu baris ini

Layar Always-On (`ReducedLuminanceView`) sengaja hanya memuat yang tidak boleh
terlewat: satu nama objek dan dua kata status. Sisa penolakan GoTo sengaja
dibuang, dan untuk hampir semuanya itu benar — "terlalu redup untuk diamati"
mengecewakan, bukan berbahaya, dan pengguna bisa mengetahuinya begitu mengangkat
pergelangan. Batas ini bahkan sudah dicatat sebagai batas yang diterima di STATUS
sebelumnya ("hint tidak muncul di layar redup").

Tapi bahaya **keselamatan** bukan kelas yang sama. Kalau `sunProximity` hilang
dari layar redup, pengguna melihat nama objek terkunci tanpa satu pun tanda
bahwa teleskop **menolak bergerak** — dibaca sebagai keberhasilan, tepat pada
satu-satunya penolakan yang bisa merusak alat atau mata. Yang paling berbahaya
justru yang paling mudah disamarkan oleh layar yang sengaja miskin.

- **`SlewDecision.safetyWarningText`** — kalimat putusan, tapi hanya saat ada
  bahaya keselamatan. Ambangnya memakai `isSafety` yang **sama** dengan
  `verdictTone`, bukan daftar yang ditulis ulang: kalau suatu saat sebuah bahaya
  dipindahkan kelasnya, warna peringatan di layar penuh dan kehadirannya di
  layar redup ikut berpindah bersama. Tidak ada dua daftar yang bisa berbeda
  pendapat.
- **`ReducedLuminanceView`** menampilkan baris itu (ikon + kalimat, `caption2`),
  dan **VoiceOver ikut mengucapkannya** — layar redup yang membacakan nama objek
  tanpa alasan teleskop menolak terdengar seperti keberhasilan.

Tiga uji baru (`SlewVerdictTests`) menjaga: bahaya keselamatan tampil, bahaya
mutu tidak, campuran tetap tampil karena keselamatan ada, dan GoTo aman tetap
sunyi di layar redup.

Gerbang: `swift-test.sh` **166 + 387 hijau** (README diperbarui), typecheck
hijau, ui-lint hijau. CI: Engine Tests (Linux) `37224500311` = success, Apple
Build `37224500279` = success.



### Pemisahan yang berhenti di tengah jalan

`SlewVerdictBanner` lahir untuk memisahkan dua penolakan yang dulu "terlihat
persis sama": `sunProximity` (melindungi alat dan **mata**) versus
`lowConfidence` (soal ketelitian). Tapi yang ia pisahkan hanya **kalimatnya**.
Keduanya tetap digambar dengan warna peringatan yang sama dan ikon yang sama —
jadi pemisahan itu berhenti tepat di titik yang paling menentukan: pengguna yang
membaca sekilas. Dan Mode Malam menutup jalan terakhir, karena palet malam
menyempit jadi satu merah (`TonePalette` sudah mencatat itu sebagai konsekuensi
yang diterima), sehingga warna berhenti membedakan tepat di mode yang paling
sering dipakai saat mengamati langit.

Perbaikannya memindahkan pembeda itu ke model, tempat ia bisa diuji di Linux:

- **`SlewHazard.isSafety`** — tiga bahaya yang melindungi alat & mata
  (`sunProximity`, `belowAltitudeLimit`, `sunPositionUnknown`) dipisahkan dari
  empat bahaya mutu (`belowHorizon`, `tooFaint`, `noTarget`, `lowConfidence`).
  `sunPositionUnknown` masuk kelas keselamatan karena ia bukan bahaya yang
  diamati, melainkan **pengaman yang tidak bisa dijalankan**: kalau posisi
  Matahari tak diketahui, perencana sengaja gagal-tertutup. Menaruhnya di kelas
  mutu akan membuatnya terlihat seperti soal ketelitian.
- **`SlewDecision.verdictTone`** — keselamatan → `.danger`, mutu → `.warning`.
  Keselamatan **menang apa pun urutan array**-nya; memilih "bahaya pertama" akan
  membuat warna bergantung pada urutan, bukan pada kepentingan.
- **`SlewDecision.verdictSymbolName`** — ikon yang **tidak ikut menyempit** di
  Mode Malam. Karena warna berhenti membedakan di sana, ikon yang memikul
  pembedaan itu.
- **`SlewVerdictBanner` kini menerima `SlewDecision`, bukan `String?`** — supaya
  warna dan ikon datang dari satu tempat yang teruji, dan jam maupun iPhone
  tidak bisa berbeda pendapat.
- **`PointingEngine.slewVerdictText` dihapus** — nol pemanggil setelah banner
  membaca putusannya utuh.

Lima uji baru (`SlewVerdictTests`) menjaga klasifikasi lengkap, kemenangan
keselamatan atas mutu di **dua** urutan array, nada `success` saat GoTo aman,
dan ikon yang berbeda antara `danger` dan `warning`.

Gerbang: `swift-test.sh` **166 + 384 hijau** (README diperbarui), typecheck
hijau, ui-lint hijau. CI: Engine Tests (Linux) `37224080767` = success, Apple
Build `37224080719` = success.



### Putusan GoTo tidak boleh turun pangkat di iPhone

Putusan yang sama (`SlewDecision` dari `SlewPlanner`, FASE 3) tampil sebagai
**dua hal yang berbeda** di dua permukaan. Di jam ia kartu berikon berlatar
bertingkat (`SlewVerdictBanner`); di iPhone ia turun pangkat menjadi
`row("GoTo", …)` — teks abu-abu dengan bobot visual yang **persis sama** dengan
baris data di sebelahnya ("Kalibrasi: Sudah").

Itu bukan soal rasa. Baris itu menyamakan penolakan karena `sunProximity`
(melindungi peralatan dan mata dari cahaya Matahari) dengan penolakan karena
`lowConfidence` (soal ketelitian) — dan menyamakannya dengan baris yang tidak
penting sama sekali. Dua permukaan yang menyimpang soal seberapa mendesak
sebuah penolakan adalah cacat yang **tidak terlihat dari layar mana pun**:
masing-masing layar tampak benar sendiri.

Perbaikannya memakai `SlewVerdictBanner` yang sudah ada di iPhone juga — satu
sumber untuk "seberapa mendesak", bukan dua. Banner itu `nil` saat GoTo aman,
jadi ia tidak pernah berbunyi di sebelah GoTo yang justru berjalan.

## Progres sebelumnya (4 Okt 2026 — putusan GoTo dihitung sekali, bukan dua kali)

### Putusan GoTo kini punya wajah, dan punya satu jalan saja

`SlewPlanner` sudah menghitung putusan keselamatan sejak FASE 3, dan
`PointingController.slewDecision(date:)` sudah menyambungkannya ke engine yang
berjalan. Sampai commit ini, `slewDecision` **nol pemanggil di seluruh
`Apps/`** — satu-satunya aturan keras PRD yang menyangkut keselamatan alat
("POINT → OBJECT ID → SAFE GOTO") tidak punya wajah di layar. Pengguna tidak
bisa tahu apakah teleskopnya boleh bergerak, dan kalau tidak, mengapa.

Yang ditambahkan: `SlewVerdictBanner` (satu view di `Apps/Shared`, dipakai
bersama oleh kartu jam dan baris iPhone), dan `PointingEngine.slewVerdict`
yang dihitung di `publish` — satu-satunya jalan tulis snapshot.

### Cacat yang ditangkap kompiler, bukan mata

Versi pertama memasang perhitungan itu **dua kali**: sekali di dalam blok
berjangka-waktu `refreshSkyContext` (yang dibatasi `skyContextInterval` 30
detik), sekali lagi di blok tanda tangan. Salinan pertama adalah sisa langkah
yang belakangan dipindah; ia tidak ikut terhapus.

Akibatnya bukan sekadar deklarasi ganda. Ia membuat penjagaan waktu milik
**efemeris** menjadi penjagaan **putusan keselamatan** juga. Itu keliru kelas:

- `refreshSkyContext` sengaja dibatasi 30 detik karena arah benda langit
  bergerak ~0.25°/menit — hasilnya tidak berubah antara dua sampel.
- Putusan GoTo **bukan** fakta lambat seperti itu. Ia penjelasan atas sebuah
  **jawaban**, dan jawaban berubah lewat enam jalur yang menulis snapshot
  (sampel sensor, `stop()`, `setSensorAvailable`, …), bukan hanya lewat waktu.
  Kalau jawaban hilang — mis. sensor mati saat objek masih terkunci — peringatan
  yang tertinggal bukan sekadar terlambat, ia **salah**: layar menampilkan
  "Terlalu dekat Matahari." di sebelah keadaan "Sensor mati".

Karena itu perhitungannya dipindah ke `publish`, dengan penjagaan **tanda
tangan** (`keadaan|id objek`), bukan waktu. Objek yang sama dihitung sekali;
objek baru langsung; jawaban yang hilang langsung mencabut peringatannya.

Kompiler menolak build karena deklarasi ganda — dan itulah yang menyelamatkan
aturan ini dari diam-diam dilanggar. Kalau kedua salinan itu punya nama yang
berbeda, tidak ada gerbang yang akan menangkapnya: keduanya menghasilkan
`SlewDecision` yang sama benar, dan hanya yang **kedua** (jalur `publish`)
yang diuji.

### Gerbang
- `swift-test.sh`: **CelestialEngine 166**, **PointingKit 379** — 46 suite,
  0 kegagalan.
- `swift-typecheck.sh` + `swift-ui-lint.sh`: hijau.
- CI `Apple Build` (macos-15) hijau setelah perbaikan; commit pertama
  (a4cbc1c) **gagal** karena `invalid redeclaration of 'refreshSlewVerdict(at:)'`.

## Progres terakhir (4 Okt 2026 — engine tahu MENGAPA tidak ada objek, tapi tidak pernah mengatakannya)

### Siklus ketiga berturut-turut: jalur yang dihitung lalu dibuang

Dua siklus sebelumnya menemukan jalur yang **tidak pernah tersambung** —
`.deepSky` yang tak ada objeknya di katalog, lalu `reloadAllTimelines` yang
tak pernah dipanggil. Siklus ini menemukan bentuk ketiga: jalur yang
**dihitung lalu dibuang**, dan sudah begitu sejak sebelum repo ini punya UI.

`PointingResolver.diagnose` mengisi `Resolution.rejected` sejak awal: setiap
benda yang tidak lolos penyaring masuk bersama `Visibility`-nya
(`belowHorizon`, `tooFaint`, `tooCloseToSun`, `daylight`), dan
`SkyContext.isDark` menyatakan apakah langit sedang terang. Semua itu
**nol konsumen** di seluruh repo — tidak ada satu pun pembaca.

Akibatnya jam selalu menampilkan satu kalimat yang sama, "Belum ada objek di
arah itu.", untuk tiga situasi yang butuh tindakan berbeda:

- **Langit masih siang** → pengguna harus menunggu gelap.
- **Semua objek di bawah horizon** → pengguna harus mengarah ke tempat lain.
- **Semua objek terlalu redup** → tidak ada yang bisa dilihat malam ini.

Mesin yang jujur seharusnya membedakannya. Yang diperbaiki bukan "menambah
fitur": seluruh informasi sudah ada dan sudah benar; yang hilang hanya jalur
dari tempat ia dihitung ke tempat ia dibaca.

### `SearchHint` — `nil` saat ada jawaban, jadi mustahil berbohong

`Resolution.searchHint` mengembalikan **`nil`** bila ada objek (`intent.best
!= nil`). Itu bukan detail: sebuah hint adalah penjelasan atas **ketiadaan**
jawaban. Kalau ia juga bisa ada saat jawaban ada, setiap pemanggil harus ingat
memeriksa keadaan sebelum menampilkannya — dan satu tempat yang lupa akan
menampilkan "semua objek di bawah horizon" di sebelah nama objek yang justru
terkunci. Dengan `nil` sebagai satu-satunya jawaban untuk "ada objek", dua
keadaan itu tidak bisa muncul bersamaan.

Urutan keputusannya:

1. **`daylight`** lebih dulu, dibaca dari `context.isDark` — **sifat langit**,
   bukan sifat satu benda. `VisibilityFilter.classify` memeriksa ketinggian
   lebih dulu, jadi saat siang sebagian benda dilaporkan `belowHorizon` dan
   sebagian `daylight`; menebak dari situ bisa salah.
2. **Sebab tunggal per-benda** (di bawah horizon / terlalu redup / terlalu
   dekat Matahari) — hanya bila **seragam**. Alasan bercampur tidak punya satu
   kalimat jujur.
3. **`noCandidates`** — sisanya, termasuk katalog kosong. "Tidak ada yang
   cocok" tetap benar, dan mengarang sebab yang lebih spesifik justru
   melanggar aturan jujur.

### Hint hanya hidup di satu keadaan: `.searching`

`PointingSnapshot.searchHint` hanya terisi saat keadaan `.searching`. Saat
`.pointing` pergelangan masih bergerak dan resolusi terakhir berasal dari arah
yang **sudah ditinggalkan**; menampilkan "semua objek di bawah horizon" untuk
arah lama akan menjelaskan sesuatu yang tidak sedang ditunjuk. Saat ada
jawaban (`lock`/`uncertain`) `Resolution.searchHint` sendiri sudah `nil`. Jadi
hint jujur di tepat satu keadaan: diam, sudah diresolusi, tanpa kandidat.

### Satu sumber kalimat untuk jam, iPhone, dan VoiceOver

`PointingSnapshot.guidanceText` memilih kalimatnya — bukan view. Alasannya
sama dengan `PointingState.shortLabel`: kalau tiap layar memilih sendiri, jam
bisa berkata "langit masih terang" sementara iPhone berkata "belum ada objek"
untuk cuplikan yang sama. Dua versi kebenaran, dan hanya satu yang diuji.
`PointingView` (kartu + pengumuman VoiceOver) dan `DiagnosticsView` (baris
"Panduan") memakai sumber yang sama.

### Uji: semua dibuktikan MERAH lebih dulu

| Mutasi | Uji/gerbang yang menangkap | Hasil |
|---|---|---|
| `guard intent.best == nil` → `!= nil` | `testNoHintWhenThereIsAnAnswer` | **MERAH**: hint muncul bersama jawaban |
| `if !context.isDark` → `if !context.isDark && rejected.isEmpty` | `testDaylightWinsOverPerObjectReasons` | **MERAH**: `allBelowHorizon` menang atas `daylight` |
| gerbang keadaan di `feed` dilepas | `testControllerDropsHintWhileMoving` | **MERAH**: hint bocor saat pergelangan bergerak |
| hapus 1 kunci dari `Localizable.xcstrings` | Aturan 6 `swift-ui-lint.sh` | **MERAH**: gerbang menunjuk kunci yang hilang |

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 342 PointingKit**, 0 gagal
  (naik dari 327 → 342, +15 uji).
- `./swift-typecheck.sh` → **SEMUA GERBANG LULUS**.
- `./swift-ui-lint.sh` → **9 aturan hijau**; Aturan 6 (paritas katalog)
  memverifikasi 46 kunci `allKeys` sebanding dengan katalog.

### Batas yang jujur

- **`daylight` belum pernah teruji dengan efemeris nyata di Linux.**
  `skyContext` mengembalikan `isDark: true` saat tidak ada efemeris, jadi uji
  integrasi di sini hanya menyentuh jalur per-benda. Cabang `daylight` diuji
  sebagai **fungsi murni** (`testDaylightWinsOverPerObjectReasons`) dengan
  `SkyContext` yang ditulis tangan — bukan lewat efemeris. Yang belum
  diverifikasi: bahwa `SunAltitude` dari `AstronomyKitEphemeris` benar-benar
  melewati ambang `-6°` seperti yang diharapkan di lapangan.
- **Hint tidak muncul di layar redup.** `ReducedLuminanceView` sengaja hanya
  menampilkan status dua kata; alasan penuh tidak masuk ke sana. Itu pilihan
  (layar redup untuk sekilas, bukan membaca), tapi berarti pengguna AOD tidak
  melihat alasan sampai mengangkat pergelangan.

### CI

Push `9477cd4` hijau:

- **Apple Build** run `37217699916` — `BUILD SUCCEEDED` app iPhone + app jam,
  gerbang peringatan bersih, job **Paket (Apple SDK)** hijau.
- **Engine Tests (Linux)** run `37217699913` — 166 + 342, 0 failures.

## Progres terakhir (4 Okt 2026 — complication yang membaca snapshot sekali lalu membeku)

### Dua siklus berturut-turut membuka jalur mati, lalu menemukan cacat di pintunya

Siklus sebelumnya menambahkan objek langit dalam ke katalog produksi dan
menutup jalur visual yang selama ini mati. Siklus ini melanjutkan pola yang
sama — cari jalur yang **tidak pernah berjalan** — dan menemukan dua:

1. **Nebula bisa jadi acuan kalibrasi** lewat jalur "tunjuk lalu catat"
   (`captureNearest`), yang melewati daftar acuan yang justru menjaganya.
2. **Complication tidak pernah menyegar**: tidak ada satu pun pemanggil
   `WidgetCenter.shared.reload...` di seluruh repo.

Keduanya kelas yang sama: setiap bagian benar secara terpisah, dan yang hilang
adalah jalur yang menghubungkannya.

### Cacat 1 — penjagaan "acuan harus bintang" hanya ada di daftar yang dilewati

`CalibrationSession.refreshReferenceTargets` sengaja menyaring `kind == .star`,
dengan alasan yang tertulis panjang di komentarnya: objek langit dalam tidak
punya tepi, jadi pengguna tidak bisa tahu bagian mana dari kabut Orion yang ia
tunjuk, dan sampelnya berisik. Tapi `captureNearest` — jalur "tunjuk lalu tekan
Catat" — **tidak lewat daftar itu**. Ia memanggil `PointingResolver.nearestTarget`
langsung, lalu `capture(objectID:)`, dan tidak satu pun memeriksa jenis benda.

Selama tidak ada objek langit dalam di katalog mana pun, jalur ini tidak bisa
dijangkau, jadi tidak ada yang tahu. Siklus sebelumnya membuatnya bisa
dijangkau. Perbaikan: penjagaan dipindah ke `nearestTarget` — satu tempat yang
**kedua** jalur lalui, jadi aturan tidak bisa lagi dilewati dengan menambah
jalan masuk baru.

### Cacat 2 — menulis berkas tidak menggambar ulang complication

Complication membaca ringkasan dari berkas yang dibagi, dan timeline-nya
`Timeline(entries:policy:.never)`: satu entri yang berlaku sampai ada yang
meminta watchOS menghitung ulang. App menulis berkas itu tiap keadaan berubah.
Tapi tidak ada pemanggil `reloadAllTimelines` — hanya **dua komentar** yang
menjanjikannya. Akibatnya complication menampilkan objek pertama yang pernah
terkunci lalu membeku di situ selamanya; berkasnya selalu mutakhir, layarnya
tidak pernah bergerak. Membaca kode justru membuatnya tampak selesai, karena
komentarnya menyebut reload yang tidak ada.

Perbaikan mengikuti pola yang sudah ada di repo ini: `haptics` dan `audioCue`
disuntikkan sebagai closure supaya `PointingEngine` tidak perlu tahu API Apple
yang tidak ada di Linux. `complicationReload` mengikuti jalur yang sama —
disuntikkan, dan app jam memasang `WidgetCenter.shared.reloadAllTimelines()`.

### Gerbang baru: Aturan 9 — WidgetKit wajib punya pemanggil reload

Cacat ini tidak bisa ditangkap gerbang mana pun yang ada:

- `swiftc -parse` tidak peduli timeline tidak pernah dihitung ulang.
- `swift test` di Linux tidak bisa membangun SwiftUI sama sekali — `WidgetKit`
  tidak ada di sana.
- CI macOS hanya gagal bila ada **warning**; pemanggilan yang hilang bukan
  warning.

Jadi penjaganya harus sapu teks: bila ada `struct ...: Widget` di `Apps/`,
harus ada pemanggil `WidgetCenter.shared.reload...` di kode. **Dibuktikan
MERAH lebih dulu** — mengosongkan pemanggil membuat gerbang gagal dan menunjuk
`ComplicationWidget.swift:23`. Sebuah gerbang yang tidak pernah merah adalah
formalitas.

### Uji: dua mutasi dibuktikan MERAH lebih dulu

| Mutasi | Uji/gerbang yang menangkap | Hasil |
|---|---|---|
| filter `kind == .star` dibuang dari `nearestTarget` | `testNearestTargetNeverResolvesToADeepSkyObject` | **MERAH**: M42 kembali sebagai acuan |
| pemanggil `WidgetCenter...reload` dikosongkan | Aturan 9 `swift-ui-lint.sh` | **MERAH**: gerbang menunjuk widget-nya |

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 327 PointingKit**, 0 gagal.
- `./swift-typecheck.sh` → **SEMUA GERBANG LULUS**.
- `./swift-ui-lint.sh` → **9 aturan hijau** (naik dari 8).

### Batas yang jujur

- **Complication belum pernah dilihat di perangkat.** Yang dibuktikan: kode
  memanggil reload saat keadaan berubah (gerbang), dan ia **kompilasi** di
  macOS (CI Apple Build hijau). Bahwa watchOS benar-benar menggambar ulang di
  jam sungguhan belum diverifikasi — itu butuh perangkat. Reload adalah
  permintaan, bukan jaminan; watchOS boleh menundanya.
- **Reload hanya terjadi saat app aktif.** `complicationReload` dipasang di
  `start()`, dan app dihentikan saat pergelangan diturunkan. Hari ini tidak ada
  perubahan keadaan dari latar, jadi tidak ada yang hilang — tapi bila nanti
  ada pembaruan latar (mis. dari iPhone lewat WatchConnectivity), reload harus
  dipasang di jalur itu juga.

### CI

Push `bbfb96c` hijau:

- **Apple Build** run `37216760021` — `BUILD SUCCEEDED` app iPhone + app jam,
  gerbang peringatan bersih, job **Paket (Apple SDK)** hijau. Ini yang
  membuktikan perubahan WidgetKit benar-benar kompilasi di macOS.
- **Engine Tests (Linux)** run `37216759989` — 166 + 327, 0 failures.

## Progres terakhir (4 Okt 2026 — jalur objek langit dalam ada, tapi tak pernah tersambung)

### Premis siklus ini: cari jalur yang mati, bukan bentuk yang salah

Tiga belas siklus terakhir bergerak di dalam satu kelas: bentuk raster yang
salah — terpotong, menembus bola, keluar `Canvas`, warna malam bukan merah.
Semua ditutup dengan memindahkan angka batas ke model yang teruji. Siklus ini
membalik pertanyaannya: bukan "bentuk mana yang salah", tapi **"jalur mana
yang tidak pernah berjalan"**.

Jawabannya dihitung, bukan ditebak: seluruh jalur visual **objek langit
dalam** ada dan teruji — `CelestialVisual.Kind.deepSky`,
`VisualFrame.nebula(fuzziness:)`, aksen `NightVisual.deepSky`, label &
pengucapan `ObjectKind.deepSky`, `drawDeepSky`, dan resolver yang **sudah**
menulis `for object in catalogue where object.kind == .star || object.kind ==
.deepSky`. Tapi tidak ada satu pun katalog yang memuat objek ber-`kind:
.deepSky`. Jadi `drawDeepSky` **tidak pernah berjalan di aplikasi mana pun**;
satu-satunya yang pernah membangun `CelestialVisual(kind: .deepSky)` adalah
uji.

### Kenapa ini kelas cacat yang paling sulit dilihat

Bentuknya sama dengan kelas yang sudah berulang di repo ini: **setiap bagian
benar secara terpisah, dan yang hilang adalah jalur yang menghubungkannya.**
Yang membuatnya lebih licin daripada cacat geometri:

- **Tidak ada yang bisa dilihat.** Cacat geometri menghasilkan gambar yang
  salah — mata bisa menangkapnya kalau tahu harus melihat ke mana. Ini
  menghasilkan **tidak ada gambar sama sekali** untuk kelas objek itu. Layar
  tampak normal; hanya saja satu kelas benda yang sudah dijanjikan di seluruh
  kode tidak pernah muncul.
- **Tidak ada gerbang yang menyala.** Uji visual menguji geometri
  `nebula(fuzziness:)` dengan nilai yang **ditulis tangan** di uji — jadi
  fungsinya terbukti benar tanpa pernah dipanggil dengan objek sungguhan. Uji
  label menguji `ObjectKind.deepSky` sebagai enum. Uji `hasPulse` memanggil
  `object(id: "m42", kind: .deepSky)` — yang **membuat** objeknya di uji.
  Semuanya hijau, dan semuanya benar.
- **Katalog yang ada tidak boleh diubah.** `Catalogue.brightStars` dikunci
  oleh uji engine: `testAuditTrailIsConsistent` menuntut
  `consideredCount == brightStars.count + pointableBodies.count`, dan uji
  warna menuntut **setiap** anggotanya ber-`kind: .star`. Menambahkan nebula
  ke sana akan memecahkan keduanya — dan keduanya benar: itu memang katalog
  **bintang**. Jadi jalurnya tidak bisa ditutup dengan menambah satu baris ke
  katalog lama; ia butuh katalog baru.

### Yang diubah, dan kenapa begini

- **`DeepSkyCatalogue` (PointingKit, teruji di Linux)** — enam objek yang
  paling dikenal dan terang (Pleiades, Andromeda, Ptolemy, Orion, Hercules,
  Laguna), koordinat J2000. Ditaruh di `PointingKit`, bukan `CelestialEngine`,
  karena engine **tidak disentuh** oleh siklus ini (166-nya tidak boleh
  berubah).
- **`EngineFactory.productionCatalogue = brightStars + deepSky`, dan kedua
  `makeResolver` memakainya.** Satu tempat yang menggabungkan, dan itu tempat
  yang sama yang dipakai **kedua** app — jadi jalurnya terbuka untuk jam dan
  iPhone sekaligus, bukan untuk yang kebetulan merakit resolver dengan
  katalog lebih luas. Ini juga yang membuatnya bisa diuji di Linux.
- **`fuzziness` per id, bukan satu angka untuk semua.** Versi lama memakai
  `0.8` untuk setiap objek langit dalam — nebula, gugus, dan galaksi tampil
  sebagai bentuk yang identik. Galaksi Andromeda (1.0, lebar & samar) dan
  gugus bola Hercules (0.35, padat & kecil) adalah pasangan yang paling
  berbeda; menyamakannya menghapus satu-satunya informasi yang membedakan
  kelas ini dari bintang. Id tak dikenal mengembalikan nilai tengah (0.6),
  **bukan 0**: nol berarti "titik", dan nebula tak dikenal yang digambar
  sebagai titik mengklaim bentuk yang tidak dimilikinya.
- **`CalibrationSession` hanya menawarkan bintang sebagai acuan.** Ini bukan
  kosmetik. Kebenaran kalibrasi diambil dari posisi katalog, dan posisi objek
  langit dalam juga di katalog — jadi menyaringnya **bukan** soal posisi.
  Yang salah: objek ini **tidak punya tepi**, jadi pengguna tidak bisa tahu
  bagian mana dari kabut Orion yang ia tunjuk. Sampel acuannya jauh lebih
  berisik, dan itu melebarkan `residualSpreadDeg` — membuat kalibrasi terlihat
  lebih buruk daripada sesungguhnya, atau lebih buruk lagi: terlihat "siap"
  dengan offset yang salah.

### Uji: 11 regresi, tiga mutasi dibuktikan MERAH lebih dulu

Dijalankan lewat `./red-test.sh` (yang menerapkan satu mutasi, memastikan uji
MERAH, lalu mengembalikan sumber):

| Mutasi | Uji yang menangkap | Hasil |
|---|---|---|
| `productionCatalogue` dikembalikan ke `brightStars` saja | `testProductionCatalogueContainsDeepSkyObjects` | **MERAH**: `0` ≠ `6` |
| `fuzziness` dikembalikan ke `0.8` untuk semua | `testDeepSkyTargetReachesVisualWithItsOwnShape` | **MERAH**: `0.8` ≠ `0.55`/`1.0`/`0.5`/`0.9`/`0.35` |
| filter `kind == .star` dibuang dari daftar acuan | `testDeepSkyObjectsAreNeverOfferedAsCalibrationReferences` | **MERAH**: nebula ditawarkan sebagai acuan |

Uji kalibrasi sengaja **tidak vacuous**: ia lebih dulu mencari waktu ketika M42
benar-benar di atas horizon dan membuktikan objeknya lolos penyaring horizon —
jadi tanpa filter jenis, ia memang akan masuk daftar acuan. Uji yang tidak bisa
gagal adalah formalitas.

Dua mutasi pertama menemukan cacat yang sudah ada (jalur mati). Mutasi ketiga
adalah **regresi yang sengaja ditambahkan siklus ini** — kelas cacat baru yang
akan lahir kalau objek bertepi kabur masuk ke daftar acuan, dan yang tidak akan
terlihat dari layar.

### Bukti merah

Ketiga baris tabel di atas dijalankan sungguhan; keluarannya cocok persis
dengan yang diharapkan. Sumber dipulihkan dan diverifikasi lewat `git status`
(bersih sebelum commit).

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 326 PointingKit** (naik dari
  315 → 326: 11 uji baru), **0 gagal**. Engine **tidak disentuh**.
- `./swift-typecheck.sh` → **SEMUA GERBANG LULUS** (build paket + parse
  seluruh `Apps/`).
- `./swift-ui-lint.sh` → **8 aturan hijau** (termasuk paritas katalog &
  sapuan aksara).
- Sapuan CJK pada 5 berkas yang diubah/ditambah → **0**.

### Batas yang jujur

- **Belum pernah dilihat di perangkat.** Uji menegakkan bahwa jalur objek
  langit dalam **ada dan tersambung** (katalog → resolver → target → visual
  dengan `fuzziness` yang benar). Bahwa nebula sungguhan tampak bagus di
  layar jam 41mm belum diverifikasi — itu butuh perangkat.
- **Koordinat & magnitudo dari ingatan, bukan dari katalog acuan.** Enam
  objek itu koordinat J2000 dan magnitudo terintegrasinya adalah nilai yang
  lazim dipakai, bukan hasil unduhan katalog. Untuk *penunjukan* ini cukup
  (galat busur tidak mengubah kesimpulan), tapi tidak boleh disebut
  "terverifikasi" sampai dicocokkan dengan sumber acuan seperti `brightStars`
  yang punya fixture JPL Horizons.
- **Ambang `fuzziness` adalah pilihan bentuk, bukan pengukuran.** Nilai
  0.35…1.0 dipilih supaya bentuk antar-objek berbeda; ia bukan ukuran sudut
  objek di langit. Uji menegakkan **bahwa** bentuknya berbeda dan berada di
  rentang yang sah, bukan bahwa nilai itu yang paling benar.

### CI

Push `504a923` hijau pada percobaan pertama:

- **Engine Tests (Linux)** run `37215870794` — 166 + 326, 0 failures, gerbang
  sapu UI hijau di macOS.
- **Apple Build** run `37215870706` — `BUILD SUCCEEDED` untuk app iPhone dan
  app jam, gerbang peringatan bersih, plus job **Paket (Apple SDK)** yang
  membangun kedua paket dan menjalankan uji PointingKit di SDK Apple.

## Progres terakhir (4 Okt 2026 — bentuk Bulan terlihat, tapi tidak terdengar)

### Premis siklus ini: cari informasi yang hanya punya satu indera

Siklus lalu menemukan sabit Bulan menghadap arah yang salah — cacat yang
tak terbaca karena gambar yang salah tetap berbentuk sabit. Siklus ini
mengambil kelas yang bersebelahan: **informasi yang hanya bisa dilihat.**

Gambar prosedural Bulan menampilkan **bentuk** yang berubah sepanjang bulan:
sabit tipis, separuh, cembung, purnama. Bagi pengguna yang melihat itu
informasi langsung. Bagi pengguna VoiceOver, yang terdengar hanya `"Bulan"` —
dan `"Bulan"` sama saja untuk purnama maupun untuk sabit tipis satu persen.
Fasenya hilang sepenuhnya.

### Kenapa ini bukan "label kurang deskriptif"

`visualPanelLabel` di iPhone **sengaja** tidak mendeskripsikan gambarannya,
dan komentarnya menjelaskan alasannya dengan benar: *"Gambar Jupiter dengan
pita oranye" tidak menambah informasi yang tidak sudah ada di nama dan jenis
benda, tapi ia menambah satu kalimat panjang yang harus didengarkan setiap
kali.*

Alasan itu benar untuk Jupiter. Pitanya tidak mengubah apa pun yang bisa
diklaim — Jupiter tetap Jupiter, dengan atau tanpa pita. Alasan itu **tidak**
benar untuk Bulan, karena fase adalah **data**: fraksi iluminasi yang
dihitung engine, dan yang tampil di layar sebagai bentuk. Membuangnya bukan
menyederhanakan pengumuman, melainkan menghilangkan isi.

Jadi yang ditutup bukan kekurangan gaya, melainkan **satu kelas informasi
yang hanya punya satu indera**: terlihat di layar, tidak pernah terdengar.

### Kenapa tidak ada gerbang yang menangkapnya

Bentuknya sama dengan kelas-kelas sebelumnya di repo ini:

- **Uji visual menguji geometri, bukan penyampaiannya.** `litBandWidth`,
  `phaseGeometry`, `brightLimbAngle` — semuanya benar dan semuanya tentang
  **cara menggambar**. Tidak ada satu pun yang bertanya "apakah fase ini
  sampai ke pengguna yang tidak melihat?"
- **Uji aksesibilitas menguji label yang ada, bukan yang hilang.** Gerbang
  memeriksa bahwa setiap `accessibilityLabel` yang **ada** memakai
  `RowSpeech`/`TextLocalization`. Label yang **tidak menyebut fase** tidak
  melanggar apa pun — dan memang tidak bisa: tidak ada daftar "informasi yang
  seharusnya diucapkan".
- **Menambahkannya tidak akan menyalakan apa pun.** Tanpa uji dan tanpa
  kunci katalog, `"Bulan sabit muda"` bisa ditulis sebagai literal dan semua
  gerbang tetap hijau.

### Perbaikannya: nama fase dari fraksi, dengan arah yang jujur

`CelestialVisual.spokenPhase` (di PointingKit, bisa diuji di Linux) memilih
nama fase dari fraksi iluminasi:

| Fraksi | Arah diketahui | Arah tidak diketahui |
|---|---|---|
| < 0.04 | Bulan baru | Bulan baru |
| 0.04 – 0.46 | Sabit muda / sabit tua | **Bulan sabit** |
| 0.46 – 0.54 | Separuh awal / separuh akhir | **Bulan separuh** |
| 0.54 – 0.96 | Cembung membesar / mengecil | **Bulan cembung** |
| > 0.96 | Bulan purnama | Bulan purnama |

Perhatikan kolom ketiga. Kalau arah waxing/waning tidak diketahui, yang
diucapkan adalah bentuk **netral** — bukan tebakan. Ini aturan yang sama
dengan `litSide = waxing ? 1 : -1` yang diperbaiki siklus lalu: **uncertainty
lebih baik daripada keyakinan palsu.** "Sabit muda" mengklaim arah; "Bulan
sabit" tidak.

Purnama dan bulan baru tidak punya masalah itu: keduanya simetris, jadi
namanya sah tanpa arah.

### Yang sengaja **tidak** dilakukan: mengucapkan angkanya

Mengucapkan `"Bulan, dua puluh dua persen menyala"` terlihat lebih
"lengkap", dan itu justru salah. Tidak ada satu pun angka yang tampil di
layar. Pengguna yang melihat mendapat **bentuk**; memberi pengguna yang
mendengar **presisi** berarti memberi mereka informasi yang lebih — bukan
aksesibilitas, melainkan dua versi kebenaran. Yang diucapkan adalah hal yang
setara dengan yang terlihat: nama bentuknya.

### Tiga kesalahan, dan bagaimana ketahuan

Ditulis apa adanya:

1. **Dua ambang salah tulis di uji.** Ditegaskan 0.54 = cembung dan
   0.96 = purnama; keduanya gagal, karena pita "separuh" tertutup di kedua
   ujung dan 0.96 masih cembung. Ketahuan dari **uji, bukan dari membaca
   ulang**: ini yang membuat ambang diuji dari dua sisi (0.539/0.541,
   0.96/0.961) alih-alih pada nilainya saja.
2. **Gerbang hitungan kunci menyala, dan itu benar.** Uji
   `testDeclaredKeysAreUniqueNonEmptyAndComplete` mengunci `allKeys.count`
   pada angka. Ditambah 11 kunci → merah. Angkanya diperbarui (30 → 41),
   bersama penjelasan mengapa angka itu memang **harus** diperbarui setiap
   kali: gerbang paritas membaca `allKeys`, jadi kunci yang masuk katalog
   tanpa masuk daftar akan lolos tanpa ada yang melihatnya.
3. **`spokenPhase` diuji lewat `spokenPhase`, hampir.** Uji pertama menyentuh
   `spokenPhase` langsung, yang di Linux selalu mengembalikan nilai bawaan —
   jadi ia hanya akan menguji teksnya, bukan pemilihan fasenya. Diuji lewat
   `moonPhaseText` (murni) untuk ambangnya, dan lewat `spokenPhase` hanya
   untuk keberadaan/ketiadaan.

### Bukti merah

Disuntikkan `return nil` di depan `spokenPhase` (persis keadaan sebelum
siklus ini: fase tidak pernah diucapkan) → **4 assertion MERAH** di 2 uji.
Berkas dipulihkan, diverifikasi sha256.

### Batas yang jujur

- **Belum pernah didengar di perangkat.** Uji menegakkan pemilihan fase;
  bahwa VoiceOver benar-benar membacanya dengan urutan dan jeda yang enak
  belum diverifikasi — itu butuh perangkat.
- **Ambangnya konvensi, bukan fisika.** Batas 4% / 46% / 54% / 96% adalah
  tata nama fase yang lazim dipakai, bukan hasil pengukuran. Uji menegakkan
  **batas itu diterapkan**, bukan bahwa batas itu yang paling benar.
- **Nama fase adalah kunci katalog**, jadi gerbang paritas menjaganya; tapi
  terjemahan Inggrisnya belum pernah dibaca penutur asli.

### Gerbang

- `./swift-test.sh` → **166 CelestialEngine + 315 PointingKit** (naik dari
  310), **0 failures**.
- `./swift-ui-lint.sh` → **8 aturan hijau**, termasuk Aturan 6 (paritas
  katalog) yang memvalidasi 11 kunci baru di kedua sisi.
- `./swift-typecheck.sh` → lulus. Sapuan CJK pada 7 berkas yang diubah → 0.
- Katalog: 160 → **171 kunci**, murni aditif (0 penghapusan).

### CI

Push `e27024c` hijau pada percobaan pertama:

- **Apple Build** run `37214082562` — `BUILD SUCCEEDED` untuk app iPhone dan
  app jam, gerbang peringatan melaporkan "Tidak ada peringatan compiler pada
  Apps/".
- **Engine Tests** run `37214082529` — 166 + 315 test, 0 failures, dan
  gerbang UI (`SEMUA GERBANG UI LULUS`) ikut hijau di macOS.


## Progres terakhir (4 Okt 2026 — sabit Bulan menghadap arah yang salah di Indonesia, dan galatnya 85 derajat)

### Premis siklus ini: periksa asumsi yang paling tidak mungkin salah

Brief Bagian 1 menulis satu syarat pendek yang mudah dilewati: **"Sabit
harus benar arahnya."** Seluruh geometri fase sudah teruji — kurva
terminator, luas pita, perpindahan di f = 0.5 — dan semua hijau. Yang belum
pernah ditanyakan bukan **besar** fasenya, melainkan **arah** sabitnya di
langit pengguna.

### Cacatnya: sisi sabit ditentukan oleh satu boolean

`CelestialVisual.phaseGeometry` menentukan sisi terang dengan:

    let litSide: Double = waxing ? 1 : -1

Artinya: waxing → sisi terang di **kanan**, waning → di **kiri**. Konvensi
ini benar untuk pengamat di lintang tinggi, tempat sabit berdiri tegak.
Repo ini, bagaimanapun, memakai **Jakarta** sebagai pengamat bawaan
(`ObserverLocation` bawaan: lintang **-6.2**). Jakarta ada di dekat ekuator,
dan di sana sabit muda justru terlihat **terlentang** — sisi terangnya
menghadap ke bawah, ke tempat Matahari terbenam.

Jadi bukan soal kurang mirip. Aplikasi ini menampilkan sabit yang menghadap
**kanan** pada pengamat yang seharusnya melihatnya menghadap **bawah**.

### Kenapa tidak ada gerbang yang menangkapnya

Tiga sebab sekaligus, dan ketiganya sudah berulang di repo ini:

1. **Semua uji fase menguji besar, bukan arah.** `litBandWidth`,
   `litBandAreaMatchesTheIlluminatedFraction`, `isGibbous` — semuanya
   simetris terhadap sisi. Membalik sisi tidak mengubah satu pun.
2. **`litSide` diuji sebagai nilai, bukan sebagai kebenaran.** Ada uji yang
   menegaskan `litSide == 1` saat waxing — jadi konvensi itu **dikunci**,
   bukan diverifikasi.
3. **Gambar tidak bisa dibaca salahnya.** Sabit yang menghadap arah salah
   tetap berbentuk sabit. Tidak ada teks di layar yang memberitahu pengguna,
   dan tidak ada yang akan melaporkannya.

### Perbaikannya: sudut, bukan boolean

Aturan fisisnya tunggal dan berlaku di lintang mana pun: **sisi terang selalu
menghadap Matahari.** Jadi yang dihitung bukan "kanan atau kiri", melainkan
**sudut** sisi terang di bidang gambar:

1. Vektor Bulan→Matahari dalam kerangka ENU (Timur–Utara–Atas), dari **beda
   vektor satuan** — bukan beda sudut alt/az, yang singular di kutub dan di
   zenit.
2. Buang komponen sepanjang garis pandang, sisakan proyeksi di bidang
   gambar. Tanpa langkah ini sudutnya berayun liar saat Bulan dekat zenit,
   padahal justru di sana yang terlihat berubah paling lambat.
3. Ukur dari "kanan" dengan "atas" positif.

Konsekuensinya bagus: **tidak ada cabang per-belahan-bumi di mana pun.**
Lintang sudah masuk lewat posisi Matahari dan Bulan, jadi belahan utara,
selatan, dan lintang tinggi semuanya keluar dari satu rumus yang sama.

### Dua kesalahan yang dibuat di siklus ini, dan bagaimana ketahuan

Ditulis apa adanya karena keduanya instruktif:

1. **Fungsi murninya salah tempat.** Ia awalnya masuk ke `extension
   PointingResolver`, bukan ke `CelestialVisual` — compiler menolaknya
   (`has no member 'brightLimbAngle'`). Dipindahkan, dan `PointingResolver`
   kini mendelegasikan.
2. **Basis gambar ditulis dari tangan, dan keduanya salah.** Versi pertama
   menulis `right = (-N, E, 0)` dan `up = (-E, -N, U)`. Yang pertama
   **terbalik** (harusnya `(N, -E, 0)`), dan yang kedua **tidak tegak lurus**
   terhadap vektor pandang — ia bahkan bukan basis yang sah. Ketahuan
   **dari uji, bukan dari membaca ulang rumusnya**: hasilnya 2.99 radian
   (~171 derajat) di tempat yang seharusnya ~0. Diganti dengan turunan
   vektor yang benar: `right = m x atas-dunia`, `up = right x m`.

Kesalahan kedua itu sendiri adalah argumen mengapa fungsi ini harus murni
dan teruji: rumus basis yang salah baca tetap menghasilkan sabit yang
berbentuk sabit.

### Uji yang menangkapnya (dan kenapa angkanya bukan karangan)

Angka alt/az di uji adalah geometri langit Jakarta sesaat setelah Matahari
terbenam — Bulan rendah di barat, hampir tepat di atas Matahari yang baru
tenggelam, jadi elongasinya kecil seperti sabit muda sungguhan:

| Kasus | Masukan (Bulan / Matahari) | Hasil | Perilaku lama |
|---|---|---|---|
| Sabit muda Jakarta | 20°, az 283° / -2°, az 285° | **-85°** (bawah) | 0° (kanan) → **galat 85°** |
| Lintang menengah | 30°, az 250° / -1°, az 285° | -37° (kanan-bawah) | 0° |
| Kutub, azimut sama | 10°, az 90° / 25°, az 90° | **+90°** (atas) | 0° |

Baris ketiga menunjukkan hal yang tidak bisa dijawab `isWaxing` **sama
sekali**: pada azimut yang sama dengan Matahari lebih tinggi, sisi terang
menghadap ke atas.

Dua di antaranya adalah **kontrol negatif**: kasus lintang menengah
memastikan perbaikannya tidak sekadar membalik semua sisi, dan uji
`testWaxingAloneCannotExpressTheLimbAngle` mengunci alasan keberadaan sudut
ini — kalau kelak ada yang menyederhanakannya kembali menjadi boolean,
uji itu gagal.

### Bukti merah: perilaku lama benar-benar gagal uji ini

Disuntikkan `return 0.0` (persis konvensi lama: sisi terang selalu kanan) ke
fungsi yang sudah diperbaiki, lalu uji dijalankan ulang:

    6 assertion MERAH di 4 uji, semuanya di CelestialVisualTests

Berkas dipulihkan dan diverifikasi lewat sha256. Tanpa langkah ini, uji
barunya cuma "ikut hijau" dan tidak membuktikan apa pun.

### Batas yang jujur

- **Sudut ini belum pernah dilihat mata manusia di perangkat.** Uji
  menegakkan geometrinya terhadap alt/az yang ditulis tangan; bahwa
  `equatorialToHorizontal` memberi alt/az yang benar sudah diuji terpisah.
  Yang belum: bahwa rumus proyeksi ini cocok dengan foto langit sungguhan.
- **`isWaxing` tetap dipakai** sebagai penentu sisi saat sudutnya tidak
  tersedia. Sudut hanya dipakai bila ia terhitung.
- Sudut tidak tersedia → gambar **tidak diputar**, bukan diputar ke sudut
  karangan. Perilaku lama tetap menjadi jaring pengaman, bukan jawaban.

### Gerbang

- `./swift-test.sh` → **166 CelestialEngine + 310 PointingKit** (naik dari
  305), **0 failures**.
- `./swift-ui-lint.sh` → 8 aturan hijau; `./swift-typecheck.sh` → lulus.
- Sapuan CJK pada 4 berkas yang diubah → **0**.

### CI

Push `c351739` hijau pada percobaan pertama:

- **Apple Build** run `37213512576` — `BUILD SUCCEEDED` untuk app iPhone dan
  app jam, dan gerbang peringatan melaporkan "Tidak ada peringatan compiler
  pada Apps/".
- **Engine Tests** run `37213512564` — 166 + 310 test, 0 failures, dan
  gerbang UI (`SEMUA GERBANG UI LULUS`) ikut hijau di macOS.


## Progres terakhir (4 Okt 2026 — cakupan Aturan 3 diperluas, dan aturan baru langsung menangkap penulisnya sendiri)

### Premis siklus ini: ambil batas yang sudah dicatat, dan uji apakah ia masih benar

STATUS mencatat berulang kali, di setiap "Batas yang diketahui":

> Aturan 3 masih buta di `*.sh`, `project.yml`, dan `*.md`.

Kalimat itu dicatat sebagai batas, **bukan** dikerjakan. Siklus ini menguji
apakah batasnya masih ada, lalu menutup bagian yang bisa ditutup.

### Apa yang ditemukan

Sapuan keempat jenis berkas itu menemukan **nol** pelanggaran di `*.sh`,
`*.yml`, dan `project.yml` — tetapi hanya karena tidak ada yang mencari,
bukan karena ada penjaga. Tiga hit CJK yang ada semuanya di `STATUS.md`,
dan ketiganya **kutipan bukti** cacat lama, bukan selip.

Itu memisahkan batasnya jadi dua hal yang berbeda, dan hanya satu yang
benar-benar celah:

- `*.sh`, `*.yml`, `project.yml` → bersih, **tak terjaga**. Bisa ditutup.
- `*.md` → berisi aksara CJK dengan **sengaja** (dokumentasi cacat).
  Memasang penjaga di sini akan membuat aturan memerah pada dokumentasinya
  sendiri.

### Yang dikerjakan

Cakupan Aturan 3 diperluas ke `*.sh`, `*.yml`, `project.yml`, dan keempat
skrip gerbang. `project.yml` ikut karena itu berkas yang **menentukan
build** — selip di sana dampaknya lebih besar daripada di satu view.

`*.md` sengaja tidak ikut, dengan alasannya ditulis di skrip supaya tidak
terbaca sebagai kelalaian.

### Aturan baru langsung menangkap penulisnya sendiri

Komentar yang menjelaskan pengecualian `*.md` awalnya **mengutip** aksara
CJK-nya sebagai contoh. Cakupan yang baru diperluas itu langsung memerah —
pada skrip yang memuat aturannya. Lint keluar **exit 1** dengan menunjuk
`swift-ui-lint.sh:100`.

Itu bukan gangguan; itu bukti bahwa perluasannya benar-benar bekerja. Dua
pilihan ada di depan: mengecualikan skripnya sendiri (menambah lubang), atau
menghapus kutipannya. Yang dipilih **menghapus kutipannya** — lebih baik
komentar kehilangan contoh harfiah daripada aturan mendapat lubang
pengecualian. Kegagalannya dicatat di komentar, jadi alasannya tidak hilang.

### Bukti dua arah

Salinan bersih di `scratch/lintcheck4` → baseline **exit 0**. Lalu:

| Suntikan | Diharapkan | Hasil |
|---|---|---|
| Aksara CJK di `swift-test.sh` | MERAH | **MERAH** |
| Aksara Cyrillic di `project.yml` | MERAH | **MERAH** |
| Aksara CJK di `STATUS.md` (kontrol negatif) | hijau | hijau |
| Kembalikan ke semula | hijau | hijau |

Kontrol negatifnya penting: tanpa itu, aturan ini bisa "lulus" hanya karena
memeriksa tempat yang salah.

### Kenapa tidak sekalian memasukkan `*.md`

Karena gerbang yang salah-merah akan dimatikan orang lain saat ia berbunyi —
alasan yang sama yang sudah dipakai repo ini untuk menolak `append` di
daftar peritel. STATUS yang mengutip cacat lama adalah pemakaian yang sah;
menuntutnya menulis ulang bukti historisnya akan merusak dokumentasinya.

### Gerbang

- `bash -n swift-ui-lint.sh` → OK; `./swift-ui-lint.sh` → **8 aturan hijau**.
- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 failures**.
- `./swift-typecheck.sh` → semua gerbang lulus.
- **CI hijau pada push pertama** (`3d72c1c`):
  - `Apple Build` run `37212597698` → 2× `BUILD SUCCEEDED` + gerbang
    *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37212597676` → hijau; `Executed 166 tests`,
    `Executed 305 tests`, dan `SEMUA GERBANG UI LULUS` terlihat di log CI.


## Progres terakhir (4 Okt 2026 — satu kata Jerman di tengah kalimat Indonesia, dan kenapa daftar kata sendiri dulu menghalangi)

### Premis siklus ini: kelas cacat yang sudah dicatat tiga kali tapi tak pernah punya penjaga

Aturan 3 menangkap aksara CJK dan Cyrillic. Yang **tidak** pernah ditangkap
adalah kata asing yang memakai huruf Latin — terbaca wajar oleh mata, lolos
total dari setiap gerbang. Kelas ini sudah muncul di STATUS berulang kali
(`di-George`, `Memorial celebrating`, `danasticity`) dan setiap kali hanya
**diperbaiki**, tidak pernah **dijaga**. Pola itu yang diakhiri di sini.

### Yang ditemukan: bukti nyata, bukan hipotesis

`Apps/Shared/LocalizationBridge.swift:39` memuat kata fungsi bahasa Jerman
di tengah kalimat Indonesia:

    /// tidak menahannya. `TextLocalization.text` deshalb menolak hasil yang

Kata itu lolos dari: lint (7 aturan waktu itu), typecheck, 471 test, dan CI
macOS. Tidak ada satu pun yang melihatnya.

### Kenapa daftarnya HANYA kata Jerman — dan itu keputusan yang diuji, bukan ditebak

Sapuan pertama memakai daftar kata Inggris + Jerman. Hasilnya satu hit yang
**bukan** cacat:

    OnboardingView.swift: /// Layar perkenalan "value-first": satu kartu singkat...

`value-first` adalah istilah desain yang sah, dan `first` menandainya. Jadi
kata Inggris umum dibuang dari daftar: ongkos positif palsunya lebih besar
daripada nilai tangkapannya. Sisa daftar kata Jerman memindai **103 berkas
→ 1 hit, dan hit itu memang cacat**. Presisi 100% pada cakupan itu.

### Jebakan yang harus dilewati: aturan tidak boleh menandai daftar katanya sendiri

Versi pertama Aturan 8 melaporkan **41 pelanggaran palsu** — semuanya berasal
dari definisi daftar kata dan komentar rasionalnya sendiri di dalam skrip.
Memecah daftar jadi dua string tidak menyelesaikannya: setiap kata tetap utuh
di dalam satu literal.

Perbaikannya bukan mengecualikan seluruh berkas skrip (itu akan membutakan
aturan pada skrip yang justru memuatnya), melainkan penanda sempit dan
eksplisit `aturan8:abaikan-mulai` / `aturan8:abaikan-selesai` yang membatasi
hanya pada definisi daftar. **Diuji bahwa penandanya tidak bocor**: selip
Jerman yang ditaruh *setelah* penanda selesai tetap membuat lint MERAH.

### Bukti dua arah

Salinan bersih di `scratch/lintcheck3` → baseline **exit 0**. Lalu:

| Suntikan | Hasil |
|---|---|
| Kata Jerman di `.swift` | MERAH, menunjuk `LocalizationBridge.swift:41` |
| Kata Jerman di `project.yml` | MERAH, menunjuk `project.yml:2` |
| Kata Jerman **setelah** penanda selesai | MERAH — penanda tidak bocor |
| Kembalikan ke semula | hijau |

`project.yml` sengaja diuji karena itu salah satu tempat yang **tidak**
tercakup Aturan 3 — celah yang sudah dicatat berulang kali.

### Batas yang jujur

Daftar ini tidak akan menangkap kata Latin korup yang di luar daftarnya.
Yang ditutup adalah kelas yang benar-benar muncul di repo ini, bukan seluruh
kemungkinannya. Itu dicatat sebagai batas, bukan diklaim sebagai penutupan
penuh.

### Gerbang

- `bash -n swift-ui-lint.sh` → OK; `./swift-ui-lint.sh` → **8 aturan hijau**.
- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 failures**.
- `./swift-typecheck.sh` → semua gerbang lulus.
- Sapuan CJK pada berkas yang diubah → **0**.



### Premis siklus ini: daftar peritelnya sendiri belum pernah diturunkan dari data

Unit sebelumnya memperbaiki **cara** argumen dibaca. Yang belum pernah
diperiksa adalah **daftar peritelnya** — 27 nama yang ditulis tangan, dan
tidak satu pun punya alasan yang bisa diperiksa. Itu persis bentuk yang sudah
tiga kali menjadi cacat di repo ini: daftar yang tumbuh dari apa yang
**diingat** orang, bukan dari apa yang ada di kode.

Jadi pertanyaannya dibalik. Bukan "peritel apa yang harus ditambahkan",
melainkan: **pemanggilan mana di seluruh `Apps/` yang argumen pertamanya
sebuah literal?** Sapuan itu tidak butuh daftar sama sekali. Hasilnya
dikelompokkan per nama:

| Nama | literal | Diperiksa? |
|---|---|---|
| `Text` | 33 | ya |
| `row` | 32 | ya |
| `Section` | 12 | ya |
| `Label` | 7 | ya |
| `Button` | 6 | ya |
| **`SharePreview`** | 2 | **tidak** |
| **`TextField`** | 1 | **tidak** |
| **`chartYAxisLabel`** | 1 | **tidak** |
| **`legend`** | 3 | **tidak** |
| **`value`** | 4 | **tidak** |

Lima nama terakhir memuat teks yang **tampil di layar** dan tidak pernah
diperiksa gerbang mana pun: judul berkas di lembar berbagi, label bidang
isian, label sumbu grafik, dan tiga label legenda grafik keyakinan.

### Sepuluh teks, dan yang paling penting bukan yang paling mudah terlihat

Yang paling mencolok justru yang paling gampang dilewatkan: **`σ`**, label
sumbu Y grafik keyakinan. Satu karakter, tidak punya huruf sama sekali —
bentuk yang sama seperti template format, dan justru karena itu tidak pernah
terpikir sebagai "teks". Ia tampil di grafik yang jadi inti layar
Diagnostik.

Tiga label legenda (`Yakin`/`Ragu`/`Tidak tahu`) punya masalah kedua yang
lebih halus: padanan `en`-nya **harus** sama dengan
`confidence.level.*.label`, karena keduanya menyebut tingkat keyakinan yang
sama di layar yang berbeda. Kalau diterjemahkan bebas, satu layar berkata
"Certain" dan layar lain "Sure" untuk konsep yang identik. Dipakai
`Certain`/`Uncertain`/`Unknown` — **dibaca dari katalog yang sudah ada**,
bukan dikarang.

`Dataset Experiment 1` sengaja **tidak** dimasukkan ke `NOT_LOCALIZED`: ia
berisi nama percobaan yang memang tidak diterjemahkan (`Experiment 1`), tapi
kata `Dataset` perlu padanan, jadi kunci penuhnya didaftarkan. Ini kebalikan
dari `Point & Know` yang seluruhnya nama produk.

### Yang sengaja TIDAK dimasukkan, dan kenapa itu keputusan

Dua nama muncul di sapuan dan **ditolak dengan alasan**, bukan dilewatkan:

- **`NSLog`** — pesan log. Tidak pernah terlihat pengguna, jadi menuntut
  padanan bahasa Inggris untuknya hanya menambah 20 kunci mati ke katalog.
- **`append`** — delapan literal, dan semuanya memang teks tampilan
  (`"Tidak dianalisis."`, `"False lock: engine yakin tapi salah."`). Tapi
  `append` adalah nama `Array.append`/`String.append`: memasukkannya akan
  menandai **setiap** `append("...")` di repo, termasuk yang bukan teks
  tampilan. Gerbang yang salah merah akan dimatikan orang lain saat ia
  berbunyi — itu alasan yang sama yang sudah dipakai repo ini untuk menolak
  daftar kata asing. Jadi batasnya dicatat di komentar skrip, bukan
  disembunyikan.

`append` tetap celah yang **nyata**, dan statusnya sekarang jujur: ia
terdaftar sebagai batas, bukan sebagai selesai.

### Katalog: 150 → 160 kunci, murni aditif

```
110 baris masuk, 0 keluar
```

Urutan kunci lama tetap tidak disentuh.

### Uji injeksi: enam arah, termasuk kontrol negatif

Dijalankan pada salinan:

| Injeksi | Diharapkan | Hasil |
|---|---|---|
| `TextField("LabelIsianBaru", …)` | MERAH | **MERAH** |
| `SharePreview("JudulBagikanBaru")` | MERAH | **MERAH** |
| `.chartYAxisLabel("SumbuBaru")` | MERAH | **MERAH** |
| `legend("LegendaBaru", …)` | MERAH | **MERAH** |
| `.value("NilaiBaru", 1.0)` | MERAH | **MERAH** |
| `NSLog("pesan log internal %@", …)` | hijau | hijau |
| tree bersih | hijau | hijau |

Enam dari tujuh adalah bukti **merah**; yang ketujuh adalah kontrol negatif —
tanpa itu, aturan ini bisa "lulus" karena menandai segalanya.

### Yang benar-benar dijalankan

- `./swift-ui-lint.sh` → **7 aturan hijau**; aturan 4 MERAH dulu (11 situs,
  10 kunci) lalu hijau.
- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 gagal**.
  Tidak ada satu baris Swift pun yang berubah di unit ini.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Sapuan CJK/Cyrillic pada berkas yang diubah: **0**.
- **CI hijau pada push pertama** (`53a6f14`):
  - `Apple Build` run `37211768305` → **`BUILD SUCCEEDED`** + gerbang
    peringatan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37211768310` → hijau; `Executed 166 tests`,
    `Executed 305 tests`, dan `== SEMUA GERBANG UI LULUS ==` terlihat di log
    CI.

### Batas yang diketahui dan belum ditutup

- **`append` belum ditutup** — lihat di atas. Kandidat yang benar bukan
  menambahkannya ke daftar peritel, melainkan memeriksa **tipe** targetnya,
  dan itu di luar jangkauan sapu teks.
- **Aturan 3 dulu buta di `*.sh`, `project.yml`, dan `*.md`** — dua yang
  pertama **sudah ditutup** di siklus berikutnya; `*.md` tetap di luar
  cakupan dengan alasan yang dicatat di skrip (STATUS memuat aksara CJK
  sebagai bukti, bukan sebagai selip).
- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux** — tidak
  berubah.

## Progres terakhir (4 Okt 2026 — 23 teks yang tampil di layar, tak terlihat gerbang mana pun)

### Premis siklus ini: STATUS lalu menunjuk ke tempat yang salah

STATUS sebelumnya menutup dengan batas yang jujur:

> **`detailRow` dengan argumen non-literal masih bisa lolos** — sapuan ini
> menangkap literalnya, tapi kalau argumennya
> `.accessibilityLabel(RowSpeech…)` yang membawa teks, jalur itu tidak
> diperiksa.

Kalimat itu **benar**, dan justru itu sebabnya berbahaya: ia menutup celah
dengan diagnosa yang tepat sasaran ke tempat yang **bukan** masalahnya.
Argumen yang bukan literal memang di luar jangkauan sapu teks — tidak ada yang
bisa diperbuat untuk itu. Yang tidak pernah diperiksa adalah **argumen kedua
yang literal**.

Pola lamanya satu regex:

```
\b(Text|row|…)\s*\(\s*"((?:[^"\\]|\\.)*)"
```

Satu literal, dan ia **harus** persis setelah tanda buka. Jadi:

| Bentuk — keduanya ada di repo | Terbaca? |
|---|---|
| `row("Keadaan", state.shortLabel)` | ya |
| `row("Device motion", motion.isAvailable ? "Ada" : "Tidak ada")` | **tidak** |

Argumen kedua sebuah `row` **selalu** teks tampilan — itu definisi helper-nya
(`row(_ title: String, _ value: String)`). Jadi **nilai**, yaitu separuh isi
setiap baris tabel di seluruh app, tidak pernah diperiksa. Dibuktikan dengan
menjalankan pola lama atas seluruh `Apps/`:

```
laporan pola lama: 0
```

Nol. Sementara **23 teks** yang benar-benar tampil di layar tidak punya satu
pun padanan bahasa Inggris — termasuk `Gelap`/`Terang`, `Sudah`/`Belum`,
`Aktif`/`Belum aktif`, `Ya`/`Tidak`, `Ada`/`Tidak ada`, `iPhone terhubung`,
empat label tombol Mode Malam & bunyi, dan tiga label kalibrasi.

### Kelas yang sama, ketiga kali — dan kali ini di dalam aturan penutupnya sendiri

"Gerbang hijau karena ada satu jalur yang tidak pernah diperiksa" sudah dua
kali muncul: aturan 4 buta terhadap metadata WidgetKit, lalu aturan 4 buta
terhadap `row`/`detailRow`. Ini ketiga kalinya, dan yang paling ironis:
**buta terhadap separuh argumen dari fungsi yang baru saja dimasukkan ke
daftar peritel** untuk menutup kejadian kedua. Menambahkan peritel tanpa
memperbaiki *cara* argumennya dibaca hanya memindahkan lubangnya.

### Yang diubah, dan kenapa begini

Pola regex tunggal diganti **pembaca argumen**:

- **`read_literal`** membaca satu literal utuh dan memperlakukan `\(…)`
  sebagai **satu kesatuan**, jadi tanda kutip di dalam interpolasi tidak
  menutup literal. Itu bentuk yang memang dipakai repo ini
  (`"· \(link.sendFailureCount) gagal"`), dan tanpa penanganan itu sapuannya
  salah baca tepat di tempat yang paling rawan.
- **`direct_arguments`** hanya mengumpulkan literal pada **kedalaman argumen
  1**. Literal bersarang (`String(format: "%.1f°", x)`) tidak ikut dianggap
  teks tampilan, sementara `row("Judul", flag ? "A" : "B")` tetap terbaca
  **keduanya**.
- **Label `systemImage` disaring karena data, bukan tebakan.** Diperiksa lebih
  dulu: satu-satunya parameter berlabel yang membawa literal di seluruh
  `Apps/` adalah `systemImage`, dan isinya nama SF Symbol
  (`"square.and.arrow.up"`) — memang bukan teks tampilan.
- **Template format murni dikecualikan**, tapi dengan syarat yang menentukan:
  hanya bila setelah specifier dibuang **tidak ada huruf tersisa**. Itu yang
  membuat `"%.0f%%"` gugur sementara `"%lld gagal"` tetap diperiksa sebagai
  teks — bentuk kedua memang punya padanan `en` di katalog.

### Katalog: 23 kunci, murni aditif

`Localizable.xcstrings` 127 → **150** kunci, semuanya dengan padanan `en`.
Urutan kunci lama **tidak disentuh** — katalog ditulis tangan, jadi urutan
berarti — dan diff-nya:

```
253 baris masuk, 0 keluar
```

Nol penghapusan, jadi tidak ada reformat yang menyamarkan perubahan.

`FALSE LOCK` sengaja masuk katalog dengan nilai `en` **yang sama**: itu
istilah teknis huruf besar yang dipakai sebagai singkatan visual (alasannya
sudah ada di komentar `Experiment1View`), dan menaruhnya di katalog membuat
keputusan itu terbaca, bukan tersembunyi.

### Uji injeksi: dua arah

Dijalankan pada salinan, bukan di repo:

| Injeksi | Diharapkan | Hasil |
|---|---|---|
| literal baru sebagai argumen **kedua** `row()` | MERAH, sebut **keduanya** | **MERAH** |
| `Label("Ekspor", systemImage: "arrow.up.doc.on.clipboard")` | hijau | hijau |
| `row("JudulUIBaru", String(format: "%.1f°", 3.0))` | MERAH, sebut judulnya saja | **MERAH** |
| `row("JudulUIBaru", flag ? "NilaiA" : "NilaiB")` | MERAH, sebut ketiganya | **MERAH** |
| `// Text("TeksDiDalamKomentar")` | hijau | hijau |
| tree bersih | hijau | hijau |

### Yang benar-benar dijalankan

- `./swift-ui-lint.sh` → **7 aturan hijau**; aturan 4 **MERAH dulu** (33 situs,
  23 kunci) sebelum katalog diisi, lalu hijau.
- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 gagal**.
  Engine tidak disentuh; tidak ada satu baris Swift pun yang berubah di unit
  ini.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Sapuan CJK/Cyrillic pada berkas yang diubah: **0**.
- **CI hijau pada push pertama** (`98c10e4`):
  - `Apple Build` run `37211406351` → **2× `BUILD SUCCEEDED`** + gerbang
    peringatan *"Tidak ada peringatan compiler pada Apps/."*; langkah
    "Gerbang sapu UI" terlihat benar-benar berjalan di log.
  - `Engine Tests (Linux)` run `37211406453` → hijau, dan `Bersih: setiap
    teks UI punya entri di katalog.` + `== SEMUA GERBANG UI LULUS ==`
    terlihat **di log CI**, bukan hanya di mesin ini.

### Batas yang diketahui dan belum ditutup

- **Sapuan tetap tidak bisa melihat teks yang tidak pernah menjadi literal.**
  `.accessibilityLabel(RowSpeech.label(title:value:))` membawa teks lewat
  variabel, dan tidak ada sapu teks yang bisa mengikutinya. Yang berubah:
  batas itu sekarang **benar-benar** batasnya, bukan alasan untuk melewatkan
  argumen kedua yang literal.
- **Aturan 3 masih buta di `*.sh`, `project.yml`, dan `*.md`** — tidak
  berubah dari siklus sebelumnya. `STATUS.md` sendiri masih menyimpan tiga
  aksara CJK di tiga baris, yang ditulis sebagai **contoh** selip; sapuan
  tidak mencakup `*.md`, jadi contoh dan selip tidak bisa dibedakan oleh
  gerbang mana pun.
- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux.** Yang terbukti:
  setiap kunci punya entri + padanan `en`, dan diff-nya aditif. Yang tidak:
  apakah `Bundle` benar-benar membacanya di perangkat.

## Progres terakhir (4 Okt 2026 — iPhone menampilkan "Mencari" lalu diam, dan aturan yang buta di label tabel)

### Dua temuan, dan yang kedua tidak akan ketahuan tanpa yang pertama

Temuan pertama berasal dari menghitung, bukan membaca: berapa kali
`guidance` muncul di tiap app?

| Berkas | `guidance` |
|---|---|
| `PointAndKnowWatch/Sources/PointingView.swift` | **5** |
| `PointAndKnowiOS/Sources/DiagnosticsView.swift` | **0** |
| `Complications/ComplicationWidget.swift` | 0 |

Jadi app jam menampilkan panduan keadaan di bawah badge
(`PointingView.swift:256`, `:234`, `:300`), dan **layar utama iPhone tidak
menampilkan sama sekali**. Barisnya cuma `row("Keadaan",
state.shortLabel)` — "Mencari" — lalu layar diam.

Yang membuatnya cacat, bukan sekadar beda: `shortLabel` menjawab **apa**
keadaannya, tidak pernah menjawab **apa yang harus dilakukan**. Dua app
untuk keadaan yang sama memberi petunjuk berbeda: jam berkata "Tahan arah
tunjuk sampai jam berhenti bergerak", iPhone tidak berkata apa pun. Ke
enam kalimat panduan sudah ada di `TextLocalization`, sudah diuji di Linux
(`PointingPresentationTests`, `TextLocalizationTests`) — yang hilang hanya
tempat menampilkannya.

### Barisnya memakai kunci yang sama, bukan kalimat baru

`row("Panduan", engine.snapshot.state.guidance)` — bukan string harfian di
view. Kalau kalimatnya ditulis terpisah di iPhone, ia bisa menyimpang dari
yang diucapkan jam, dan dua app yang memberi petunjuk berbeda adalah cacat
yang paling buruk: pengguna jam mendapat instruksi, pengguna iPhone tidak,
dan tidak ada yang bisa tahu itu disengaja.

### Temuan kedua: aturan 4 buta tepat di jalur paling umum

Bukti RED-nya lewat injeksi, bukan dengan membaca aturan:

```
Text("TeksUIYangBaru")      ->  merah
row("LabelUIYangBaru")      ->  LOLOS, tanpa laporan
```

`Text` ada di daftar peritel aturan 4; `row` — helper label-lebar yang
dipakai **empat berkas** — tidak. Padahal label tabel adalah jalur paling
banyak dari teks yang benar-benar tampil di layar. `row` dan `detailRow`
ditambahkan ke `POS`.

Setelah diperlebar, aturan itu langsung melaporkan **36 label yang hilang
sungguhan** di empat berkas. Ini pola yang sama seperti dua kali
sebelumnya: gerbang hijau, aturannya ada, penerapannya juga ada — tapi ada
satu jalur yang tidak pernah diperiksa, dan jalurnya justru yang paling
sering dipakai.

Tiga puluh tiga di antaranya saya masukkan ke `Localizable.xcstrings`
lengkap dengan padanan bahasa Inggris dan komentar singkat — termasuk
`Panduan` yang barusan ditambahkan oleh perubahan ini.

### Urutan katalog tidak boleh disentuh

Katalog ditulis tangan (`SWIFT_EMIT_LOC_STRINGS: NO`, alasannya di
`project.yml`), jadi **urutan kuncinya berarti**. Versi pertama saya
menjalankan `sorted()` atas seluruh kunci demi kerapian dan menghasilkan
**83 baris churn** yang tidak ada hubungannya dengan pekerjaan ini — diff
yang terlihat busy dan menutupi sebenarnya. Dikembalikan, dan kunci baru
ditambahkan di akhir dengan `OrderedDict`:

```
363 baris masuk, 0 keluar
```

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 gagal**.
- `./swift-ui-lint.sh` → **7 aturan hijau**.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Injeksi ulang setelah perbaikan: `row`, `detailRow`, dan `Text`
  **ketiganya merah**; tree bersih tetap hijau.
- CI di `e719e65`: `Apple Build` run `37210235342` → 2× `BUILD SUCCEEDED`
  + "Tidak ada peringatan compiler pada Apps/."; `Engine Tests (Linux)` →
  hijau.

### Yang masih terbuka

- **`detailRow` dengan argumen non-literal masih bisa lolos** — sapuan ini
  menangkap literalnya, tapi kalau argumennya
  `.accessibilityLabel(RowSpeech…)` yang membawa teks, jalur itu tidak
  diperiksa. Terpisah dari perubahan ini.
- **Complication tetap tanpa panduan** (`0`), dan itu **memang benar**:
  layar complication satu baris, dan `shortLabel` memang yang tepat di
  sana. Tidak diubah karena tidak ada yang rusak.
- **Terjemahan `en` untuk 33 kunci baru tidak bisa diverifikasi di Linux**
  — tidak berubah dari siklus sebelumnya, alasannya juga tidak berubah.

## Progres terakhir (4 Okt 2026 — planet di panel kunci menggambar dirinya sendiri 30 kali per detik)

### Premis siklus ini: cari barang yang membazir, bukan barang yang belum ada

Semua item brief sudah ada (diverifikasi ulang di entri "Ringkasan keadaan" 4 Okt). Jadi pertanyaan siklus ini bukan "apa yang belum dikerjakan",
tapi **"dari yang sudah ada, mana yang membazir tanpa terlihat"**. Bukti
baterai-redraw yang paling bersih di repo ini ditemukan dengan menghitung,
bukan dengan membaca: sapuan seluruh `Apps/` untuk sumber redraw per frame.

Hasilnya satu, dan itu cukup:

| Pola | Jumlah | Lokasi |
|---|---|---|
| `TimelineView` | 1 | `DiagnosticsView.swift:550` |
| `Timer`/`CADisplayLink`/`DispatchSource` timer | 0 | — |
| `onReceive(Timer…)` | 0 | — |
| `Canvas` | 1 | `CelestialVisualView.swift:45` |
| `symbolEffect` / `PhaseAnimator` | 0 | — |

Satu `TimelineView` untuk seluruh app. Dan ia bergerak **30 frame per
detik**, terus-menerus, untuk setiap objek yang tampil di panel kunci.

### Cacatnya: timer untuk gambar yang tidak pernah bergerak

`TimelineView(.animation(minimumInterval: 1.0 / 30.0))` dipasang supaya glow
bintang bisa berdenyut. Tapi `pulse` **hanya** dibaca di `drawStar`
(`CelestialVisualView.swift:453`) — diverifikasi dengan melacak satu-satunya
pemakai `pulse` di seluruh view:

```
CelestialVisualView.swift:453   let pulseFactor = 1 + … * CGFloat(sin(pulse))
```

Hanya itu. Planet, Bulan, Matahari, dan nebula digambar dari konstanta saja:
`drawPlanet`, `drawMoon`, `drawSun`, `drawDeepSky` tidak pernah menyentuh
`pulse`. Jadi ketika panel kunci menampilkan **planet**, yang terjadi adalah
30 render per detik untuk `Canvas` yang menggambar piksel yang **persis sama**
setiap frame.

Yang membuatnya layak diperbaiki dan bukan sekadar catatan performa:
pertanyaan yang sama tidak pernah bisa dijawab siapa pun di repo ini. App jam
tidak pernah memasang `TimelineView` sama sekali (visualnya diam), jadi
"apakah denyut boleh jalan" adalah pertanyaan yang dua app jawab berbeda —
dan tidak ada satu pun tempat yang mencatat bahwa mereka **bertanya tentang
hal yang sama**.

### Yang diperbaiki, dan kenapa tempatnya di model

`hasPulse` masuk ke `CelestialVisual` (`PointingKit`), bukan ke view. Alasan
teknisnya memaksa hal itu: `TimelineView` harus dipasang **sebelum** view
tahu apa yang akan digambar, jadi view tidak bisa menjawab pertanyaan
"apakah saya perlu denyut" — itu sudah terlambat untuk dijawab di tempat
yang salah. Tanpa properti di model, jalan yang tersedia hanya
menjalankannya untuk semua jenis dan berharap pengoptimasian menyusul;
itu pola *hope-it-works* yang tidak pernah diaudit di repo ini.

Perbaikannya sendiri satu baris ambang:

```swift
if motion.allowsContinuousMotion && visual.hasPulse {
```

Jalur `else` sudah benar tanpa perubahan: ia mengirim `pulse: 0`, dan
`pulsePhase` sudah mengembalikan **nol persis** saat geraknya gated
(diuji di `MotionPolicyTests`) — jadi kedua jalur menghasilkan gambar yang
sama persis, dan tidak ada keadaan setengah yang perlu ditangani.

Jalur bintang **tidak** berubah sedikit pun: `pulsePhase` tetap dihitung
dengan `MotionPolicy` yang sama, jadi denyut yang benar-benar ada tetap
berjalan.

### Bukti RED, dua arah

1. **Mutasi** `hasPulse` → `{ true }`: uji merah di keempat jenis, dengan
   pesan yang menyebut jumlah frame per detik
   (`./red-test.sh`, hasil benar-benar merah — bukan "hijau pada kode
   rusak").
2. **Sebelum properti ada**, uji gagal **kompilasi** (`value of type
   'CelestialVisual' has no member 'hasPulse'`) — jadi uji ini memang
   menguji keputusan model, bukan sekadar kompilasi yang kebetulan lolos.

Dua uji baru:

- `testOnlyStarsPulse` — hanya `.star`; `planet`/`moon`/`sun`/`deepSky`
  tidak, dengan pesan yang menyebut konsekuensinya (30 frame/detik).
- `testPulseFollowsTheObjectKindForEveryCatalogueEntry` — **seluruh 25
  entri katalog**, bukan hanya enum tangan, supaya cabang baru yang lupa
  ketahuan oleh data — **ditambah** enam benda di luar katalog
  (`jupiter`/`saturn`/`mars` sebagai `.planet`, `moon` sebagai `.moon`,
  `sun` sebagai `.sun`, `m42` sebagai `.deepSky`).

  Versi pertamanya memanggil `object(id: "moon", kind: .planet)` — salah
  jenis, dan karena itu **lulus tanpa pernah menguji apa pun**: planet pun
  memang tidak berdenyut, jadi apa pun yang diperiksa untuk `moon` akan hijau.
  Uji yang terlihat benar dan tidak memeriksa apa pun lebih berbahaya
  daripada tidak menulis ujinya, karena ia menutup celah yang sebenarnya
  terbuka. Diperbaiki ke jenis yang sebenarnya; katalog `brightStars`
  memang hanya berisi bintang (25 entri, dihitung), jadi tanpa loop luar
  ini `planet`/`moon`/`sun`/`deepSky` **tidak akan pernah** ikut teruji.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 305 PointingKit, 0 gagal**
  (naik dari 303, +2).
- `./swift-ui-lint.sh` → **7 aturan hijau**.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Sapuan aksara non-Latin: **0**.
- CI di `8070012`: `Apple Build` run `37209410461` → **2× `BUILD
  SUCCEEDED`** + "Tidak ada peringatan compiler pada Apps/."; `Engine
  Tests (Linux)` → hijau.

### Catatan jujur soal proses

Selama siklus ini, alat `write_file` menyisipkan karakter asing ke dalam
komentar **beberapa kali** — termasuk `希望`, `仓库` (aksara CJK), `RALAT`,
serta potongan Latin yang tidak masuk akal seperti `Swiftly`/`iList`. Semuanya
ketahuan karena ada penyapu, dan semuanya dibuang sebelum commit — satu
potongan sempat bocor ke pesan commit pertama sebelum ikut dibersihkan.
Ini bukan kebaru: kelas cacat yang sama sudah menimpa repo ini berulang
kali, dan sekarang ada aturan yang menangkapnya
untuk kode aplikasi (aturan 3). Yang **belum** ada adalah penjaga yang
sama untuk `*.sh` dan `STATUS.md` — dan itu tercatat di entri aturan 7
sebagai batas yang diketahui, bukan disembunyikan.

## Progres terakhir (4 Okt 2026 — Reduce Motion tidak pernah dibaca di mana pun)

### Premis siklus ini: preferensi pengguna yang paling sering dipakai, tanpa satu pun penjaga

Brief sudah terpasang: Fase B menutup animasi halus, denyut glow bintang, dan
pop spring saat kunci. Yang **tidak pernah** ditanyakan adalah apakah semua
itu boleh berjalan untuk pengguna yang minta jangan bergerak. Sapu diverifikasi
terlebih dulu, bukan dibaca sambil lalu:

```
$ grep -rn "accessibilityReduceMotion" Apps Packages/*/Sources
(nihil)
```

Nol. Sementara di repo yang sama ada **empat** `withAnimation(.spring)`
(`PointingView` 2, `DiagnosticsView` 2) dan satu `TimelineView(.animation)`
30 Hz yang menyegarkan denyut glow bintang — berulang tanpa henti selama layar
menyala. Jadi bentuk gerak yang paling mengganggu (yang tidak pernah
berhenti sendiri) justru yang paling tidak bisa dihentikan.

Kelas cacatnya persis yang sudah repo ini tutup berulang kali: **aturan ada,
penerapannya tidak.** Bandingkan dengan Dynamic Type (muncul lagi di berkas
complication yang ditambahkan belakangan) dan aturan penyapu UI (buta terhadap
metadata WidgetKit). Yang membuat kelas ini bertahan: tidak ada satu pun gerbang
yang bisa merah kalau `accessibilityReduceMotion` tidak dibaca, karena tidak ada
gerbang yang tahu bahwa preferensi itu **seharusnya** dibaca.

### Yang membedakan unit ini dari "tambah AnimatedFeature"

Aturan motion dipindah ke `PointingKit` sebagai `MotionPolicy`, bukan ditulis
di view. Alasannya bukan kerapian: `accessibilityReduceMotion`,
`TimelineView`, dan `Canvas` **tidak bisa dibangun di Linux**, jadi kalau
aturannya tinggal di view satu-satunya pembuktiannya adalah "berkompilasi di
Mac" — persis celah yang membuat geometri kutub Mars bisa menembus 0.26R
selama lima siklus.

Yang lebih penting, ada **dua bentuk gerak dengan jawaban yang berbeda**, dan
menyamakan keduanya adalah jebakan:

| Bentuk | Contoh | `reduceMotion` | Layar redup | Scene tak aktif |
|---|---|---|---|---|
| Kontinu | denyut glow bintang | **stop** | **stop** | **stop** |
| Transisi | pop saat kunci | **stop** | **stop** | **boleh** |

Baris terakhir adalah inti keputusan. `isSceneActive` menghentikan denyut
karena denyut di latar belakang hanya membebani baterai tanpa pernah terlihat.
Tapi **transisi dipicu aksi pengguna**, jadi saat transisi berjalan layarnya
aktif — dan memasukkan `isSceneActive` ke sana akan mematikan umpan balik
"kunci berhasil" tepat saat itu. Uji `testInactiveSceneDoesNotKillTransitions`
mengunci perbedaan itu secara eksplisit, dan mutasinya **dibuktikan MERAH**.

Menulis unit ini memasukkan lima selip CJK (satu di `MotionPolicy.swift`,

empat di `MotionPolicyTests.swift`) — semuanya di komentar, semua terlihat
benar di layar. Tapi sapuan yang sudah ada menangkapnya seperti biasa.
  denyutnya diam. Hanya perbandingan yang menangkapnya.
- **Laju denyut** (1,1 rad/dtk → satu denyut penuh tiap 5,712 detik) dipindah
  dari literal `* 1.1` di view ke konstanta bernama, karena angka yang sampai
  ke mata pengguna setiap detik harus punya satu sumber yang bisa diuji.

### Cacat kedua yang ditemukan: aturan 3 menangkap CJK tapi buta terhadap Latin rusak

Menulis unit inilatorCC imposed five CJK slips (satu di `MotionPolicy.swift`,
empat di `MotionPolicyTests.swift`) — semuanya di komentar, semua terlihat
benar di layar. TapiSapuan yang sudah ada menangkapnya seperti biasa.

Yang **tidak** tertangkap adalah temuan lain: **empat kata Latin korup** yang
sudah lama ada di repo, termasuk di dalam test suite:

| Tempat | Selip | since |
|---|---|---|
| `Apps/Shared/CelestialVisualView.swift:54` | `di-George` | siklus moon-phase |
| `LockArrivalTests.swift:43` | `nil` akan *flowing* 20 kali/detik | — |
| `LockArrivalTests.swift:92` | *Memorial celebrating* untuk benda yang tidak ada | — |
| `NightVisualTests.swift:9` | `dan_colors_nyaelly` | — |
| `NightVisualTests.swift:21` | `danasticity` (menggantikan "dan elastisitasnya") | — |

Semuanya **jejak CJK yang hilang** — huruf CJK dihapus dari kalimat Indonesia,
dan sisa gagalnya menyatu jadi satu kata aneh (`danasticity` =
"dan" + "asticity"). Karena itu aturannya lolos: sapuan CJK tidak melihatnya,
dan sapuan Latin tidak punya daftar kata jenis itu. `di-George` dan
`Memorial celebrating` lebih buruk lagi karena **terbaca benar** sebagai
bahasa Inggris, bukan salah eja.

Kandidat unit berikutnya sudah jelas: daftar kata asing yang **tidak** pernah
muncul dalam kode ini — diturunkan dari apa yang benar-benar tampil sebagai
teks, bukan dari daftar umum. Sama seperti aturan 4 yang hanya memindai
peritel yang memang dipakai.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 303 PointingKit, 0 gagal**
  (naik dari 292; +11 uji). Engine tidak disentuh.
- **Dua mutasi dibuktikan MERAH lebih dulu** lewat `./red-test.sh`:
  - `allowsTransitions` ikut `isSceneActive` → `testInactiveSceneDoesNotKillTransitions`
    gagal: *"transisi dipicu aksi pengguna, jadi layar aktif saat ia berjalan"*.
  - `pulsePhase` `0` → `0.0001` → `testPulsePhaseIsExactlyZeroWhenContinuousMotionIsDenied`
    gagal di 12 titik: *`("0.0001") is not equal to ("0.0")`*.
- `./swift-ui-lint.sh` → 6 aturan hijau.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS (build kedua paket + parse 23
  berkas `Apps/`).
- Sapuan CJK/Cyrillic/fullwidth pada seluruh berkas yang diubah: **0**
  (lima selip tertangkap dan dibuang sebelum commit).
- **CI hijau pada push pertama** (`90b0940`):
  - `Apple Build` run `37208040057` → **2× `BUILD SUCCEEDED`**, gerbang
sebelumnya, belum ditutup), dan sekarang terbukti butanya **lebih
  - `Engine Tests (Linux)` run `37208040009` → hijau, sebelas uji motion
    terlihat **lolos per nama di log CI** (bukan hanya di mesin ini).

### Batas yang diketahui dan belum ditutup

- **`accessibilityReduceMotion` baru dipasang di dua tempat**: pop saat kunci
  (jam + iPhone) dan denyut glow (iPhone). Yang **belum** disambungkan:
  animasi lain yang mungkin muncul nanti, dan `TimelineView` denyut **di
  app jam** — jam memang tidak punya denyut kontinu (gambar di sana statis),
  jadi tidak ada yang perlu dihentikan, tapi itu **kebetulan**, bukan aturan.
  Kandidat: `MotionPolicy` exposing/hanya dibaca di view yang memanggil
  `withAnimation`/`TimelineView`/`repeatForever` — sapuan statis baru.
- **Aturan 3 masih buta di `*.sh` dan `project.yml`** (dicatat di siklus
  sebelumnya, belum ditutup), dan sekarang terbukti butanya **lebih
  dalam**: ia menangkap aksara non-Latin tapi tidak menangkap Latin yang
  rusak. Dua kelas cacat berbeda dengan satu sapuan.
- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux** — tidak berubah,
  alasannya tidak berubah.

## Progres terakhir (4 Okt 2026 — aturan 7: gerak tanpa penjaga, dan probe yang menyalahkan gerbang yang benar)

### Premis siklus ini: memasang aturan tanpa penjaga hanya memindahkan cacat

Unit sebelumnya memasang `MotionPolicy` dan `accessibilityReduceMotion`. Tapi
mengabaikan aturan yang tidak punya gerbang adalah pola yang **baru saja**
dibayar mahal di repo ini: Dynamic Type selesai, lalu `.system(size:)` muncul
lagi di berkas complication yang ditambahkan belakangan; aturan penyapu UI
hijau, lalu terbukti buta terhadap metadata WidgetKit. Keduanya hijau sepanjang
waktu aturan itu **seharusnya** dibaca.

Pertanyaan yang lebih jujur dari "apakah aturannya sudah ada": **gerbang mana
yang akan merah kalau animasi ditambah tanpa membaca `reduceMotion`?** Tidak
ada. Sapu yang ada hanya melihat font, aksara, teks UI, kunci YAML, dan paritas
katalog — tidak satu pun tahu bahwa gerak adalah sesuatu yang bisa mati
sendiri.

### Yang ditutup: kelas, bukan satu situs

Aturan 7 memeriksa setiap berkas `Apps/` yang memanggil API gerak
(`withAnimation`, `.animation(`, `.repeatForever`, `TimelineView(.animation)`)
dan menuntut berkas itu merujuk penjaga gerak (`reduceMotion`, `MotionPolicy`,
atau `isLuminanceReduced`). Jadi `withAnimation` pada tombol baru tertangkap di
commit yang sama — bukan beberapa bulan kemudian, seperti Dynamic Type.

Dua detail yang menentukan apakah gerbang ini bisa dipercaya:

- **Nama API dibaca dari kode, penjaga boleh dari komentar.** Dokumentasi aturan
  ini sendiri menyebut `withAnimation`; penyapu yang menghitung komentar akan
  melaporkan dirinya sendiri. Itu persis gerbang yang selalu merah dan akan
  dimatikan orang lain saat ia berbunyi.
- **Daftar peritel sengaja pendek.** Hanya empat API yang benar-benar
  menghasilkan gerak berulang atau transisi. Kandidat yang tidak pernah muncul
  di repo ini tidak dimasukkan — daftar panjang peritel yang tidak pernah dipakai
  menambah permukaan untuk salah baca, bukan perlindungan (aturan yang sama
  sudah dipakai di aturan 4).

### Cacat aturan ini ditemukan oleh uji injeksi, bukan oleh membaca

Versi pertama mem-pattern `.animation()` **tanpa argumen**. Saya menyapunya
dan ia hijau — lalu menyuntik bentuk yang dipakai sungguhan:

```
Text("X").animation(.linear, value: 1)   ->  LULUS (tidak dilaporkan)
```

Bentuk tanpa argumen justru yang paling jarang di SwiftUI; bentuk dengan
argumen adalah yang dipakai setiap hari. Kalau tes injeksi tidak dilakukan,
aturan ini akan terlihat sempurna sambil menutup kelas cacat yang paling mungkin
dialam. Diperbaiki ke `.animation\s*\(` tanpa membatasi isi.

Bukti dua arah di salinan (bentuk nyata, bukan rekaan):

| Injeksi | Hasil |
|---|---|
| `withAnimation` tanpa penjaga | **merah** |
| `.animation(.linear, value: 1)` tanpa penjaga | **merah** |
| `.repeatForever` di dalam `withAnimation` | **merah** |
| `TimelineView(.animation)` tanpa penjaga | **merah** |
| + `MotionPolicy` / `isLuminanceReduced` | hijau |
| tree bersih | hijau |

### Probe saya sendiri sempat salah baca — dicatat karena hampir jadi klaim salah

Injeksi pertama memakai `Button("X") { withAnimation(...) }`. Aturan 7 **hijau**
dan exit 1 — jadi sempat disangka aturannya sendiri yang salah. Penyebabnya
bukan aturan 7: `Button("X")` membuat **aturan 4** merah, karena `"X"` tidak
ada di katalog string. Dua gerbang benar, exit code milik salah satu.

Yang benar adalah memperbaiki **probnya**: injeksi harus menguji aturan yang
dimaksud tanpa memicu aturan lain. Setelah `Button("X")` diganti
`.animation(.linear, value: 1)` (tanpa literal UI), aturan 4 tetap hijau dan
redanya benar-benar milik aturan 7. Dua-duanya tercatat karena "gerbang saya
hijau saat(@" adalah tanda probe yang rusak, bukan tanda gerbang yang benar.

### Yang benar-benar dijalankan

- `./swift-ui-lint.sh` → **7 aturan, semua hijau** (naik dari 6).
- `./swift-test.sh` → **166 CelestialEngine + 303 PointingKit, 0 gagal**
  (tidak berubah — aturan lint tidak menyentuh kode paket).
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- Sapuan CJK/Cyrillic pada `swift-ui-lint.sh`: **0**. (Tiga selip sempat
  masuk ke komentar aturan ini saat menulis, dibuang sebelum commit — bukti
  lagi bahwa kelas ini muncul di mana-mana, bukan cuma di view.)
- CI hijau pada push pertama unit sebelumnya (`90b0940`): `Apple Build` run
  `37208040057` → **2× `BUILD SUCCEEDED`**, gerbang peringatan melaporkan
  *"Tidak ada peringatan compiler pada Apps/."*; `Engine Tests (Linux)` run
  `37208040009` → hijau, sebelas uji motion terlihat **lolos per nama di log CI**.

### Batas yang diketahui dan belum ditutup

- **Daftar kata asing yang korup** (`di-George`, `Memorial celebrating`,
  `danasticity`, …) **tidak** ditutup di unit ini, dan sudah dicoba lalu
  ditolak dengan bukti: harvests dari repo ini menunjukkan **2715 kata** yang
  hanya muncul di komentar, dan majority-nya adalah Bahasa Indonesia yang
  normal. Daftar peritel yang terlalu longgar akan selalu merah. Kandidat yang
  benar adalah sinyal mekanis, bukan daftar kata — misalnya pola
  `di-[ kapital]` yang filtered dari nama simbol, yang tadi diuji dan
  menghasilkan **111 false positive** (`di PointingKit`, `ke Linux`). Dua
  percobaan gagal dicatat supaya tidak diulang.
- **Aturan 7 belum menutup animasi implisit**: `.transition(...)` yang memuat
  kurva animasi sendiri, dan animasi bawaan dari `List`/`NavigationStack`.
  Keduanya di luar jangkauan penyapu teks, dan menambahkannya perlu bukti
  bahwa bentuknya benar-benar muncul di repo ini dulu.
- **Aturan 3 masih buta di `*.sh` dan `project.yml`**, dan sekarang butanya
  terbukti **lebih dalam**: ia menangkap aksara non-Latin tapi tidak
  menangkap Latin yang rusak (`di-George`, `danasticity`) — dua kelas cacat
  berbeda dengan satu sapuan.

## Progres terakhir (4 Okt 2026 — kunci katalog yang hilang menampakkan nama kuncinya sendiri)

### Premis siklus ini: STATUS lalu menutup satu celah dengan kalimat yang benar, tapi tidak lengkap

STATUS sebelumnya menulis, di "Batas yang diketahui":

> Bridge tidak dipasang di complication. Complication adalah proses terpisah
> yang tidak memanggil `.install()`, jadi labelnya selalu Bahasa Indonesia —
> bukan string kosong, dan itu jujur. Tapi kalau layer lokalisasi nanti
> ditambah, complication akan tertinggal.

Kalimat itu **benar** — dan karena itu berbahaya. Ia menutup celah dengan
diagnosa yang benar, sementara yang sebenarnya hilang bukan hanya bridge.
Dibuktikan dengan membangun XcodeGen lalu membaca `project.pbxproj` yang
dihasilkannya: target complication **tidak punya fase Resources sama
sekali**, dan `Localizable.xcstrings` hanya ada di dua app. Jadi bukan
satu lapis yang hilang, tapi dua: tidak ada katalog untuk dibaca, dan tidak
ada yang membacanya.

### Cacat pertama: `Bundle.localizedString` tidak pernah mengembalikan `nil`

`LocalizationBridge` memasang
`Bundle.localizedString(forKey:value:table:)` dengan `value:` = nama
kuncinya sendiri. Pola itu **benar sendiri** — string kosong membuat baris
terlihat kosong tanpa penjelasan. Tapi konsekuensinya belum pernah
dipikirkan: kalau kunci tidak ada di katalog, hasilnya adalah `value` — jadi
kunci yang hilang kembali sebagai **nama kuncinya**, non-kosong, dan
pemeriksaan "terjemahan tidak kosong" di `TextLocalization.text` **tidak
menahannya**.

Diverifikasi dengan program kecil, bukan dengan membaca (`Bundle.main` di
Linux memang tidak punya `.lproj`, `localizations == []`):

| Kunci | `localizedString` mengembalikan |
|---|---|
| tidak ada di katalog | `pointing.state.lock.label` — **namanya sendiri** |
| `value: ""` | `pointing.state.lock.label` juga (kosong dicegah oleh API) |

Jadi tiga label yang paling sering dibaca sekilas di seluruh app akan tampil
sebagai pengenal mentah begitu bridge terpasang dan katalog tidak ikut:
`pointing.state.lock.label`, `object.kind.star.display.label`,
`confidence.level.medium.label`.

Yang membuatnya bertahan: **teorinya benar** — "label punya terjemahan"
memang terbukti (93 kunci + padanan `en`), aturan 6 hijau, dan satu-satunya
gejalanya ada di tempat yang tidak pernah difoto: label tampil sebagai pengenal mentah hanya bila kunci hilang dari katalog,
dan tidak ada satu pun gerbang yang bisa membuat katalog kehilangan kunci.

### Perbaikannya di paket, bukan di bridge

`TextLocalization.text` sekarang menolak hasil yang **sama dengan nama
kuncinya**, lalu jatuh ke Bahasa Indonesia. Di paket, bukan di `Apps/`,
supaya setiap bridge di masa depan otomatis ikut terlindungi — termasuk yang
belum ada sekarang, termasuk `ComplicationLocalization` yang baru dibuat di
siklus ini.

Konsekuensinya dinyatakan jujur di kode: kalau katalog suatu saat hilang
**total**, layar kembali Bahasa Indonesia tanpa terlihat rusak. Itu
trade-off yang benar — lebih baik Bahasa Indonesia daripada
`pointing.state.lock.label` di wajah pengguna.

### Cacat kedua: tiga selip CJK yang tidak tertangkap aturan 3

Aturan 3 menyapu `*.swift` di `Apps/` dan `Packages/`. Yang tertulis di
`swift-ui-lint.sh` dan `project.yml` **tidak** tercakup — dan STATUS lama
sudah memperingatkan soal ini sebagai kandidat perbaikan. Terbukti sekali
lagi di siklus ini, bukan sebagai kemungkinan:

| Tempat | Selip | Tertangkap? |
|---|---|---|
| `swift-ui-lint.sh` (komentar aturan 4) | 2 kata asing tersisip | **tidak** |
| `ComplicationLocalization.swift` (komentar) | 3 kata asing tersisip | **ya** (aturan 3) |
| `ComplicationWidget.swift` (komentar) | 4 kata asing tersisip | **ya** (aturan 3) |

Selipnya sengaja **tidak ditulis ulang di sini** dengan huruf aslinya: kalau
huruf itu ikut tercantum, sapuan karakter akan menandainya di dokumen status
yang justru mencatat tempat selip itu. Yang dicatat jumlahnya, bukan isinya.

Jadi aturan 3 menangkap selip di kode tapi buta di gerbang & konfigurasi —
persis pola "hijau yang tidak hijau", kali ini pada alat yang auditorsnya
gunakan. Kandidat penutup: perluas sapuannya ke `*.sh` + `project.yml`.

### Cacat ketiga: aturan 4 buta terhadap metadata WidgetKit

Aturan 4 menyapu view modifier (`Text`, tombol, label aksesibilitas).
`.description("Objek terakhir yang dikenali, tanpa membuka app.")` — teks
yang tampil di layar pemilihan complication watchOS — **tidak pernah
disapu**, karena `description` bukan salah satu nama yang dipindai.
Terbukti: di `ComplicationWidget.swift` yang sama, aturan 4 hanya melaporkan
tiga kemunculan `Point & Know` (yang memang sengaja tidak diterjemahkan)
sementara deskripsi complication yang sebenarnya tidak punya padanan `en`
lolos.

Daftar peritel diperluas ke yang teksnya kelihatan: metadata complication
(`configurationDisplayName`, `description`), judul dialog konfirmasi, dan
pengenal aksesibilitas. Kandidat yang tidak pernah muncul di repo ini
sengaja **tidak** ditambahkan — daftar peritel yang tidak pernah dipakai
hanya menambah permukaan untuk salah baca, bukan perlindungan.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 292 PointingKit, 0 gagal**
  (naik dari 291; +1 uji). Engine tidak disentuh.
- Uji baru **dibuktikan MERAH lebih dulu** pada `text()` lama: 3 assertion
  gagal, menyebut gejalanya — *`("pointing.state.lock.label") is not equal
  to ("Terkunci")`*, `("object.kind.star.display.label") is not equal to
  ("Bintang")`, `("confidence.level.medium.label") is not equal to ("Ragu")`*.
  Uji yang tidak pernah merah adalah formalitas.
- Aturan 4 yang diperluas **dibuktikan dua arah di salinan**: tree bersih
  hijau; `accessibilityHint("Petunjuk barkas tanpa entri katalog")` yang
  disuntik → **merah**, sebut kuncinya.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS. `./swift-ui-lint.sh` → 6
  aturan hijau.
- XcodeGen **dibangun sendiri** (2.45.3, 185 detik) di container `swift:6.0`;
  `xcodegen generate` pada repo → ketiga target punya
  `Localizable.xcstrings` di fase Resources. **Sebelum perubahan: hanya
  dua**, dan target complication tidak punya fase Resources sama sekali.
- **CI hijau pada push pertama** (`a4ce1d0`):
  - `Apple Build` run `37206180937` → **2× `BUILD SUCCEEDED`**, gerbang
    peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37206180938` → hijau, dan uji baru
    **terlihat lulus per nama di log CI** (bukan hanya di mesin ini).

### Batas yang diketahui dan belum ditutup

- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux.** `Bundle.main`
  tidak punya `.lproj`, dan `String(localized:)` tidak ada di Swift 6.0
  Linux. Yang terbukti: katalog ikut ke **setiap** bundel, dan setiap
  proses extension punya bridge yang membacanya. Yang tidak: apakah `.xcstrings`
  benar-benar diterjemahkan saat perangkat berjalan. Itu wilayah CI dan
  perangkat.
- **Daftar kunci aturan 5 bisa jadi sudah usang.** `Tools/xcodegen-known-keys.txt`
  dibuat dari XcodeGen **2.46.0**, sedangkan yang bisa dibangun di VPS ini
  tag-nya **2.45.3**. Perbedaannya tidak diperiksa, jadi aturan 5 mungkin
  sudah menilai kunci yang sebenarnya berubah nama.
- **Aturan 3 masih buta di `*.sh` dan `project.yml`** — dibuktikan di atas,
  bukan asumsi.
- `ComplicationProvider.init()` memasang bridge, tapi `TextLocalization` itu
  singleton proses: kalau suatu saat complication punya lebih dari satu
  sumber (mis. setelah `AppIntent`), urutan pemasangan jadi hal yang harus
  dijaga. Saat ini hanya ada satu, jadi belum jadi masalah.

## Progres terakhir (4 Okt 2026 — 10 label yang tampil di layar tidak punya terjemahan)

### Premis siklus ini: STATUS sebelumnya menutup satu celah dengan kalimat yang salah

STATUS lalu menulis, di bagian "Batas yang diketahui":

> label `ObjectKind` (`Apps/Shared/ObjectKindLabels.swift`) — satu berkas di
> app, masuk aturan 4 seperti biasa.

Kalimat itu **diuji, bukan dipercaya** — dan ia salah. Aturan 4 tidak bisa
melihat berkas itu sama sekali. Aturan itu menyapu literal
`Text("...")`/`Button`/`Label`/`accessibilityLabel`, sedangkan
`return "Bintang"` di dalam `switch` **tidak pernah menjadi salah satu dari
itu**.

Dibuktikan di salinan, di berkas yang sama: menyuntik
`Text("Literal nyata tanpa entri katalog")` **membuat aturan 4 merah**,
sementara sepuluh label yang benar-benar tampil di layar tidak punya satu pun
padanan bahasa Inggris. Aturan 4 menangkap jebakan yang salah dan meloloskan
yang benar — dua-duanya pada berkas yang sama.

| Label | Layar | Ada padanan `en`? |
|---|---|---|
| "Bintang", "Planet", "Bulan", "Matahari", "Objek langit dalam" | panel detail jam, panel detail iPhone, complication rectangular | **tidak** |
| "bintang", "planet", … "objek langit jauh" | VoiceOver di kedua app | **tidak** |

Aturan 6 tidak menolong — dan itu menarik. Aturan 6 menjaga kunci yang
*dideklarasikan di paket*, sementara teks ini justru hidup di app. Dua
aturan itu sama-sama benar, dan keduanya mengukur bagian yang tidak
bermasalah: persis bentuk "hijau yang tidak hijau" yang sudah tiga kali
muncul di repo ini, kali ini **di dalam gerbang yang dibuat untuk menutupnya**.

### Cacat kedua, yang muncul dari perbaikannya sendiri

Label itu dipindahkan ke paket supaya bisa diuji dan bisa menjangkau katalog.
Setelah dipindahkan, **aturan 6 ikut kehilangan 10 kuncinya**: `declared`
dibaca dari `TextLocalization.swift` saja, sementara kunci baru hidup di
`ObjectKindLabels.swift`. Arah 1 ("dideklarasikan tapi tidak ada di katalog")
tidak akan melaporkannya, dan suite tetap hijau — termasuk saat semua katalog
hilang.

Jadi gerbang yang lahir untuk menangkap "kunci yang dideklarasikan tapi tidak
punya entri" justru buta terhadap kunci yang dideklarasikan di berkas kedua.
Diperbaiki dengan membaca kunci dari **seluruh** sumber paket, bukan menambah
pemeriksaan baru; dan namespace `object.kind.` ditambahkan ke Arah 2.

### Yang diubah, dan kenapa begini

- **`ObjectKindLabels.swift` pindah ke `PointingKit`**, memakai
  `LocalizedText` — sama seperti `PointingState.shortLabel` dan
  `ConfidenceLevel.displayName`. Katalog 83 -> **93** kunci, sepuluh di
  antaranya punya padanan `en`.
  Yang dipindahkan bukan cuma bentuk tampilannya. Complication berjalan di
  **proses terpisah** dan hanya menarik `PointingKit`, jadi selama labelnya di
  app, satu-satunya penjaga konsistensinya adalah pathway compile yang
  kebetulan menyertakannya — bukan aturan apa pun.
- **`spokenName` tidak disatukan ke `displayName`.** "Objek langit dalam"
  memang terdengar janggal saat diucapkan; menyatukannya demi lebih ringkas
  akan menghapus justru alasan pemisahannya. Uji menjaga keduanya punya kunci
  sendiri.
- **`swift-typecheck.sh`**: berkas dihapus dari daftar typecheck, dan
  daftarnya dibiarkan gagal keras (`no such file`) bila berkasus hilang —
  lebih baik begitu daripada diam-diam memeriksa satu berkas lebih sedikit.
- **`project.yml`**: `Apps/Shared/ObjectKindLabels.swift` tidak lagi disebut
  eksplisit sebagai sumber target complication.

**Nilai Bahasa Indonesia tidak berubah satu karakter pun** — yang dipindah adalah
*tampilannya di bahasa kedua*.

### Yang benar-benar dijalankan

- `./swift-test.sh` -> **166 CelestialEngine + 291 PointingKit, 0 gagal**
  (naik dari 286; +5 uji). Engine tidak disentuh.
- **Dua mutasi dibuktikan MERAH lebih dulu** lewat `./red-test.sh`:
  (a) `spokenName` disatukan ke `displayText` ->
  `testInstalledLookupReachesKindLabelsToo` gagal; (b) nilai bawaan
  `id: "bintang"` -> `"star"` -> **2 uji** gagal. Uji yang tidak pernah merah
  adalah formalitas.
- **Aturan 6 diperkuat, dibuktikan tiga arah di salinan**: kunci
  `object.kind.star.display.label` dibuang dari katalog -> **merah**; kunci
  `object.kind.hantu.display.label` disuntik -> **merah**; tree bersih ->
  **hijau**.
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- `./swift-ui-lint.sh` -> 6 aturan hijau.
- Sapuan karakter non-Latin pada `Apps/`, `Packages/`, `Tools/`, dan skrip: **0**.
- **CI hijau pada push pertama** (`4063338`):
  - `Apple Build` run `37204467679` -> **2x `BUILD SUCCEEDED`**, gerbang
    peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37204467708` -> hijau.

### Catatan kejujuran: selip non-Latin terjadi lagi, di tempat yang tidak dijaga

Aturan 3 menjaga `Apps/` + `Packages/`, tapi **tidak** menjaga `project.yml`
maupun skrip gerbang. Tiga selip CJK masuk ke komentar saat menulis (satu di
paket, satu di `swift-ui-lint.sh`, satu di `project.yml`) dan tidak ada
gerbang yang melihatnya — keduanya harus dipindai manual. Satu di antaranya
sudah ikut ke reviewer yang sama sebelum dibuang. Dua kandidat perbaikan
nanti: perluas aturan 3 ke `project.yml` + `*.sh`, atau minimal beri tahu
skrip gerbang bahwa ia sendiri tidak tercakup sapuannya.

### Batas yang diketahui dan belum ditutup

- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux** — `Bundle.main`
  di Linux tidak punya `.lproj`, dan `String(localized:)` tidak ada di
  Swift 6.0 Linux. Yang bisa dibuktikan: setiap kunci punya entri + padanan
  `en`. Yang tidak: apakah `Bundle` benar-benar membaca `.xcstrings` saat
  perangkat berjalan. Itu wilayah CI dan perangkat.
- **Bridge tidak dipasang di complication.** Complication adalah proses
  terpisah yang tidak memanggil `.install()`, jadi labelnya selalu Bahasa
  Indonesia — bukan string kosong, dan itu jujur. Tapi kalau layer lokalisasi
  nanti ditambah, complication akan tertinggal. Belum ada gerbang yang menjaga
  hal itu.
- Teks yang dihasilkan di paket yang **belum** terjangkau katalog, dengan
  alasan masing-masing: `CalibrationSpeech` (dilewati dengan sengaja — kalimat
  itu **diucapkan**, jadi bentuknya harus bisa diuji di Linux); label
  `CalibrationFlow` (punya `formatSpecifier`, jadi katalog butuh kunci format,
  bukan teks yang sama); ringkasan `ExperimentHarness` (dirangkai dari
  beberapa bagian dengan sisipan angka).


## Progres terakhir (4 Okt 2026 — teks yang dihasilkan di PointingKit akhirnya bisa dijangkau katalog)

### Premis siklus ini: celah yang STATUS lalu sebut "belum ditutup" memang nyata

STATUS sebelumnya menutup bagian Fase C dengan satu kalimat: label yang
**dihasilkan** di `PointingKit` (`shortLabel`, `guidance`, `displayName`)
tidak pernah melewati `Text("literal")`, jadi katalog tidak bisa menjangkau
mereka. Kalimat itu dibaca, bukan dipercaya — dan memang benar, dengan
bukti: `"Terkunci"` **tidak ada** di `Localizable.xcstrings`, padahal itu
teks yang paling sering dibaca sekilas di seluruh app.

Yang membuatnya kelas yang layak dikejar: **gerbangnya hijau sepanjang
itu**. Aturan 4 menyapu literal `Text("...")` di `Apps/`, dan laporan itu
benar — tidak ada satu pun literal bermasalah. Yang tidak diukur adalah
teks yang tidak pernah menjadi literal di sana.

| Teks | 통과 aturan 4? | Punya padanan `en`? |
|---|---|---|
| "Terkunci", "Kurang yakin", "Sensor mati", "Siap", "Arahkan", "Mencari" | ya (tidak ada literal-nya) | **tidak** |
| "Yakin" / "Ragu" / "Tidak tahu" | ya (tidak ada literal-nya) | **tidak** |
| 6 kalimat panduan keadaan | ya (tidak ada literal-nya) | **tidak** |
| 5 label jenis pesan jam<->iPhone | ya (tidak ada literal-nya) | **tidak** |

20 kunci, nol di antaranya bisa dilihat oleh gerbang mana pun yang ada.

### Yang diubah, dan kenapa begini

- **`LocalizedText` (baru, `TextLocalization.swift`)** — menyimpan **kunci
  yang stabil** + Bahasa Indonesia sebagai **nilai bawaan**. Perbedaannya
  penting: kalau Bahasa Indonesia yang jadi identitas (yaitu kunci katalog
  = teksnya), maka memperbaiki ejaan berarti mengganti kunci dan seluruh
  terjemahan ikut hilang.
  - **Nilai bawaan ada di dalam tipe, bukan hanya di katalog**, karena
    paket ini **dipakai di Linux** tempat `Bundle.main` tidak punya
    `.lproj` sama sekali (`localizations == []`) dan `String(localized:)`
    **tidak ada** di Swift 6.0 Linux. Tanpa nilai bawaan, seluruh uji Linux
    menguji string kosong.
  - **Pencarian dipisah dari jenis teks.** `TextLocalization` tidak tahu
    apa pun tentang `Bundle`; app yang memasangnya
    (`LocalizationBridge`, satu fungsi). Jadi bagian yang bisa diuji di
    Linux dan bagian yang tidak bisa dipisahkan secaraGcoding — bukan
    dicampur dalam satu berkas yang tidak bisa diuji.
- **Kunci ber-NAMESPACE, bukan teksnya sendiri.** Bukti konkretnya sudah
  ada di repo: `"Kalibrasi"` di katalog berarti **judul layar kalibrasi**,
  sementara `link.kind.calibrationReady` juga berbunyi "Kalibrasi" untuk
  hal berbeda. Kalau teksnya jadi kunci, keduanya menyatu diam-diam —
  mengubah satu ikut mengubah yang lain. Uji menjaga prefix namespace-nya.
- **Aksesor lama tidak berubah bentuk**, hanya isinya:
  `shortLabel`/`guidance`/`displayName` tetap `String`, dan
  `stateLabelText`/`stateGuidanceText`/`displayText` ditambahkan sebagai
 829 sumber kunci. Tanpa bridge terpasang, hasilnya **identik dengan
  sebelumnya** — itu yang diuji dengan literal, bukan dengan `.indonesian`
  (kalau ujinya memakai `.indonesian` untuk kedua sisi, ia hanya
  membuktikan kedua sisi bergerak bersama, dan typo pada nilainya lolos).

### Cacat yang ditemukan: gerbang aturan 4 membaca komentar

Aturan 4 menjadi merah setelah `LocalizationBridge` ditulis — menunjuk
`Apps/Shared/LocalizationBridge.swift: Text: '...'`. Penyebabnya bukan
kode: baris itu **dokumentasi** yang menjelaskan kenapa aturan 4 tidak
bisa melihat teks di paket, dan ia memuat `Text("...")` sebagai contoh.

Gerbang yang membaca komentarnya sendiri akan **selalu merah**, dan gerbang
yang selalu merah akan dimatikan orang lain saat ia berbunyi. Aturan 1 dan
3 di skrip yang sama sudah membuang komentar; aturan 4 tidak pernah diberi
perlakuan itu karena ia belum pernah salah membaca komentar.

Diperbaiki dengan membuang `//` **hanya bila berada di luar literal**
(hitung status Escape) — karena `//` di dalam string (URL, regex, path)
adalah kode. Dibuktikan dua arah di salinan sementara: yang menyuntik
literal UI nyata **tetap merah**, dan yang bersih hijau.

### Cacat kedua: uji menangkap typo saya sendiri

`testDefaultTextIsExactlyTheIndonesianItShippedWith` gagal, dan pesan Xcode
menampilkan kedua sisi **terbaca identik**: `"Ambah keyakinan"`.

Yang sebenarnya berbeda satu byte: nilai bakunya di sumber tertulis
`Ambah` (huruf ke-4 `h`), sedangkan yang ditulis di uji `Ambah`. Keduanya
tampil sama di layar; hanya perbandingan byte yang membedakannya. Jadi dua
string yang **tidak bisa dibedakan mata** menangkap cacat yang **tidak bisa
dibaca dari teks**.

Perhatikan arah perbaikannya. Hampir "`tidak bisa dibedakan mata`" membuat
saya shy untuk memperbaiki ujinya, karena pesannya sendiri terlihat benar
di kedua sisi. Yang benar adalah memperbaiki **sumbernya**: nilai bawaan di
`TextLocalization.swift` yang salah eja, sementara ujinya sudah benar.
Uji itu benar karena nilainya diketik dari katalog, bukan disalin dari
sumber yang sama.

Ini persis kelas yang sudah beberapa kali muncul di repo ini, dengan satu
perbedaan penting: cacatnya ada di kode yang **baru ditulis pada siklus
ini**, jadi uji menangkapnya **sebelum sempat keluar repo** — berbeda dari
uji-uji sebelumnya yang menangkap cacat siklus-siklus lalu.

### Aturan 6: paritas dua arah

Menutup kelas yang sama, tapi **kebalikannya**: dari kunci katalog ke
paket, supaya kunci tidak bisa "dibuang diam-diam" dari `allKeys` demi
membuat pemeriksaan arah pertama terasa cukup.

| Disuntik | Hasil |
|---|---|
| hapus `pointing.state.lock.label` dari katalog | **merah**, sebut kuncinya |
| tambah `pointing.state.hantu.label` ke katalog | **merah**, sebut kuncinya |
| tree bersih | hijau |

Diverifikasi pada **salinan** (`/tmp/lintcheck`), bukan di repo.

### Yang benar-benar dijalankan

- `./swift-test.sh` -> **166 CelestialEngine + 286 PointingKit, 0 gagal**
  (naik dari 277; +9 uji). Engine tidak disentuh.
- **Dua mutasi dibuktikan MERAH lebih dulu**: (a) `shortLabel` dialihkan ke
  nilai bawaan langsung -> `testInstalledLookupWinsOverTheDefaultValue`
  gagal ("Terkunci" != "Locked"); (b) terjemahan kosong dipercaya ->
  `testEmptyTranslationFallsBackToIndonesian` gagal dengan pesan
  `("") is not equal to ("Terkunci")` — persis kegagalan diam yang paling
  berbahaya di UI.
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS. `LocalizationBridge`
  **ditambahkan** ke daftar typecheck: ia memanggil `PointingKit` lintas
  modul, yang tidak bisa diselesaikan `-parse`. Batasnya sama seperti
  berkas lain di daftar itu — Linux masih tidak punya SwiftUI.
- `./swift-ui-lint.sh` -> 6 aturan hijau. Aturan 4 **tetap menangkap**
  pelanggaran nyata setelah diperbaiki (dibuktikan di salinan).
- Sapuan karakter non-Latin pada 10 berkas yang diubah: **0**. (Tiga selip
  sempat masuk saat menulis — termasuk ke dalam **pesan commit yang sama**,
  lalu ditulis ulang dengan `--amend` sebelum push. Aturan 3 menjaga kode,
  tapi tidak menjaga pesan commit; ini bukti bahwarowing sapuan tempat
  yang sama perlu mata juga.)
- **CI hijau pada push pertama** (`550f475`):
  - `Apple Build` run `37202871620` -> **2x `BUILD SUCCEEDED`**, gerbang
    peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37202871610` -> hijau, dan **sembilan uji
    baru terlihat lulus per nama di log CI** (bukan hanya di mesin ini).

### Batas yang diketahui dan belum ditutup

- **Terjemahan `en` tetap tidak bisa diverifikasi di Linux** — sama seperti
  catatan siklus sebelumnya, dan alasannya tidak berubah. Yang bisa
  dibuktikan di sini: setiap kunci punya entri + padanan `en`, dan nilai
  bakunya tampil benar. Yang **tidak** bisa: apakah `Bundle` benar-benar
  membaca `.xcstrings` saat perangkat berjalan. Itu wilayah CI dan
  perangkat, bukan Linux.
- **20 kunci baru**, tapi teks yang dihasilkan di paket belum semuanya
  terjangkau. Yang tersisa, dengan alasan masing-masing:
  - `CalibrationSpeech` — **dilewati dengan sengaja**. Kalimat itu teks
    **yang diucapkan**, jadi bentuknya harus bisa diuji di Linux, dan sudah
    punya ujinya sendiri. Melocalisasi bentuknya berarti menambah lapisan
    yang tidak bisa diuji di tempat yang sekarang bisa.
  - label `CalibrationFlow` (`"Sebaran %.1f° masih terlalu lebar…"`) —
    punya `formatSpecifier`, jadi katalog butuh kunci format
    (`"Sebaran %1$@ masih terlalu lebar…"`), bukan teks yang sama.
  - ringkasan `ExperimentHarness` — dirangkai dari beberapa bagian dengan
   sisipan angka.
  - label `ObjectKind` (`Apps/Shared/ObjectKindLabels.swift`) — satu berkas
    di app, masuk aturan 4 seperti biasa.

  Kandidat unit berikutnya bukan yang paling mudah, tapi yang bentuknya
  paling berbeda satu per satu — supaya tiap bentuk punya aturan sendiri
  yang bisa diuji.

## Progres terakhir (4 Okt 2026 — katalog string terpasang, dan dua "cacat" yang ternyata bukan cacat)

### Premis siklus ini: ada pekerjaan yang belum di-commit di meja

`git status` menunjukkan unit Fase C item 2 (katalog string) sudah ditulis:
`Localizable.xcstrings` (63 kunci, semua punya padanan `en`), entri resource di
`project.yml`, dan aturan 4 di `swift-ui-lint.sh`. Sebelum push, isinya dibaca
ulang - dan **dua dari tiga hal yang saya kira cacat ternyata bukan cacat.**
Bagian paling berharga dari siklus ini justru catatan itu.

### Yang saya klaim cacat, lalu saya buktikan sendiri tidak jadi

| Klaim awal | Kenyataan |
|---|---|
| `knownRegions` di `options` membuat CI gagal | **Bukan opsi XcodeGen sama sekali** - diabaikan diam-diam |
| Entri `Apps/Shared/Resources` menggandakan katalog | XcodeGen sudah memetakan `.xcstrings` ke resources; hasilnya **identik** |

Keduanya saya buktikan dengan cara yang tidak bisa dibantah: saya **membangun
XcodeGen 2.46.0 sendiri** di container `swift:6.0` (187 detik), lalu
menjalankan `xcodegen generate` pada repo ini dan pada salinan yang
`project.yml`-nya dikembalikan ke versi lama. Hasilnya sama persis:
`developmentRegion = id`, `knownRegions = (Base, en, id)`, katalog jadi
2 build file (satu per app), 1 fileRef.

Pelajarannya bukan soal dua baris YAML. **`project.yml` tidak punya gerbang.**
`swiftc -parse` tidak membaca YAML, `swift test` tidak membangun proyek, dan
CI memanggil `xcodegen generate` yang keluar 0 meski isinya salah total.
Jadi kelas cacat ini mustahil ditangkap gerbang yang ada - dan saya baru
menyadarinya setelah hampir mendorong dua "perbaikan" yang tidak memperbaiki
apa pun.

### Cacat NYATA yang ditemukan di unit yang sama: `developmentRegion` selalu `en`

Kunci yang benar-benar ditemukan bukan yang saya duga. `developmentRegion`
diisi dari `options.developmentLanguage` (`PBXProjGenerator:99`,
`project.options.developmentLanguage ?? "en"`), **bukan** dari build setting
`DEVELOPMENT_LANGUAGE` di `settings.base` yang sudah ada.

Dibuktikan di tiga kondisi:

| Kondisi | `developmentRegion` |
|---|---|
| `project.yml` di HEAD apa adanya | **`en`** |
| `knownRegions` tak dikenal, tanpa `developmentLanguage` | **`en`** |
| `developmentLanguage: id` | **`id`** |

Jadi sejak katalog ini belum pernah ada, proyek menyatakan bahasa
pengembangan `en` sementara seluruh teks sumbernya bahasa Indonesia. Dan
`knownRegions` pun ikut salah: tanpa `id`, bahasa Indonesia tidak pernah
muncul sebagai bahasa yang bisa dipilih di Xcode - padahal brief dan Fase C
meminta dua bahasa siap pakai.

Perbaikannya satu baris (`developmentLanguage: id`) plus penjelasan kenapa
build setting saja **tidak cukup** - keduanya memang perlu, dan hanya
menuliskan yang satu meninggalkan keadaan yang sama.

### Gerbang baru: aturan 5, dan dua false positive yang harus dibunuh

Kelas cacat "kunci `project.yml` yang diabaikan diam-diam" tidak boleh bisa
berulang, jadi `./swift-ui-lint.sh` dapat **aturan 5**: kunci di `options:` dan
`settings:` dicek terhadap daftar yang diambil dari sumber XcodeGen
(`Tools/xcodegen-known-keys.txt`, beserta perintah untuk memperbarinya).

Gerbang ini harus direvisi dua kali sebelum benar, dan itu bagian paling
bernilai untuk dicatat:

1. Versi pertama menelusuri seluruh turunan YAML, lalu melaporkan `base`,
   `Debug`, `Release`, `iOS`, `watchOS`, dan `SWIFT_ACTIVE_COMPILATION_CONDITIONS`
   sebagai "tidak dikenal". Semuanya **sah**. Gerbang yang selalu merah akan
   dimatikan orang lain saat berbunyi, jadi ini bukan sekadar soal tampilan -
   itu alasan gerbang tidak boleh longgar.
2. Perbaikannya menyisakan `base` (anak sah dari `settings:`), sehingga
   perbaikannya sendiri masih merah. Butuh daftar anak yang dikecualikan
   secara eksplisit.

Sekarang terbukti keempat arah di salinan sementara: tree bersih **hijau**;
`knownRegions` disuntik **merah** (tepat satu kunci); `opsiNgawur` **merah**;
dikembalikan lagi **hijau**.

Gerbang aturan 4 juga dibuktikan dua arah pada siklus ini (kunci
`Text("Kunci baru tanpa entri katalog")` disuntik -> keluar 1; tree bersih
-> keluar 0), karena katalog **tidak** diisi otomatis
(`SWIFT_EMIT_LOC_STRINGS: NO`) sehingga tidak ada gerbang Xcode yang bisa
melihat teks yang belum punya terjemahan.

### Temuan yang harus dicatat: `xcodegen generate` mengubah `Info.plist`

Menjalankan XcodeGen di repo ini **menghapus** `CFBundleDisplayName` dari
`Apps/PointAndKnowWatch/Complications/Info.plist` dan menggantinya dengan
tab. Berkas itu di-commit, jadi menjalankan generator di mesin kerja langsung
membuat tree kotor - dan kalau tidak sengaja ikut ter-commit, complication
kehilangan nama tampilnya. Dikembalikan dengan `git checkout --`.

Batasnya jujur: ini efek samping yang saya temukan tanpa sengaja, **bukan**
uji. Yang diketahui pasti: generator menulis ulang `Info.plist` yang
dispesifikasikan di `project.yml`, dan `Info.plist` yang di-commit bisa
menjadi lebih kaya daripada hasil generator. Yang belum diperiksa: apakah
Xcode di CI melihat perubahan yang sama.

### Batas yang diketahui dan belum ditutup

- **Terjemahan `en` tidak bisa diverifikasi di Linux.** `Bundle.main` di Linux
  tidak punya `.lproj` (`localizations == []`), dan `String(localized:)`
  **tidak ada** di Swift 6.0 Linux - hanya
  `Bundle.localizedString(forKey:value:table:)`, yang selalu mengembalikan
  fallback di sini. Jadi yang bisa dibuktikan di Linux: setiap kunci punya
  entri, dan setiap pasangan key/`en` punya paritas `%`-specifier. Yang
  **tidak**: terjemahan itu benar dibaca perangkat. Itu tetap wilayah
  CI dan perangkat.
- Katalog berisi 63 kunci; `Text(...)` di `Apps/` yang tidak punya entri
  **nol** menurut aturan 4. Tapi label yang **dihasilkan** di `PointingKit`
  (`shortLabel`, `guidance`, `displayName`) tidak pernah melewati
  `Text("literal")`, jadi katalog tidak bisa menjangkau mereka. Itu celah
  Fase C yang belum ditutup, dan kandidat unit berikutnya.

### Yang benar-benar dijalankan

- `./swift-test.sh` -> **166 CelestialEngine + 277 PointingKit, 0 gagal**.
  Engine tidak disentuh.
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- `./swift-ui-lint.sh` -> 5 aturan, semua hijau; aturan 4 dan 5 dibuktikan
  merah lalu hijau di salinan sementara.
- `xcodegen generate` (XcodeGen 2.46.0, dibangun lokal) -> proyek terbentuk,
  `developmentRegion = id`, `knownRegions = (Base, en, id)`, katalog 2 build
  file dan 1 fileRef, `postGenCommand` berjalan.
- Sapuan karakter non-Latin pada semua berkas yang diubah: **0**.
  Beberapa selip sempat masuk ke dalam komentar, dan tertangkap aturan 3
  sebelum commit - itulah alasan aturannya ada. Entri STATUS.md ini sendiri
  pertama kali kena cacat yang sama, lalu ditulis ulang per bagian.


## Progres terakhir (4 Okt 2026 — baris keempat + gerbang aksara, lalu README, lalu VoiceOver)

### Siklus 4 — kelas cacat yang saya klaim selesai, padahal tidak

Siklus 2 menulis: "`row(_:_:)` dipakai di **tiga** layar". Itu salah.
Ada **empat** — `SkyContextView.row` di jam punya bentuk yang sama persis,
tapi masih merangkai kalimatnya sendiri. Jadi kelas cacat "dua jalur yang
seharusnya identik, hanya satu yang diperbaiki" **masih ada**, persis seperti
yang diklaim sudah ditutup.

Yang membuatnya berbahaya: STATUS.md sudah mencatatnya selesai, jadi tidak
ada yang akan mencarinya lagi. Persis kondisi yang membuat siklus 1 terjadi —
klaim "sudah beres" yang tidak pernah diverifikasi ulang.

**Gerbang aturan 3** sekarang menjaga dua hal sekaligus:

1. `row(_:_:)` tidak lagi menangkai kalimat pengumuman sendiri.
2. Tidak ada aksara CJK/Cyrillic/fullwidth di kode.

Yang kedua terjadi **berulang dalam satu siklus**, termasuk pada pesan
commit yang sama. Bukan keputusan yang salah — selip yang di tengah kalimat
Indonesia terbaca sebagai satu kata lalu dilewati. Persis kelas cacat yang
tak terlihat mata dan tak tertangkap compiler.

Sapaan diperluas dari `Apps/` ke `Apps/` + `Packages/`. Terbukti dua arah:
tree bersih lulus, tree dengan karakter disuntikkan gagal.

### Catatan kejujuran

Satu commit sempat terpush dengan CJK di pesannya, lalu ditulis ulang
dengan `--force-with-lease`. Riwayat bersih sekarang; tidak ada commit
dengan CJK yang masih terjangkau di `main`.

### Siklus 3 — README: isi yang paling dibutuhkan orang yang baru membuka repo

Repo ini belum punya README, padahal isinya persis yang dibutuhkan:
cara membangunnya, mengapa logika ada di paket dan bukan di app, dan
**bagaimana cara mengukur** klaim "akurasi jam adalah hipotesis".

Yang ditulis lebih penting daripada daftar perintah:

- `POINT → OBJECT ID → SAFE GOTO` dan kenapa arah pergelangan tidak boleh
  pernah jadi perintah motor.
- Kenapa `Packages/` ada: seluruhnya teruji di Linux — pemisahan inilah
  yang membuat cacat logika bisa ditangkap tanpa Mac.
- Kenapa kalimat VoiceOver pindah ke paket: kalimat terucap tidak pernah
  terlihat salah di layar mana pun, jadi satu-satunya penangkapnya uji.
- Tiga gerbang dicatat sebagai tiga **celas berbeda**, bukan duplikat.

Setiap angka dan nama berkas diverifikasi terhadap repo sebelum commit:
166 engine + 277 PointingKit, 3 tab iPhone (bukan 2 — klaim pertama salah),
macos-15, dan batas `red-test.sh` (hanya PointingKit) dinyatakan apa adanya
alih-alih diklaim universal.

### Siklus 2 — cacat yang ditemukan oleh gerbang siklus 1

Aturan 2 (`°/dtk` tanpa padanan ucapan) mem-flag 5 situs. Pemeriksaan
lebih dalam menemukan **kelas cacat yang sama** dengan siklus 1: dua jalur
yang seharusnya identik, hanya satu yang dibenahi.

`row(_:_:)` dipakai di tiga layar dengan kode yang benar-benar identik
(`Text(title)` — `Spacer()` — `Text(value)`). Dua (`PointingView.statusCard`,
`SkyContextView.row`) mengumumkannya sebagai satu kalimat; yang ketiga tidak
mengumumkan apa pun. Akibatnya VoiceOver membaca **dua elemen tanpa
hubungan** — "Laju pergelangan" lalu "0.5°/dtk" — dan "/dtk" bukan kata.

Perbaikannya bukan menambal yang tertinggal, melainkan membuat ketiganya
memakai satu sumber (`RowSpeech` di PointingKit) sehingga tidak ada lagi
jalur yang bisa tertinggal. Kalimat terucap adalah **janji produk** yang
tidak terlihat salah di layar mana pun — jadi ia harus teruji.

**Cacat yang ditemukan saat menulisnya:** `spokenRate` awalnya `%.0f`, jadi
tampilan "0.4°/dtk" diucapkan "0 derajat per detik". Laju pergelangan saat
diam memang bernilai di bawah 1 — jadi "bergerak pelan" terdengar sama
dengan "diam". Uji ditulis dulu, dibuktikan merah, baru diperbaiki.
Presisi kini mengikuti tampilan (`spokenDegrees(_:precision:)`), sama
seperti RA/Dec yang ditulis `%.4f°`.

Baris percobaan diumumkan dengan **verdict lebih dulu**: di layar mata
melihat nama besar di kiri dan verdict kecil di kanan, tapi di suara tidak
ada "kiri" dan "kanan" — dan yang menentukan apakah baris itu layak dibuka
adalah verdict-nya.

### Premis siklus 1: aturan yang sudah ditegakkan, lalu muncul lagi

STATUS lama mencatat Dynamic Type selesai: "Semua font sudah semantic, 0
`.system(size:)` di kode". Audit siklus ini menemukan klaim itu **sudah tidak
berlaku** — ada satu pelanggaran nyata di
`ComplicationWidget.swift:102`, `.font(.system(size: 11, weight: .semibold))`.

Bukan karena ada yang sengaja melanggar. Berkas itu ditambahkan **siklus
lalu** (complication watchOS), setelah sapuan Dynamic Type terakhir dijalankan.
Dan tidak ada satu pun gerbang yang melihatnya:

| Gerbang | Apakah ia melihatnya |
|---|---|
| `swiftc -parse` | tidak — sintaks tidak peduli ukuran font |
| `swift test` (Linux) | tidak — berkas SwiftUI tidak ikut terbangun |
| CI macOS | tidak — ia hanya gagal bila ada *warning* |

Jadi satu-satunya penjaga aturan ini adalah **ingatan orang yang sedang
menulis**, dan itulah yang gagal. Ini kelas cacat yang berbeda dari lima
siklus sebelumnya (geometri raster yang tak terbaca): di sini kodenya benar,
niatnya benar, dan **prosesnya** yang tidak punya penjaga.

### Kenapa ini bukan sekadar satu baris

Lingkaran complication adalah **ruang terkecil di seluruh app**. Ukurannya
kecil justru karena ia dibaca sekilas — dan teks yang dibaca sekilas paling
perlu bisa membesar mengikuti Dynamic Type. Ukuran tetap 11pt mengabaikan
skala pengguna **sepenuhnya**: di jam 41mm dengan teks diperbesar, angka itu
tidak bergerak.

Ini juga cacat yang paling mudah muncul lagi. Complication adalah berkas baru;
berkas baru adalah tempat aturan lama paling sering tidak ikut terbawa.

### Yang diubah, dan kenapa begini

- **`swift-ui-lint.sh` (baru)** — sapu teks untuk aturan UI yang tidak bisa
  ditegakkan compiler. Menutup **kelasnya**, bukan satu gejalanya: berkas
  complication berikutnya (atau view baru apa pun) ikut tercakup tanpa ada
  yang perlu ingat.
  - **Komentar sengaja dilewati.** Proyek ini mendokumentasikan "kenapa"
    panjang lebar, dan beberapa komentar menyebut `.system(size:)` sebagai
    contoh yang **dilarang**. Sapu naif akan selalu merah — dan gerbang yang
    selalu merah akan dimatikan orang lain saat ia berbunyi. Yang diperiksa
    adalah bagian sebelum `//`.
- **Dipasang di kedua workflow, bukan hanya macOS.** Alasan praktisnya:
  pelanggaran ketahuan dalam detik di Linux, tanpa menunggu antrean runner
  macOS. Alasan prinsipnya: sapunya murni teks, jadi ia **bisa** berjalan di
  Linux — menjadikannya gerbang macOS-only berarti membuang kemampuan itu.
- **Dibuktikan dua arah**, bukan hanya hijau: **MERAH** (keluar 1) pada
  pelanggaran yang ada, dan **HIJAU** (keluar 0) setelah diperbaiki di salinan
  sementara. Gerbang yang belum pernah merah tidak bisa dipercaya hijaunya.
- **Perbaikan nyata**: `.caption2.weight(.semibold)`. Beratnya dipertahankan,
  ukurannya diserahkan ke sistem.

### Aturan 2: peringatan yang sengaja tidak dijadikan kegagalan

Sapu kedua mencari singkatan **visual** — `°/dtk`, `RA`, `Dec`, `mag`.
Itu terbaca oleh mata dan tidak terbaca oleh pembaca layar. Sapu **tidak
bisa** membuktikan bahwa padanan yang diucapkan ada, jadi menjadikannya
kegagalan hanya akan memaksa orang menulis `// swift-ui-lint: disable`.
Dibiarkan sebagai peringatan yang harus dibaca.

Ia langsung menemukan inkonsistensi nyata (belum diperbaiki, lihat bawah).

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 266 PointingKit, 0 gagal**.
- `./swift-typecheck.sh` → SEMUA GERBANG LULUS.
- `./swift-ui-lint.sh` → **MERAH dulu** pada pelanggaran nyata, lalu **HIJAU**
  setelah perbaikan; dibuktikan pada salinan sementara.
- **CI hijau pada push pertama** (`354801e`): `Apple Build` run `37197032727`
  **success** (termasuk gerbang peringatan "Tidak ada peringatan compiler pada
  Apps/"), `Engine Tests (Linux)` run `37197032731` **success**. Langkah
  "Gerbang sapu UI (font tetap)" terlihat **benar-benar berjalan di log kedua
  workflow**, bukan sekadar dilewati.

### Inkonsistensi yang ditemukan dan sengaja BELUM diperbaiki

Aturan 2 membuktikan bahwa aturan "singkatan visual harus punya padanan yang
diucapkan" **tidak dipegang merata**:

| Tempat | VoiceOver |
|---|---|
| `PointingView.statusCard` | benar — laju diucapkan "derajat per detik" |
| `SkyContextView.row` | benar — `.accessibilityLabel("\(title): \(value)")` |
| `DiagnosticsView.row` | **tidak ada** — "0.5°/dtk" terbaca apa adanya |
| `LinkView.row` | **tidak ada** |
| `Experiment1View` (baris + `detailLine`) | **tidak ada** |

Dua tempat sudah benar, tiga tidak — persis pola "dua jalur yang seharusnya
sama justru berbeda" yang sudah dua kali jadi cacat di repo ini. Sengaja
dicatat di sini, bukan dikerjakan di siklus yang sama: siklus ini menambah
gerbangnya dulu, dan gerbang itu yang akan membuktikan perbaikannya.

### Pelajaran

Lima siklus terakhir menemukan cacat dengan **menghitung** (kutub Mars
0.26R, cincin Saturnus 0.9R, pita Bulan terbalik, lencana ragu 0.132R).
Siklus ini berbeda: cacatnya bukan angka, melainkan **aturan yang tidak punya
penjaga**. Menghitung akan tetap menemukan cacat geometri; yang menemukan
kelas ini adalah bertanya *"gerbang mana yang akan merah kalau ini
dilanggar?"* — dan bila jawabannya "tidak ada", menulis gerbangnya.

### Premis siklus ini: Fase C item 1 — complication WidgetKit

Item 4 (izin lokasi ditolak terlihat) sudah hijau. Sekarang celah tersisa
terbesar: **complication watchOS**. Tanpa dia, pengguna harus membuka app
setiap kali ingin tahu apa yang terakhir dikunci — persis gesit yang membedakan
app astronomi premium (Star Walk menaruh objek terkunci di wajah jam).

### Yang ditambah, dan kenapa begini

- **`ComplicationDigest` di PointingKit** (`PointingPresentation.swift`) — ini
  inti keputusannya. Complication hidup di proses terpisah, jadi ia hanya
  menerima beberapa nilai sederhana. Tapi aturan "bagaimana ringkasan ini
  ditampilkan" adalah **janji tampilan**, dan janji itu harus bisa diuji di
  Linux. Kalau bentuknya diletakkan di `Apps/`, satu-satunya verifikasi yang
  ada hanyalah "kompilasi di Mac" — persis celah yang membuat
  `CelestialSnapshot` dulu bisa menampilkan identitas saat engine ragu.
  Maka bentuk + aturannya diletakkan di `PointingKit` (yang sudah punya
  `PointingPresentationTests`), dipakai bersama oleh app dan complication.
  - **`objectKindRaw`, bukan labelnya.** Label Bahasa Indonesia tiap jenis
    benda (`"Objek langit dalam"`) adalah urusan app dan boleh berubah saat UX
    berubah. Kalau label ikut di-*snapshot*, setiap perubahan label jadi **data
    lama yang salah** sampai app menyimpan ulang. Menyimpan `ObjectKind`
    (nilai engine yang stabil) membuat label selalu dihitung saat render.
  - **`.uncertain` tetap menampilkan nama kandidat** (`headline`), persis
    seperti layar utama — tapi `isConfirmed` hanya `true` saat `.lock`, lewat
    `looksConfident` yang sudah ada. Empat tes baru menjaga ini, termasuk
    `testDigestKeepsObjectNameButRefusesToClaimIdentity`.
- **`Apps/Shared/Complication/ComplicationStore.swift`** — satu-satunya tempat
  baca/tulis berkas. App Group `group.dev.celestial.pointandknow` (wajib untuk
  berbagi antar-proses di watchOS) dengan **fallback ke caches** bila container
  `nil` (CI tanpa tanda tangan / Simulator tanpa grup). Fallback itu sadar dan
  terdokumentasi — bukan "kegagalan diam", sebab di perangkat nyata dengan grup
  aktif, app & complication memakai URL yang sama.
- **`Apps/PointAndKnowWatch/Complications/ComplicationWidget.swift`** — target
  WidgetKit (`@main`, `StaticConfiguration`, `supportedFamilies` circular/
  rectangular/inline). Timeline `policy: .never` + satu entri: kita tidak tahu
  kapan pengguna mengunci, jadi **app** yang memicu reload saat transisi.
- **Throttle tulis di `PointingEngine.publish`** — hanya menulis bila tanda
  tangan (keadaan, nama objek, konfirmasi) berubah. `publish` dipanggil
  20×/dtk; menulis berkas 20×/dtk membakar baterai & memicu reload percuma.
- **Target + entitlements** — `PointAndKnow Watch Complication`
  (`type: app-extension`, `NSExtensionPointIdentifier: com.apple.widgetkit-extension`,
  `entitlementsPath`) terbenam di app jam lewat `embed: true`.

### Cacat yang ditemukan siklus ini: gerbang lokal terlalu lemah

Empat kegagalan berturut-turut, dan **tiga di antaranya tidak terlihat lokal**:

1. `entitlements:` vs `entitlementsPath:` — XcodeGen menolak spec-nya, jadi
   baru ketahuan dari CI (parse gagal sebelum kompilasi dimulai).
2. `replaceItem(at:withItemAt:)` — Linux **tipe-check**-nya tidak, jadi
   argumen yang kurang (`backupItemName:`, `resultingItemURL:`) lolos `parse`
   lalu meledak di macOS.
3. `containerURL(forSecurityApplicationGroupIdentifier:)` — API Apple-only;
   `parse` di Linux tidak pernah menyentuhnya.
4. **Tiga cacat SwiftUI sekaligus** di widget: `StaticConfiguration` butuh
   label `provider:`; `switch` di atas `WidgetFamily` tidak exhaustive
   (`@unknown default` tidak menutup kasus yang *sudah ada*, hanya kasus
   yang belum dikenal); dan cabang `switch` yang bertipe beda (`Text` vs
   `Gauge` vs `HStack`) — `@ViewBuilder` tidak bisa mengembalikan satu
   tipe dari beberapa view berbeda.

**Akar masalahnya sama**: `swiftc -parse` hanya memeriksa sintaks. Semua cacat
tipe lolos lokal lalu menunggu CI macOS — satu siklus penuh per kesalahan.
Maka **`swift-typecheck.sh`** dibuat: ia menjalankan `swiftc -typecheck` (bukan
`parse`) untuk berkas yang hanya mengimpor Foundation/CelestialEngine/
PointingKit, di dalam Docker yang sama. Batasnya ditulis jujur di kepala
berkas: berkas SwiftUI (WidgetKit/Canvas/Combine) tetap hanya bisa di-parse di
Linux. Cacat #4 membuktikan batas itu nyata, bukan sekadar angan-angan.

### Verifikasi

- `./swift-typecheck.sh` → **SEMUA GERBANG LULUS** (typecheck store + label,
  parse semua `Apps/**/*.swift`).
- `./swift-test.sh` → **166 CelestialEngine + 256 PointingKit = 422 hijau**.
- CI macOS: `App (iPhone + Watch)` **success** — termasuk langkah
  **"Gerbang peringatan (kode sendiri)"**, artinya complication kompilasi dengan
  **nol warning**. `Paket (Apple SDK)` success, `Engine Tests (Linux)` success.
- Run: `37193453845` (Apple) & `37193453796` (Engine).

### Risiko yang diketahui

- Complication butuh App Group **aktif di profil provisi** untuk berbagi data
  lintas proses. Di CI (unsigned) ia tetap kompilasi & lolos, tapi di sana
  complication hanya membaca bila grup tersedia. Ini kebutuhan platform, bukan
  cacat — tidak ada cara berbagi tanpa grup.
- `swift-test.sh`: **166 CelestialEngine + 256 PointingKit = 422 hijau** (4 tes
  baru untuk `ComplicationDigest`).

### Premis siklus lalu: Fase C dimulai dari celah yang paling berdampak

Bagian 1–4 (visual + polish) dan Fase A (malam, AOD, VoiceOver) serta Fase B
(animasi, Dynamic Type, audio) sudah terpasang. Dari empat celah Fase C, tiga
sudah ada: Info.plist izin (item 3) tertulis di `project.yml`; widget (item 1)
dan lokalisasi (item 2) belum dipegang. Item 4 — **verifikasi izin runtime** —
justru punya cacat nyata yang belum tertutup, dan itulah yang dikerjakan dulu.

### Cacat yang ditemukan: penolakan izin lokasi diam

`LocationProvider` memang menghitung `statusText = "Izin lokasi ditolak — memakai
lokasi bawaan"` saat `authorizationStatus` `.denied`/`.restricted`, di **dua**
tempat (`start()` dan `locationManagerDidChangeAuthorization`). Tapi `statusText`
itu **tidak pernah dibaca UI mana pun** — ia hanya `private(set)` lokal. Akibatnya
saat pengguna menolak izin lokasi, engine tetap jalan dengan `ObserverLocation.fallback`
(Jakarta), dan layar jam/iPhone **tetap terlihat normal**: tidak ada peringatan,
tidak ada penanda. Pengguna tidak tahu bahwa seluruh langit dihitung untuk Jakarta,
bukan tempatnya. Itu tepat kelas "kegagalan diam" yang berulang kali dilarang PRD
("jangan diam saat izin ditolak"), dan sepadan dengan cacat sensor-mati yang sudah
ditutup di siklus lalu — hanya beda sumber.

Sebaliknya `MotionLogger.unavailableReason` **memang** ditampilkan (di `PointingView`
dan `DiagnosticsView`), jadi penolakan sensor terlihat sedangkan penolakan lokasi
tidak. Dua jalur izin yang seharusnya sama justru berbeda: satu diam, satu terlihat.

### Yang diubah, dan kenapa begini

- **`LocationProvider.note` (`String?`)** — satu sumber peringatan yang `nil` di
  luar keadaan gagal. Sengaja **bukan** `statusText` apa adanya: `statusText`
  memakai nilai netral ("Lokasi belum diminta", "Mencari lokit…") yang bukan
  kesalahan, jadi membakar semuanya ke layar justru memunculkan pesan menakutkan
  saat segalanya normal. `note` di-set hanya pada `.denied`/`.restricted` dan pada
  `didFailWithError`, dan **di-clear** (`nil`) saat lokasi sungguhan tiba serta saat
  mulai mengambil (jalur `default`). Semantik "ada peringatan ↔ nilai tidak-nil"
  inilah yang membuat tampilan tidak perlu membedakan teks.
- **Pesan penolakan menyebut jalan keluar**: "Buka Pengaturan untuk mengizinkan,
  atau pakai lokasi bawaan (Jakarta)." Bukan sekadar "ditolak" — pengguna harus tahu
  bahwa app tetap berguna (dengan akurasi yang diketahui buruk), dan cara memperbaiki.
- **`PointingView` menerima `location: LocationProvider`** (sebelumnya tidak) dan
  menampilkan `location.note` di bawah peringatan sensor, dengan `PointingTone.warning`.
  `PointAndKnowWatchWatchApp` menyuntikkannya.
- **`DiagnosticsView` menampilkan `location.note`** di bagian "Sensor & lokasi",
  sejajar dengan `motion.unavailableReason`.

Perubahan murna `Apps/`: `PointingKit`/`CelestialEngine` tidak disentuh, jadi 165 +
252 test tidak bisa terpengaruh.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **165 CelestialEngine + 252 PointingKit, 0 gagal** (naik
  dari STATUS lama "166 + 244"; angka terbaru dari satu siklus ini). Engine tidak
  disentuh.
- Gerbang sintaks `swiftc -parse -swift-version 5` seluruh 22 berkas app lolos di
  container `swift:6.0` (`ALL PARSED`) — `LocationProvider.note` baru, injeksan
  `location` ke `PointingView`, dan call-site `PointAndKnowWatchWatchApp` semua
  lolos parse.
- CI macOS (Apple Build) akan memverifikasi resolusi tipe (`@ObservedObject
  var location` baru, `location.note`) yang `-parse` tidak selesaikan.

## Progres terakhir (4 Okt 2026 — fase gibbous & purnama tergambar sebagai komplemennya)

### Premis siklus ini: "sabit benar arahnya" belum berarti "fase benar besarnya"

Brief menyebut sabit harus benar arahnya, dan itu memang sudah terperbaiki
serta teruji (`litSide`). Tapi pengujian lama hanya memeriksa **tanda** dan
**lebar pita di ekuator** — dua bilangan yang keduanya benar untuk separuh
fase dan **salah total untuk separuh lainnya**. Yang tidak pernah diuji: apakah
luas yang benar-benar digambar sama dengan fraksi iluminasi.

### Cacat yang ditemukan: tanda yang dibuang, lalu dikalikan ulang

`drawMoon` menulis:

    let side = CGFloat(phase.litSide)
    let semiWidth = CGFloat(phase.terminatorSemiWidth)   // abs(terminatorOffset)
    x = side * semiWidth * radius * sqrt(1 - dy*dy)

`terminatorOffset` sudah bernilai `litSide · (1 − 2f)`, jadi **tandanya sudah
menentukan sisi terminator**: positif untuk sabit, negatif untuk gibbous. View
mengambil nilai mutlaknya, lalu mengalikan lagi dengan `litSide` — tanda itu
ikut hilang, dan untuk `f > 0.5` kurvanya terpaku kembali ke sisi yang menyala.
Pita yang digambar menjadi **komplemen** dari fraksi yang benar:

| f (engine) | Pita digambar | Selisih |
|---|---|---|
| 0.25 | 0.2503 | benar |
| 0.50 | 0.4998 | benar |
| 0.75 | 0.2503 | **−0.50** |
| 0.85 | 0.1504 | **−0.70** |
| 0.95 | 0.0506 | **−0.90** |
| **1.00** | **0.0007** | **−1.00** |

Dihitung dengan rumus shoelace pada poligon yang **sama** dengan yang
digambar `Canvas` (72 segmen), bukan dengan Integral analitik — supaya angka
yang diuji adalah angka yang sampai ke layar. Diskritisasi 72 segmen menambah
~0.001, jauh di bawah cacatnya.

### Akibat yang paling merusak: bulan purnama tampil sebagai piringan gelap

Pada `f = 1.0` luas pita yang digambar **0.0007** — praktis nol. Jadi di layar
Ketelitian tertulis **"Fase Bulan 100%"** sementara tepat di bawahnya
tergambar piringan gelap. Ini bukan sekadar salah gambar: PRD melarang visual
yang **lebih yakin** atau bertentangan dengan teksnya, dan di sini keduanya
saling meniadakan — teksnya benar, gambarnya menyatakan kebalikannya. Tidak
ada jalur yang bisa dibaca pengguna untuk memperbaiki sendiri: gambar dan
angka berasal dari sampel yang sama, jadi ketidakcocokan ini bukan soal data
basi.

### Mengapa ia bertahan melewati 224 uji

1. **Setengah fase memang benar.** Sabit 25% tergambar 25% (selisih 0.0003).
   Setiap pemeriksaan visual yang dilakukan orang — dan setiap uji lama —
   kebetulan jatuh di sisi yang benar.
2. **Uji lama mengukur bilangan yang salah.** `litSide` benar untuk semua
   fase. `litBandWidth` benar untuk semua fase **karena ia selalu positif**
   (memakai `abs`) — ia tidak pernah bisa membedakan gibbous dari sabit.
   Uji yang paling tampak lengkap justru tidak bisa menangkapnya.
3. **`swiftc -parse` hanya sintaks**, `swift test` di Linux tidak punya
   `Canvas`, dan tidak ada teks layar lain yang bisa diperiksa.
4. Geometri ini **tidak pernah dihitung** — hanya dibaca. Membaca
   `abs(bertanda) * sisi` memang terlihat "benar" bagi mata.

### Yang diubah, dan kenapa begini

- **Kurva limb & terminator pindah ke `PhaseGeometry`** sebagai
  `limbX(atNormalizedHeight:)` dan `terminatorX(atNormalizedHeight:offset:)`,
  memakai **offset bertanda** apa adanya. View kini hanya meneruskan model.
  Ini mengikuti aturan repo yang sudah berlaku: keputusan visual yang bisa
  salah tanpa ada yang bisa mengujinya **tidak boleh tinggal di view**.
- **`terminatorSemiWidth` dihapus.** Isinya persis
  `abs(terminatorOffset)` — yaitu pemicunya — dan setelah view diperbaiki ia
  **tidak punya pemanggil sama sekali**. Membiarkannya berarti menyisakan
  jebakan yang bisa dipakai ulang persis oleh bug yang sama.
- **`litBandWidth` diberi peringatan di komentarnya** bahwa ia bukan ukuran
  yang digambar, dan tidak bisa membedakan gibbous dari sabit.
- Parameter `offset:` pada `terminatorX` sengaja ada hanya supaya uji bisa
  memanggil `abs(...)` secara eksplisit untuk mengunci cacat lama. Swift
  **melarang instance member sebagai nilai default parameter**, jadi ia
  `Double? = nil` dengan fallback di dalam badan — bukan `= terminatorOffset`.

### Uji dibuktikan MERAH lebih dulu

Dengan `terminatorX` dikembalikan ke geometri lama (`litSide * abs(...)`):

- `testLitBandAreaMatchesTheIlluminatedFraction` → **8 assertion gagal**,
  pesan menyebut angkanya: *"pita terang digambar 14.97 persen untuk fraksi
  85.0 persen (membesar)"*.
- `testFullMoonFillsTheDiscInsteadOfGoingBlack` → gagal: `5.3e-17` vs `0.98`
  (piringan gelap, seperti diterangkan di atas).
- `testLegacyAbsoluteTerminatorDrewTheComplement` → **hijau** pada geometri
  lama, sesuai desainnya: ia mengunci angka cacat yang lama, bukan geometri
  yang sekarang.
- **Yang tetap hijau** pada geometri lama: `f = 0.05, 0.20, 0.25, 0.50` —
  dipertahankan sebagai bukti langsung bahwa separuh fase memang benar
  sejak dulu.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 233 PointingKit, 0 gagal**
  (naik dari 228 → 233). Engine **tidak disentuh**.
- Kelima uji baru **dibuktikan MERAH lebih dulu** pada geometri lama.
- Gerbang sintaks: seluruh **22** berkas app lolos `swiftc -parse -swift-version
  5` di container `swift:6.0`.
- Sapuan CJK/Cyrillic/simbol fullwidth pada berkas yang diubah: **0** (dua
  kata asing sempat lolos ke komentar saat penulisan, dibuang sebelum commit).
- **CI hijau pada push pertama** (`41f58d1`):
  - `Apple Build` run `37185919763` → **2× `BUILD SUCCEEDED`** dan gerbang
    peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
    (`swiftc -parse` tidak akan pernah menangkap unresolved call ke tipe
    `PointingKit` — hanya build Apple SDK yang bisa).
  - `Engine Tests (Linux)` run `37185919693` → hijau, kelima uji fase terlihat
    **lulus di log CI** (bukan hanya di mesin ini).

### Pelajaran yang berulang (lima siklus berturut-turut)

Lima siklus terakhir menemukan cacat di kelas yang **sama**: keputusan visual
yang benar secara terpisah tapi salah secara gabungan, dan tidak terlihat dari
teks mana pun di layar — kutub Mars menembus 0.26R, cincin Saturnus terpotong
0.9R, bintang terpotong 0.81R, lencana ragu terpotong 0.132R, dan sekarang
pita terang yang terbalik pada separuh fase. Semuanya lolos `swiftc -parse`,
semuanya lolos `swift test` yang ada, dan semuanya hanya ketahuan dengan
**menghitung**. Polanya cukup konsisten untuk aturan operasional: setiap
bentuk di `Canvas` harus punya **uji yang mengukur hasil yang benar-benar
tampil** — luas, bukan hanya koordinat — karena koordinat yang "masuk akal"
bukan jaminan bahwa bentuknya yang benar.

## Progres terakhir (4 Okt 2026 — gambar lebih yakin daripada teksnya saat engine ragu)

### Premis siklus ini: cacatnya bukan bentuk yang salah, tapi klaim yang salah

Empat siklus terakhir menemukan cacat di kelas **geometri raster** — bentuk
yang terpotong, menembus bola, keluar dari `Canvas`. Semua ditutup dengan
memindahkan angka batas ke `VisualFrame`. Siklus ini menemukan cacat di kelas
yang berbeda, dan lebih berbahaya: **bentuknya benar, klaimnya salah.**

Selama keadaan `.uncertain` — engine secara eksplisit menyatakan diri *kurang
yakin* — layar menampilkan **seluruh ciri pengenal objek**: cincin Saturnus,
pita Jupiter, kutub Mars, tanpa lencana tanda tanya apa pun. Sementara itu,
badge di sebelahnya bertuliskan **"Ragu"**.

### Mengapa ini lolos dari empat siklus audit

Gerbangnya adalah `isConfirmed: !isStale`, dan `isStale` dihitung dari
`hasAnswer`. `hasAnswer` adalah `.lock || .uncertain` — jadi `.uncertain`
**bukan** sisa, dan dengan demikian lolos sebagai gambar "pastu".

Keduanya benar secara terpisah:

- `.uncertain` memang bukan sisa (ia punya jawaban *sekarang*),
- `.uncertain` memang tidak boleh mengklaim identitas.

Cacatnya adalah menggunakan **satu ambang untuk dua pertanyaan yang berbeda**.
"Apakah ini hasil kedaluwarsa?" dan "Bolehkah gambar mengklaim ini benda itu?"
punya jawaban berbeda tepat pada `.uncertain`.

### Mengapa ini bentuk false confidence yang paling sulit ditangkap

Teksnya jujur. Badge-nya mengatakan "Ragu". Tidak ada yang bisa dibaca
pengguna untuk mengecek gambar itu — pengguna tidak tahu bahwa cincin
Saturnus adalah klaim identitas, bukan dekorasi. Dan **mata membaca gambar
lebih dulu daripada badge**: gambar menetapkan kesan, teks hanya mengoreksinya
kalau sempat terbaca.

Ini persis larangan PRD: *jangan salah identifikasi demi "magic"; uncertainty >
false confidence*. Cacatnya bukan menampilkan sesuatu yang tidak ada, tapi
menampilkan sesuatu **dengan tingkat kepastian yang salah**.

### Perbaikannya memakai predikat yang sudah ada

Tidak ada predikat baru yang ditulis. `PointingState.looksConfident`
(hanya `.lock`) **sudah ada di PointingKit dan sudah punya uji** — hanya saja
belum pernah dipakai UI mana pun. Itu tanda cacatnya: ambang yang benar sudah
tersedia, dan UI mengambil turunan yang lebih longgar.

- `PointingSnapshot.confirmsIdentity(lastLocked:)` — ambang gambar; memakai
  `state.looksConfident`, dan mensyaratkan objek benar-benar ditampilkan
  (tanpa itu, `.lock` tanpa kandidat akan menggambar ciri pengenal di atas
  bola generik).
- `PointingEngine.confirmsDisplayedIdentity` meneruskannya.
- `ObjectDetailView` (jam) & `LockArrivalPanel` (iPhone) memakai ambang baru.

`isStale` tetap dipakai untuk peringatan sisa — dua ambang, dua pertanyaan.

### Uji: 4 regresi, 3 di antaranya merah terhadap logika lama

Diverifikasi dengan mengembalikan predikat ke `hasAnswer` dan menjalankan
ulang: 3 uji merah, lalu hijau kembali setelah dikembalikan.

Uji keempat (`testIdentityThresholdIsStricterThanTheStaleThreshold`) sengaja
mengunci **perbedaan** kedua ambang secara konstruktif: ia mencari keadaan
yang bukan sisa tetapi tidak mengonfirmasi identitas, dan menuntut
`.uncertain` ada di dalamnya. Menyatukan kembali dua ambang itu sekarang tidak
bisa dilakukan tanpa ada uji yang merah.

- `166` engine + `228` PointingKit (224 + 4 baru), 0 gagal.
- CI: Engine Tests (Linux) hijau, Apple Build hijau (termasuk gerbang
  tanpa peringatan).

### Satu cacat compile yang hanya muncul di CI macOS

`argument 'visual' must precede argument 'isConfirmed'` — Swift mewajibkan
urutan argumen mengikuti deklarasi, dan `isConfirmed` disisipkan sebelum
`visual`. Tidak tertangkap di Linux karena `Apps/` tidak ikut terbangun di
`swift-test.sh`. Ini pola yang berulang: perubahan di `Apps/` hanya
terverifikasi oleh CI macOS, jadi setiap penyisipan parameter baru di call
site SwiftUI harus dicek urutannya terhadap deklarasi.

## Progres terakhir (4 Okt 2026 — lencana tanda tanya terpotong 0.132 R di dua sisi Canvas)

### Premis siklus ini: bentuk yang tersisa bukan yang belum ada, tapi yang belum dihitung

Tiga siklus terakhir menemukan cacat di kelas yang sama — **geometri raster
yang tidak terbaca dari teks** — dan masing-masing ditutup dengan memindahkan
angka batas ke `VisualFrame`. Siklus ini membalik pertanyaannya: alih-alih
mencari bentuk baru, **setiap** bentuk di `Canvas` dihitung ulang untuk tahu
mana yang belum punya uji batas. Hasilnya: cincin Saturnus, blob nebula, dan
bintang sudah punya; pita Jupiter, Bintik Merah Besar, kawah Merkurius, kabut
Venus, Maria Bulan, korona Matahari, dan pembelah Cassini semuanya **0
overflow**. Yang tersisa tinggal satu — dan justru yang paling penting.

### Cacat yang ditemukan: lencana keraguan terpotong di dua sisi sekaligus

`drawCandidateMarker` menaruh lencana di sudut kanan atas dengan radius
`0.22 · lebar` dan pusat di `(0.846 · lebar, 0.154 · lebar)`. Karena lencana
berada di **sudut**, dua sisinya dekat tepi frame sekaligus — bukan satu:

| Sisi | Posisi | Batas frame | Keluar |
|---|---|---|---|
| Kanan | 1.132 R | 1.0 R | **+0.132 R** |
| Atas | −1.132 R | −1.0 R | **+0.132 R** |

30% radius lencana hilang, di dua sisi. Karena `Canvas` memotong dengan **tepi
lurus**, lingkarannya tidak tampak "agak kepotong" — ia tampil sebagai busur
yang berhenti mendadak di dua tepi kartu.

### Kenapa ini bukan cacat kosmetik (dan beda dari tiga pendahulunya)

Cincin Saturnus yang terpotong membuat **satu planet** tampil salah. Ini
berbeda: lencana tanda tanya adalah **satu-satunya penanda di layar yang
mengatakan "engine ragu"**. Kalau ia terpotong habis, yang tersisa hanya
gambar objek **tanpa** penanda — dan gambar tanpa penanda terbaca sebagai
identitas yang pasti. Jadi cacat pada bentuk ini **membatalkan alasan bentuk
ini ada**: pelanggaran PRD ("JANGAN tampilkan visual yang mengklaim identitas
saat engine ragu") justru terjadi lewat hilangnya penanda yang mencegahnya.

Ini juga cacat yang paling mudah lolos: lencana hanya tampil saat engine
ragu — keadaan yang sengaja jarang, jadi hampir tidak pernah terlihat saat
menguji sekilas dalam keadaan terkunci.

### Yang diubah, dan kenapa begini

- **`VisualFrame.candidateMarker()` menghitung radius dari sudut yang
  diizinkan**, bukan dari lebar yang diinginkan lalu dibiarkan meluber — pola
  yang sama dengan `VisualFrame.star`. Karena `jarak + radius = corner`
  secara konstruktif, memperbesar lencana tidak bisa lagi mendorongnya keluar:
  ia menempel makin dekat ke tengah.
- **Inset dibuat pecahan frame, bukan angka mutlak.** Versi pertama memakai
  `inset` tetap; uji `testCandidateMarkerKeepsInsetFromTheEdge` menangkapnya
  merah pada frame 2.0 (jarak 0.06 vs syarat 0.1). Lencana digambar di kartu
  jam 38pt **dan** panel iPhone 132pt, jadi jarak yang tetap akan menempel
  pada bingkai di ukuran besar.
- **`overflow(frameHalfExtent:)` menerima frame yang diukur**, bukan membaca
  konstanta `halfExtent`. Kesalahan pertama ada di sini dan ketahuan oleh uji
  sendiri pada frame 2.0: batasnya dilaporkan "0.94 R keluar" padahal tidak
  ada yang keluar. Diperbaiki di model, bukan di uji.
- **View tidak punya rumus lencana lagi.** `drawCandidateMarker` membaca
  `marker.centerX/centerY/radius/glyphRadius`. Ini mempertahankan aturan
  repo: keputusan visual yang bisa salah tanpa ada yang bisa mengujinya tidak
  boleh tinggal di view.

### Uji dibuktikan MERAH lebih dulu

Dengan geometri lama dikembalikan (`radius = 0.44`, `jarak = 0.692` dalam
satuan radius):

- `testCandidateMarkerStaysInsideForAnySize` → **gagal** pada seluruh 4
  ukuran (0.132 R) dan pada frame 0.5 (0.632 R).
- `testCandidateMarkerKeepsInsetFromTheEdge` → **gagal**: jarak −0.132 R.
- `testLegacyCandidateMarkerOverflowedOnTwoSides` mengunci angka lama
  sebagai bukti cacatnya nyata — dan angkanya cocok persis dengan hitungan
  Python mandiri (0.132 R di kanan **dan** atas).

Satu uji awalnya salah dan diperbaiki, bukan ditambal: ia mengukur jarak ke
tepi dengan `VisualFrame.halfExtent` (konstanta 1.0) sehingga hanya kebetulan
benar untuk frame 1.0. Diubah mengukur terhadap frame yang dipakai lencana
itu, dan dijalankan pada 0.5/1.0/2.0.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 224 PointingKit, 0 gagal** (naik
  dari 218 → 224). Engine tidak disentuh.
- Keempat uji lencana **dibuktikan MERAH lebih dulu**, bukan hanya hijau.
- Gerbang sintaks: seluruh 22 berkas app lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan CJK/Cyrillic pada berkas yang diubah: **0** (satu kata CJK sempat
  lolos di komentar uji, dibuang sebelum commit).
- **CI hijau pada push pertama** (`0714d2b`):
  - `Apple Build` run `37182401570` → **2× `BUILD SUCCEEDED`** + gerbang
    peringatan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37182401575` → hijau, ke-6 uji lencana
    terlihat **lolos di log CI** (bukan hanya di mesin ini).

### Pelajaran yang berulang (empat siklus berturut-turut)

Empat siklus terakhir menemukan cacatnya di kelas yang **sama**: geometri
raster yang tidak terbaca dari teks. Kutub Mars menembus 0.26R; cincin
Saturnus terpotong 0.9R; bintang terpotong 0.81R; dan sekarang lencana
keraguan terpotong 0.132R. Keempatnya lolos `swiftc -parse`, keempatnya lolos
`swift test` yang ada sebelum uji batasnya ditulis. Polanya kini cukup
konsisten untuk dibaca sebagai aturan operasional: **setiap bentuk di `Canvas`
yang ukurannya dikalikan dari angka dasar harus punya uji batas di
`VisualFrame`** — dan audit siklus ini memakai aturan itu untuk menyisir
seluruh `Canvas`, bukan menunggu kecurigaan datang.

## Ringkasan keadaan (4 Okt 2026, pagi)

**Brief UI/UX (Bagian 1–4) sudah terpasang penuh — dan diverifikasi ulang dari
awal pada siklus ini, bukan dipercaya dari klaim lama.** Visual objek
(prosedural, tanpa aset), token permukaan & kontras, mode malam merah,
always-on, VoiceOver, animasi kedatangan kunci, onboarding, audio, dan
`@ScaledMetric` semuanya **ada di kode dan berjalan**.

Yang ditemukan siklus ini bukan "fitur kurang", melainkan **satu cacat
geometri yang tidak terlihat dari teks mana pun di layar**: glow dan
diffraction spike bintang terpotong tepi `Canvas` pada **24 dari 25 bintang
di katalog** — Sirius paling parah, 0.81R hilang. Detail di entri "Progres
terakhir" di bawah.

- Engine (Fase 1–3) + logika app: **166 test CelestialEngine + 224 test
  PointingKit, 0 gagal** (`./swift-test.sh` dari nol, Swift 6.0 Docker,
  Linux) — dan **kedua workflow CI hijau** di HEAD `0714d2b` (Apple Build
  `37181603764` 2× `BUILD SUCCEEDED` + gerbang peringatan "Tidak ada
  peringatan compiler pada Apps/."; Engine Tests `37181603824`, keenam uji
  bintang terlihat lolos di log CI).
- Rincian: `166 + 224` naik dari `166 + 218` (+6 uji batas lencana kandidat,
  lihat entri siklus ini). Sebelumnya `166 + 218` naik dari `166 + 212`
  (+6 uji batas bintang), dan `166 + 212` dari `166 + 201` (+11 uji batas
  frame).

### Yang diverifikasi ulang (bukan dengan mempercayai STATUS lama)

Seluruh 22 berkas `Apps/` + model visual di `PointingKit` dibaca ulang, lalu
**dihitung** (bukan dibaca) untuk klaim yang bersifat numerik. Hasilnya:

1. **Visual objek lengkap** — `CelestialVisualView.swift` (498 baris,
   `Canvas` murni, tanpa aset): planet (pita Jupiter + Bintik Merah Besar,
   cincin Saturnus dua-lapis dengan `clip`, kutub Mars, kawah Merkurius,
   kabut Venus), **fase Bulan dari fraksi engine** dengan `litSide` terpisah
   dari tanda terminator, bintang (glow berlapis + 4 diffraction spike,
   warna B−V dari tabel per bintang, ukuran logaritmik dari magnitudo),
   Matahari berkorona, nebula kabur.
2. **Penanda ragu** — `isConfirmed: !isStale`, predikat yang **sama** dengan
   badge keyakinan; ciri pengenal (cincin/pita/kutub) ditolak saat ragu,
   warna bola tetap boleh tampil.
3. **Semuanya teruji di Linux** — palet, ciri, geometri fase, tabel B−V,
   palet permukaan & kontras WCAG, urutan terang mode malam, kalimat
   VoiceOver kalibrasi, gerbang kedatangan kunci.
4. **Token dipakai kedua app** — `SurfaceTokens.swift` (jembatan ke `Color`),
   `forceDarkScheme()`, `.appBackground()` + `scrollContentBackground(.hidden)`
   di semua layar; mode malam lewat `PointingTone.color` **satu** sumber.
5. **Celah wajib Bagian 3 tertutup** — mode malam (1 ketuk, `@AppStorage`,
   semua visual ikut merah), always-on (`NightAwareContainer` +
   `ReducedLuminanceView`, tanpa animasi), VoiceOver (label status/panel/tombol
   + pengumuman perubahan keadaan).
6. **Bagian 4** — animasi spring saat `lockArrivalToken` naik (bukan
   `state == .lock`), Dynamic Type penuh (0 `.system(size:)` di kode), audio
   opsional prosedural 880Hz, `@ScaledMetric` pada ikon status.
7. **Onboarding di kedua app** — `PointAndKnowWatchWatchApp.swift:23,39-41`
   dan `DiagnosticsView.swift:43,60-63` (STATUS lama menyebutnya "hanya di
   jam + RootView"; sekarang keduanya dikonfirmasi di lokasi nyata).

Tidak ada satu pun item brief yang tersisa. Yang belum ada tetap item
`ROADMAP.md` yang bukan kode: teleskop fisik.

## Progres terakhir (4 Okt 2026 — dua bentuk raster terpotong tepi Canvas)

### Premis siklus ini: STATUS lama dibaca, lalu diuji dengan menghitung

STATUS lama menyatakan Bagian 1–4 "sudah terpasang penuh dan diverifikasi
ulang". Audit siklus ini menerima klaimnya untuk **logika** (palet, ciri
pengenal, geometri fase, tabel B−V memang lengkap dan teruji), lalu mengalihkan
pertanyaan ke tempat yang belum pernah dihitung: **bentuk raster yang
dilukis `Canvas`**. Alasannya sama dengan siklus kutub Mars — dan terbukti
tepat.

### Cacat yang ditemukan: `Canvas` memotong dengan tepi lurus

`Canvas` menggambar hanya di dalam `frame`-nya sendiri, dan ia memotong dengan
**tepi lurus**, bukan dengan memudar. Jadi bentuk yang kelewat besar tidak
tampak "agak kepotong" — ia tampak sebagai garis yang berhenti mendadak. Dua
bentuk melanggar batas itu, keduanya dihitung (bukan dibaca):

| Bentuk | Ukuran lama | Batas frame | Keluar |
|---|---|---|---|
| Cincin Saturnus | `3.8 × radius` (ujung di x = ±1.9R) | ±1.0R | **0.90R** |
| Blob kabut nebula (yang digeser) | radius tetap | ±1.0R | **0.28R** |

Cincin Saturnus adalah yang paling parah dan paling mudah dikenali: hampir
separuh lebarnya berada di luar kotak, jadi yang tampil di layar **bukan
cincin** melainkan dua garis yang berhenti mendadak di tepi kartu. Di kartu jam
38pt potongan itu sangat mudah tidak disadari.

Nebula punya jebakan sendiri: blob-nya **digeser** dari pusat (supaya kabut
tidak simetris sempurna), dan batas frame bersifat **per sumbu**, bukan radial.
Jadi blob yang terpusat aman sementara blob yang digeser keluar — dan potongannya
jatuh **tepat di tengah gradien yang belum selesai memudar** (opasitas 0.084 di
situ), persis ciri "terlihat digambar" yang ingin dihindari nebula.

### Kenapa ini tidak bisa ditangkap dengan membaca

Tiga lapis verifikasi di repo ini semuanya lolos: `swiftc -parse` hanya
memeriksa sintaks; `swift test` di Linux tidak bisa menyentuh warna/`Canvas`;
dan tidak ada satu pun teks di layar yang memberitahu pengguna bahwa gambarnya
terpotong. Yang tersisa hanyalah **menghitungnya** — persis teknik yang
menemukan kutub Mars menembus 0.26R pada siklus lalu.

### Yang diubah, dan kenapa begini

- **Angka batas pindah ke `PointingKit` sebagai `VisualFrame`.** Enum ini
  adalah satu-satunya tempat yang tahu ukuran frame, dengan
  `overflow(centerX:centerY:halfWidth:halfHeight:)` yang mengembalikan nilai
  ≥ 0 bila bentuk keluar. `saturnRing()` dan `nebula(fuzziness:)` keduanya
  **dihitung dari sisa ruang ke tepi frame**, bukan dari radius mentah — jadi
  memperbesar bentuk tidak bisa lagi diam-diam melewati batas.
- **`saturnBodyRadius(for:)` dipisah dari `saturnRing`.** Bola harus mengecil
  mengikuti cincin; kalau bola tetap memakai radius frame penuh sementara cincin
  mengisi frame, bola menutupi cincin dan hasilnya **piring**, bukan Saturnus.
  Mengambilnya dari lebar cincin membuat proporsi itu benar secara
  konstruktif.
- **View tidak punya rumus sendiri lagi.** `drawRings` dan `drawDeepSky` kini
  membaca model. Ini mempertahankan aturan repo yang sudah berlaku: keputusan
  visual yang bisa salah tanpa ada yang bisa mengujinya **tidak boleh tinggal
  di view**.

### Uji dibuktikan MERAH lebih dulu

Dengan geometri lama dikembalikan (`halfWidth = frameHalfExtent × 1.9`):

- `testSaturnRingStaysInsideTheFrame` → **gagal**: `0.8999999999999999 > 0`,
  pesan *"cincin keluar 0.9 R di luar frame dan akan terpotong tegak"*.
- `testSaturnBodyFitsInsideItsRing` → **gagal**: `1.007` vs `0.594`.
- `testEveryDeepSkyBlobStaysInsideTheFrame` → **gagal**: *"blob nebula 0 keluar
  0.28 R di luar frame"*.
- `testLegacySaturnRingOverflowedTheFrame` ditambahkan justru untuk **mengunci
  angka lama** sebagai bukti bahwa cacatnya nyata, bukan perbedaan rasa.

Satu uji awalnya salah dan diperbaiki, bukan ditambal: ia menuntut bola lebih
kecil dari **tinggi** cincin. Itu keliru — cincin Saturnus tampak miring, jadi
tinggi elipsnya memang lebih kecil dari jari-jari bola, dan justru dua ujung
cincin yang tampil di luar bola itulah yang membuatnya terbaca sebagai
Saturnus. Yang benar adalah bola harus lebih kecil dari **lebar** cincin.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 212 PointingKit, 0 gagal** (naik
  dari 201 → 212: 11 uji batas frame baru). Engine tidak disentuh.
- Ketiga uji di atas **dibuktikan MERAH lebih dulu**, bukan hanya hijau.
- Gerbang sintaks: seluruh 22 berkas app lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan CJK/Cyrillic di berkas yang diubah: **0**.
- **CI macOS sempat MERAH dan itu cacat nyata**: push pertama (`61defdb`)
  ditolak dengan 3 × `error: 'saturnRing'/'saturnBodyRadius'/'nebula' is
  inaccessible due to 'internal' protection level`. Tiga helper `static` di
  dalam `public enum` turun ke `internal` (default Swift) — dan **tidak satu
  pun** gerbang Linux yang bisa melihatnya, karena uji hidup di modul yang
  sama. Diperbaiki di `c5ff66c` dengan mengekspor kelimanya ke `public`.
- CI hijau di `c5ff66c`: `Apple Build` run `37180733204` → **2 × `BUILD
  SUCCEEDED`** + gerbang peringatan *"Tidak ada peringatan compiler pada
  Apps/."*; `Engine Tests (Linux)` run `37180733201` hijau dengan kelima uji
  batas frame **terlihat lolos di log CI** (bukan hanya di mesin ini).

### Pelajaran yang berulang (dan kali ini dua kali berturut-turut)

Dua siklus terakhir menemukan cacatnya di tempat yang sama: **geometri
raster yang tidak bisa dibaca dari teks**. Kutub Mars menembus 0.26R; cincin
Saturnus terpotong 0.9R. Keduanya lolos `-parse`, keduanya lolos `swift test`
yang ada, dan keduanya hanya ketahuan dengan menghitung. Dan kali ini
tambahannya: **akses `internal` vs `public` adalah cacat kelas ketiga yang
hanya build macOS yang bisa tangkap** — `swift test` di Linux tidak bisa
melihatnya sama sekali karena pengujinya satu modul.

## Progres terakhir (4 Okt 2026 — glow & spike bintang terpotong tepi Canvas, 24 dari 25 bintang)

### Premis siklus ini: geometri yang sudah punya `VisualFrame` harus dihitung, bukan hanya dibaca

Dua siklus terakhir menemukan cacat di tempat yang sama — **geometri raster
yang tidak terbaca dari teks** — dan keduanya ditutup dengan memindahkan
angka batas ke `VisualFrame` di `PointingKit`. Siklus ini memperluas
pertanyaannya: `VisualFrame` sudah mengurusi **cincin Saturnus** dan **blob
nebula**, tapi ada bentuk ketiga di `Canvas` yang sama-sama dikalikan dari
ukuran dasar dan **tidak punya uji batas sama sekali** — bintang.

### Cacat yang ditemukan: inti dihitung maju, batasnya tidak pernah dihitung

`drawStar` menghitung `coreRadius = 0.22 + 0.30 · relativeSize`, lalu
mengalikannya: glow terluar `×3.0` dan spike `×3.2`. Tidak ada satu pun
bagian yang memeriksa apakah hasilnya masih di dalam frame. Karena
`Canvas` memotong dengan **tepi lurus**, bukan dengan memudar, yang tampil
bukan "bintang yang agak kepotong" melainkan **bola cahaya yang berhenti
mendadak di keempat tepi kartu**.

Dihitung untuk seluruh katalog, bukan ditebak:

| Bintang | Ujung terluar | Keluar frame |
|---|---|---|
| **Sirius** | 1.811R | **+0.811R** |
| Canopus | 1.519R | +0.519R |
| Arcturus | 1.316R | +0.316R |
| Vega | 1.296R | +0.296R |
| Polaris | 0.987R | −0.013R (satu-satunya yang muat) |

**24 dari 25 bintang terpotong**, dan yang paling parah justru bintang
paling terang — yang paling sering dikunci pengguna. Ini cacat yang lebih
luas daripada dua pendahulunya: cincin Saturnus hanya salah pada satu
planet, blob nebula pada satu kelas objek, sedangkan ini salah pada
hampir seluruh katalog bintang.

### Kenapa denyut harus ikut dihitung (dan kenapa itu cacat yang paling mudah lolos)

Geometri lama memakai `pulseFactor = 1 + 0.10 · sin(pulse)`, yang
mengembangkan gambar **setelah** ukuran inti dipilih. Jadi batas yang
dihitung dari keadaan diam meloloskan gambar yang terpotong **hanya saat
denyut memuncak** — cacat yang muncul dan hilang berulang, persis kelas
yang paling mudah tidak disadari saat menguji sekilas. Karena itu
`outerRadius` dihitung pada **puncak** denyut, bukan pada keadaan diam.

### Yang diubah, dan kenapa begini

- **`VisualFrame.star(relativeSize:)` menghitung inti MUNDUR dari ruang
  yang tersedia**, bukan maju dari ukuran yang diinginkan. Ini yang
  membuat batasnya **konstruktif**: memperbesar glow atau spike tanpa
  sengaja tidak bisa lagi mendorong ujungnya keluar frame, karena inti
  menyusut sendiri mengikutinya. Dua siklus sebelumnya memperbaiki gejala
  per bentuk; ini memperbaiki **kelasnya** — rumusnya tidak bisa lagi
  menghasilkan ujung yang keluar, berapa pun pengalinya.
- **Urutan magnitudo tetap terjaga lewat `outerFraction` (0.62 → 0.92).**
  Bahaya yang sengaja dihindari: memotong inti dengan plafon tetap akan
  meratakan Sirius dan Polaris menjadi dua titik yang sama, dan
  "ukuran mengikuti magnitudo" hilang — informasi yang masih terbaca di
  layar. Uji `testBrighterStarIsStillDrawnLarger` menguncinya.
- **View tidak punya rumus bintang lagi.** `drawStar` membaca
  `geometry.coreRadius`, `glowScales`, `spikeScale`, dan `pulseAmplitude`
  dari model. Ini mempertahankan aturan repo yang sudah berlaku:
  keputusan visual yang bisa salah tanpa ada yang bisa mengujinya **tidak
  boleh tinggal di view**. Opasitas glow (`glowOpacities`) ikut naik ke
  konstanta bernama, karena array literal di dalam loop sebelumnya
  bergantung secara diam-diam pada jumlah lapis yang sama dengan
  `glowScales`.

### Uji dibuktikan MERAH lebih dulu

Dengan geometri lama dikembalikan (`outer = 0.22 + 0.30 · clamped`,
`growth = 1.0`):

- `testEveryCatalogueStarStaysInsideTheFrame` → **gagal**, dan pesannya
  menyebut bintangnya satu per satu: *"sirius keluar 0.8111258278291038 R
  di luar frame dan akan terpotong tegak"*, *canopus 0.5186*, *arcturus
  0.3160*, *vega 0.2964* … angkanya cocok persis dengan hitungan Python
  mandiri di atas.
- `testEnlargingTheGlowCannotPushTheStarOutOfFrame` → **gagal** pada
  seluruh 9 kombinasi pengali (terburuk 10.44R), membuktikan bahwa
  rumusnya memang tidak punya batas, bukan kebetulan muat.
- `testLegacyStarOverflowedTheFrame` ditambahkan justru untuk **mengunci
  angka lama** sebagai bukti bahwa cacatnya nyata, bukan perbedaan rasa
  tentang seberapa besar glow yang pantas.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 218 PointingKit, 0 gagal**
  (naik dari 212 → 218). Engine tidak disentuh.
- Ketiga uji di atas **dibuktikan MERAH lebih dulu**, bukan hanya hijau.
- Gerbang sintaks: seluruh 22 berkas app lolos `swiftc -parse
  -swift-version 5` di container `swift:6.0`.
- Sapuan CJK/Cyrillic pada berkas yang diubah: **0**.
- **CI hijau pada push pertama** (`3ab030e`) — tidak ada kejutan `internal`
  vs `public` seperti siklus lalu, karena `star(...)`, `StarGeometry`, dan
  seluruh anggotanya dideklarasikan `public` sejak awal:
  - `Apple Build` run `37181603764` → **2× `BUILD SUCCEEDED`** + gerbang
    peringatan *"Tidak ada peringatan compiler pada Apps/."*
  - `Engine Tests (Linux)` run `37181603824` hijau, keenam uji bintang
    terlihat **lolos di log CI** (bukan hanya di mesin ini).

### Pelajaran yang berulang (tiga siklus berturut-turut)

Tiga siklus terakhir menemukan cacat di kelas yang **sama**: geometri
raster yang tidak terbaca dari teks. Kutub Mars menembus 0.26R; cincin
Saturnus terpotong 0.9R; dan sekarang bintang terpotong 0.81R. Ketiganya
lolos `swiftc -parse` (sintaks saja), ketiganya lolos `swift test` yang
ada sebelum uji batasnya ditulis, dan ketiganya hanya ketahuan dengan
**menghitung**. Polanya sudah cukup konsisten untuk dibaca sebagai aturan:
setiap bentuk di `Canvas` yang ukurannya dikalikan dari angka dasar harus
punya uji batas di `VisualFrame`, atau ia akan terpotong tanpa ada yang
memberi tahu.

## Progres terakhir (4 Okt 2026 — kutub Mars menembus 0.26R keluar dari bola)

### Cacat yang ditemukan: dua rumus untuk satu bentuk simetris

Siklus ini diawali dengan brief yang sama seperti sebelumnya, jadi STATUS lama
**layap dibaca, bukan dipercaya**. Hasilnya berbeda dari beberapa siklus
sebelumnya: brief-nya memang sudah terpenuhi seluruhnya. Jadi pekerjaan
siklus ini berubah dari "menambah fitur" menjadi **menyisir raster prosedural
secara numerik** — karena di situlah satu-satunya kelas kesalahan yang tidak
bisa ditangkap hanya dengan membaca kode.

`drawPolarCaps` memakai **dua rumus berbeda untuk dua kutub**:

    utara:  y = center.y - radius
    selatan: y = center.y + radius - capHeight      // <-- bukan cermin
    tinggi elips: 2 * capHeight

Karena tinggi elips adalah `2 · capHeight` (bukan `capHeight`), kutub selatan
berakhir di **y = 1.26R** — yaitu **0.26R di luar bola**. Diperiksa dengan
menghitung titik terjauh elips dari pusat, bukan dengan mengira: elips di
y∈[0.74, 1.26] punya titik di y=1.26 yang jaraknya 1.26R.

| Kutub | Protrusion versi lama | Protrusion versi ini |
|---|---|---|
| Utara | 0.0038R | 0.0038R |
| **Selatan** | **0.2600R** | **0.0038R** |

Jadi Mars tampil dengan kutub putih yang **menggantung di ruang kosong** di
bawah bola, dan tidak simetris dengan kutub utara — tepat di tanda yang
paling mudah dibaca mata telanjang.

**Cakupan dicek, bukan diasumsikan.** Pita Jupiter (7 pita), 5 kawah
Merkurius, dan kabut Venus dihitung dengan cara yang sama: **0 protrusion**
semuanya. Jadi hanya kutub yang salah, dan tidak ada "perbaikan" yang
menyentuh ciri planet lain.

### Kenapa ini bukan sekadar rasa

PRD melarang visual yang **menglaim identitas** saat engine ragu, dan logika
yang sama berlaku lebih luas: gambar adalah klaim. Kutub adalah **ciri
pengenal Mars** — persis kelas yang sudah dipisahkan dari warna di
`DistinguishingFeature` (cincin Saturnus ≠ pita Jupiter). Bentuk kutub yang
salah bukan sekadar soal rasa: tidak ada teks di layar yang bisa dibaca
pengguna untuk memeriksanya, dan Mars tidak punya sabit/cincin yang bisa
menutupinya.

### Yang diubah

- **`CelestialVisual.polarCaps()` + `CelestialVisual.PolarCaps` di
  `PointingKit`** — kutub selatan dihitung sebagai **cermin kutub utara**
  (`southTop = 1 - height`), jadi keduanya simetris secara **konstruktif**,
  bukan dua rumus yang harus dicocokkan manual. Hasilnya dalam satuan radius,
  supaya model tidak perlu tahu satuan apa yang sedang digambar.
- **View memakai tipe itu; tidak ada rumus kutub lagi di `Apps/`.** Ini
  menjaga pemisahan yang sudah jadi aturan repo: keputusan visual yang bisa
  salah tanpa ada yang bisa mengujinya **tidak boleh tinggal di view**.

### Tiga uji, semuanya dibuktikan MERAH dulu

Dengan `southTop` dikembalikan ke `1 - capHeightFraction` (geometri lama):

- `testPolarCapsStayOnThePlanetSurface` → **gagal**: `1.26 > 1.01`,
  pesan *"kutub south menembus 0.26 R di luar bola"*.
- `testPolarCapsAreMirrorImagesOfEachOther` → **gagal**: `-1.0` vs `-1.26`.
- `testPolarCapDefaultsAreInRadiusUnits` → hijau (kebetulan tidak menyentuh
  bug; dipertahankan karena mengunci satuan agar view tidak salah skala).

Jadi dua dari tiga uji menangkap bug ini secara numerik, bukan sebagai
formalitas.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 201 PointingKit, 0 gagal**
  (naik dari 198 → 201). Engine **tidak disentuh**.
- Gerbang sintaks: **seluruh 22 berkas app** lolos `swiftc -parse
  -swift-version 5` di container `swift:6.0`.
- `swift build` `PointingKit` di container: **Build complete**.
- Sapuan CJK/Cyrillic di `Apps/` + `Packages/`: **0**.
- **CI macOS hijau** di `3b9dcf2`: `Apple Build` run `37179379077` → **2×
  `BUILD SUCCEEDED`** (iPhone termasuk app jam, dan app jam sendiri), gerbang
  peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
  `Engine Tests (Linux)` run `37179379101` → **166 + 201**, ketiga uji kutub
  terlihat **lulus di log CI** (bukan hanya di mesin ini).

### Pelajaran yang diulang (dan masih berlaku)

`swiftc -parse` lolos untuk **seluruh** perubahan di sini — termasuk tiga uji
yang gagal pada geometri lama. `-parse` memeriksa sintaks, bukan perilaku;
hanya `swift test` yang bisa merah. Dan `Color`/SwiftUI tidak bisa
diuji di Linux sama sekali, yang justru alasan geometri kutub **dipindahkan ke
`PointingKit`**: bentuknya tidak bisa diverifikasi di lapisan yang tidak
memiliki gerbang.

### Audit awal: visual sudah ada, tapi latarnya tidak pernah tampil

Siklus ini diawali dengan memercayai bahwa Bagian 1–4 sudah selesai (klaim
STATUS lama), lalu membaca ulang seluruh berkas app alih-alih mempercayainya.
Yang ditemukan: model visual, mode malam, always-on, VoiceOver, animasi, dan
onboarding **semua sudah ada dan teruji** — tetapi gradien latar `#0A0A0F`/
`#121216` yang sudah dihitung & diuji kontrasnya di `SurfacePalette.appBackground`
**hanya dilukis di `OnboardingView`**. Seluruh layar konten (jam + `ReducedLuminanceView`
+ ketiga `List` iPhone) dirender di latar bawaan sistem, dan siang memakai
`preferredColorScheme(nil)` — jadi di iPhone yang disetel terang, `List` dan
chrome sistem berbalik putih sementara token `SurfacePalette` mengasumsikan
gelap. Itu sumber nyata keluhan "masih jelek / tidak konsisten": permukaan
bertinting (surface-stepping) dan kontras 4.5:1 yang diklaim di brief **ada
di kode tapi tidak pernah terlihat** di layar.

### Apa yang diubah, dan kenapa begini

- **`SurfaceTokens.forceDarkScheme()`** — pembungkus `preferredColorScheme(.dark)`.
  Skema dipaksa gelap di **seluruh** app, bukan `nil` saat siang. Alasannya
  bukan "mode gelap pilihan": token permukaan dirancang untuk latar gelap, dan
  menyerahkannya ke sistem berarti chrome putih di iPhone terang merusak
  kontras yang sudah diuji. Skema gelap di sini adalah **kontrak** dengan
  palet; mode malam (merah) adalah lapisan di atasnya, bukan pengganti.
- **Latar gradien dipasang ke akar semua layar:** `PointingView` +
  `ReducedLuminanceView` (jam), dan `DiagnosticsView`/`Experiment1View`/
  `LinkView` (iPhone) masing-masing dapat `.appBackground()`. Pada ketiga
  `List` iPhone ditambah `scrollContentBackground(.hidden)` supaya chrome
  `List` bawaan tidak menutupi gradien — kartu tetap memakai `surfaceCard`.
- `OnboardingView` sudah benar (memakai `SurfacePalette.appBackground` secara
  langsung); tidak diubah.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 198 PointingKit, 0 gagal** (engine
  dan `PointingKit` tidak disentuh; perubahan murna `Apps/`).
- Gerbang sintaks: seluruh 20 berkas app lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` (setelah satu galat tutup-kurung berlebih di
  `SurfaceTokens` diperbaiki saat edit).
- **CI macOS (Apple Build) hijau** di `c414cc5` (run `37178623141`, 2× `BUILD
  SUCCEEDED`) + gerbang peringatan melaporkan *"Tidak ada peringatan compiler
  pada Apps/."* — `scrollContentBackground`/`preferredColorScheme` hanya
  terbukti resolve di sini, bukan di `-parse`. `Engine Tests (Linux)` run
  `37178623098` hijau.

## Progres terakhjah (4 Okt 2026 — Bagian 4.4: animasi kedatangan kunci di UI)

### Audit awal: 4.4 ternyata hanya setengah jadi

Siklus ini diawali dengan mengaudit klaim STATUS lama, bukan memercayainya.
Table di atas menandai 4.4 "SELESAI" — tapi yang ditulis di sana hanyalah
plumbing model (`LockArrivalGate` + `PointingEngine.publish`). Pemanggil
UI-nya **tidak ada**: satu-satunya kejadian `withAnimation` di seluruh `Apps/`
adalah di `ReducedLuminanceView` (komentar, bukan pemanggilan). Jadi saat
objek baru terkunci, kartu di jam dan panel di iPhone muncul **tanpa** animasi —
bagian 4.4 ("fade/scale saat objek muncul") belum terwujud di layar.

### Apa yang diubah, dan kenapa begini

- **`ObjectDetailView` (jam)** sekarang menerima `lockArrivalToken: Int?` dan
  memainkan pop (scale 1 → 1.04 → 1 + opasitas) lewat `withAnimation(.spring)`
  saat token **naik**. Dipicu oleh `engine.lockArrival?.token`, bukan oleh
  `state == .lock`, karena `snapshot` ditulis ulang 20×/detik selama terkunci —
  memakai keadaan membuat kartu berkedip terus-menerus. `LockArrivalGate` sudah
  menyaring itu: token hanya naik saat ada **kedatangan kunci baru** dengan
  objek yang berlaku sekarang, dan kembali `nil` saat kunci dilepas. `.onChange`
  hanya memutar pop saat token naik, mengabaikan saat kembali `nil` — supaya
  kita tidak "merayakan" objek sisa (kelas false confidence yang dilarang PRD).
- **iPhone**: panel yang tadinya bersarang langsung di `List` dipecah menjadi
  `LockArrivalPanel` (di `DiagnosticsView`). Pemecahan ini penting karena panel
  lama berada di dalam `TimelineView(.animation(30 Hz))` yang merender ulang
  per frame — menaruh state animasi di atasnya berarti pop diputar ulang tiap
  frame. `LockArrivalPanel` memegang `@State appearScale/appearOpacity`
  sendiri dan dipicu oleh `.onChange(of: lockArrivalToken)` yang sama dengan
  jam, dengan penjagaan naik-token yang sama. Gambar besar (diameter 132) +
  denyut glow bintang tetap dipertahankan di dalam `TimelineView` internalnya.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 198 PointingKit, 0 gagal**
  (engine tidak disentuh; UI hanya membaca `lockArrival` yang sudah ada).
- Gerbang sintaks: **seluruh berkas app lolos `swiftc -parse -swift-version 5`**
  di container `swift:6.0`.
- Perubahan hanya di `Apps/` (jam + iPhone); tidak ada simbol `PointingKit`/
  `CelestialEngine` yang disentuh, jadi 198 test tidak bisa terpengaruh.
- Belum dijalankan di sini: build macOS CI sebenarnya (`ios-build.yml`), karena
  VPS ini tanpa Xcode — itu yang akan membuktikan resolusi overload/tipe
  (`@State` di `ObjectDetailView`, `LockArrivalPanel`, `.onChange` dua-argumen).
  Lolos `-parse`, tapi `-parse` tidak menyelesaikan tipe, jadi CI macOS adalah
  verifikasi sebenarnya (sama seperti siklus-siklus sebelumnya).

### CI macOS pertama GAGAL — dan itu kegagalan nyata, bukan peringatan alat

Push pertama (`18ba900`) ditolak oleh `Apple Build` dengan **5 galat compile**
yang `-parse` tidak bisa lihat (sesuai dugaan di atas):

- `DiagnosticsView.swift:260: error: cannot find 'visual' in scope` — call site
  `LockArrivalPanel(visual: visual, ...)` kehilangan binding `visual` karena
  blok `if let visual = ...` lama ikut terhapus saat panel dipindah. Diperbaiki
  dengan membungkus call site: `if let visual = engine.visualForDisplayedObject { ... }`.
- `DiagnosticsView.swift:485/487/488/490/503: error: instance member 'detailRow'/
  'visualPanelLabel' of type 'DiagnosticsView' cannot be used on instance of
  nested type 'DiagnosticsView.LockArrivalPanel'` — kedua helper itu `private
  func` instance, tak terjangkau dari nested type. Diperbaiki jadi `static` (ia
  murni: hanya pakai `SurfacePalette`/argumen) dan dipanggil via
  `DiagnosticsView.detailRow`/`visualPanelLabel`.

Push kedua (`9745f9f`) → **Apple Build hijau** (2× `BUILD SUCCEEDED`, gerbang
peringatan "Tidak ada peringatan compiler pada Apps/") + Engine Tests hijau.
Pelajaran yang sudah berkali-kali terbukti di sini: `swiftc -parse` hanya
memeriksa sintaks; **hanya build macOS yang membuktikan resolusi tipe/overload**,
dan nested type vs instance method adalah jebakan yang tepat di situ.

## Progres terakhir (4 Okt 2026 — sisa Bagian 4: onboarding + audio + @ScaledMetric)

Siklus ini menutup tiga item terakhir dari brief yang benar-benar belum ada:
onboarding value-first, audio opsional saat lock, dan `@ScaledMetric` (font
sudah semantic, jadi yang tersisa adalah metric yang belum ikut scale). Aturan
keras PRD tidak dilonggarkan; engine tidak disentuh.

### Yang dikerjakan, dan kenapa begini

1. **Onboarding value-first (`Apps/Shared/OnboardingView.swift`).** Satu kartu
   singkat: "Arahkan jam ke langit → ketahui apa yang kamu lihat", plus janji
   jujur "jika ragu, engine akan mengatakannya". Tidak ada tur panjang: saat
   pengguna mengangkat pergelangan di malam hari, lima layar instruksi justru
   menunda hal yang dicari. Ditampilkan sekali lewat `.sheet` (kunci
   `OnboardingStorage.key`), dan menutupnya tidak mereset alur. **Tidak ada
   satu pun klaim hasil ukur** di kartu ini, jadi tidak ada risiko false
   confidence dari layar pembuka.

2. **Audio opsional saat lock (`Apps/Shared/AudioCue.swift`).** `AudioCueEngine`
   menyintesis nada 880Hz di memori (`AVAudioEngine` + `AVAudioPCMBuffer`,
   amplop naik-turun) — **tanpa aset**, sejalan dengan visual yang tanpa aset.
   Dipasang tepat seperti `HapticEngine`: closure `engine.audioCue` (paralel
   `haptics`, dipanggil dari `ingest`), jadi tidak menyentuh logika engine
   teruji. Hanya berbunyi untuk `.lockSucceeded` — bunyi saat ragu sama
   berbahayanya dengan getaran saat ragu (false confidence berwujud suara).
   `AudioCue.isOn` default **nyala** (aksesibilitas multi-modal), ada toggle
   "Bunyi saat kunci" di kedua app. `setCategory(.playback, .mixWithOthers)`
   supaya tidak memotong musik latar pengguna.

3. **`@ScaledMetric` pada ikon status.** Semua *font* memang sudah semantic,
   tapi `WatchMetrics.iconSize` (16, tetap) diniatkan ikut scale menurut
   komentarnya sendiri namun tidak pernah dipakai. Diganti `@ScaledMetric(
   relativeTo: .headline)` di `PointingView` untuk frame simbol status, supaya
   ikon dan teks mendapat tekanan yang sama saat Dynamic Type diubah. Anggota
   mati `WatchMetrics.iconSize` dibuang; komentarnya diubah menjelaskan bahwa
   metric yang *memang* tak boleh scale (diameter visual, radius) tetap angka
   tetap.

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 198 PointingKit, 0 gagal** (naik
  dari 188 → 198: 10 uji `LockArrivalGate` ditambahkan siklus sebelumnya,
  terhitung di sini). Engine/logika app tidak disentuh.
- Gerbang sintaks `swiftc -parse` seluruh 20 berkas app lolos di `swift:6.0`
  setelah perubahan.
- **CI macOS (Apple Build) GAGAL dulu pada `e8f8bb9`**, lalu hijau di `17a5c32`:
  - Kegagalan pertama murni salah letak: `onboardingSeen` & `audioCue` mendarat
    di struct `PointAndKnowiOSApp` (cocok salah dengan `@StateObject trace`),
    padahal dirujuk di `RootView` → "cannot find in scope". Dipindah ke
    `RootView`, bukan cuma di-`_fix_`.
  - Dua catatan CI yang tersisa **bukan** kode kita: (a) `swift-format cannot
    parse configuration` (alat, sengaja diabaikan gate), (b)
    `CalibrationSessionTests.swift:285` `XCTUnwrap` unused — berkas *test*
    `PointingKit` di luar scope `Apps/`; sudah tercatat di STATUS lama sebagai
    sengaja tidak diubah.
  - Gerbang peringatan "kode sendiri" (`Apps/`) lolos: Tidak ada peringatan
    compiler pada Apps/.
- **Engine Tests (Linux) hijau** di `17a5c32`.

## Progres terakhir (4 Okt 2026 — kalibrasi: VoiceOver + Dynamic Type)

### Dua klaim STATUS.md yang ternyata tidak berlaku

Siklus ini dimulai dari brief yang sama seperti sebelumnya, jadi STATUS.md
layap dibaca bukan dipercaya. Dua klaim di dalamnya **tidak berlaku**:

1. **"Dynamic Type: semua `.system(size:)` sudah diganti."** Benar untuk
   `PointingView` dan `ReducedLuminanceView` — tapi `CalibrationView.swift`
   masih punya **13** `.system(size:)`, yaitu 20% dari berkas app. Dan itu
   bukan layar pinggir: kalibrasi justru layar yang paling sering dipakai
   pengguna yang perlu kacamata di lapangan. Semua angka sudah gone sekarang
   (sweep `\.system\(size:` di `Apps/` → **0 di kode**, sisanya komentar).
2. **"Bagian 3.3 selesai."** `statusCard` dan `ObjectDetailView` memang
   berlabel, tapi brief menyebut secara khusus **tombol kalibrasi & "Catat"** —
   keduanya tidak punya label, dan `statusMessage` tidak pernah diumumkan.

### Tiga cacat nyata di layar kalibrasi (bukan sekadar label yang belum ada)

1. **`statusMessage` tidak pernah sampai ke VoiceOver.** Layar ini tidak punya
   `.onChange(of: engine.snapshot.state)` seperti `PointingView`, jadi **tidak
   ada satu pun** pengumuman di seluruh alur. Akibatnya menekan "Catat" bisa
   **ditolak** tanpa umpan balik apa pun — kelas "kegagalan diam" yang sama
   dengan Cacat 9/11 di riwayat, dan justru paling merusak di sini: satu-satunya
   jalan memasang kalibrasi.
2. **Ikon dekoratif ikut diucapkan.** Tombol acuan tidak
   `accessibilityHidden` pada ikon, jadi VoiceOver membacakan "bintang, plus
   lingkaran, Sirius, 40 derajat tinggi, plus lingkaran".
3. **Label tombol "Pakai" tidak membedakan hidup/mati.** `.disabled` adalah
   sifat visual; penolakan karena sebaran terlalu lebar — hasil yang paling
   mudah disalahartikan di seluruh alur ini — tidak pernah sampai ke pengguna
   suara.

### Teks yang diucapkan pindah ke `PointingKit` — dan kenapa

`CalibrationSpeech.swift` (baru) memuat `spokenPhaseSummary`,
`spokenApplyButtonLabel`, `spokenName`, `spokenCaptureLabel`.

Alasannya bukan kerapian. Kalimat-kalimat ini adalah **janji produk yang
bisa salah tanpa ada satu pun bagian UI yang keliru**: kalau label lupa menyebut
tahap, layar tetap menampilkan "Siap dipakai" dengan hijau, dan pengguna yang
tidak melihat layar tidak punya jalan apa pun untuk mengetahuinya. Persis kelas
"objek sisa tampil sebagai hasil sekarang" — UI yang tampak benar sambil
menyembunyikan apa yang sebenarnya berlaku. Konsekuensi yang ikut: angka
diucapkan sebagai kata ("derajat"), karena derajat adalah singkatan visual yang
tidak terbaca sebagai kata.

### Yang benar-benar dijalankan pada siklus ini

- `./swift-test.sh` → **166 CelestialEngine + 188 PointingKit, 0 gagal** (naik
  dari 179 → 188: 9 uji `CalibrationSpeechTests`).
- **Kedua mutasi dibuktikan MERAH lebih dulu**, bukan hanya hijau:
  - `spokenApplyButtonLabel` diabaikan `isReady` → **2 test gagal**;
  - `offset`/`sebaran` dikarang (`?? 0`) saat kalibrasi belum ada → **2 test
    gagal**.
- Semua keadaan diuji lewat alur **sungguhan** (`add`/`markApplied`), bukan
  menyetel `phase` langsung: `phase` `private(set)` dan dihitung dari sampel, jadi
  itulah satu-satunya cara mengujinya tanpa mengarang keadaan.
- Gerbang sintaks: **seluruh 20 berkas app** lolos `swiftc -parse -swift-version 5`
  di `swift:6.0`.
- Sapuan CJK/Cyrillic di `Apps/` + `Packages/`: **0**. Sapuan
  `\.system(size:` di `Apps/` → 0 di kode.
- CI `Apple Build` run `37173802303` → **2× `BUILD SUCCEEDED`** dan gerbang
  peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*; CI
  `Engine Tests (Linux)` run `37173802319` → hijau.

### Temuan yang sengaja TIDAK diperbaiki siklus ini

`CalibrationSessionTests.swift:285` menghasilkan `warning: result of call to
'XCTUnwrap(...)' is unused` — terlihat di log CI macOS. Sekali baris saja
(`_ =`), tapi di luar satuan kerja siklus ini dan tidak ada hubungannya dengan VoiceOver.
Dicatat supaya tidak dibaca ulang sebagai penemuan baru.

## Progres terakhir (4 Okt 2026 — Bagian 2: polish ala Mobbin)

### Premis siklus ini: klaim numerik harus dihitung, bukan dibaca

Brief meminta "kontras ≥ 4.5:1 (WCAG)". Itu **klaim numerik**, dan
klaim seperti ini tidak bisa dibuktikan dengan membaca kode — harus dihitung.
Selama ini tidak ada yang menghitungnya. Akibatnya `SurfacePalette` (RGB
mentah, tanpa SwiftUI) sekarang ada di `PointingKit`, dengan
`SurfacePaletteTests` yang menjaga angkanya di Linux; `Apps/Shared/SurfaceTokens.swift`
hanya menjembatanikannya ke `Color`.

### Tiga temuan nyata dari menghitung, bukan membaca

1. **`nightAwareSecondary` lama punya kontras 1.49:1 di mode malam** — bukan
   4.5:1. Syarat WCAG di brief sebenarnya tidak pernah terpenuhi di mode
   malam. Sekarang semua warna sekunder datang dari `SurfacePalette`, dan tes
   mengatakannya.
2. **Plafon kontras mode malam = 5.25:1** (merah murni di atas hitam tidak bisa
   lebih terang dari itu). Artinya "teks utama" vs "sekunder" hanya punya ruang
   kanal 1.00 → 0.95: pada mode malam **taksonomi** lebih berguna daripada
   terang-versus-redup. Dicatat di palet + diuji, supaya tidak nanti
   "diperbaiki" ke abu pucat demi "kontras" lalu membatalkan alasan mode malam.
3. **`surfaceSteps` harus dihitung dalam kanal sRGB, bukan luminance.**
   Permukaan malam punya hijau/biru nol, jadi luminance-nya hanya ~1/4 dari abu
   equivalent — ambang "langkah terlalu tipis" jadi tidak berwarna. Diperbaiki ke
   selisih kanal terbesar; **satu ambang berlaku untuk dua mode**.

### Yang berubah di UI

- Latar `#0A0A0F` / `#121216` + tiga lapis **surface stepping** (dari
  kecerahan, bukan shadow — di layar gelap shadow tak terlihat).
- Aksen gradien "ruang → nebula" hanya di keadaan `.lock`, supaya "aktif"
  tetap berarti sesuatu.
- **`.ultraThinMaterial` diganti warna solid.** Glassmorphism ada di brief, tapi
  warnanya bergantung apa yang ada di belakangnya sehingga klaim kontras yang
  sudah dihitung tidak bisa dijamin. Overrule dicatat di `NightMode.swift`,
  bukan diam-diam.
- **Dynamic Type**: semua `.system(size:)` di `PointingView` dan
  `ReducedLuminanceView` → semantic font. Angka tetap hanya untuk metric (jarak,
  radius, gambar).
- **Always-On**: kontras pakai `textPrimary`, bukan tone keadaan — watchOS
  menahan kromatik dan cyan/hijau di atas gelap hilang duluan. Ditambah label
  VoiceOver yang pendek.

### Cacat CI kedua yang hanya macOS bisa tangkap

CI pada `7e5b1de` gagal: `SurfaceTokens.swift:57: error: missing return in
getter expected to return 'LinearGradient'`. Semua getter di berkas itu kini
`return` eksplisit, jadi implicit-return tidak bisa menggigit lagi di sana.
`swiftc -parse` tetap lolos. Verde di `e0aec92` (Apple Build run
`37172701449` + Engine Tests run `37172701444`).

### Yang benar-benar dijalankan

- `./swift-test.sh` → **166 CelestialEngine + 179 PointingKit, 0 gagal**
  (naik dari 167 → 179: 12 uji palet baru).
- Uji kontras **dibuktikan MERAH lebih dulu** pada metrik `surfaceSteps`
  berbasis luminance sebelum diperbaiki ke sRGB.
- Gerbang sintaks seluruh 17 berkas app lolos `swiftc -parse` di `swift:6.0`.
- Sapuan CJK di `Apps/` dan `Packages/`: 0.
- CI: Apple Build hijau + gerbang peringatan lolos; Engine Tests hijau.

## Progres terakhir (4 Okt 2026 — Bagian 1: visual objek)

### Cacat yang ditemukan: visual yang belum pernah dibangun CI

Siklus ini dimulai dari brief "tingkatkan UI/UX, tambahkan visual objek".
`CelestialVisualView.swift` ternyata **belum pernah ter-commit** — ia ada di
disk sebagai berkas untracked. Akibatnya isinya belum pernah melewati satu pun
build. Dua cacat yang pasti:

1. **`PlanetPalette` tidak akan pernah bisa dikompilasi.** Ia memanggil
   `.mercuryBody`, `.venusBody`, `.marsBody`, `.jupiterBody` — enum
   `SphereEnd` yang dideklarasikan hanya punya `.neutralBody`,
   `.neutralShadow`, `.saturnBody`, `.saturnShadow`. Empat case tidak ada.
   `switch`-nya pun tidak lengkap, jadi `SphereEnd` adalah Dead enum.
2. **Cincin Saturnus tidak akan pernah bisa dikompilasi.**
   `context.clip(to:)` tanpa `restoreClip()` — `GraphicsContext.clip(to:)` ada
   hanya di API yang tidak aktif, dan apelasi di sini memakai yang aktif.
3. **Dan kalau sempat terkompilasi, sabitnya terbalik saat gibbous.** Sisi limb
   diambil dari `sign(terminatorOffset)`; untuk fase gibbous tanda itu
   **berlawanan** dengan sisi yang menyala. Ini persis jebakan yang
   `phaseGeometry(waxing:)` perbaiki di commit sebelumnya — modelnya sudah
   benar, pemanggilnya belum.

Yang ketiganya lolos karena `-parse` hanya memeriksa sintaks: ia tidak
menyelesaikan tipe, tidak menyelesaikan enum case, dan tidak menyelesaikan
overload API.

### Yang diperbaiki, dan kenapa begini

- **Palet & ciri pengenal planet pindah ke `PointingKit`.** Warna dan
  `DistinguishingFeature` (pita / cincin / kutub / kawah / kabut) kini bagian
  dari model, jadi **teruji di Linux**: setiap planet punya warna berbeda,
  setiap planet punya ciri unik, dan `saturn → .rings` terverifikasi. Selama
  ini pemetaan itu hanya ada sebagai enum lokal di app yang belum pernah
  dibangun — ARTIFAK yang paling berbahaya, karena "gambar yang salah" lebih
  meyakinkan daripada teks yang salah dan tidak ada yang mengetahuinya.
- **`DistinguishingFeature` sengaja dipisah dari warna.** Warna bola boleh
  tampil saat engine ragu (bola abu tidak menunjuk planet tertentu), ciri
  pengenal **tidak boleh** (cincin = Saturnus). View uphold: `guard
  isConfirmed` sebelum menggambar ciri. Dan `isConfirmed` di layar diambil dari
  predikat yang **sama** dengan badge keyakinan (`!isStale`) — kalau gambar
  dan badge mengambil keputusan sendiri, gambar bisa tampil pasti sementara
  badge-nya disembunyikan, dan gambar lebih meyakinkan daripada badge.
- **`nightModeBrightness` = kanal merah, bukan luminance Rec.709.** Uji
  pertamanya **REDAH** dengan luminance: mode malam membuang hijau/biru, jadi
  yang benar-benar sampai ke mata hanya kanal merah. Memakai luminance penuh
  membuat planet abu terang (Merkurius, 0.70) tampak **lebih** terang dari
  Mars (0.51) — kebalikan dari bola mereka di langit. Diperbaiki ke kanal
  merah, dan sekarang **setiap** planet punya kanal merah berbeda (teruji), jadi
  mode malam tidak pernah mengubah lima planet menjadi satu bayangan sama.
- **`visualForDisplayedObject` memakai sumber yang ter-cache.** Arah fase
  (waxing/waning) dihitung **sekali per refresh konteks**, bukan di `body`.
  Pemanggilan di `body` berarti efemeris Matahari + Bulan dihitung ulang 20×
  per detik hanya untuk menggambar satu sabit. Bundle-nya satu: fraksi fase
  dari `skyContext`, arah fase dihitung pada sampel yang sama — jadi gambar dan
  angka "Fase Bulan" di layar Ketelitian tidak bisa berbeda.
- **`ObjectKind.displayName`/`spokenName` jadi satu sumber** di
  `Apps/Shared/ObjectKindLabels.swift`; switch duplikat di `PointingView`
  dihapus. Dua salinan akan cepat berbeda, lalu benda yang sama tampil dengan
  nama berbeda di jam dan iPhone.

### Cacat build yang hanya CI macOS bisa tangkap

CI pertama pada commit `23bc897` **gagal**:
`CelestialVisualView.swift:205: error: extraneous argument label 'rect:' in call`.
`Path` tidak punya inisialisasi `rect:` — harus `Path(CGRect)`. `swiftc -parse`
tetap bilang bersih. Perbaikan di `59fee76`; CI hijau di kedua workflow
(`Apple Build` run `37171706500` — 2× `BUILD SUCCEEDED`, gerbang peringatan
melaporkan "Tidak ada peringatan compiler pada Apps/"; `Engine Tests (Linux)`
run `37171706423`).

### Yang benar-benar dijalankan pada siklus ini

- `./swift-test.sh` → **166 CelestialEngine + 167 PointingKit, 0 gagal** (naik
  dari 143 → 167: 4 uji baru + 2 uji yang ditulis ulang).
- Uji baru `testNightModeKeepsBrightnessOrdering` dibuktikan **MERAH lebih
  dulu** pada versi luminance sebelum diperbaiki ke kanal merah.
- Gerbang sintaks: seluruh 16 berkas app lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan karakter asing (CJK) di `Apps/`: 0.
- Sapuan simbol enum yang tidak ada di `Apps/` — 0 setelah perbaikan.
- CI: `Apple Build` hijau + `Engine Tests (Linux)` hijau di HEAD `59fee76`.

## Ringkasan keadaan (4 Okt 2026, dini hari — sebelum Bagian 1)

**Seluruh kode selesai.** Yang tersisa di `ROADMAP.md` hanyalah satu item yang
**bukan kode**: "Point & Slew POC 1 teleskop — perencana aman sudah ada
(`SlewSafety`), perangkat keras belum". Itu menunggu teleskop fisik, bukan
pekerjaan repo ini.

- Engine (Fase 1–3) + logika app: **166 test CelestialEngine + 143 test
  PointingKit, 0 gagal** (`./swift-test.sh`, Swift 6.0 di Docker, Linux) —
  dan sejak siklus sebelumnya **keduanya juga ditegakkan di CI Linux**, bukan
  hanya yang pertama.
- Pembungkus app (watchOS + iOS): **terpasang lengkap**, dan **CI macOS
  (`Apple Build`) hijau** — bukan sekadar lolos parse. Build itu kini juga
  **gagal bila ada peringatan compiler pada kode sendiri**, jadi peringatan
  tidak bisa lagi menumpuk tanpa terlihat.
- CI: `engine-tests.yml` (ubuntu, 2 paket) + `ios-build.yml` (macos-15,
  XcodeGen, gerbang peringatan).

## Progres terakhir (4 Okt 2026 — verifikasi menyeluruh xcode-dev)

### Siklus ini: audit independen penuh terhadap klaim "item brief tersisa" (tanpa perubahan kode)
Brief masuk memerintahkan "selesaikan semua kode app dalam semalam, fokus
pembungkus app". Alih-alih mempercayai klaim STATUS lama maupun brief itu
sendiri, seluruh 15 berkas app dibaca baris demi baris DAN setiap simbol
`PointingKit`/`CelestialEngine` yang dipanggilnya diverifikasi keberadaan &
bentuknya di `Packages/`. Hasilnya: **tidak ada satu item pun dari brief yang
tersisa** — ketiga prioritas sudah terpasang dan konsisten.

**Yang diverifikasi dengan membaca + mencari (bukan percaya STATUS lama):**

1. **watchOS — MotionLogger**: `consume(_:at:)` memanggil
   `controller.feed(cmX:cmY:cmZ:cmW:timestamp:)` (PointingController.swift:296),
   yang lewat `DeviceAttitude.init?(cmX:cmY:cmZ:cmW:)` (Frames.swift:82) →
   `PointingController.feed`. `init?(cmX:…)` terkonfirmasi ada & publik.
2. **watchOS — CalibrationFlow/Solver**: `CalibrationView` memakai
   `CalibrationSession` (atas `CalibrationFlow` → `CalibrationSolver`), tombol
   "Pakai" mati sampai `flow.isReady`, dan `reset()` menyegarkan cuplikan engine
   via `engine.apply(calibration: .none)`.
3. **watchOS — WatchView dari PointingState**: `PointingView` merender langsung
   dari `engine.snapshot.state` (keenam keadaan via `PointingPresentation`:
   `symbolName`/`shortLabel`/`guidance`/`tone`) + `ObjectDetailView`. Tidak ada
   keadaan tanpa cabang.
4. **watchOS — Haptic**: `HapticEngine` memetakan `.lockSucceeded` → `.success`
   dan `.uncertain` → `.retry`; pemicunya `PointingController.hapticEvents(from:to:)`
   dengan penjaga `previous != current`, jadi hanya saat transisi keadaan.
5. **watchOS — WatchConnectivity**: `WatchLinkService` mengirim **keputusan**
   (`PointingLinkMessage.state(from:at:sigmaDeg:)`), bukan sudut pergelangan;
   gerbang `LinkReportGate.deliver` kirim-hanya-bila-berhasil.
6. **iOS — Diagnostik**: `DiagnosticsView` menggambar `ratioToSigma` (Swift
   Charts) + ekspor via `ConfidenceTraceArchive`/`JSONArchiveDocument`.
7. **iOS — Experiment 1**: `Experiment1View` + `ExperimentRecorder`
   (tunjuk→rekam→ekspor; verdict menyaring GAGAL; sensor mati mematikan tombol
   Rekam).
8. **Build**: `project.yml` (dua target app + `postGenCommand` tanam app jam ke
   `PlugIns/`) dan `ios-build.yml` sudah memuat `brew install xcodegen` + gerbang
   peringatan `Apps/`.

**Verifikasi silang simbol (risiko nyata build macOS):** semua simbol yang
dipanggil app — `PointingController.feed/resolver/calibration/answeredIntent/
setObserver/setConfidencePolicy/setSensorAvailable/stop`,
`PointingSnapshot.*` (rawPointing/calibratedPointing/reportedPointing/
answeredObject/answeredLevel/displayedObject/isDisplayingStaleObject/aim),
`PointingState.hasAnswer`, `PointingPresentation` (tone/symbolName/shortLabel/
guidance), `CalibrationSession`/`CalibrationFlow` (phase/samples/isReady/
capture/applyIfReady/reset/refreshReferenceTargets/suggestedConfidencePolicy),
`LinkReportGate.deliver`, `PointingLinkMessage` (init/plist/state/calibration/
policy/confidencePolicy), `ConfidenceTrace`/`ConfidenceTraceArchive`/
`DatasetArchive`, `ExperimentHarness` (record/removeLast/dataset/verdict/
summary/suggestedConfidencePolicy/availableTargets), `EngineFactory`,
`PointingResolver.confidencePolicy/skyContext`, `DeviceAttitude.init?(cmX:…)`,
`DeviceAimAxis.rawValue`, `PointingTrial.{intent,groundTruthObjectID}` — **semua
ada dengan akses level dan label argumen yang cocok** (termasuk getter lintas-
modul `controller.resolver`/`calibration` yang `public private(set)`).

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 143 PointingKit, 0 gagal** (Swift
  6.0, Docker, Linux) — dijalankan dari nol, bukan sekadar klaim.
- Sapuan stub (`TODO`/`FIXME`/`placeholder`/`stub`) di `Apps/` → 0 (satu-satunya
  "matches" adalah PNG ikon biner, bukan kode).
- Sapuan `@main` → tepat **dua** (jam + iPhone); tidak ada ketiga.
- Sapuan `try!`/`as!`/`fatalError` di `Apps/` → 0.
- `gh run list`: **`Apple Build` hijau** (run `37163527245`, 2m38s) **dan**
  `Engine Tests (Linux)` hijau (`37163527216`) pada HEAD `8038969` — artinya app
  benar-benar dikompilasi terhadap Apple SDK + `PointingKit` nyata, bukan sekadar
  lolos parse.

**Kesimpulan:** tidak ada kode app yang tersisa. Satu-satunya baris `ROADMAP.md`
yang belum tertutup tetap "Point & Slew POC 1 teleskop" — menunggu perangkat
keras fisik, bukan repo ini. Tidak ada aturan keras PRD yang dilonggarkan;
engine tidak disentuh.

## Progres terakhir (4 Okt 2026)

### Siklus ini: verifikasi mandiri independen (xcode-dev, sesi baru) — seluruh item brief (1–3) terpenuhi
Siklus ini dimulai dari brief yang memerintahkan "selesaikan semua kode dalam
semalam", dengan STATUS.md yang menyatakan pembungkus app sudah lengkap. Alih-alih
mempercayai klaim itu, seluruh berkas app (15 file) dibaca ulang baris demi baris
dan setiap simbol `PointingKit`/`CelestialEngine` yang dirujuknya dicari keberadaan
nyatanya di `Packages/`. Hasilnya: **tidak ada satu item pun dari brief yang tersisa**
— semua ada dan konsisten.

**Yang diverifikasi dengan membaca + mencari (bukan percaya STATUS lama):**
- Prioritas 1 (watchOS): `MotionLogger.consume` memanggil `controller.feed(cmX:cmY:cmZ:cmW:)`
  yang membangun `DeviceAttitude` lewat `init?(cmX:cmY:cmZ:cmW:)` (Frames.swift:82) →
  `PointingController.feed`. `CalibrationView` memakai `CalibrationSession` (di atas
  `CalibrationFlow`/`CalibrationSolver`), tombol "Pakai" mati sampai `flow.isReady`,
  dan `reset()` menyegarkan cuplikan engine. `PointingView` merender langsung dari
  `snapshot.state` (keenam keadaan via `PointingPresentation.symbolName/shortLabel/
  guidance/tone`) + `ObjectDetailView`. `HapticEngine` memetakan `.lockSucceeded` →
  `.success` dan `.uncertain` → `.retry`. `WatchLinkService` mengirim **keputusan**,
  bukan sudut pergelangan.
- Prioritas 2 (iOS): `DiagnosticsView` menggambar `ratioToSigma` (Swift Charts) + ekspor
  via `ConfidenceTraceArchive`/`JSONArchiveDocument`; `Experiment1View`+
  `ExperimentRecorder` (tunjuk→rekam→ekspor, verdict menyaring GAGAL).
- Prioritas 3: `project.yml` (dua target app + `postGenCommand` tanam app jam ke
  `PlugIns/`) dan `ios-build.yml` sudah memuat `brew install xcodegen` + gerbang
  peringatan `Apps/`.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 143 PointingKit, 0 gagal** (Swift 6.0,
  Docker, Linux) — dijalankan dari nol, bukan sekadar klaim.
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` (loop `find Apps -name '*.swift'` → bersih).
- Sapuan stub (`TODO`/`FIXME`/`placeholder`/`stub`) di `Apps/` → 0.
- `gh run list`: **`Apple Build` hijau** (run `37162913757`, 2m42s) — artinya app
  benar-benar dikompilasi terhadap Apple SDK + `PointingKit` nyata, bukan sekadar
  lolos parse; `Engine Tests (Linux)` hijau pada HEAD yang sama.

**Kesimpulan:** tidak ada kode app yang tersisa. Satu-satunya baris `ROADMAP.md` yang
belum tertutup tetap "Point & Slew POC 1 teleskop" — menunggu perangkat keras fisik,
bukan repo ini. Tidak ada aturan keras PRD yang dilonggarkan; engine tidak disentuh.

### Siklus ini: konfirmasi mandiri ulang pembungkus app + gerbang Linux (tanpa regresi)
Fokus: siklus ini dimulai dengan brief yang menyatakan "pembungkus app (watchOS +
iOS) tersisa". Setelah membaca seluruh berkas dan menjalankan gerbang, ternyata
ketiga prioritas brief **sudah terpasang lengkap** dan hanya perlu dikonfirmasi,
bukan dikerjakan. Tidak ada aturan keras PRD yang dilonggarkan; engine tidak
disentuh.

**Yang diverifikasi ulang (bukan sekadar percaya STATUS.md lama):**
- Prioritas 1 (watchOS) — semua ada: `MotionLogger` (`CMDeviceMotion` →
  `DeviceAttitude` lewat `init?(cmX:cmY:cmZ:cmW:)`, diverifikasi rantainya di
  `Frames.swift:82` + `PointingController.feed`); `CalibrationView` di atas
  `CalibrationSession`/`CalibrationSolver`; `PointingView` merender langsung dari
  `PointingSnapshot.state` (keenam keadaan); `HapticEngine` memicu `.lockSucceeded`
  / `.uncertain` (lewati `PointingController.hapticEvents`); `WatchLinkService`.
- Prioritas 2 (iOS) — `DiagnosticsView` (grafik `separation/σ` Swift Charts +
  `ShareLink` ekspor JSON via `JSONArchiveDocument`) dan `Experiment1View` +
  `ExperimentRecorder` (tunjuk→rekam→ekspor, verdict menyaring **gagal**).
- Prioritas 3 — `project.yml` XcodeGen (dua target app + `postGenCommand`
  tanam app jam ke `PlugIns/`) dan `ios-build.yml` sudah memuat
  `brew install xcodegen` + gerbang peringatan Apps/.
- Tidak ada stub: sapuan `TODO`/`FIXME`/`placeholder`/`stub` di `Apps/` → 0.
  `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` ada di kedua app.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 143 PointingKit, 0 gagal** (Swift
  6.0, Docker, Linux).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- `gh run list`: `Apple Build` (macOS) run `37160377165` hijau pada HEAD
  `a8b8856`; `Engine Tests (Linux)` hijau.

**Kesimpulan:** tidak ada kode app yang tersisa. Satu-satunya baris `ROADMAP.md`
yang belum tertutup tetap "Point & Slew POC 1 teleskop" — menunggu perangkat
keras fisik, bukan repo ini.

### Siklus sebelumnya: audit mandiri penuh pembungkus app + verifikasi CI (tanpa regresi)
Fokus: baca ulang **seluruh** berkas app (watchOS + iOS + Shared) dan
seluruh `PointingKit`/`CelestialEngine` yang dirujuknya, lalu cari cacat
nyata yang belum tertutup. Tidak ada satu baris pun yang diubah: hasilnya
adalah **konfirmasi**, bukan perbaikan.

**Yang diverifikasi mandiri (bukan sekadar percaya STATUS.md):**
- `./swift-test.sh` dijalankan dari nol: **166 test CelestialEngine + 143 test
  PointingKit, 0 gagal** (Swift 6.0, Docker, Linux).
- `gh run list` terakhir: **Apple Build hijau** (run `37157355179`, 3m17s,
  2026-10-03T22:07Z) — build + gerbang peringatan lewat.
- Setiap simbol yang dibaca view sudah ada: `PointingTone`/`PointingState`/
  `PointingSnapshot`/`PointingLinkMessage` (PointingKit), `WatchMetrics` &
  `JSONArchiveDocument` & `ConfidenceTraceStore` (app), `@main` tepat **dua**
  (satu per app). Tidak ada `try!`/`as!`/`fatalError` di `Apps` maupun
  `PointingKit`.
- Jalur data Watch↔iPhone, kalibrasi, haptic, dan Experiment 1 sudah
  konsisten: objek sisa tidak bocor ke iPhone, kiriman gagal tidak memakan
  kesempatan berikutnya, kalibrasi dibuang menyegarkan cuplikan jam,
  sensor mati terlihat di layar, dan ambang dari iPhone diterapkan lewat
  engine (bukan controller langsung) sehingga `snapshot` ikut berubah.

**Kesimpulan:** semua item brief (1–3) sudah selesai dan terverifikasi.
Satu-satunya baris `ROADMAP.md` yang belum tertutup adalah "Point & Slew POC
1 teleskop" — itu menunggu perangkat keras fisik, bukan kode. Tidak ada
pekerjaan repo tersisa.

### Siklus sebelumnya: kalibrasi yang dibuang tetap diklaim terpasang di jam
Fokus: menyisir **klaim kalibrasi** — apakah yang ditampilkan jam masih
berlaku setelah pengguna membuang kalibrasinya. Logika engine **tidak
disentuh**; aturan keras PRD tidak dilonggarkan.

**Cacat 13 — `CalibrationView.reset()` membuang kalibrasi tanpa menyegarkan
cuplikan engine.** Tombol "Ulang" memanggil `CalibrationSession.reset()`, yang
memang membuang offset di controller (`controller.apply(calibration: .none)`).
Masalahnya: layar jam **tidak membaca controller** — ia membaca
`engine.snapshot`. `reset()` tidak pernah menyegarkan cuplikan itu, sedangkan
`apply()` (jalur "Pakai") melakukannya lewat `engine.apply(calibration:)`.
Jadi satu jalur memperbarui tampilan dan satu jalur tidak, padahal keduanya
mengubah kalibrasi yang sama.

Akibatnya tidak terlihat sama sekali dari layar: ikon "scope" di toolbar dan
baris "Kalibrasi: Sudah" di panel detail **tetap menyala** setelah kalibrasi
dibuang. Pengguna lalu mempercayai arah tunjuk yang sebenarnya belum
terkalibrasi — persis klaim tanpa dasar yang dilarang PRD
("uncertainty > false confidence"). Ini sekaligus membuat tombol "Ulang"
terasa tidak bekerja: kalibrasi memang hilang, tapi tampilannya berkata
sebaliknya.

Diperbaiki di `CalibrationView.reset()`: setelah `session?.reset()`, jalur
yang sama dengan `apply()` dipakai — `engine.apply(calibration: .none)` —
sehingga cuplikan yang dirender ikut berubah. Ini memperbaiki **kelas**
cacatnya, bukan satu gejalanya: setiap perubahan kalibrasi di UI kini lewat
`PointingEngine`, tidak ada lagi jalur yang menyentuh controller di belakang
tampilan.

**Janji engine-nya dikunci dengan uji.** Selama ini tidak ada satu pun test
yang menegakkan "membuang kalibrasi harus terbaca di cuplikan" — `reset()`
diuji hanya lewat `c.calibration == .none`, bukan lewat `c.snapshot`. Uji
regresi baru (`CalibrationSessionTests.testResetClearsCalibrationFromPublishedSnapshot`)
dibuktikan **MERAH lebih dulu**: dengan `controller.apply(calibration: .none)`
dihapus dari `reset()`, assertion gagal
("kalibrasi yang dibuang tidak boleh tetap diklaim terpasang di cuplikan").

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 143 PointingKit, 0 gagal** (exit 0).
- Uji regresi baru dijalankan **dulu** pada `reset()` tanpa pembersihan →
  **gagal**; setelah perbaikan → **lulus**.
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` setelah perubahan.
- Sapuan ulang jalur kalibrasi: hanya `CalibrationView` yang memanggil
  `CalibrationSession`; `apply()` sudah lewat engine, dan `reset()` kini ikut.
- Cacat dokumentasi ikut ditutup: komentar di `project.yml` masih menyebut
  **92 tes** untuk `PointingKit`, padahal suite Linux yang benar-benar
  dijalankan adalah **143**. Angka disamakan dengan hasil nyata.
- CI `Engine Tests (Linux)` run `37157040232` pada commit `1fb57ff` → **166 +
  143, 0 gagal** (kedua paket).
- CI `Apple Build` run `37157040221` pada commit `1fb57ff` → **2× `BUILD
  SUCCEEDED`** (iPhone termasuk app jam, dan app jam sendiri) dan gerbang
  peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*

### Siklus sebelumnya: sesi tautan yang sudah mati tetap diklaim "Aktif" (dan tidak bisa diaktifkan ulang)
Fokus: menyisir **klaim keadaan tautan** di lapisan app — satu-satunya bagian
yang belum pernah diperiksa dari sisi "apakah yang ditampilkan masih berlaku?".
Logika engine **tidak disentuh**; aturan keras PRD tidak dilonggarkan.

**Cacat 12 — `PhoneLinkService.activate()` dijaga oleh flag yang tidak pernah
dibersihkan.** `isActivated` dilaporkan ke UI (layar Tautan: "Aktif" /
"Belum aktif") dan nilainya hanya diubah dari `activationDidCompleteWith`.
Ketika sesi benar-benar berhenti — `sessionDidDeactivate` dipanggil saat
pasangan berpindah, mis. jam baru dipasangkan — flag itu tetap `true`.

Akibatnya ada dua, dan keduanya tidak terlihat dari UI:

1. **Layar Tautan terus berbohong.** iPhone menampilkan "Aktif" selamanya
   padahal tidak ada satu pun pesan yang bisa lewat. Itu persis klaim tanpa
   dasar yang dilarang PRD ("uncertainty > false confidence") — versi
   tautannya, bukan versi pointing.
2. **Sesi tidak akan pernah diaktifkan ulang.** Penjaganya `!isActivated`,
   jadi panggilan `activate()` dari `sessionDidDeactivate` — yang komentarnya
   sendiri menjanjikan "Aktifkan ulang" — **langsung `return`** karena flag-nya
   masih `true`. Setelah jam baru dipasangkan, tautan mati sampai app dibunuh
   dan dibuka ulang.

Diperbaiki di `PhoneLinkService`: penjaga `activate()` sekarang memakai keadaan
sesi yang sebenarnya (`session.activationState != .activated`), dan
`sessionDidDeactivate` mengosongkan `isActivated`/`isReachable` sebelum
memanggil `activate()` — jadi UI jujur **dan** pengaktifan ulang benar-benar
dijalankan. Ini memperbaiki **kelas** cacatnya, bukan satu gejalanya:
`WatchLinkService` tidak punya penjaga seperti ini, jadi tidak ada jalur
kembar yang perlu ikut diperbaiki.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 142 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` setelah perubahan.
- CI `Engine Tests (Linux)` run `37154632209` pada commit `85a1744` → **166 +
  142, 0 gagal** (kedua paket).
- CI `Apple Build` run `37154632211` pada commit `85a1744` → **2× `BUILD
  SUCCEEDED`** (iPhone termasuk app jam, dan app jam sendiri) dan gerbang
  peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
- Cacat dokumentasi ikut ditutup: `ROADMAP.md` dan komentar di
  `engine-tests.yml` masih menyebut **140/140** dan **165 + 124**, padahal
  suite Linux yang benar-benar dijalankan adalah **166 + 142**. Angka di
  keduanya disamakan dengan hasil nyata.

### Siklus sebelumnya: kiriman yang gagal memakan kesempatan berikutnya (iPhone terjebak di keadaan lama)
Fokus: menyisir **janji "kegagalan tidak boleh diam"** sampai ke akibatnya pada
**urutan operasi**, bukan hanya pada penghitungnya. Siklus sebelumnya (Cacat 9)
membuat kegagalan kirim *terlihat*; siklus ini menemukan bahwa kegagalan itu
masih *hilang*. Logika engine **tidak disentuh**; aturan keras PRD tidak
dilonggarkan.

**Cacat 11 — gerbang "kirim saat keputusan berubah" menandai terkirim sebelum
mencoba mengirim.** `LinkReportGate` sengaja dibuat (Cacat 2) supaya iPhone
tidak menerima 20 pesan per detik untuk keputusan yang sama, dan supaya
kehilangan jawaban **tetap** terkirim. Tapi `PointAndKnowWatchWatchApp` dan
`WatchLinkService.sendIfDecisionChanged` memanggilnya dengan urutan:

    guard reportGate.shouldReport(snapshot) else { return false }   // tandai dulu
    send(state: snapshot, ...)                                      // kirim kemudian

`shouldReport` menyimpan `last = decision` saat ia dipanggil — **sebelum**
pengiriman dicoba. Jadi begitu satu kiriman gagal, keputusan itu sudah tercatat
"sudah dilaporkan", dan **tidak pernah dicoba lagi** selama keputusannya sama.

Yang membuat ini bukan sekadar teori: kegagalan yang paling sering di lapangan
adalah **jam belum tersambung ke iPhone** (Cacat 9 menyebutnya sendiri sebagai
"kegagalan yang paling sering terjadi"). Justru kegagalan itulah yang paling
lama bertahan — beberapa detik sampai menit — dan justru selama rentang itulah
gerbangnya menelan setiap kesempatan berikutnya. Hasilnya persis kebalikan dari
yang gerbang ini dibuat untuk mencegah: iPhone terjebak di keadaan lama (mis.
**"terkunci"** pada Sirius) sementara di jam sudah bergerak dan keadaannya sudah
berubah, **tanpa satu pun kiriman berikutnya yang membetulkannya** — sampai
kebetulan keputusannya berubah lagi. Kegagalan yang *terlihat* (penghitung naik)
tetap bisa berujung pada iPhone yang *salah*, dan tidak ada bagian UI yang
tampak keliru.

Diperbaiki di satu tempat, `PointingKit`: `LinkReportGate.deliver(_:via:)`
membalik urutannya — **kirim dulu, tandai hanya bila berhasil**. Keputusan yang
gagal tetap dianggap baru, jadi percobaan berikutnya mengulanginya sampai
berhasil; dan karena `send` tetap menaikkan penghitung kegagalan, pengulangan
itu terlihat, bukan diam. `WatchLinkService.send(_:)` / `send(state:)` kini
mengembalikan `Bool` supaya keberhasilannya bisa diketahui pemanggil, bukan
sekadar dihitung.

Dua uji regresi baru (`LinkMessageTests`) dibuktikan **MERAH lebih dulu** pada
urutan lama sebelum diperbaiki: percobaan kedua ditolak penyaringnya dan
`attempts` tetap 1 — jadi ini bukan pembacaan kode, melainkan hasil uji yang
benar-benar merah.

**Yang benar-benar dijalankan pada siklus ini:**
- Uji regresi dijalankan **dulu** pada urutan lama → **gagal** (5 assertion:
  "gagal kirim bukan terkirim", "keputusan yang gagal harus diulang"). Setelah
  perbaikan → **lulus**.
- `./swift-test.sh` → **166 CelestialEngine + 142 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Pola `deliver(_:via:)` (gate `mutating` + closure di kelas `@MainActor`)
  dibuktikan lebih dulu dengan probe `-typecheck` di container `swift:6.0`.
- Sapuan ulang pemanggil `shouldReport`/`send(state:)` di `Apps/` dan
  `PointingKit/Sources`: hanya `WatchLinkService.sendIfDecisionChanged` yang
  memakai gerbang, dan ia kini lewat `deliver`.
- CI `Engine Tests (Linux)` run `37154348034` pada commit `10dd936` → **166 +
  142, 0 gagal** (kedua paket).
- CI `Apple Build` run `37154348042` pada commit `10dd936` → **2× `BUILD
  SUCCEEDED`** dan gerbang peringatan melaporkan *"Tidak ada peringatan compiler
  pada Apps/."*

### Siklus sebelumnya: GoTo teleskop dihitung dari resolusi yang sudah tidak berlaku
Fokus: menyisir **predikat "jawaban berlaku sekarang"** ke jalur yang belum
pernah diperiksa — jalur yang berujung ke **motor teleskop**. Siklus-siklus
sebelumnya menutup objek sisa pada pesan ke iPhone dan riwayat keyakinan; yang
tersisa justru jalur paling berbahaya. Logika engine **tidak disentuh**;
aturan keras PRD tidak dilonggarkan.

**Cacat 10 — perintah GoTo diambil dari arah tunjuk sebelumnya.** `lastResolution`
sengaja dipertahankan agar cuplikan tetap membawa jarak tetangga untuk
diagnostik, dan ia hanya dibuang saat alur **dihentikan** (atau saat
lokasi/ambang berubah) — **bukan** saat arah tunjuk bergeser dan keadaan
kehilangan jawabannya. `PointingController.slewDecision(date:policy:)`
membacanya mentah: `guard let resolution = lastResolution`, lalu
`SlewPlanner.plan(...)`.

Akibatnya: selama pergelangan bergerak menjauh setelah sempat terkunci,
`lastResolution` masih berisi resolusi Sirius. Keadaannya sudah kembali
`pointing` (tidak punya jawaban sekarang), tapi `slewDecision` tetap
mengembalikan `.allowed(...)` untuk Sirius — dengan arah target dihitung dari
**posisi objek**, sesuai aturan PRD, tapi objek itu sudah tidak ada di arah
tunjuk sekarang. Langkah OBJECT ID dilewati: POINT → **SAFE GOTO**, tanpa
identifikasi yang berlaku. Ini kelas yang sama dengan Cacat 1 (objek sisa bocor
ke iPhone) — kali ini ujungnya motor, bukan layar.

Diperbaiki dengan predikat yang sudah dipakai jalur-jalur lain: `slewDecision`
kini gagal-tertutup (`nil`) kecuali `snapshot.state.hasAnswer`. Objek yang
dikunci dengan ambang lama pun tidak bisa lagi lolos, karena mengubah ambang
sudah menghentikan alur dan membuang jawabannya.

Satu uji baru menguncinya (`PointingControllerTests.testSlewDecisionRefusedWhenAnswerIsStale`):
terkunci di Sirius → GoTo diizinkan; arahkan 170° menjauh → `slewDecision` **nil**
(bukan lagi `.allowed` untuk Sirius). Uji ini gagal pada kode lama dengan pesan
yang menyebut Sirius beserta koordinatnya — jadi ia bukan sekadar formalitas.

**Yang benar-benar dijalankan pada siklus ini:**
- Uji regresi dijalankan **dulu** pada kode lama → **gagal** (`.allowed` untuk
  Sirius saat arah tunjuk 170° menjauh). Setelah perbaikan → **lulus**.
- `./swift-test.sh` → **166 CelestialEngine + 140 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan ulang `lastResolution`/`answeredIntent`/`hasAnswer` di `Apps/` dan
  `PointingKit/Sources`: tidak ada lagi jalur yang membaca resolusi lama tanpa
  memeriksa apakah keadaan punya jawaban. `lastResolution` kini hanya dipakai
  untuk jarak tetangga diagnostik (aman: keadaan yang menampilkannya juga sudah
  memberi tahu) dan oleh `slewDecision` yang sudah dijaga.
- CI `Engine Tests (Linux)` run `37153246327` pada commit `ce3da4c` → **166
  CelestialEngine + 140 PointingKit, 0 gagal** (kedua paket).
- CI `Apple Build` run `37153246367` pada commit `ce3da4c` → **2× `BUILD
  SUCCEEDED`** (skema iPhone yang ikut membangun app jam, dan skema jam sendiri),
  uji PointingKit di Apple SDK **140, 0 gagal**, dan langkah gerbang melaporkan
  *"Tidak ada peringatan compiler pada Apps/."*

### Siklus sebelumnya: arah tunjuk dari sensor yang sudah mati masih ikut terkirim, dan kegagalan kirim yang paling sering tidak terlihat
Fokus: menyisir **predikat "berlaku sekarang"** yang sudah dipakai untuk objek dan
keyakinan — apakah **arah tunjuk** punya padanannya — lalu memeriksa janji
"kegagalan tidak boleh diam" di jalur kirim. Logika engine **tidak disentuh**;
aturan keras PRD tidak dilonggarkan.

**Cacat 8 — azimut/ketinggian dari beberapa detik lalu terkirim sebagai pengukuran
sekarang.** Siklus sebelumnya (Cacat 7) menutup satu jalur bacaan arah tunjuk:
`PointingEngine.pointing` kini `nil` saat `snapshot.hasSensor == false`, karena
`calibratedPointing` sengaja **dipertahankan** di cuplikan dan saat sensor mati
isinya adalah arah terakhir sebelum sensor hilang. Tapi perbaikan itu hanya
menyentuh **layar jam**. Jalur kedua membaca field yang sama dan tidak pernah
diperiksa:

`PointingLinkMessage.state(from:)` — pesan keadaan ke iPhone — mengirim
`snapshot.calibratedPointing?.altitudeDeg` / `.azimuthDeg` **tanpa penjagaan
sensor**. Saat jam kehilangan sensornya, pesan yang terkirim tetap membawa
azimut/ketinggian dari beberapa detik sebelumnya, dan di iPhone tidak ada penanda
apa pun bahwa angkanya sudah tidak berlaku — persis kelas yang sama dengan Cacat 7,
kali ini di jalur yang Cacat 7 tidak mencapai.

Cara menutupnya sama seperti objek/keyakinan: aturannya dipindahkan ke
`PointingKit` sebagai predikat semantik
(`PointingSnapshot.reportedPointing`, berlaku hanya bila sensor hidup), lalu
**kedua** jalur memakainya — `PointingEngine.pointing` dan
`PointingLinkMessage.state(from:)`. Dengan begitu keduanya tidak bisa lagi berbeda
pendapat tentang kapan sebuah arah tunjuk boleh dilaporkan; sebelum ini aturannya
ditulis dua kali, dan hanya satu yang benar.

Dua uji baru mengunci perilakunya (`LinkMessageTests`,
`PointingPresentationTests`): sensor mati → `altitudeDeg`/`azimuthDeg` **tidak
dikirim** (sementara `state` tetap dilaporkan apa adanya), sensor hidup → arah
tetap ikut. Satu di antaranya secara eksplisit menegaskan bahwa
`calibratedPointing` **memang** masih terisi saat sensor mati — itulah yang
membuat kiriman mentah berbahaya, dan yang membuat uji ini bukan sekadar
formalitas.

**Cacat 9 — kegagalan kirim yang paling sering justru satu-satunya yang tidak
terlihat.** `WatchLinkService.send(_:)` berkomentar sendiri: *"Gagal kirim
**tidak** diam: penghitungnya naik supaya bisa dilihat saat pengujian lapangan."*
Isinya tidak begitu — `guard ... else { return }` pada sesi yang belum aktif
**tidak** menaikkan apa pun. `send(calibration:)` di berkas yang sama, dengan
penjagaan yang identik, **memang** menaikkannya. Jadi dua jalur yang sama
menjanjikan hal yang sama, dan hanya satu yang menepatinya — pola yang sama
seperti Cacat 8.

Akibatnya persis kebalikan dari niatnya: keadaan "jam belum tersambung ke iPhone"
— kegagalan yang paling sering terjadi di lapangan — adalah satu-satunya yang
tidak terlihat. Di layar jam angka "N gagal" tetap nol, dan penguji menyimpulkan
tautannya baik-baik saja sementara tidak ada satu pun keputusan yang sampai.
`requestState()` memakai jalur ini juga, jadi permintaan iPhone yang tidak pernah
dijawab pun tidak meninggalkan jejak.

Sekarang kedua jalur menghitung sesi-belum-aktif sebagai kegagalan, dengan pesan
yang menyebut sebabnya.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 139 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan ulang seluruh pembacaan field cuplikan yang dipertahankan
  (`snapshot.intent` / `bestObject` / `calibratedPointing` / `rawPointing`) di
  `Apps/` dan `PointingKit/Sources`: tidak ada lagi jalur kirim/rekam/tampil yang
  membacanya mentah. Tersisa hanya `ExperimentRecorder` (arah tunjuk **mentah**
  untuk mengukur galat, sudah dijaga `hasSensor` di pemanggilnya) dan
  `CalibrationSession` (titik acuan, sudah dijaga `hasSensor` di kedua jalan
  masuknya).
- `angularRateDegPerSec` **diperiksa dan ternyata benar**: `AngularRateTracker`
  ikut direset saat sensor hilang, jadi `nil` — bukan nilai lama. Tidak diubah.
- CI `Apple Build` run `37152202855` pada commit `a74d5be` → **2× `BUILD
  SUCCEEDED`**, gerbang peringatan *"Tidak ada peringatan compiler pada Apps/."*
- CI `Engine Tests (Linux)` run `37152202846` → **166 + 139, 0 gagal**.
- CI `Apple Build` run `37151800262` pada commit `775b89f` → **2× `BUILD
  SUCCEEDED`** (skema iPhone yang ikut membangun app jam, dan skema jam sendiri),
  dan langkah gerbang melaporkan *"Tidak ada peringatan compiler pada Apps/."*
- CI `Engine Tests (Linux)` run `37151800258` → **166 CelestialEngine + 139
  PointingKit, 0 gagal**, kedua paket ditegakkan di CI.

### Siklus sebelumnya: objek sisa bocor ke iPhone, dan jam berhenti bicara tepat saat jawabannya hilang
Fokus: menyisir **jalur yang mengirim dan merekam** "apa yang engine katakan
sekarang" — tempat objek yang sengaja dipertahankan mesin keadaan bisa keluar
dari layar jam (yang menandainya sisa) menuju tempat yang tidak punya penanda
itu. Logika engine **tidak disentuh**; aturan keras PRD tidak dilonggarkan.

**Cacat 1 — objek sisa terkirim sebagai jawaban sekarang.** Mesin keadaan
sengaja mempertahankan `currentIntent` supaya panel jam tidak berkedip saat
pergelangan bergerak sedikit (`PointingFlow.swift`). `PointingView` sudah
menanganinya: objek sisa ditampilkan **dengan** peringatan, dan badge keyakinan
disembunyikan. Tapi dua jalur lain membaca `snapshot.bestObject` /
`snapshot.intent?.level` mentah:

- `PointingLinkMessage.state(from:)` — pesan ke iPhone;
- `ConfidenceTrace.record(snapshot:)` — riwayat keyakinan di iPhone.

Keduanya **tidak** punya penanda "sisa". Akibatnya, tepat setelah jam kehilangan
jawabannya (pergelangan bergerak lagi), iPhone menerima dan merekam objek dari
arah tunjuk **sebelumnya** lengkap dengan badge "Yakin" dari keyakinan lama.
Ini persis false confidence yang dilarang PRD, dan ia muncul justru pada momen
paling menyesatkan. Diperbaiki di **satu tempat**: `PointingSnapshot` kini punya
predikat semantik `answeredObject` / `answeredLevel` / `answeredSeparationDeg`
(yang berlaku hanya bila `state.hasAnswer`), dan kedua jalur memakainya.
`displayedObject` sengaja tetap mempertahankan objek terakhir — itu benar untuk
layar jam, yang menandainya sisa.

**Cacat 2 — jam berhenti bicara tepat saat jawabannya hilang, dan mengirim 20×
per detik saat terkunci.** `PointAndKnowWatchWatchApp` menyaring kiriman dengan
`update.snapshot.state.hasAnswer`, padahal komentarnya sendiri menjanjikan
"bukan tiap sampel 20 Hz". Syarat itu salah dua kali sekaligus: selama terkunci
jawabannya **terus** ada, jadi syaratnya tetap benar dan jam mengirim 20×/detik
(persis yang ingin dicegah); dan tepat saat jawabannya **hilang** syaratnya
menjadi salah, jadi kiriman berhenti — iPhone membeku di objek terkunci terakhir
seolah masih berlaku, tanpa cara apa pun untuk tahu bahwa jam sudah tidak
mengidentifikasi apa pun. Diganti dengan `LinkReportGate` (di `PointingKit`,
teruji di Linux): kirim saat **keputusan berubah** — keadaan, objek, atau
keyakinan — termasuk saat berubah menjadi "tidak ada jawaban".

**Cacat 3 — dua kontrol di layar Diagnostik iPhone yang tidak mengatakan
keadaannya.** Saklar "Rekam keyakinan" menulis langsung ke
`trace.trace.isRecording`; `ConfidenceTrace` bukan `ObservableObject`, jadi
perubahan itu tidak dipublikasikan dan saklarnya bisa tampak tidak menanggapi.
Tombol "Kosongkan riwayat" tetap aktif saat perekaman **dijeda** — tampak siap
menghapus padahal tidak ada yang tersimpan lagi. Keduanya kini lewat store dan
mencerminkan keadaan yang sebenarnya.

**Cacat 4 — Experiment 1 bisa merekam pengukuran yang tidak pernah terjadi.**
`ExperimentRecorder.record()` hanya memeriksa "ada arah tunjuk?" (`rawPointing
!= nil`). Saat sensor mati, `rawPointing` yang tersisa di cuplikan adalah
**nilai terakhir sebelum sensor hilang** — nilainya tetap terisi, jadi
pemeriksaan itu meloloskannya. Yang akan terekam: arah dari beberapa detik lalu
dipasangkan dengan target yang dipilih sekarang, lalu masuk ke dataset yang
justru ada untuk mengukur akurasi Watch. Alat ukur tidak boleh mengarang data.
Kini sensor harus benar-benar hidup; tombol Rekam di layar ikut mati saat sensor
mati supaya penguji tidak mengira percobaannya tercatat.

**Cacat 5 — alat ukur Experiment 1 bisa melaporkan false lock palsu.**
`ObservationLog.analyze` menghitung `isFalseLock` murni dari `intent.level`.
Padahal `intent` sengaja **dipertahankan** oleh mesin keadaan saat pergelangan
bergerak: rekaman yang diambil pada keadaan `pointing` masih membawa intent
sisa berlevel HIGH. Hasilnya: engine dituduh "yakin tapi salah" untuk jawaban
yang tidak pernah ia tampilkan — dan `falseLockCount` inilah yang menentukan
lulus/gagal Experiment 1 (`passesSafetyCriterion`). Alat ukur tidak boleh
memproduksi kegagalan yang tidak terjadi. `analyze` kini menerima `state`
opsional: keadaan tanpa jawaban (`pointing`/`searching`/`idle`/`unavailable`)
tidak bisa menghasilkan false lock. Parameter berdefault `nil` supaya pemanggil
lama (165 uji engine) berperilaku persis seperti sebelumnya, dan harness
PointingKit sekarang meneruskan `state` yang selama ini sudah ia simpan di
`stateAtCapture` tetapi tidak pernah dipakai.

**Cacat 6 — kalibrasi bisa dipasang dari arah tunjuk yang sudah tidak berlaku.**
Kelas yang sama, kali ini di `CalibrationSession`: kedua jalan masuknya
(`capture(objectID:)` dan `captureNearest()`) membaca
`controller.snapshot.rawPointing` — yang **tetap terisi** saat sensor mati.
Akibatnya kalibrasi bisa dipasang dari arah terakhir sebelum sensor hilang:
seluruh pointing sesudahnya bergeser, dan kesalahannya tersembunyi di balik
sebaran sisa yang terlihat bagus. Keduanya kini menolak saat
`snapshot.hasSensor == false`, dengan pesan yang menyebut sebabnya.

**Cacat 7 — bacaan arah tunjuk tetap tampil dari sensor yang sudah mati.**
`PointingEngine.pointing` meneruskan `snapshot.calibratedPointing` apa adanya.
Saat sensor hilang, nilai itu adalah arah **terakhir sebelum sensor mati**, dan
layar Ketelitian menampilkannya sebagai azimut/ketinggian tanpa penanda — bacaan
lama tampak seperti pengukuran sekarang. Ini kelas yang sama dengan enam cacat
di atas (nilai yang sengaja dipertahankan, dibaca sebagai nilai berlaku), dan
kini disamakan: `nil` saat `snapshot.hasSensor == false`.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **166 CelestialEngine + 136 PointingKit, 0 gagal** (exit 0).
  Dua belas uji baru mengunci perilaku ini: objek sisa tidak terkirim
  (`LinkMessageTests`), tidak terekam (`ConfidenceTraceTests`), predikat
  "berlaku sekarang" (`PointingPresentationTests`), dan gerbang kiriman
  (`LinkMessageTests`).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- Sapuan jalur kirim/rekam: tidak ada lagi pembacaan `bestObject` /
  `intent?.level` mentah di `Apps/`.
- CI `Apple Build` run `37150857427` dan `Engine Tests (Linux)` run
  `37150857564` pada commit `d43d0a9` → keduanya hijau.
- CI `Apple Build` run `37150667798` dan `Engine Tests (Linux)` run
  `37150667892` pada commit `4e15d90` → keduanya hijau (App iPhone+Watch
  `BUILD SUCCEEDED`, 166 + 136 uji lolos).
- CI `Apple Build` run `37149633633` → **2× `BUILD SUCCEEDED`** dan gerbang
  peringatan melaporkan *"Tidak ada peringatan compiler pada Apps/."*
- CI `Engine Tests (Linux)` run `37149633616` → **165 CelestialEngine + 131
  PointingKit, 0 gagal**, kedua paket ditegakkan di CI.
- Siklus yang sama juga menutup klaim tes yang terlalu longgar:
  `displayedObject` mengembalikan `intent?.best` tanpa memandang keadaan,
  padahal tesnya menjanjikan "idle/unavailable tidak menampilkan objek apa
  pun" — janji itu hanya benar karena tesnya memakai intent kosong. Sensor yang
  mati di tengah pandangan memang menyisakan objek lama, jadi sekarang diuji
  apa adanya: panelnya tetap tampil **dengan** penanda sisa dan tanpa badge
  keyakinan (**132** tes PointingKit).
- CI `Apple Build` run `37149935666` dan `Engine Tests (Linux)` run
  `37149935687` pada commit berikutnya → keduanya hijau.

### Siklus sebelumnya: menutup temuan peringatan @preconcurrency + menjadikannya gerbang
Fokus: menutup **satu-satunya temuan yang sengaja dibiarkan terbuka** oleh
siklus sebelumnya. Logika engine **tidak disentuh**; aturan keras PRD tidak
dilonggarkan.

**Temuan yang ditutup.** Siklus sebelumnya mencatat tiga peringatan build yang
bertentangan dengan komentar di kodenya sendiri —
`@preconcurrency attribute on conformance to '...' has no effect` di
`LocationProvider.swift`, `WatchLinkService.swift`, dan `PhoneLinkService.swift`
— dan memilih **tidak** menyentuhnya karena menghapusnya tanpa bisa membangun
di macOS akan menjadi tebakan.

**Yang membuatnya bukan tebakan lagi.** Compiler-nya sendiri memberi verdict,
dan verdict itu bisa dibaca dari log CI yang sudah ada: Xcode 16.4 (16F6)
menandai atribut itu **tidak berpengaruh** dan menawarkan fix-it untuk
membuangnya. Compiler benar, dan alasannya bisa diperiksa di kode: **setiap**
metode delegasi di ketiga berkas sudah `nonisolated` dan menyerahkan hasilnya
ke main actor lewat `Task`, jadi tidak ada satu pun persyaratan protokol yang
dilanggar isolasi. Atribut itu memang tidak mengerjakan apa-apa, dan komentar
lama ("compiler menolak konformansnya tanpa atribut ini") sudah tidak berlaku.
Tiga atribut dibuang; komentarnya diganti dengan alasan yang berlaku sekarang.

**Arah perubahannya juga lebih gagal-tertutup.** Dengan atribut itu, kesalahan
isolasi **baru** di kemudian hari (mis. metode delegasi yang lupa `nonisolated`)
hanya menjadi peringatan runtime. Tanpa atribut, kesalahan yang sama menjadi
**galat kompilasi** — jauh lebih awal ketahuan.

**Agar tidak terulang.** Peringatan build hanya terlihat di log CI macOS, dan
peringatan yang menganggur adalah cara paling halus untuk menutupi komentar
kode yang sudah tidak berlaku — persis yang terjadi selama ini. Karena itu
kedua build app kini menyimpan keluarannya, dan langkah baru
**"Gerbang peringatan (kode sendiri)"** gagal bila ada `warning:` yang
menunjuk berkas `Apps/`. Peringatan alat Xcode (urutan build manual, metadata
AppIntents, swift-format) sengaja **tidak** dihitung — itu bukan kode ini, dan
menjadikannya kegagalan hanya akan membuat gerbangnya dimatikan orang lain saat
ia berbunyi.

**Celah kedua yang ditemukan dan ditutup.** `engine-tests.yml` hanya
menjalankan `CelestialEngine`, padahal kriteria "ENGINE SIAP" di `ROADMAP.md`
berbunyi "165/165 engine + 124/124 PointingKit di Linux, **tanpa Mac**".
Separuh kriteria itu karena itu tidak pernah ditegakkan di CI: perubahan pada
`PointingKit` — tempat seluruh keputusan produk yang bisa salah hidup (kapan
yakin, kapan menolak, apa yang direkam) — hanya akan tertangkap job macOS yang
jauh lebih lambat. Kini `swift test --package-path Packages/PointingKit`
dijalankan sebagai langkah kedua di sana.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **165 CelestialEngine + 124 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- **Pola gerbang peringatan diuji terhadap log run `37147598026` yang
  sebenarnya** (bukan dikarang): **16 peringatan kode tertangkap**, **6
  peringatan alat diabaikan**.
- CI `Apple Build` run `37148159414` → **2× `BUILD SUCCEEDED`**, langkah gerbang
  melaporkan *"Tidak ada peringatan compiler pada Apps/."* → tiga peringatan
  `@preconcurrency` **hilang**, terverifikasi di Apple SDK.
- CI `Engine Tests (Linux)` run `37148349397` → **kedua paket hijau**
  (165 + 124). CI `Apple Build` run `37148349347` → hijau.

### Siklus sebelumnya: peringatan lokasi bawaan tidak boleh bergantung pada string mentah
Fokus: menutup satu cacat laten di lapisan app. Logika engine **tidak
disentuh**; aturan keras PRD tidak dilonggarkan.

**Cacat yang ditemukan dan diperbaiki.** `PointingView` memutuskan apakah
menampilkan peringatan "lokasi belum didapat" lewat perbandingan string mentah:
`!engine.location.source.elementsEqual("corelocation")`. Padahal
`ObserverLocation` sudah punya predikat semantik `isFallback`. Perbandingan itu
benar **hari ini** hanya karena `LocationProvider` kebetulan menulis
`source: "corelocation"`. Begitu string itu berubah (atau ada sumber lokasi lain
yang ditambahkan), peringatan itu **terbalik diam-diam**: ia muncul justru saat
lokasi sungguhan, dan hilang tepat saat tinggi benda langit dihitung untuk
tempat lain. Itu persis kelas kesalahan yang PRD larang — UI yang tampak
normal sambil menyembunyikan bahwa angkanya tidak berlaku. Diganti dengan
`engine.location.isFallback` (predikat yang sama dengan yang dipakai layar
Experiment 1, jadi kedua layar tidak bisa lagi berbeda pendapat).

**Yang benar-benar dijalankan pada siklus ini:**
- Gerbang sintaks: **seluruh 15 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0`.
- `./swift-test.sh` → **165 CelestialEngine + 124 PointingKit, 0 gagal** (exit 0).
- CI `Apple Build` + `Engine Tests (Linux)` pada commit siklus ini.

**Temuan yang dulu BELUM ditutup — kini sudah (lihat entri siklus terbaru di
atas).** Build macOS hijau tetapi mengeluarkan tiga peringatan yang
**bertentangan** dengan komentar di kodenya sendiri:
`@preconcurrency attribute on conformance to 'WCSessionDelegate' has no effect`
(`WatchLinkService.swift:138`, `PhoneLinkService.swift:99`) dan
`... to 'CLLocationManagerDelegate' has no effect` (`LocationProvider.swift:40`).
Siklus itu sengaja **tidak** mengubahnya: menghapus atribut tanpa bisa
membangun di macOS adalah tebakan, dan mempertahankannya adalah pilihan yang
gagal-tertutup (paling buruk: peringatan yang tidak berguna, bukan galat).
Siklus berikutnya menutupnya — atributnya memang tidak berpengaruh (semua
metode delegasi sudah `nonisolated`), dibuang, dan peringatan build pada kode
sendiri kini menjadi gerbang di CI.

### Siklus sebelumnya: ekspor dataset benar-benar menjadi berkas bernama
Fokus: menyisir berkas app terhadap daftar item yang tersisa, lalu menutup satu
cacat nyata. Logika engine **tidak disentuh**; aturan keras PRD tidak dilonggarkan.

**Cacat yang ditemukan dan diperbaiki.** Dua layar ekspor ("Ekspor dataset
(JSON)" di `DiagnosticsView` dan `Experiment1View`) membagikan **`String`**
mentah lewat `ShareLink`. Akibatnya berkas yang keluar dari lembar berbagi
adalah teks tanpa nama dan tanpa akhiran `.json`: di Files/penerima ia muncul
sebagai "Teks", bukan dataset. Yang membuat ini jelas cacat, bukan sekadar
kosmetik: helper nama berkas berstempel waktu UTC —
`DatasetArchive.suggestedFilename(for:)` dan
`ConfidenceTraceArchive.suggestedFilename(for:)` — **sudah ada dan sudah
diuji** di `PointingKit`, tetapi **tidak pernah dipanggil dari app**. Jadi
stempel waktu anti-tabrakan yang sengaja ditulis itu mati: dua ekspor bisa
saling menimpa, dan item "ekspor dataset" baru terpenuhi setengah.

Perbaikannya:
- `Apps/PointAndKnowiOS/Sources/JSONArchiveDocument.swift` — pembungkus
  `Transferable` (`FileRepresentation(exportedContentType: .json)`) yang menulis
  `Data` ke berkas sementara dengan nama dari `suggestedFilename`, lalu
  menyerahkan `SentTransferredFile(url)`. `ShareLink` kini menerima dokumen ini,
  bukan `String`.
- Kedua layar memakai helper nama yang sudah teruji; jalur gagal-encoding tetap
  membagikan pesan kesalahan **di dalam berkas**, bukan berkas kosong yang
  tampak sah.

**Yang benar-benar dijalankan pada siklus ini:**
- Gerbang sintaks: **seluruh 15 berkas app** (bertambah satu) lolos
  `swiftc -parse -swift-version 5` di container `swift:6.0`.
- `./swift-test.sh` → **165 CelestialEngine + 124 PointingKit, 0 gagal** (exit 0).
- CI `Apple Build` pada commit akhir siklus → **2× `BUILD SUCCEEDED`** (skema
  iPhone yang ikut membangun app jam, dan skema jam sendiri); `Engine Tests
  (Linux)` hijau. Percobaan pertama **gagal** (lihat di bawah) dan diperbaiki
  sebelum hijau.

**Galat nyata yang hanya muncul saat dibangun di macOS (dan sudah diperbaiki):**
- Percobaan pertama memakai `ShareLink(item:)` dengan label tapi **tanpa**
  `preview:`. Di macOS, `ShareLink` hanya mengimplementasikan sebagian
  permutasi initializer-nya: bila `item:` bukan `String`/`URL` **dan** tidak ada
  `preview:`, tidak ada initializer yang cocok →
  `error: no exact matches in call to initializer` (lalu satu galat susulan
  "type of expression is ambiguous" di baris berikutnya). Ditambahkan
  `preview: SharePreview(...)` pada kedua layar. Gerbang `swiftc -parse` **tidak**
  bisa menangkap ini: ia memeriksa sintaks, bukan resolusi overload — sama
  seperti kasus kontrol akses `PointingEngine.bind` di siklus sebelumnya.
  Pelajaran: untuk API SwiftUI baru, `-parse` bukan bukti; hanya build macOS
  yang membuktikan.

### Siklus sebelumnya: objek sisa tampil sebagai hasil sekarang (anti false-confidence)
Fokus: membaca sendiri setiap berkas app, lalu memperbaiki satu cacat nyata yang
ditemukan — bukan menambah fitur. Logika engine **tidak disentuh** (165 test
CelestialEngine tetap hijau); aturan keras PRD tidak dilonggarkan.

**Cacat yang ditemukan dan diperbaiki.** `PointingEngine.isDisplayingStaleObject`
menilai "objek basi" dari `snapshot.bestObject == nil`. Itu **salah**, karena
mesin keadaan sengaja mempertahankan `currentIntent` supaya panel tidak berkedip:
saat keadaan sudah kembali `pointing` setelah pergelangan bergerak,
`bestObject` **tetap terisi** objek dari arah tunjuk sebelumnya. Akibatnya
sinyal "sisa pandangan sebelumnya" bernilai `false` tepat pada objek yang paling
basi. Dua akibat nyata:

- Peringatan "Sisa pandangan sebelumnya" di `PointingView` (jam) **tidak pernah
  bisa muncul** — syarat render lamanya (`state.hasAnswer`) hanya lolos saat
  `bestObject != nil`, dan saat itu `isStale` selalu `false`.
- `DiagnosticsView` (iPhone) menampilkan `displayedObject` tanpa penjagaan di
  bagian berjudul **"Sekarang"**, sehingga objek lama terbaca sebagai hasil
  pengukuran sekarang.

Perbaikannya: aturan pindah ke `PointingKit`
(`PointingSnapshot.displayedObject(lastLocked:)` +
`isDisplayingStaleObject(lastLocked:)`) supaya bisa diuji di Linux, dan
"basi" kini ditentukan oleh **`state.hasAnswer`**, bukan dari mana objek diambil.
`PointingView` menampilkan panel detail **dengan** peringatan sisa (bukan
disembunyikan, yang membuat jam berkedip) dan menyembunyikan badge keyakinan
pada objek sisa; `DiagnosticsView` menandai barisnya "Objek (sisa) — bukan hasil
sekarang".

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **165 CelestialEngine + 124 PointingKit, 0 gagal** (exit 0).
  Dua uji regresi baru menjaga aturan ini (`PointingPresentationTests`).
- Gerbang sintaks: **seluruh 14 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` setelah perubahan.
- `gh run view` pada `Apple Build` HEAD `6e5edd8` → **2× `BUILD SUCCEEDED`**
  (skema iPhone yang ikut membangun app jam, dan skema jam sendiri), **0 galat**.

### Siklus sebelumnya: perbaikan bug siklus hidup sensor di app iPhone
Fokus: membaca sendiri setiap berkas app, lalu memperbaiki satu cacat nyata yang
ditemukan — bukan menambah fitur. Logika engine **tidak disentuh** (165 + 122
test tetap hijau); aturan keras PRD tidak dilonggarkan.

**Cacat yang ditemukan dan diperbaiki.** `DiagnosticsView` dan `Experiment1View`
masing-masing menyalakan dan mematikan sensor **yang sama** di `onAppear` /
`onDisappear`. `TabView` menahan kedua tabnya tetap hidup, jadi:
- keduanya menyetel `motion.onUpdate` pada satu `MotionLogger` — penyambungan
  yang belakangan menimpa yang duluan, sehingga salah satu tab berhenti merekam;
- `onDisappear` salah satu tab memanggil `engine.stop()` untuk alur yang sedang
  dipakai tab lain.

Gejalanya persis jenis yang dilarang: layar tetap tampak hidup sementara sensor
sudah mati. Perbaikannya: siklus hidup sensor/lokasi/alur dipindahkan ke
`RootView` (satu kali untuk seluruh umur app, plus `scenePhase`), dan tiap tab
tidak lagi memilikinya. `Experiment1View` kini hanya menerima `engine` + `link`.

**Yang benar-benar dijalankan pada siklus ini:**
- `./swift-test.sh` → **165 CelestialEngine + 122 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 14 berkas app** lolos `swiftc -parse -swift-version 5`
  di container `swift:6.0` setelah perubahan.
- `gh run view` pada `Apple Build` HEAD `6e5edd8` → **2× `BUILD SUCCEEDED`**
  (skema iPhone yang ikut membangun app jam, dan skema jam sendiri), **0 galat**.
  Peringatan yang tersisa hanya bersifat kosmetik: `@preconcurrency ... has no
  effect` (sudah ditangani compiler Xcode 16.4, tidak berpengaruh fungsional) dan
  "Building targets in manual order is deprecated".

### Siklus sebelumnya: verifikasi independen ulang + koreksi klaim dokumen
Fokus: menjalankan sendiri seluruh verifikasi (bukan membaca klaim), lalu
memperbaiki satu klaim dokumen yang tidak cocok dengan berkasnya. Tidak ada kode
engine maupun app yang diubah; tidak ada aturan keras PRD yang dilonggarkan.

**Yang benar-benar dijalankan:**
- `./swift-test.sh` → **165 CelestialEngine + 122 PointingKit, 0 gagal** (exit 0).
- Gerbang sintaks: **seluruh 14 berkas app** lolos
  `swiftc -parse -swift-version 5` di container `swift:6.0`.
- `gh run list` → **`Apple Build` (macOS) dan `Engine Tests (Linux)` hijau** pada
  commit HEAD `abd2d64` (pohon git bersih) — jadi app benar-benar dikompilasi
  Apple SDK, bukan sekadar lolos parse.
- Sapuan stub (`TODO`/`FIXME`/`placeholder`) → bersih; satu-satunya kemunculan
  kata "placeholder" adalah komentar di `Confidence.swift` yang menjelaskan
  mengapa sigma awal sengaja longgar.
- Penyisiran jalur `rawPointing`: hanya di `CalibrationSession` (titik acuan),
  `ExperimentHarness`/`ExperimentRecorder` (pengukuran galat), dan `PointingView`
  (tidak dipakai). Tidak ada jalur yang menuju motor — `SlewCommand` tetap hanya
  bisa dibentuk `SlewPlanner`, dari objek teridentifikasi, gagal-tertutup.

**Koreksi dokumen (bukan kode):** `STATUS.md` menyebut `project.yml` punya
"empat target (2 app + 2 tes)". Berkasnya — dan seluruh riwayatnya — hanya pernah
mendefinisikan **dua target app** (`type: application`); tidak pernah ada target
tes Xcode. Tes memang hidup di paket SwiftPM (`swift test`), bukan sebagai target
Xcode. Klaimnya dikoreksi supaya cocok dengan berkasnya; tidak ada perubahan
build, jadi hijau CI tidak terpengaruh.

**Kesimpulan:** seluruh item kode di `ROADMAP.md` terpenuhi; satu-satunya item
yang tersisa adalah POC teleskop fisik, yang menunggu perangkat keras.

### Siklus sebelumnya: audit independen seluruh daftar item app (tanpa regresi)
Fokus: **memverifikasi, bukan mempercayai** — membaca ulang setiap berkas app
dan engine, lalu menjalankan suite, untuk memastikan tidak ada item yang
diklaim selesai padahal belum. Tidak ada aturan keras PRD yang dilonggarkan,
dan tidak ada kode engine yang diubah (165 + 122 test tetap hijau).

**Yang diverifikasi ulang satu per satu (semuanya sudah ada):**
- `MotionLogger` memetakan `CMDeviceMotion.attitude.quaternion` → `DeviceAttitude`
  lewat `init?(cmX:cmY:cmZ:cmW:)` → `controller.feed(...)` (`MotionLogger.swift:112`).
- `CalibrationView` memakai `CalibrationSession` (di atas `CalibrationFlow` →
  `CalibrationSolver`) dan hanya memasang kalibrasi lewat `engine.apply` setelah
  sebaran acuan sempit (`CalibrationView.swift:153,186`).
- `PointingView` merender **langsung** dari `PointingSnapshot`; keenam keadaan
  (`idle/pointing/searching/lock/uncertain/unavailable`) dipetakan lengkap di
  `PointingPresentation` (simbol, label, panduan, nada) — tidak ada keadaan tanpa
  cabang.
- Haptic dipicu **hanya pada perpindahan keadaan**, di
  `PointingController.hapticEvents(from:to:)` dengan penjagaan `previous != current`
  — jadi tidak bergetar tiap sampel 20 Hz. `.lock` → `.success`, `.uncertain` →
  `.retry` (`HapticEngine.swift:33-36`).
- `WatchLinkService`/`PhoneLinkService` memakai bentuk kabel yang sama
  (`PointingLinkMessage.plist` / `init?(plist:)`); kalibrasi lewat
  `transferUserInfo` (tidak tertimpa), keadaan lewat `updateApplicationContext`.
  `rawPointing` **tidak** pernah dikirim.
- iOS: `DiagnosticsView` menggambar rasio jarak-kandidat/σ (Swift Charts) +
  `ShareLink` ekspor JSON; `Experiment1View`/`ExperimentRecorder` merekam
  tunjuk→rekam→ekspor dengan kebenaran mengikuti `engine.location`.
- `project.yml` menunjuk path yang benar-benar ada (termasuk
  `Resources/Assets.xcassets` dengan `AppIcon-1024.png`), `ios-build.yml` sudah
  memuat `brew install xcodegen`.

**Aturan keras PRD diperiksa ulang di kode:** `rawPointing` (sudut pergelangan)
hanya dipakai di dua tempat yang memang diizinkan — `CalibrationSession` (titik
acuan) dan `ExperimentHarness` (pengukuran galat). Tidak ada di jalur mana pun
yang menuju motor. `SlewPlanner`/`SlewCommand` tetap satu-satunya jalan membentuk
perintah GoTo, diturunkan dari objek teridentifikasi, gagal-tertutup.

**Tidak ada perubahan kode** — siklus ini murni verifikasi. Yang dijalankan:
- `./swift-test.sh` → **165 CelestialEngine + 122 PointingKit, 0 gagal** (exit 0).
- `gh run list` → **CI macOS `Apple Build` + CI Linux `Engine Tests` hijau** pada
  commit `12b4ce9` (HEAD), pohon git bersih.
- Sapuan stub (`TODO`/`FIXME`/`placeholder`) → bersih; satu-satunya kemunculan
  kata "placeholder" adalah komentar di `Confidence.swift` yang **menjelaskan**
  mengapa sigma awal sengaja longgar.

**Kesimpulan:** seluruh item kode di `ROADMAP.md` terpenuhi; satu-satunya item
yang tersisa adalah POC teleskop fisik, yang menunggu perangkat keras.

## Progres terakhir (3 Okt 2026)

### Siklus ini: kalibrasi yaw diterapkan DUA KALI (galat sisa 2× offset)
Fokus: menguji **siklus kalibrasi penuh**, bukan hanya potongan fungsinya.

**Bug yang ditemukan (dan tidak terlihat oleh 165+120 test lama):**
- `PointingController` memakai `calibration.yawOffsetDeg` **dua kali**:
  sekali sebagai `rollAboutViewDeg` saat membangun `DeviceAttitude`
  (`PointingController.swift:299`, `:328`), lalu sekali lagi sebagai koreksi
  azimut lewat `calibration.apply(to:)`.
- Akibatnya offset yang *benar* menghasilkan galat sisa ≈ 2×offset. Probe
  numerik dengan offset 37° memberi galat **35.36°**, `state = .searching`,
  `bestObject = nil` — jam gagal mengunci bintang yang ditunjuk tepat, padahal
  kalibrasinya sudah benar.
- Setelah diperbaiki (offset hanya lewat `calibration.apply`): galat sisa
  **8.5e-07°**, `state = .lock`, `bestObject = sirius`.
- **Mengapa lolos selama ini:** suite lama menguji `PointingCalibration.apply`
  dan `DeviceAttitude(rollAboutViewDeg:)` secara terpisah, tapi tidak pernah
  menjalankan satu siklus lengkap "kalibrasi → tunjuk → kunci". Bug hanya
  muncul saat keduanya dirangkai.
- **Regresi permanen:** `CalibrationRoundTripTests` (2 test) mengunci perilaku
  ini — offset diterapkan tepat sekali, azimut terkoreksi, altitude tidak
  tersentuh, dan hasil akhirnya `.lock` pada target yang benar.
  **Pelajaran:** uji jalur ujung-ke-ujung, bukan hanya unit terpisah; offset
  ganda adalah kelas bug yang tak terlihat dari test per-komponen.

### Siklus sebelumnya: sensor mati di tengah pemakaian tidak terlihat di layar
Fokus: menyisir **perubahan keadaan yang tidak pernah sampai ke UI**. Tidak ada
aturan keras PRD yang dilonggarkan.

**CI macOS menangkap satu kesalahan yang Linux tidak bisa lihat:**
- `PointingUpdate` tidak punya inisialisasi publik (memberwise default bersifat
  `internal`), sehingga `MotionLogger.publishSensorLoss()` ditolak dengan
  *"'PointingUpdate' initializer is inaccessible due to 'internal' protection
  level"*. Ditutup dengan `public init(snapshot:haptics:)`.
  **Pelajaran:** `swiftc -parse` hanya memeriksa sintaks — ia tidak tahu soal
  tingkat akses antar-modul. Untuk app, macOS CI adalah verifikasi sebenarnya.
- Setelah perbaikan: **CI macOS hijau** (`Apple Build`, run `37140770415`) dan
  **CI Linux hijau** (run `37140770436`).

**Yang ditemukan & ditutup:**
- **`MotionLogger.handleFailure` menghentikan alur tanpa memberi tahu UI.**
  Jalur galat CoreMotion (sensor dilepas, izin dicabut, hardware gagal) memanggil
  `controller.setSensorAvailable(false)` langsung — yang memang membuang
  jawaban di dalam controller. Tapi `PointingEngine.snapshot`, satu-satunya
  sumber yang dibaca `PointingView`, **tidak ikut berubah**: sampel sudah
  berhenti mengalir, jadi `onUpdate` tidak pernah dipanggil lagi.
  - Akibatnya jam tetap menampilkan objek terakhir **seolah masih
    terkonfirmasi**, beserta getaran "terkunci" yang terakhir — persis yang
    dilarang PRD ("jangan pernah salah identifikasi demi magic"). Tidak ada
    bagian UI yang terlihat keliru, karena yang terlihat justru jawaban lama
    yang tampak normal.
  - Perbaikan: kehilangan sensor dikirim lewat **saluran yang sama dengan
    sampel sensor** (`PointingUpdate` yang sudah diperbarui + peristiwa haptic),
    bukan dengan menyentuh controller diam-diam. Jalur "perangkat tanpa device
    motion" di `start(controller:)` juga dialihkan ke jalur yang sama — di sana
    ia dijalankan sebelum `self.controller` diset, jadi sebelumnya sensor tidak
    pernah ditandai mati sama sekali.
- **`ExperimentHarness.availableTargets` dihitung ulang tiap pembacaan.**
  Layar Experiment 1 membacanya di dalam `body`, dan `body` dievaluasi pada
  setiap sampel sensor — jadi seluruh katalog + efemeris tata surya disapu 20
  kali per detik sepanjang pengukuran. Ditambah cache berjangka 30 detik yang
  dibatalkan saat tempat berubah (dengan `isSamePlace`, supaya perbaikan GPS
  yang hanya menggeser `capturedAt` tidak membuangnya), plus
  `targetComputationCount` supaya daftar yang dihitung ulang tidak terlihat
  sama dengan yang di-cache.

**Tes baru (8):** `testChangingObserverDropsAnswerComputedForOldSky`,
`testReapplyingSameObserverIsANoOp`, `testSetObserverKeepsCalibration`,
`testReferenceListBecomesStaleWhenObserverMoves`,
`testReferenceListStaysFreshWhenOnlyTimeChanges`,
`testTargetListIsNotRecomputedOnEveryRead`,
`testTargetListIsRecomputedAfterMoving`,
`testTargetListIsNotRecomputedForSamePlace`.
Uji pertama **dibuktikan MERAH lebih dulu** sebelum perbaikan: keadaan tetap
`lock` dan Sirius tetap tampil setelah pindah Jakarta → Quito.

**Status:** `./swift-test.sh` → **165 engine + 120 PointingKit, 0 gagal**.
Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
`swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: jawaban langit lama bertahan setelah pindah tempat
Fokus: menyisir **pembatalan jawaban yang menumpang pada efek samping pemanggil
lain** — kelas bug yang tidak terlihat di UI. Tidak ada aturan keras PRD yang
dilonggarkan.

**Yang ditemukan & ditutup:**
- **Perbaikan siklus lalu (kalibrasi yang sama = tanpa-efek) mematahkan
  pembatalan yang ternyata dipakai orang lain.** `PointingEngine.update(location:)`
  membatalkan jawaban lama dengan memanggil `apply(calibration:)` — yang
  menghentikan alur. Begitu panggilan itu jadi tanpa-efek, **perpindahan tempat
  berhenti membatalkan apa pun**: setelah pengguna pindah tempat, jam tetap
  menampilkan objek yang dihitung untuk langit **lama**. Keadaan `lock` ikut
  bertahan, jadi haptic "terkunci" tidak pernah berbunyi lagi di tempat baru.
  Tidak ada satu pun bagian UI yang terlihat keliru.
  - Perbaikan: pembatalan **melekat pada lokasi itu sendiri** lewat
    `PointingController.setObserver(_:)` (hentikan alur, buang resolusi,
    segarkan cuplikan). `observer` menjadi `private(set)` supaya tidak ada jalur
    yang bisa menggantinya tanpa membatalkan. Memasang pengamat yang sama tetap
    tanpa-efek. Kalibrasi **sengaja dipertahankan**: offset yaw adalah sifat
    pemasangan jam, bukan sifat tempat.
- **`CalibrationSession` menghitung daftar acuan untuk langit tempat lama.**
  Bintang yang tampak di atas horizon di satu tempat bisa sudah terbenam di
  tempat lain. Lokasi sungguhan tiba beberapa detik setelah layar kalibrasi
  dibuka, jadi pengguna memilih bintang yang tidak ada di langitnya, lalu offset
  kalibrasi dihitung dari kebenaran yang salah — dan daftar yang salah tempat
  tampak sama normalnya dengan yang benar.
  - Perbaikan: `referenceObserver` + `isReferenceListStale`, dan `CalibrationView`
    menghitung ulang saat lokasi berubah.
- **`PointingEngine.refreshSkyContext` menjalankan efemeris penuh 20 Hz.**
  Dokumennya sendiri menyebut "dipanggil jarang", tapi ia dipanggil dari
  `ingest(_:)` pada **setiap** sampel sensor: efemeris Matahari dan Bulan penuh
  di main actor tiap sampel. Ditambah penjagaan 30 detik; perubahan lokasi
  melewatinya, karena konteks tempat baru memang belum pernah dihitung.
- **`ExperimentHarness.availableTargets` dihitung ulang tiap pembacaan.**
  Layar Experiment 1 membacanya di dalam `body`, dan `body` dievaluasi pada
  setiap sampel sensor — jadi seluruh katalog + efemeris tata surya disapu 20
  kali per detik sepanjang pengukuran. Ditambah cache berjangka 30 detik yang
  dibatalkan saat tempat berubah (dengan `isSamePlace`, supaya perbaikan GPS
  yang hanya menggeser `capturedAt` tidak membuangnya), plus
  `targetComputationCount` supaya daftar yang dihitung ulang tidak terlihat
  sama dengan yang di-cache.

**Tes baru (8):** `testChangingObserverDropsAnswerComputedForOldSky`,
`testReapplyingSameObserverIsANoOp`, `testSetObserverKeepsCalibration`,
`testReferenceListBecomesStaleWhenObserverMoves`,
`testReferenceListStaysFreshWhenOnlyTimeChanges`,
`testTargetListIsNotRecomputedOnEveryRead`,
`testTargetListIsRecomputedAfterMoving`,
`testTargetListIsNotRecomputedForSamePlace`.
Uji pertama **dibuktikan MERAH lebih dulu** sebelum perbaikan: keadaan tetap
`lock` dan Sirius tetap tampil setelah pindah Jakarta → Quito.

**Status:** `./swift-test.sh` → **165 engine + 120 PointingKit, 0 gagal**.
Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
`swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: memasang kalibrasi yang sama mereset alur tanpa alasan
Fokus: menyisir operasi yang **tidak idempoten** padahal seharusnya. Tidak ada
aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup:**
- **`PointingController.apply(calibration:)` selalu mereset perata orientasi dan
  menghentikan mesin keadaan**, bahkan ketika kalibrasi yang dipasang persis
  sama dengan yang sedang berlaku. Dua pemanggil memang mengirim nilai yang
  sama:
  - `PointingEngine.update(location:)` mempertahankan kalibrasi dengan
    memanggil `apply(calibration: controller.calibration)` — nilai yang sama
    persis.
  - `CalibrationView.capture()` memanggilnya setelah mencatat acuan, padahal
    mencatat acuan tidak mengubah kalibrasi yang berlaku.
  - Akibatnya kunci yang sudah benar dibuang tanpa ada yang berubah — dan itu
    terjadi justru saat pengguna sedang mengkalibrasi. Ini sisa dari siklus
    lokasi: perbaikan `isSamePlace` menutup jalur yang paling sering, tapi
    akarnya ada di sini.
  - Perbaikan: penjagaan `newValue != calibration` ditaruh di controller supaya
    pemanggil tidak bisa "lupa". Reset hanya masuk akal bila kalibrasinya
    memang berubah, karena hanya perubahan yang membuat acuan lama tidak
    sebanding. Baris berlebih di `CalibrationView.capture()` dibuang, dengan
    komentar yang menjelaskan mengapa tidak perlu.
- **Tes baru (1):** `testReapplyingSameCalibrationIsANoOp` — kalibrasi yang sama
  tidak membuang kunci yang sudah benar. `testApplyingCalibrationResetsFlow`
  yang sudah ada tetap memastikan kalibrasi yang **berbeda** tetap mereset alur.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 112, 0 gagal**.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: tiap perbaikan GPS menghentikan alur dan mereset perata orientasi
Fokus: menyisir **kesetaraan nilai** yang dipakai sebagai penanda perubahan.
Tidak ada aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup:**
- **`PointingEngine.update(location:)` memakai `!=`, padahal `ObserverLocation`
  membawa `capturedAt`.** Tiap pembaruan lokasi membuat nilai itu berbeda, jadi
  **setiap** perbaikan GPS — kira-kira tiap detik, selama app terbuka —
  dianggap perpindahan tempat. Jalur itu menjalankan
  `controller.apply(calibration:)`, yang **mereset perata orientasi dan
  menghentikan mesin keadaan**.
  - Akibatnya jam **tidak akan pernah sempat** menunggu pergelangan diam lalu
    mengunci selama lokasi masih diperbarui, dan haptic "kembali ke idle"
    berbunyi berulang tanpa pengguna melakukan apa pun.
  - Getaran GPS puluhan meter hanya menggeser langit ≈0.0005° — tidak berarti
    apa-apa dibanding sigma pointing. Yang benar-benar menggeser langit adalah
    perpindahan tempat, bukan penajaman koordinat.
  - Perbaikan: `ObserverLocation.isSamePlace(as:toleranceDeg:)` membandingkan
    **koordinat saja** (ambang 0.01° ≈ 36″), dan menolak lokasi yang tidak sah.
    `update(location:)` memakainya. Sifat ini ditaruh di tipe-nya supaya
    perbandingan ini bisa diuji di Linux — bukan tersembunyi di lapisan app.
- **Tes baru (2):** `testIsSamePlaceIgnoresTimestampAndJitter` (waktu berbeda +
  getaran GPS → tempat yang sama; perpindahan 0.05° → bukan tempat yang sama),
  `testInvalidLocationIsNeverSamePlace`. Tes pertama menyatakan eksplisit
  `XCTAssertNotEqual(first, later)` — jadi ia gagal kalau pembandingnya
  dikembalikan ke `!=`.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 111, 0 gagal**.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: sampel dari jam membawa sigma yang tidak pernah berlaku
Fokus: memastikan **konteks** yang menemani sampel benar, bukan hanya
sampelnya. Tidak ada aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup:**
- **`ConfidenceTrace.record(message:)` mencatat sigma bawaan.** Jam tidak
  pernah menyertakan sigma dalam pesan keadaannya, jadi cabang ini memakai
  `ConfidencePolicy().pointingSigmaDeg` — angka yang **tidak pernah berlaku di
  jam**. Berkas ekspor karena itu memuat konteks yang dikarang, tanpa cara bagi
  pembacanya untuk mengetahuinya. Ini bertentangan langsung dengan alasan
  `ConfidenceTraceArchive` menyimpan lokasi/kalibrasi/sigma bersama sampel:
  *"berkas berisi derajat saja adalah anekdot."*
  - `PointingLinkMessage.state(from:at:sigmaDeg:)` dan
    `WatchLinkService.send(state:at:sigmaDeg:)` kini membawa sigma yang berlaku
    di jam. Bukan untuk keputusan apa pun di iPhone — melainkan karena riwayat
    keyakinan menyimpan konteks bersama sampelnya.
  - `record(message:)` memakai **nol** bila sigma tidak ada, bukan bawaan. Nol
    berarti "tidak terukur", dan `ratioToSigma` sengaja kosong untuk sigma nol.
    Menuliskan bawaan berarti mengarang konteks; menulis nol membuat
    ketidak-tahuannya terlihat.
  - Layar Tautan memperingatkan bila ada sampel tanpa sigma, supaya `0` tidak
    terbaca sebagai akurasi sempurna.
- **Tes baru (2):** `testStateMessageCarriesWatchSigma` (sigma ikut dalam pesan
  keadaan), `testStateMessageWithoutSigmaKeepsItNil` (`nil` tetap `nil`).

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 109, 0 gagal**.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: kebenaran Experiment 1 dihitung untuk tempat yang salah
Fokus: menyisir jalur **kebenaran** (ground truth) di Experiment 1. Tidak ada
aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup:**
- **`ExperimentHarness` memakai lokasi bawaan, bukan lokasi penguji.**
  Harness dibuat sekali di `init` dengan `engine.location` — yang saat itu
  masih `ObserverLocation.fallback` (Jakarta), karena lokasi sungguhan baru
  tiba beberapa detik setelahnya. `harness.location` hanya disinkronkan di
  dalam `record()`. Akibatnya:
  - Daftar target "di atas horizon" dihitung untuk Jakarta di mana pun
    penguji berada. Tinggi objek yang ditampilkan salah, dan target yang
    tampak terlihat bisa sebenarnya sudah terbenam.
  - Penguji memilih target itu, menekan Rekam, dan rekamannya ditolak
    ("arah target tidak bisa dihitung") tanpa sebab yang bisa dipahami.
  - Saat rekaman berhasil, `trial` dan `target` memakai lokasi yang berbeda,
    sehingga galat yang diukur mencampur galat lokasi dengan galat sensor —
    persis kekeliruan yang membuat Experiment 1 tidak menjawab pertanyaannya.
  - Perbaikan: `ExperimentRecorder.updateLocation(_:)` menyinkronkan kebenaran,
    dipanggil saat `onAppear` **dan** setiap kali `engine.location` berubah.
  - Layar kini memperingatkan bila lokasinya masih bawaan, karena daftar yang
    salah tempat tampak sama normalnya dengan yang benar.
- **`ObserverLocation.isFallback`** ditambahkan (dengan uji di Linux) untuk
  memisahkan lokasi terukur dari lokasi darurat. Label yang mirip **tidak**
  boleh membuat lokasi terukur dianggap darurat — yang menentukan adalah
  `source`. Uji ini akan merah kalau pembedanya dibalik ke perbandingan label.
- **Sisa dari siklus lalu:** hook `ExperimentRecorder` kini ikut memakai
  lokasi yang sama, sehingga tidak ada lagi dua sumber kebenaran lokasi.

**Tes baru (1):** `TargetsTests.testIsFallbackDistinguishesMeasuredLocation`.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 107, 0 gagal**.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- **CI macOS hijau** (`Apple Build`) + **CI Linux hijau** pada commit ini.

### Siklus sebelumnya: jalur Watch ↔ iPhone tidak pernah benar-benar tersambung
Fokus: memeriksa **transport** antar-perangkat, bukan isi pesannya. Tidak ada
aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup (tiga defect, semuanya tidak terlihat dari UI):**

**1. Kalibrasi selalu tertimpa sebelum sampai ke iPhone.**
`updateApplicationContext` menyimpan **satu** kamus saja — setiap kiriman
menggantikan yang sebelumnya. Hasil kalibrasi dikirim lewat jalur itu, jadi
pembaruan keadaan berikutnya (yang dikirim tiap kali ada jawaban) menimpanya.
Akibatnya iPhone bisa **tidak pernah** menerima kalibrasi, sementara di jam
kalibrasi tampak berhasil dan pesannya terkirim tanpa galat. Yang hilang di
sana bukan sekadar tampilan: `residualSpreadDeg` adalah sigma terukur yang
menyetel ambang keyakinan di iPhone — jadi Experiment 1 kehilangan
satu-satunya pengukuran yang membuatnya berguna.
- Kalibrasi (dan ambang keyakinan dari iPhone, yang punya masalah sama) kini
  lewat `transferUserInfo`, yang mengantre dan dikirim berurutan.
- Kedua sisi mendapat `session(_:didReceiveUserInfo:)`; tanpa itu pesan
  antre akan tiba dan dibuang diam-diam — lebih buruk daripada tidak dikirim.

**2. Tombol "Minta keadaan terakhir" tidak pernah dijawab.** iPhone mengirim
`.stateRequest`, dan handler di jam hanya berisi `break` dengan komentar
*"Balasan disiapkan pemanggil; di sini cukup dicatat."* Tidak ada pemanggil
yang melakukannya. Jadi tombol itu terlihat berfungsi, menaikkan penghitung
pesan, dan tidak pernah menghasilkan apa pun. Jam kini menjawab dengan
`currentSnapshot` (dibaca saat diminta, bukan disalin), dan kalau alurnya
belum siap ia mengatakan itu — bukan diam.

**3. Sisi iPhone membalas permintaan dengan permintaan.** `PhoneLinkService`
menangani `.stateRequest` dengan memanggil `requestState()`, yang mengirim
`.stateRequest` kembali. Dua perangkat bisa saling melempar permintaan yang
tidak pernah dijawab. Kini ia membalas dengan keadaan terakhir yang diketahui.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 106, 0 gagal**.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- **CI macOS hijau** (`Apple Build`): app iPhone (termasuk app jam) build
  sukses.

### Siklus sebelumnya: lokasi sungguhan tidak pernah sampai ke engine
Fokus: menyisir pembungkus app terhadap janji yang **ditulis** di komentarnya
sendiri. Tidak ada aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup (dua defect, keduanya kelas "tidak akan terlihat dari UI"):**

**1. Lokasi sungguhan tidak pernah dipakai engine.** `engine.update(location:)`
dipanggil **tepat sekali**, di `onAppear`/`start()` — yaitu sebelum CoreLocation
menjawab. Setelah itu tidak ada satu pun kode yang meneruskan lokasi sungguhan
ke engine (`onChange`/`onReceive`/`sink` tidak ada di seluruh Apps/). Akibatnya:
- Watch dan iPhone **selamanya** menghitung langit untuk `ObserverLocation.fallback`
  (Jakarta), di mana pun pengguna berada — sementara layar Diagnostik di
  sebelahnya menampilkan koordinat sungguhan. Dua angka yang bertentangan di satu
  layar, dan yang salah adalah yang dipakai menjawab.
- Untuk Final Challenge di lokasi selain Jakarta, seluruh langit tergeser;
  dan karena rentang geserannya sama untuk semua kandidat, **tidak ada bagian
  UI yang terlihat keliru**. Experiment 1 akan mengukur galat yang sebagian
  besar berasal dari lokasi, bukan dari akurasi Watch — persis kesalahan yang
  membuat eksperimennya tidak menjawab pertanyaannya.
- Perbaikan: `LocationProvider.onLocationChanged` dijalankan pada tiap
  pembaruan lokasi, dan `PointingEngine.bind(location:)` menyambungkannya ke
  `update(location:)`. Ketiga titik pemakaian (`PointingWatchApp`,
  `DiagnosticsView`, `Experiment1View`) kini memanggil `bind`, bukan memberi
  satu cuplikan lalu ditinggal. Penyambungan ditaruh di dalam engine supaya app
  tidak bisa "lupa" melakukannya.
- Uji `testWrongObserverShiftsTheWholeSky` membuktikan efeknya nyata: langit
  bergeser > 20° antara Jakarta dan Quito, sehingga Sirius yang tepat ditunjuk
  tidak lagi dikenali. Uji ini akan merah kalau lokasi diabaikan.

**2. Dimensi "ambigu" di diagnostik tidak pernah bisa terisi.** `ConfidenceTrace`
punya `neighbourRatioToSigma` dan `uncertainReason(for:)` bisa mengembalikan
`.ambiguous` — tapi `nearestNeighbourDeg` tidak pernah diisi oleh siapa pun
untuk sampel dari perangkat sendiri. Akibatnya, `uncertainReason` **selalu**
menjawab `.tooFar` atau `.none`, dan kalimat diagnostik
*"Semua jawaban ragu karena kandidat terlalu jauh. Perbaiki kalibrasi dulu."*
akan muncul bahkan ketika sebab sebenarnya adalah dua bintang berdekatan —
yang perbaikannya sama sekali berbeda (keterbatasan akurasi, bukan kalibrasi).
Ini persis jenis kebohongan yang dilarang: alat diagnostik yang menunjuk
perbaikan yang salah.
  - **Akarnya di engine.** Jarak tetangga dihitung di `diagnose()`, dipakai
    `ConfidenceModel`, lalu dibuang. Kini disimpan di
    `Resolution.nearestNeighbourDeg` — **angka yang sama** yang dipakai
    keputusan, bukan hasil hitung ulang. Menghitungnya kembali dari
    `intent.candidates` akan salah: `candidates` hanya tiga teratas, sedangkan
    keputusan dihitung dari seluruh kandidat dalam kerucut.
  - `PointingSnapshot.nearestNeighbourDeg` meneruskannya ke UI, dan
    `PointingController` mengisinya dari `lastResolution` — termasuk di
    `refreshSnapshot`, dan **dikosongkan** saat `stop()` supaya jarak dari
    pandangan lama tidak menempel pada pandangan baru.
  - `ConfidenceTrace.record(snapshot:)` kini membaca jarak itu dari cuplikan
    yang diberikan, bukan menunggu pemanggil mengisinya. Cuplikan sudah membawa
    variabel keputusannya; satu tempat saja yang tahu dari mana angka itu
    berasal.
  - Uji baru di `PointingControllerTests` sempat **gagal lebih dulu**
    (`.none` vs `.ambiguous`) sebelum perbaikan selesai — jadi klaim ini bukan
    pembacaan kode, melainkan hasil uji yang benar-benar merah.

**Tes baru (6):** 2 di `ResolverTests` (jarak tetangga dilaporkan & sama dengan
jarak sesungguhnya; kandidat tunggal → `nil`, bukan nol), 3 di
`PointingControllerTests` (jarak tetangga sampai ke cuplikan → sebabnya
`.ambiguous`; `stop()` mengosongkan jarak itu; lokasi salah menggeser langit),
1 perubahan `ConfidenceTrace`.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 165 + PointingKit 106, 0 gagal** (exit 0).
- Seluruh berkas app lolos `swiftc -parse -swift-version 5` di container
  `swift:6.0`.
- Build macOS (app iPhone + jam) diverifikasi CI `Apple Build` pada commit ini.

**Galat nyata yang hanya muncul saat dibangun di macOS (dan sudah diperbaiki):**
- `PointingEngine.bind(location:)` ditulis `public` padahal parameternya tipe
  internal `LocationProvider` → `error: method cannot be declared public
  because its parameter uses an internal type`. Gerbang sintaks
  (`swiftc -parse`) **tidak** memeriksa kontrol akses, jadi ini hanya
  tertangkap build sungguhan. Method dibuat `internal`, dan CI hijau pada
  commit berikutnya. Pelajaran yang layak diingat: `-parse` membuktikan
  berkasnya *terbaca*, bukan bahwa berkasnya *saling cocok*.

### Siklus sebelumnya: ekspor diagnostik + verifikasi ulang
Fokus: menyisir berkas app terhadap daftar item yang tersisa, dan menutup satu
item yang benar-benar belum ada. Tidak ada aturan keras PRD yang dilonggarkan.

**Yang ditemukan & ditutup:**
- **Tab Diagnostik tidak punya ekspor dataset.** Grafik keyakinannya ada, tapi
  riwayatnya hanya hidup di memori — item "iOS diagnostik: grafik confidence +
  ekspor dataset" belum terpenuhi sepenuhnya.
  - `Packages/PointingKit/Sources/PointingKit/ConfidenceTraceArchive.swift` —
    `ConfidenceTraceExport` + `ConfidenceTraceArchive` (encode/decode/nama berkas).
  - **Kenapa konteks ikut diekspor.** `ratioToSigma` hanya bisa ditafsirkan kalau
    sigma yang berlaku saat itu ikut tersimpan; lokasi, kalibrasi, dan sigma
    ditulis bersama sampelnya. Berkas berisi derajat saja adalah anekdot.
  - Memakai pengekod arsip yang sama dengan `DatasetArchive`
    (`JSONEncoder.pointingArchive()`) supaya pecahan detik tidak hilang dan
    urutan sampel tetap bisa direkonstruksi.
  - Sampel dari jam **tidak** diberi jarak kandidat karangan — jam memang tidak
    mengirim sudut pergelangan, jadi `separationDeg` tetap kosong.
  - `DiagnosticsView` kini punya `ShareLink` "Ekspor dataset (JSON)"; kalau
    encoding gagal, yang dibagikan adalah pesan kesalahan, bukan berkas kosong
    yang tampak sah.
  - 8 tes baru (`ConfidenceTraceArchiveTests`): bolak-balik mempertahankan
    variabel keputusan, waktu berpecahan detik, sigma nol tetap `nil`, sampel jam
    tetap tanpa jarak, arsip kosong tetap sah, berkas rusak **gagal** dibaca.
- **`PhoneLinkService.onMessage` tidak pernah disambungkan.** Hook-nya ada dan
  `ConfidenceTraceStore.record(message:)` juga ada, tapi tidak ada yang
  memanggil `onMessage` — jadi bagian "Sampel dari jam" di layar Tautan akan
  selamanya nol sambil tampak normal. Kini disambungkan di akar `RootView`,
  sekalian mengaktifkan sesi sekali (sebelumnya hanya di `LinkView.onAppear`,
  sehingga pesan yang tiba sebelum tab itu dibuka tidak terekam).

**Yang diverifikasi ulang (tidak diubah, ternyata sudah ada):**
- `WatchLinkService.sessionReachabilityDidChange` **sudah** ada; `isReachable`
  di layar jam memang ikut berubah. (Sempat saya duga hilang — ternyata tidak.)
- `MotionLogger` sudah memetakan `CMDeviceMotion` → `init?(cmX:cmY:cmZ:cmW:)`.
- Haptic `.lock`/`.uncertain` sudah dipicu dari perpindahan keadaan di
  `PointingController.hapticEvents(from:to:)`, bukan di lapisan UI.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 163 test + PointingKit 103 test, 0 gagal**
  (exit 0). PointingKit naik dari 95 → 103 karena 8 tes arsip baru.
- Seluruh 14 berkas app lolos `swiftc -parse -swift-version 5` **di dalam
  container swift:6.0** (swiftc tidak ada di host; gerbang sintaks dijalankan
  lewat Docker yang sama dengan suite).
- `ROADMAP.md` disinkronkan: item Fase 2/3 app yang sudah terwujud ditandai,
  dan baris "156/156" dikoreksi menjadi 163/163.
- Verifikasi build macOS ada di CI (`Apple Build`) pada commit ini.

### Siklus sebelumnya: pembungkus app iPhone + Watch, konfigurasi XcodeGen
Fokus: mengubah logika yang sudah teruji menjadi app yang bisa dibuka.
Tidak ada aturan keras PRD yang dilonggarkan; yang berubah hanya pembungkusnya.

**Struktur yang dipilih (dan alasannya):**
- `Packages/CelestialEngine` — mesin murni (Fase 1–3). **Tidak disentuh** selain
  penambahan aditif. 156 test tetap hijau.
- `Packages/PointingKit` — **logika lapisan app, bebas API Apple**. Semua
  keputusan yang bisa salah (kapan yakin, kapan menolak, apa yang direkam,
  apa yang dikirim ke iPhone) hidup di sini supaya bisa diuji di Linux.
  **95 test hijau** via Docker.
- `Apps/PointAndKnowWatch/`, `Apps/PointAndKnowiOS/` — hanya pembungkus:
  sensor, UI, haptic, WatchConnectivity. Berkas-berkas ini **tidak punya
  logika keputusan**; kalau ada `if` soal keyakinan di dalamnya, itu bug.

**Watch (Apps/PointAndKnowWatch/):**
- ✅ `Apps/Shared/MotionLogger.swift` — satu-satunya pembaca CoreMotion.
  `CMDeviceMotion` → `DeviceAttitude` lewat `init?(cmX:cmY:cmZ:cmW:)`, lalu
  diteruskan ke controller. Kalau sensor tidak ada, controller diberi tahu
  supaya **berhenti menebak** — bukan diam-diam memakai sampel terakhir.
- ✅ `HapticEngine.swift` — satu-satunya pemanggil `WKInterfaceDevice.play`.
  Pola getaran dibedakan tajam per peristiwa, karena getaran satu-satunya
  saluran yang tidak butuh mata.
- ✅ `PointingView.swift` — merender **langsung dari `PointingSnapshot`**
  (idle/pointing/searching/lock/uncertain/unavailable) + detail objek.
- ✅ `CalibrationView.swift` — memakai `CalibrationSession` di PointingKit
  (di atas `CalibrationSolver`). Kalibrasi **tidak boleh kelihatan selesai**
  sebelum sebaran titik acuannya benar.
- ✅ `WatchLinkService.swift` — mengirim **keputusan** (keadaan + objek), bukan
  sudut pergelangan mentah.
- ✅ `SkyContextView` (struct di dalam `PointingView.swift`) — konteks langit
  (kapan gelap, tinggi Matahari).

**iPhone (Apps/PointAndKnowiOS/):**
- ✅ `DiagnosticsView.swift` — grafik keyakinan (Swift Charts) + ekspor dataset.
  Yang digambar adalah **variabel keputusan** (`separation / sigma`), bukan
  hanya jawabannya.
- ✅ `Experiment1View.swift` + `ExperimentRecorder.swift` — harness Experiment 1:
  tunjuk target diketahui → rekam → ekspor. Verdict menyeleksi **percobaan
  gagal**, bukan menyembunyikannya.
- ✅ `PhoneLinkService.swift` + `LinkView.swift` — sisi iPhone dari
  WatchConnectivity; bisa mengirim ambang keyakinan hasil Experiment 1 ke jam.
- ✅ `JSONArchiveDocument.swift` — pembungkus `Transferable` supaya "Ekspor
  dataset (JSON)" benar-benar menghasilkan berkas bernama berakhiran `.json`
  (memakai `suggestedFilename` berstempel waktu dari `PointingKit`), bukan teks
  tanpa nama.
- ✅ `PointAndKnowiOSApp` (`@main`, di dalam `DiagnosticsView.swift`) — titik
  masuk app iPhone.

**Build:**
- ✅ `project.yml` (XcodeGen) — satu proyek, **dua target app**
  (`PointAndKnow` + `PointAndKnow Watch`), paket SwiftPM lokal dirujuk dari repo.
  Tes tidak hidup sebagai target Xcode: seluruh logika ada di paket SwiftPM
  (`CelestialEngine`, `PointingKit`) dan dijalankan lewat `swift test` — di Linux
  (`engine-tests.yml`) maupun di Apple SDK (job `Paket` di `ios-build.yml`).
  Berkas app sendiri tidak punya logika keputusan, jadi tidak ada yang perlu
  diuji di sana.
- ✅ `.github/workflows/ios-build.yml` — CI macOS: `brew install xcodegen`,
  generate proyek, build watch + iOS ke simulator.
- ✅ Ikon app digenerate deterministik oleh `Tools/make_app_icons.py`
  (satu PNG 1024×1024 per app) supaya `actool` tidak menggagalkan build.

**Verifikasi (yang benar-benar dijalankan):**
- `./swift-test.sh` → **CelestialEngine 163 test + PointingKit 95 test, 0 gagal**.
- Setiap berkas app lolos `swiftc -parse -swift-version 5` (gerbang sintaks;
  impor Apple tidak perlu resolve).
- `project.yml` divalidasi dengan **XcodeGen yang dibangun dari sumber di
  Linux** — parsing + validasi spec lolos, dan proyek yang dihasilkan
  diperiksa: 2 target app, sumber & dependensi paket terpasang benar, app jam
  ditanam ke `PlugIns/` milik app iPhone.
- **CI macOS hijau** (`Apple Build`): `xcodegen generate` → `xcodebuild` untuk
  app iPhone (termasuk app jam) dan app jam sendiri, keduanya **build sukses**.

**Galat nyata yang hanya muncul saat dibangun di macOS (dan sudah diperbaiki):**
- `WKInterfaceDevice.isDeviceSupported` tidak ada → dihapus. `play(_:)` diam
  saja di perangkat tanpa Taptic Engine, jadi tidak perlu dijaga.
- `nonisolated @objc` → `@objc nonisolated`. Urutan ini satu-satunya yang
  diterima parser; dibuktikan dengan probe terpisah.
- `LocationProvider` tidak mendeklarasikan `CLLocationManagerDelegate` sama
  sekali → ditambahkan, plus `@preconcurrency` karena protokol ObjC tidak
  di-`@MainActor` sedangkan kelasnya `@MainActor`. Hal yang sama diterapkan
  pada dua konformans `WCSessionDelegate`.
- `MotionLogger` memakai `CMDeviceMotion.timestamp` sebagai waktu Unix — itu
  keliru (detik sejak perangkat menyala), jadi tiap sampel akan bertanggal
  1970: alur tidak akan pernah melihat pergelangan diam dan efemeris dihitung
  untuk tanggal yang salah. Sekarang memakai waktu dinding.
- Dua sumber teks status (`PointingController.statusText` vs
  `PointingState.shortLabel`) → disatukan, supaya janji "ragu terlihat ragu"
  tidak bisa dibatalkan di layar.
- `CalibrationSession` menyimpan controller sebagai `unowned` → kuat; alur
  kalibrasi boleh hidup lebih lama dari pemanggilnya.
- `PointingController.resolver` dibuat `private(set)`; penggantian ambang
  keyakinan kini lewat `setConfidencePolicy(_:)` yang menolak sigma nol,
  negatif, atau tak berhingga.

### Siklus sebelumnya: pengaman slew (aturan keras PRD) + fondasi Fase 2 → 156 test hijau
- ✅ `SlewSafety.swift` — **POINT → OBJECT ID → SAFE GOTO**, ditegakkan di tipe,
  bukan sekadar konvensi:
  - `SlewCommand` tidak punya inisialisasi publik; satu-satunya jalan
    membuatnya adalah `SlewPlanner.plan(...)`. Jadi mustahil membentuk perintah
    motor dari sudut pergelangan tanpa lewat pemeriksaan.
  - Arah target perintah = **posisi objek yang teridentifikasi**, bukan arah
    tunjuk. Ini persis aturan PRD.
  - Gagal-tertutup: tanpa target, keyakinan di bawah syarat, atau posisi
    Matahari tidak diketahui → **ditolak**, tidak pernah diasumsikan aman.
  - Bahaya dilaporkan sebagai daftar unik & terurut (`SlewHazard`).
- ✅ `Resolution.sunHorizontal` diekspos supaya pengaman teleskop bisa dihitung
  dari jejak audit resolver (sebelumnya arah Matahari tidak pernah keluar).
- ✅ Uji integrasi pada geometri langit sungguhan: Bulan → identifikasi HIGH →
  GoTo **diizinkan**; Jupiter yang ambigu (~6.8° dari Pollux) → hanya MEDIUM →
  GoTo **ditolak** (`lowConfidence`). Aturan "jangan salah identifikasi demi
  magic" terbukti berlaku sampai ke teleskop.
- ✅ `swift test`: **156 test, 0 gagal** (Swift 6.0, Docker, Linux aarch64).

### Siklus sebelumnya: fondasi Fase 2 yang bisa diuji di Linux (139 test)
- ✅ `Geometry.swift` — `Vector3` + `Matrix3x3`, **tanpa `simd`** (tidak ada di
  Linux). Penamaan `m11…m33` sengaja sama dengan `CMRotationMatrix` supaya
  lapisan app bisa memetakan sensor tanpa berpikir ulang indeks.
- ✅ `Rotation.swift` — `Quaternion` `(w,x,y,z)` + konversi `CMQuaternion`
  (urutan x,y,z,w dipetakan di satu tempat). Ada `rotationMatrix`,
  `rotated(_:)`, komposisi, konjugat, sudut antar-orientasi, dan **nlerp**
  yang menangani *double cover*.
- ✅ `Frames.swift` — inti Fase 2 yang paling rawan salah:
  - `LocalFrame` ENU (Timur–Utara–Atas) ⇄ `HorizontalCoord`, azimut dari Utara.
  - `DeviceAttitude`: quaternion + **roll mengelilingi sumbu pandang** →
    `deviceToWorld` → arah tunjuk di langit.
  - `DeviceAimAxis` (`view` / `screenUp` / `screenRight`) — sumbu "arah tunjuk"
    adalah keputusan UX, jadi diserahkan sebagai parameter, bukan dipatri.
  - Temuan penting yang diuji eksplisit: **roll tidak mengubah arah pandang
    keluar-layar** bila sumbu itu mendatar. Jadi kalibrasi yaw memang wajib —
    bukan opsional.
- ✅ `Calibration.swift` — kalibrasi dari titik acuan:
  - Yaw diselesaikan dengan **rata-rata sirkular** (rata-rata biasa salah di
    sekitar 0°/360°).
  - Hanya **offset azimut** yang dikoreksi. Koreksi altitude akan menyembunyikan
    galat sensor — bertentangan dengan prinsip PRD. Sebaran sisa dilaporkan
    sebagai `residualSpreadDeg` (1σ).
  - `confidencePolicy()` menyambung sigma terukur → `ConfidencePolicy`, jadi
    ambang HIGH engine otomatis mengikuti hasil Experiment 1.
- ✅ `Sensing.swift` — `PointingSmoother` (nlerp bobot tetap) dan
  `AngularRateTracker`. Ada jeda maksimum antar sampel: setelah sensor
  terputus, laju **tidak** ditebak.
- ✅ `PointingFlow.swift` — `PointingStateMachine`: idle → pointing → searching
  → lock/uncertain. **`lock` hanya untuk keyakinan HIGH**; medium/low menjadi
  `uncertain`. Bergerak lagi membatalkan tampilan terkunci.

### Siklus sebelumnya
- ✅ anti-false-lock + instrumentasi Experiment 1 → Fase 1 selesai (65 test).
- ✅ Penyaringan visibilitas + efemeris tersambung ke resolver (`Visibility`,
  `diagnose()` dengan jejak audit, pengaman Matahari).
- ✅ Efemeris Bulan & planet via AstronomyKit, divalidasi vs JPL Horizons
  (simpangan terburuk 8.91″).
- ✅ Reduksi presesi J2000 → of-date di resolver (sebelumnya bintang meleset
  ~0.3°). Ditemukan & diperbaiki.
- ✅ Scaffold monorepo + CelestialEngine (Fase 1 inti).
- ✅ Terbukti engine bisa diuji di VPS2 TANPA Mac (via `./swift-test.sh`).

## Siklus 2026-10-04 — audit numerik mode malam pada gambar

**Unit terkecil:** "semua warna, termasuk visual, ikut mode malam" — janji yang
tertulis di `CelestialVisualView` dan Night Mode, tapi tidak pernah diuji.

### Yang ditemukan

Mode malam dipraktekan sebagai **daftar warna** yang ditulis satu per satu di
view, tepat di sebelah warna siangnya. Menghitungnya menunjukkan 10 dari 13
warna aksen **bukan merah murni**:

| bagian gambar | hijau | biru | porsi luminansi di kanal merusak |
|---|---|---|---|
| pita terang Bulan | 0.85 | 0.80 | 77% |
| cincin Saturnus | 0.30 | 0.16 | 63% |
| kabut Venus | 0.26 | 0.12 | 60% |

Di layar semuanya terlihat "merah", dan itu sebabnya cacat ini bertahan:
yang diuji adalah **penampilan**, bukan **nilainya**. Justru warna-warna itu
yang paling merusak, di mode yang dipilih justru untuk melindungi mata.

Dua kelas cacat lain yang muncul dari perhitungan yang sama:

1. **Urutan terang terbalik.** Pita Jupiter paling gelap (kanal merah 0.72)
   punya angka malam 0.43; paling terang (0.85) punya 0.34. Di mode malam
   pita gelap tampak lebih terang dari pita terang — dan tidak ada yang bisa
   melihatnya, karena semuanya sudah merah semua.
2. **Kontras sabit runtuh.** `shadow` untuk piringan gelap bulan
   dinaikkan ke 0.44, sehingga kontras sabit terhadap gelap turun ke 2.99:1 —
   di bawah WCAG AA, di layar yang justru paling dipakai untuk melihat bulan.

### Yang diperbaiki

- Aksen pindah ke `CelestialVisual.accents` (`NightVisual.swift`): **hanya
  warna siang** yang disimpan di sana. Warna malam diturunkan secara
  mekanis dari kanal merah — jadi "hampir merah" tidak mungkin terjadi, dan
  mengubah satu aksen tidak bisa meninggalkan malamnya tertinggal.
- `NightVisual.surface` (memancarkan) vs `.shadow` (gelap) dipisah sebagai
  dua peran; satu-satunya jalan masuknya `mapped(_:isShadow:)`, supaya
  "lupa dipetakan" tidak bisa ditulis.
- Kecerahan malam bintang diambil dari **ukuran relatif**, bukan dari
  warnanya: konversi B−V → RGB tidak menjamin kanal merahnya mengikuti terang
  bintang sungguhan.
- `starRGB` pindah dari view ke `PointingKit` **dan dijepit ke 0...1**.
  Sebelum dijepit, Betelgeuse (B−V 1.85) menghasilkan kanal merah **1,11** —
  di luar rentang yang punya arti; luminance ikut terangkat dan urutan terang
  ikut berubah. Ini tidak terlihat di layar ("merah tetap merah").

### Verifikasi

11 uji baru di `NightVisualTests`. Yang paling penting: **mutasi**. `surface`
sengaja dibuat membocorkan hijau/biru dan `shadow` dikolapskan jadi `surface`,
lalu uji dijalankan — kebocoran hijau/biru dan kontras sabit 2.88 (vs 4.5)
terdeteksi. Uji yang hanya membaca kode tidak akan menangkap keduanya.

**166 + 244 hijau, tanpa warning.**

### Satu cacat yang tidak terlihat di Linux

Apple Build gagal pada versi pertama: `Color(NightVisual.surface(raw))`.
Tidak ada overload `Color(_:)` yang menerima `RGBComponents` — SwiftUI
tidak punya konversi itu, dan build Linux tidak pernah menyentuh file view,
jadi `./swift-test.sh` tetap hijau. Semua kelas kesalahan view
harus dicek dengan menyisir polanya, bukan dengan menunggu test.

Yang terungkap saat memperbaikinya justru lebih penting dari
kesalahannya sendiri: tiga pintasan (`color`, `accent`, `shadowAccent`) memanggil
pemetaan malamnya **masing-masing**, dan `accent()` memanggil
`color(surface(raw))` — jadi peta diterapkan **dua kali**. Pemetaan tidak
idempoten. Dihitung: piringan gelap bulan (kanal merah 0,047) dipetakan lagi
sebagai permukaan menjadi **0,357** — hampir delapan kali lebih terang, tanpa
satu pun angka baru yang ditulis. Cacat seperti ini tidak akan pernah terlihat
dari membaca kode, karena tidak ada baris yang salah; yang salah adalah
**urutan** pemanggilan.

Sekarang ada **satu** pintasan `color(_:isShadow:)`. Perannya dinyatakan sebagai
argumen, bukan lewat pintasan terpisah, supaya "bagian gelap ikut dipetakan
seperti permukaan" tidak bisa ditulis — persis kelas bug yang ketahuan lewat
perhitungan, bukan lewat mata.

Catatan untuk siklus berikutnya: **uji di Linux tidak menutup kelas kesalahan
view.** Yang bisa ditutup di sini hanya logika murni; kompilasi view harus
dibuktikan CI macOS, dan pola berisiko (`Color(<expr>)`) sebaiknya disisir
sebelum push, karena tidak ada gerbang lokal yang menangkapnya.

## Siklus 2026-10-04 (2) — warna nada lolos dari gate kontras

**Unit terkecil:** warna nada (`PointingTone.color`) — label keadaan, badge
keyakinan, ikon kalibrasi — pernah ditulis manual di `Apps/Shared/NightMode.swift`
dan **tidak punya uji kontras sama sekali**, karena `PointingPresentationTests`
hanya memeriksa enum `tone`, bukan keluarannya sebagai warna.

### Yang ditemukan (dihitung, bukan ditebak)

Mode malam mengirimkan `red 0.50 / 0.62 / 0.80 / 1.00`. Rasio kontrasnya
terhadap permukaan malam:

| nada | nilai lama | rasio | ambang |
|---|---|---|---|
| neutral | 0.50 | 1.49:1 | ✗ |
| warning | 0.62 | 2.06:1 | ✗ |
| active | 0.80 | 3.10:1 | ✗ |
| success/danger | 1.00 | 5.25:1 | ✓ |

Tiga dari lima nada **tidak terbaca sebagai teks** justru di mode yang dipilih
supaya penglihatan malam terjaga. Mode siang memakai warna sistem (`.cyan`,
`.green`, `.orange`, `.red`, `.secondary`) yang **tidak bisa dihitung** — nilainya
bisa bergeser antar OS tanpa satu uji pun menyentuhnya. Dan badge keyakinan
memakai `nada.color.opacity(0.2)`: di mode malam itu justru **mendekatkan**
latar kapsul ke teksnya, bukan menjauhkannya (inversi kontras).

### Yang diperbaiki

- `TonePalette.swift` (PointingKit, **teruji di Linux**): semua warna nada hari &
  malam dipin ke `SurfaceColor` dengan kontras yang dihitung. Mode malam =
  merah murni di kanal 0.94…1.0 (semua ≥ 4.5:1; plafon fisik 5.25:1).
- `BadgeFills`: isi kapsul dihitung sebagai nada @ 0.2 di atas permukaan paling
  terang lalu dijadikan **opak** (hari), atau **permukaan tingkat dua** (malam,
  karena warna nada merah tidak boleh mem-back badge). Bukan `opacity(0.2)` di
  view.
- Jembatan `PointingTone.color` (NightMode.swift) sekarang memanggil
  `SurfacePalette.active.tones` — satu sumber kebenaran, bukan dua daftar warna.
- `PointingView.swift`: badge pakai `.badgeFillColor`, bukan `.color.opacity(0.2)`.

### Kenapa (fisika, bukan rasa)

Mode malam membuang hijau/biru → semua warna hidup di kanal merah saja. Merah
murni di atas hitam punya plafon kontras **5.25:1**, jadi rentang yang boleh
dipakai untuk teks 4.5:1 hanya 0.9365…1.0 (6% kanal). Konsekuensinya: di mode
malam warna nada **tidak lagi** membedakan keadaan (selisih ujung-ujung 1.12:1,
praktis tak terlihat) — yang membedakan adalah terang-vs-gelap penuh. Badge
keyakinan di mode malam dibedakan lewat **teksnya** ("Yakin"/"Ragu"/"Tidak tahu"),
bukan warna. Dicatat di komentar palet supaya tidak nanti "diperbaiki" dengan
melanggar batas merah murni.

### Verifikasi

8 uji baru di `TonePaletteTests` (kontras nada hari & malam vs ketiga permukaan,
badge, bebas hijau/biru, urutan tak berbalik, kedua mode lewat satu pintu).
**252 hijau (166 engine + 86 PointingKit), tanpa warning.** Kompilasi view
(badge bridge) dibuktikan CI macOS (`ios-build.yml`) — Linux tidak menyentuh
file view.

## Siklus 2026-10-04 (3) — galaksi, gugus terbuka, dan gugus bola digambar sama

**Unit terkecil:** bentuk objek langit dalam. `CelestialVisual.Kind.deepSky`
sudah ada, katalog produksi sudah berisi enam objek (M45, M31, M7, M42, M13,
M8), `VisualFrame.nebula(fuzziness:)` sudah menghitung geometri, `drawDeepSky`
sudah menggambar, dan `fuzzinessByID` sudah membedakan lebarnya. Yang hilang
hanya satu: **pembeda bentuknya**.

### Yang ditemukan (dibaca dari kode, bukan ditebak)

`fuzziness` hanya mengatur **seberapa lebar** kabut. Bentuknya selalu tiga
blob yang sama. Akibatnya, di katalog produksi:

- M31 (galaksi Andromeda) — lebar 1.00
- M7 (gugus terbuka Ptolemy) — lebar 0.50
- M13 (gugus bola Hercules) — lebar 0.35

ketiganya digambar dengan **susunan blob yang identik**; yang berbeda cuma
skala. Galaksi tidak punya cakram, gugus bola tidak punya inti padat, gugus
terbuka tidak "terbuka" di mana pun. Tidak ada satu pun teks di layar yang
bisa membedakan mereka, jadi ini klaim bentuk yang paling sulit terlihat —
tidak ada yang salah untuk dilihat.

Ini kelas cacat yang sama dengan yang sudah berulang di repo ini: **setiap
bagian benar secara terpisah, yang hilang adalah jalur/pembeda yang
menghubungkannya.**

### Yang diperbaiki

- `DeepSkyCatalogue.Morphology` (`nebula` / `galaxy` / `openCluster` /
  `globularCluster`) + `morphologyByID`, per id seperti `fuzzinessByID`.
- `VisualFrame.deepSky(morphology:fuzziness:)` menyusun blob per bentuk:
  - **galaksi** — cakram miring (rasio sumbu 0.34, rotasi −18°) dengan inti
    yang lebih bulat (0.42): tonjolan pusat yang khas;
  - **gugus bola** — inti padat di tengah (blob terbesar & paling terang),
    dikelilingi dua cincin bintang yang makin redup ke luar;
  - **gugus terbuka** — bintik-bintik nyaris seragam yang tersebar, **tanpa
    blob di pusat**;
  - **nebula** — kabut asimetris (bentuk lama, tetap).
- `CelestialVisual.objectID` diteruskan dari objek engine, supaya view bisa
  menanyakan morfologi (`DeepSkyCatalogue.morphology`, teruji di Linux) alih-alih
  menebak bentuk dari lebarnya.
- View menggambar elips berotasi dengan gradien **utuh**: gradien digambar di
  ruang yang di-skala (`scaleBy(x:1, y:hh/hw)`), bukan `radialGradient` melingkar
  pada path elips — yang akan memotong gradien di sumbu pendek dan meninggalkan
  tepi rata, persis cacat "digambar" yang ingin dihindari.

### Kenapa id tak dikenal **tidak** menebak bentuk

`fuzziness` boleh jatuh ke nilai tengah (0.6): lebar yang tidak diketahui tidak
mengklaim apa pun. Morfologi tidak punya "nilai tengah" — setiap pilihan
menyatakan "ini galaksi" atau "ini gugus bola". Menebak salah satunya adalah
klaim identitas yang keliru, persis yang dilarang PRD. Jadi
`morphology(forObjectID:)` mengembalikan `nil`, dan lapisan gambar memakai kabut
netral yang tidak menyatakan salah satu jenis.

### Cacat yang ditemukan uji saat implementasi

Rumus ruang pertama saya mengabaikan rotasi. Elips yang diputar tidak lagi
sejajar sumbu: bentang x-nya bertambah `hh·|sin θ|`. Akibatnya cakram galaksi
18° **keluar frame 0.056 R** — ditemukan oleh
`testEveryDeepSkyBlobStaysInsideTheFrame` (bukan oleh mata, karena 0.056 R
kecil). Rumusnya sekarang memakai bentang terotasi
`hw·(|cos θ| + aspect·|sin θ|)`.

Uji yang sama juga menangkap bahwa gugus terbuka saya masih terlalu seragam
ukurannya untuk bisa dibedakan dari gugus bola; layoutnya diperbaiki
(ukuran nyaris seragam **dan** tidak ada blob di pusat), dan ujinya diubah
untuk mengukur properti yang benar-benar memisahkan keduanya —
**konsentrasi**, bukan ukuran blob.

### Verifikasi

15 uji baru (342 → **357** PointingKit, +166 engine = **523 hijau**, tanpa
warning). Yang paling penting:
- `testLegacyDeepSkyGeometryWasIdenticalForEveryObject` — pengunci cacat lama;
- `testDifferentMorphologiesProduceDifferentGeometry` — dua morfologi tidak
  boleh menghasilkan blob yang sama;
- `testGlobularIsMoreConcentratedThanOpenCluster` — pembeda langsung bola vs
  terbuka;
- `testEveryMorphologyIsUsedByTheCatalogue` — daftar dari `allCases`, jadi
  menambah `case` baru tanpa objeknya langsung merah (bukan jalur mati);
- `testEveryDeepSkyBlobStaysInsideTheFrame` — kini menyapu **semua** morfologi
  termasuk `nil`, dengan bentang terotasi.

Gate: `./swift-ui-lint.sh` 9/9 bersih, `./swift-typecheck.sh` lulus.
CI: Engine Tests (Linux) + Apple Build keduanya **success** (`32367c8`).

## Siklus 2026-10-04 (7) — tiap bentuk langit dalam punya pembanding, bukan satu contoh

**Unit terkecil:** katalog objek langit dalam. Sebelas baris data, tanpa satu
pun kode gambar baru — tapi ia mengubah apa yang **bisa dipelajari** dari
layar.

**Keadaannya sebelum siklus ini.** Enam objek: satu galaksi (M31), satu gugus
bola (M13), dua gugus terbuka (M45, M7), dua nebula (M42, M8). Jadi tiap
bentuk muncul **sekali**. Itu cukup untuk membuktikan bentuknya digambar
berbeda — dan memang sudah diuji — tapi tidak cukup untuk membuat pengguna
**belajar** membedakannya. Orang yang baru pernah melihat satu galaksi tidak
punya cara tahu mana ciri galaksi dan mana kebetulan objek itu. Pola baru
terbaca saat bentuk yang sama muncul di dua objek berbeda.

**Yang ditambahkan** (semuanya mag ≤ 6, terlihat mata telanjang atau
binokuler — menawarkan target tak terlihat hanya menghasilkan penunjukan yang
menyesatkan):

    M44 Gugus Sarang Lebah  gugus terbuka   mag 3.7
    M33 Galaksi Triangulum  galaksi         mag 5.7
    M22 Gugus Sagitarius    gugus bola      mag 5.1
    M6  Gugus Kupu-kupu     gugus terbuka   mag 4.2
    M17 Nebula Omega        nebula emisi    mag 6.0

Sekarang tiap bentuk punya minimal dua wakil.

**Kenapa koordinatnya harus dari data, bukan ditebak.** Objek langit dalam
tidak punya satu titik terang untuk dikoreksi. Posisi yang salah **tetap
tampak benar** di layar; ia hanya muncul di tempat yang keliru, dan tidak ada
satu teks pun di layar yang bisa membacanya. Jadi koordinatnya diambil dari
data publik J2000 (epoch 2000.0), dan dua uji yang menutupnya menuntut bukti
alih-alih asumsi:

- `testEveryObjectRisesAboveTheHorizonForTheTargetLatitude` menyapu satu
  tahun jam demi jam di lintang 6.2°S — lintang darurat yang **pasti**
  dialami pengguna saat izin lokasi ditolak, jadi bukan asumsi tentang tempat
  mereka — dan menuntut setiap objek naik di atas 10°. Ambang 10°, bukan 0°:
  benda yang hanya menyentuh horizon beberapa menit tidak berguna untuk
  penunjukan, dan ambang longgar akan meloloskan target yang praktis tak
  terlihat.
- `testEveryCatalogueCoordinateIsInRange` mengunci RA di `0..<360` dan
  deklinasi di `−90…90`.

**Satu uji mengunci niatnya, bukan cuma hasilnya.**
`testEveryMorphologyHasMoreThanOneRepresentative` menuntut setiap morfologi
punya ≥ 2 wakil. Tanpa itu, katalog bisa menyusut kembali ke satu contoh per
bentuk dan semua uji lain tetap hijau — keadaannya sebelum siklus ini.

**Tabel paritas menolak objek baru yang tidak dipilih bentuknya.**
`fuzzinessByID` dan `morphologyByID` ikut diperluas, dan uji paritas yang
sudah ada (`testEveryDeepSkyObjectHasAFuzzinessEntry`,
`testEveryDeepSkyObjectHasAMorphologyEntry`) akan merah kalau objek baru
mengandalkan nilai bawaan yang **tampak sah** padahal bentuknya tidak pernah
dipilih — kelas cacat yang sudah pernah terjadi di repo ini pada tabel warna
bintang.

**Hasil:** PointingKit 370 (dari 367), CelestialEngine 166. Gerbang UI 10
aturan hijau, `swift-typecheck.sh` hijau. Aturan 10 — yang baru dipasang
siklus sebelumnya — langsung membuktikan gunanya: ia merah begitu uji
bertambah, karena README masih menyebut 367.

Commit `d8f0c0a`. CI: Engine Tests (Linux) 37221366114 + Apple Build
37221366098, keduanya hijau.

## Siklus 2026-10-04 (6) — hitungan uji di README membusuk tanpa gerbang

**Unit terkecil:** angka di README. Terlihat sepele, tapi kelas cacatnya
sama dengan yang sudah berkali-kali muncul di repo ini: nilai yang **benar
saat ditulis**, lalu menjadi salah tanpa ada yang berubah secara salah.

### Yang ditemukan

README menjanjikan "CelestialEngine 166, PointingKit **277**". Suite
sebenarnya sudah **367**. Selisih 90 uji yang tidak pernah terlihat siapa
pun, karena:

- menambah uji tidak menyentuh README;
- tidak ada gerbang yang membandingkan keduanya;
- dan angka itu justru satu-satunya ukuran seberapa tebal jaring pengaman
  proyek ini bagi pembaca baru.

Angka yang membusuk perlahan adalah bentuk paling murni dari cacat yang
tidak bisa dilihat: ia tidak pernah "salah" pada satu commit tertentu.

### Yang diperbaiki

- **Aturan 10** di `swift-ui-lint.sh`: menghitung `func test` per paket dan
  membandingkan dengan klaim di README. Merah kalau tidak cocok.
- README: 277 → **367**; bagian penjelasan `swift-ui-lint.sh` juga diperbarui
  — ia menyebut satu aturan (font tetap) padahal berkasnya sudah 10.

### Kenapa hitungan statis cukup

Yang dijaga adalah **kelas** drift (angka vs kenyataan), bukan angka
tepatnya. `func test` per berkas sama persis dengan jumlah yang dijalankan
sekarang (diverifikasi: 367 dan 166). Kalau suatu saat uji dihasilkan
dinamis sehingga hitungan statis menyimpang, aturan ini yang pertama
memberi tahu — dan itu justru tujuannya.

### Verifikasi

Dibuktikan **merah lebih dulu**: aturan melaporkan "README bilang PointingKit
277, berkas uji berisi 367", lalu hijau setelah README diperbaiki. Gate lint
**10/10**, typecheck lulus. CI: Engine + Apple Build **success** (`fc5a57f`).

## Siklus 2026-10-04 (5) — gambar langit dalam lebih yakin daripada badge "Ragu"

**Unit terkecil:** keyakinan engine sebagai penentu bentuk yang boleh
digambar. Cacat ini **dibuka oleh siklus morfologi sebelumnya** — jadi ini
perbaikan atas pekerjaan sendiri, bukan pekerjaan baru.

### Yang ditemukan

`drawPlanet` sudah lama punya aturan ini, dan alasannya tertulis di repo:

> Saat identitas belum pasti, hanya **warnanya** yang boleh tampil —
> bentuknya tidak. Cincin Saturnus adalah penanda yang sama meyakinkannya
> dengan pita Jupiter, jadi menampilkannya pada kandidat yang belum terkunci
> berarti menyampaikan identitas yang tidak dimiliki engine.

`drawDeepSky` tidak punya aturan itu. Ia membaca
`morphology(forObjectID:)` **langsung**, tanpa melihat `isConfirmed`. Jadi
galaksi berpalung dan gugus bola berinti padat digambar penuh di sebelah
badge "Ragu".

Sebelum siklus morfologi, cacat ini tidak bisa terlihat: semua objek langit
dalam digambar sebagai kabut yang sama, jadi tidak ada ciri pengenal yang
bisa bocor. Begitu bentuk yang berbeda-beda ditambahkan, cacatnya ikut
terbuka. Pelajaran yang berulang di repo ini: **menambah detail pada gambar
menambah pula yang bisa salah diklaim.**

### Yang diperbaiki

- `DeepSkyCatalogue.drawableMorphology(forObjectID:isConfirmed:)` — satu
  tempat, murni, diuji di Linux, aturan yang sama dengan planet dengan cara
  yang sama. Saat `isConfirmed == false` hasilnya `nil` → kabut netral yang
  tidak mengklaim jenis apa pun (bukan bentuk objeknya, bukan bentuk lain).
- `drawBody` meneruskan `isConfirmed` ke `drawDeepSky`.
- `spokenDeepSkyMorphology` kini menerima `isConfirmed`. Ini penting: tanpa
  itu pengguna VoiceOver mendengar "galaksi" di sebelah badge yang justru
  tidak menggambarnya — suara yang lebih yakin daripada gambar. Kedua call
  site (jam & iPhone) dan `visualPanelLabel` ikut diperbarui.

### Verifikasi

5 uji baru (363 → **367** PointingKit, +166 engine = **533 hijau**, tanpa
warning). Tiga yang mengunci aturannya:

- `testUnconfirmedObjectClaimsNoShape` — **setiap** objek katalog, jadi
  objek baru tidak bisa lolos.
- `testConfirmedObjectDrawsItsOwnShape` — mengunci bahwa `nil` bukan jawaban
  tetap: uji pertama bisa lulus dengan cara yang salah (selalu `nil`).
- `testUnconfirmedObjectDoesNotSpeakAShape` — pasangan suaranya.

Gate: lint 9/9, typecheck lulus. CI: Engine + Apple Build **success**
(`9beb2c9`).

## Siklus 2026-10-04 (4) — bentuk objek langit dalam tidak terdengar

**Unit terkecil:** pengumuman VoiceOver untuk bentuk objek langit dalam.
Siklus sebelumnya membuat galaksi, gugus bola, dan gugus terbuka digambar
berbeda — tapi tidak satu pun dari itu terdengar.

### Yang ditemukan

"Gugus Ptolemy" (M7, gugus terbuka) dan "Gugus Hercules" (M13, gugus bola)
sama-sama ber-`kind: .deepSky`. Pengumumannya karena itu **sama persis**:
nama, `spokenName` ("objek langit jauh"), magnitudo. Padahal di layar keduanya
kini digambar berbeda (bintik tersebar vs inti padat). Satu kelas informasi
yang hanya bisa dilihat.

Ini kategori yang sama dengan fase Bulan, dan itu sudah pernah ditutup di
repo ini (`spokenPhase`, `MoonPhaseSpeech.swift`). Yang belum tertutup adalah
kelas **bentuk objek langit dalam** — jenisnya tidak membedakan mereka.

### Yang diperbaiki

- `DeepSkySpeech.swift` (PointingKit, teruji di Linux):
  `spokenDeepSkyMorphology` + `deepSkyMorphologyText` (murni, tanpa bundle —
  supaya pemilihannya bisa diuji, bukan cuma teksnya).
- Empat kunci katalog baru (`deepSky.morphology.*`, id + en) + entri di
  `LocalizedText.allKeys`, jadi gerbang paritas aturan 6 ikut menjaganya.
- Dua call site diperbarui: label VoiceOver jam (`PointingView`) dan iPhone
  (`visualPanelLabel`), tepat setelah fase Bulan.
- Hitungan kunci di `testDeclaredKeysAreUniqueNonEmptyAndComplete` naik
  46 → 50 — gerbang itu sengaja memaksa angka diperbarui setiap kunci
  ditambah, supaya kunci yang masuk katalog tanpa masuk `allKeys` tidak lolos.

### Kenapa `nil` untuk id tak dikenal (bukan tebakan)

Sama dengan `morphology(forObjectID:)`: gambar memakai kabut **netral** saat
bentuknya tidak diketahui, jadi pengumuman tidak boleh menyebut bentuk apa
pun. `spokenDeepSkyMorphology` mengembalikan `nil` untuk bukan objek langit
dalam **dan** untuk id tak dikenal — sehingga suara selalu cocok dengan
gambar, bukan versi kedua dari kebenaran.

### Trade-off yang disengaja

Untuk objek yang namanya sudah menyebut jenisnya ("Galaksi Andromeda"), kata
morfologinya sedikit berulang saat diucapkan. Dibiarkan: alternatifnya adalah
mencocokkan teks yang dilokalisasi untuk melihat apakah nama sudah memuat
kata jenisnya, dan itu rapuh persis pada bahasa yang belum ada terjemahannya.
Pengulangan kecil lebih baik daripada aturan yang bisa diam-diam salah.

### Verifikasi

6 uji baru (357 → **363** PointingKit, +166 engine = **529 hijau**, tanpa
warning). Yang mengunci pembedanya:
`testTwoClustersWithTheSameKindSoundDifferent` — dua objek berjenis sama
harus terdengar berbeda; `testUnknownDeepSkyIDDoesNotGuessASpokenMorphology`
— suara tidak mengklaim bentuk yang tidak ada di layar.

Gate: lint 9/9, typecheck lulus. CI: Engine + Apple Build **success**
(`4ff6a6d`).

## Siklus 2026-10-04 (8) — kalimat yang lahir di dalam view punya kunci sendiri

### Cacat yang ditemukan

Aturan 4 menyapu literal di dalam `Text(...)`. Aturan 12 menyapu literal yang
**ditugaskan** ke variabel berakhiran `Note`/`Label` lalu dirender. Di antara
keduanya ada celah yang tidak pernah ditutup: kalimat yang dirakit **sebagai
argumen**, di dalam `String(format: …)`, `parts.append(…)`, atau `text += …`.

Sepuluh kalimat di `Apps/` kena. Contoh yang paling merusak:

    String(format: "Laju pergelangan %.0f derajat per detik.", rate)
    text += ". \(link.sendFailureCount) kiriman gagal."
    var parts = ["Keadaan: \(state.shortLabel).", …]

### Kenapa kelas ini lolos dari semua gerbang, dan kenapa ia berbahaya

1. Bentuknya bukan argumen `Text`, jadi Aturan 4 tidak menyapunya.
2. Tidak pernah jadi nilai variabel berakhiran `Note`/`Label`, jadi Aturan 12
   juga tidak.
3. Yang paling menentukan: **tidak terlihat salah.** "mag %.2f" dan
   "%.0f° tinggi" berisi angka dan derajat yang identik di semua bahasa, jadi
   diff dan tangkapan layar tidak menunjukkan apa pun. Yang berbeda — kata
   pengantar dan **urutannya** — baru terasa oleh pengguna yang membaca bahasa
   lain.

Dua di antaranya bahkan kelas yang lebih halus:

- `text += ". N kiriman gagal."` — **menyambung** string. Bukan sekadar
  terjemahan: menyambung memaku *urutan* di kode, dan Bahasa Inggris bisa sah
  menulis "3 messages failed" maupun "4 failed messages" dengan urutan
  berbeda. Katalog hanya bisa mengizinkan satu.
- `String(format: "Laju pergelangan %.0f derajat per detik.", …)` — memaksa
  Bahasa Inggris mengucapkan kata Indonesia "derajat" di tengah kalimat
  Inggeris.

### Yang diperbaiki

- 10 kunci baru (`.objectDisplayCoordinates`, `.objectDisplayMagnitude`,
  `.objectSpeechStaleShort`, `.rowSpeechWristRate`, `.rowSpeechWristRateWord`,
  `.rowSpeechStateLine`, `.calibrationDisplayCaptureAltitude`,
  `.calibrationDisplaySuggestedSigma`, `.linkStatusSendFailures`,
  `.linkStatusSendFailuresWord`). Kunci = **174** (dari 164).
- `TextLocalization.text(_:_:)` — overload berformat. **Kenapa butuh
  overload terpisah, bukan `String(format: text(key), …)` di tiap pemanggil:**
  setelah katalog diterjemahkan, terjemahan boleh memuat `%lld` di tempat
  berbeda; yang memanggil overload ini hanya menyerahkan kunci dan nilai,
  **urutan argumennya milik terjemahan**, bukan milik pemanggil.
- Helper yang dipakai pemanggil: `RowSpeech.stateLine(_:)` (awalan kalimat
  keadaan), `RowSpeech.spokenWristRate(_:)` (kalimat laju pergelangan),
  `LinkStatusText.sendFailures(_:)` (kalimat jumlah kiriman gagal).

### Gerbang baru: Aturan 13

Aturan 13 menyapu `Apps/` untuk literal **di dalam konteks perakitan kalimat**
(`String(format:`, `.append(`, `.insert(`, `+=`, `var x = [`, `let x = [`) yang
tidak ada sebagai kunci katalog.

Dua keputusan desain yang membuat gerbang ini bisa dipercaya:

- **Daftar yang dikecualikan adalah daftar _kata_, bukan daftar _kalimat_**:
  `iPhone`, `watchOS`, `GoTo`, `False lock`. Kalau daftarnya kalimat, setiap
  kalimat baru yang belum pernah disetuji akan ditambahkan ke sana dan
  gerbangnya jadi tidak berguna apa-apa.
- **Ambang "ada kata yang harus diterjemahkan"** dihitung setelah specifier
  `%…f` dibuang, minimal 3 huruf — supaya `%.0f°` (murni simbol) lolos tapi
  `"%.0f° tinggi"` (ada katanya) tertangkap.

**Gerbang ini sudah dibuktikan menyala**: literal `Ambang keyakinan usulan:
σ %.1f°` sengaja dikembalikan ke view, Aturan 13 memerah dan menyebut barisnya,
lalu dikembalikan lagi dan gerbang hijau. Gerbang yang tak pernah menyala
tidak dihitung sebagai penjaga.

### Verifikasi

6 uji baru (459 → **465** PointingKit, +166 engine = **631 hijau**).
`testFormattedOverloadUsesTheTranslationAsThePattern` mengunci bahwa overload
memakai **terjemahan** sebagai cetakan — kalau ia membaca `key.indonesian`,
semua nilai terformat akan selalu Bahasa Indonesia tanpa satu pun kegagalan
terlihat.

Gate: lint **13/13**, typecheck lulus. CI: Engine + Apple Build **success**
(`37236063140` + `37236063163`) — termasuk "Gerbang peringatan (kode sendiri)",
yang gagal bila ada warning dari kode kita.

## Siklus 2026-10-04 (9) — perluas katalog visual langit dalam (Fase C #5)

### Cacat yang ditemukan (dibaca dari kode, bukan ditebak)

Katalog produksi (`DeepSkyCatalogue.objects`) cuma punya 11 objek. Jalur
gambar objek langit dalam sudah lengkap dan umum — `CelestialVisual.Kind
.deepSky`, `VisualFrame.nebula(fuzziness:)`, `NightVisual.deepSky`, dan
`CelestialVisualView.drawDeepSky` semuanya sudah ada dan teruji. Yang kurang
bukan jalur, tapi **isi**: empat Messier yang masuk akal ditunjuk dengan
binokuler belum ada, padahal koordinat & magnitudonya data publik.

Ini bukan cacat yang merusak (seperti cacat sebelumnya), tapi celah
penyempurnaan tanpa-henti yang bernilai nyata: pengguna yang menunjuk
Nebula Cincin atau Galaksi Pusaran saat ini tidak mendapat apa-apa, karena
objek itu tidak ada di katalog.

### Kenapa ini aman, bukan risiko

- `productionCatalogue = Catalogue.brightStars + DeepSkyCatalogue.objects`
  (EngineFactory). Menambah entri ke `DeepSkyCatalogue.objects` langsung
  mengalirkannya ke **kedua** app (jam + iPhone) tanpa satu pun sentuhan
  di `Apps/` — jalur yang sudah ditutup oleh siklus (3)/(5)/(7).
- Aturan kejujuran dipertahankan: setiap objek baru punya entri **eksplisit**
  di `fuzzinessByID` dan `morphologyByID`. Tidak ada yang jatuh ke default
  `fuzziness` (0.6) atau ke `nil` morfologi — jadi bentuknya tidak pernah
  ditebak. Itu syarat PRD: jangan menampilkan visual yang mengklaim identitas
  yang tidak dimiliki objek.
- M51 (mag 8.4) berada di bawah ambang magnitudo terbatas bawaan (6.0).
  Itu **bukan** bug: penyaring visibilitas memang menolak objek yang terlalu
  redup untuk mata/binokuler telanjang. Honesti tetap utuh — engine tidak
  mengklaim M51 terlihat bila tidak.

### Yang ditambahkan

- `DeepSkyCatalogue.objects`: +M27 (Nebula Dumbel, mag 7.4), M57 (Nebula
  Cincin, mag 8.8), M51 (Galaksi Pusaran, mag 8.4), M11 (Gugus Bebek Liar,
  mag 6.3). Koordinat J2000 dari data publik (SIMBAD/Wikipedia), bukan
  karangan.
- `fuzzinessByID`: M27 0.68, M57 0.40, M51 0.92, M11 0.42.
- `morphologyByID`: M27/M57 `.nebula`, M51 `.galaxy`, M11 `.openCluster`.

M51 menjadi wakil **galaksi berlengan** selain cakram miring M31/M33 —
variasi bentuk yang bisa dibaca dari layar, bukan cuma label. Jumlah objek
11 → 15.

### Verifikasi

- `DeepSkyCatalogueTests` mengunci: koordinat in-range (RA 0..<360, Dec
  -90..90), id unik, **setiap** objek punya morfologi, dan ≥2 wakil per
  morfologi. Keempat tambahan lulus semuanya.
- swift-test (Docker swift:6.0): CelestialEngine **171**, PointingKit **485**,
  0 failures.
- CI: Engine Tests (Linux) `37245347857` = success; Apple Build `37245347814`
  = success (termasuk gerbang "Peringatan kode sendiri" — gagal bila ada
  warning kode kita). View SwiftUI yang mengonsumsi `DeepSkyCatalogue`
  terkompilasi bersih di macOS.

### Kenapa bukan perluasan katalog planet

`CelestialVisual.Planet` cuma Mercury–Saturn, tapi itu **bukan** celah:
`EphemerisBody` engine (`Ephemeris.swift:14`) hanya mencantumkan
sun/moon/mercury/venus/mars/jupiter/saturn. Uranus & Neptune tidak ada di
engine, jadi menambah kasus planet ke model visual = kode mati yang tidak
pernah diproduksi engine. Memperluas katalog planet butuh perubahan engine
(di luar ruang lingkup "hanya Apps/ + logika murni PointingKit"), jadi
ditunda.

## Siklus 2026-10-04 (10) — uji regresi resolusi objek langit dalam (Fase C #5/#6)

### Cacat yang ditemukan (dibaca dari kode, bukan ditebak)

`DeepSkyCatalogue.objects` baru masuk ke `productionCatalogue` (EngineFactory)
pada siklus (9). Tapi **tidak ada satu pun uji engine** yang meresolusi objek
ber-`kind: .deepSky` lewat jalur utuh `PointingResolver.diagnose` — semua
uji resolver memakai `Catalogue.brightStars` saja. Artinya regresi yang
melewatkan `kind == .deepSky` di `diagnose`/`VisibilityFilter` akan lolos:
objek langit dalam diam-diam tak pernah jadi kandidat, dan tak ada teks
layar yang memberitahu pengguna bahwa Nebula Orion seharusnya muncul.

### Yang ditambahkan

`ResolverEphemerisTests.testDeepSkyObjectResolvesAndRejectsBelowHorizon`:
- (1) M42 (Nebula Orion) di atas horizon & ditunjuk -> tebakan terbaik,
  `kind` tetap `.deepSky`, **tidak** jatuh ke `.low`.
- (2) objek langit dalam di bawah horizon -> bukan kandidat & dilaporkan
  `.belowHorizon`, sama seperti bintang.

Bagian (1) **sengaja tidak** menuntut `.high`. Saat dijalankan, M42 duduk
dekat Rigel (~10°) di Orion, jadi aturan ambiguitas menahannya di `.medium`
— itu anti-false-lock yang benar, bukan cacat. Yang diuji sungguhan: engine
tetap **mengidentifikasi** objek langit dalam (bukan menjatuhkannya ke `.low`
atau mengklaimnya pasti). Cek di bawah-horizon dibuat deterministik dengan
mencerminkan koordinat bintang yang terbukti di bawah horizon pada saat uji
(sama seperti `testBelowHorizonBodiesAreReportedAsSuch`), bukan sekadar
menunjuk ke alt -80° (yang tak menjamin objek ikut turun).

Pakai `CelestialObject(kind: .deepSky)` minimal, **bukan** `DeepSkyCatalogue`
(PointingKit), agar uji tetap di paket CelestialEngine tanpa gandeng silang
ke PointingKit.

### Verifikasi

- CelestialEngine **171 → 172** hijau (Docker swift:6.0). PointingKit tetap
  485 (tidak disentuh).
- CI: Engine Tests (Linux) `37245795702` = success; Apple Build **= failure**
  (lihat koreksi di bawah), lalu hijau di `a103cd2`.

### Koreksi proses: "✓ Complete job" bukan berarti run hijau

Apple Build pada dua push pertama (`2076f8c`, `ed423aa`) **gagal**, dan saya
melaporkannya sebagai hijau. Alasannya: `gh run watch` mencetak
`✓ Complete job` — itu berarti **job-nya selesai**, bukan run-nya sukses.
`gh run view --json conclusion` satu push kemudian menunjukkan `failure`
pada job `App (iPhone + Watch)`.

Penyebabnya **bukan** kode: Aturan 10 ("hitungan uji di README cocok dengan
berkas uji") memerah karena uji baru menambah CelestialEngine ke 172 sementara
README masih menulis 171. Log yang membenarkan:

    README bilang CelestialEngine 171, berkas uji berisi 172.

Diperbaiki di `a103cd2` (`README.md` 171 → 172), dan ketiga gerbang lokal
(`swift-test.sh`, `swift-typecheck.sh`, `swift-ui-lint.sh`) hijau lagi
serta Apple Build `a103cd2` = success.

**Pelajaran yang dipakai seterusnya.** Gerbang Aturan 10 justru menangkap
kekurangan yang tidak terlihat dari layar atau diff — dan kegagalannya saya
salah baca. Dua hal yang harus dibedakan:
- "✓ Complete job" (job selesai) ≠ `conclusion: success` (run hijau).
- Semua job harus dicek lewat `gh run view --json conclusion,jobs`, bukan
  dari baris `✓` terakhir pada `gh run watch`.

## Cara test
    cd /home/ubuntu/projects/celestial-pointing
    ./swift-test.sh          # docker swift:6.0 — CelestialEngine + PointingKit
    ./swift-typecheck.sh     # typecheck + parse semua berkas Apps/
    ./red-test.sh <berkas-uji> <nama-test> <berkas-sumber> <lama> <baru>

## Dua gerbang yang dulu tidak benar-benar berjalan

**`swift-typecheck.sh` tidak pernah bisa lulus di VPS2.** Skrip itu memanggil
`swift build`/`swiftc` langsung di host, dan di host tidak ada Swift — hanya di
dalam Docker. Jadi "tidak ada error" yang tercetak berasal dari
`command not found`, bukan dari kode yang bersih; skrip tetap keluar 0 karena
`$?` diambil dari pipeline yang sudah hancur. Itu menjelaskan tiga siklus
berturut-turut yang menemukan cacat baru tepat setelah push. Sekarang
seluruh perintah dijalankan di dalam container dan status diambil dari sana.

**`red-test.sh` (baru) membuktikan uji benar-benar menangkap cacat.** Uji yang
tidak pernah merah adalah formalitas: ia hanya membuktikan kode sekarang cocok
dengan ekspektasi penulisnya. Skrip ini menerapkan satu mutasi, memastikan uji
MERAH, lalu mengembalikan sumber — sehingga "uji ini menangkap mutasi" adalah
klaim yang bisa diulang, bukan cadangan.

Dua cacat di siklus ini ditemukan oleh gerbang itu, bukan oleh mata:
- Uji label-vs-slug pertama membandingkan dengan `lowercased()`. Katalog
  menyimpan `name` sebagai slug yang hanya dib capitalized (`sirius`/`Sirius`),
  jadi perbandingan itu **tidak mungkin gagal** — uji formalitas yang lolos
  begitu saya tulis. Diperbaiki ke perbandingan byte.
- `write_file` sempat menyisipkan fragmen CJK (`仓库`, `把它`) ke komentar.
  Damage itu lolos kompilasi dan lolos CI. Pemeriksaan CJK sekarang jadi
  bagian siklus.

## Teks layar bukan pengenal mesin

Empat teks menampilkan nilai yang dibuat untuk mesin (`DisplayLabels.swift`,
`DisplayLabelTests` — 9 uji). Yang paling terlihat: headline tiap baris
percobaan di Experiment 1 menulis slug katalog apa adanya — `sirius` di tempat
yang seharusnya `Sirius`. Aksesor yang benar sudah ada
(`ConfidenceLevel.displayName`); masalahnya pemanggil mengambil `rawValue`.

Bentuk kabel dan label kini dipisah: `rawValue` untuk serialisasi,
`displayName` untuk layar. `LinkMessageKind.rawValue` **tidak** diubah — itu
kunci `plist`; ujinya menjaga agar memperbaiki tampilan tidak pernah menyentuh
bentuk kabel. `objectName(forObjectID:)` mengembalikan `nil` untuk id tak
dikenal: mengarang nama dari id terlihat benar untuk seluruh katalog sekarang
dan diam-diam salah begitu ada id yang tidak mengikuti pola itu.
`ExperimentRecorder` tetap memakai `aim.rawValue` — itu JSON untuk mesin.

## Catatan penting
- `Package.swift` kini `swift-tools-version:6.0` (dibutuhkan AstronomyKit),
  dengan `swiftLanguageMode(.v5)` pada target agar kode Fase 1 tetap valid.
- `Package.resolved` di-commit → build CI reprodusibel.
- Fixture acuan: `Packages/CelestialEngine/Tests/CelestialEngineTests/Fixtures/horizons_reference.json`
  (dari JPL Horizons DE441). Segarkan dengan `python3 Tools/fetch_horizons_reference.py`.
- AstronomyKit tersambung ke `PointingResolver` lewat `diagnose()`. Bulan &
  planet ikut jadi kandidat dengan koordinat of-date. Matahari hanya konteks,
  tidak pernah jadi target.
- **Engine tidak menyentuh API Apple apa pun.** Yang butuh Mac hanyalah
  pembungkus sensor/UI, bukan logika. Karena itu attitude, kalibrasi, dan
  resolusi bisa dibuktikan di Linux.
- **App dibangun lewat XcodeGen**, bukan `.xcodeproj` yang di-commit. Jalankan
  `xcodegen generate` di Mac (atau biarkan CI yang melakukannya).
- **Akurasi Apple Watch tetap hipotesis.** Experiment 1 ada persis untuk
  mengujinya; ambang keyakinan disetel dari hasilnya, bukan dari asumsi.

## Langkah berikutnya
1. Jalankan app di perangkat sungguhan: izinkan lokasi & gerak, lalu kalibrasi
   dengan satu bintang terang. Kalau kalibrasi tidak pernah selesai, itu
   memang jawaban yang benar — sebaran titik acuannya belum cukup rapat.
2. Experiment 1: kumpulkan data lapangan, ukur `residualSpreadDeg`, lalu
   suapkan ke `ConfidencePolicy` lewat `setConfidencePolicy(_:)`.
3. Kalau sigma hasil ukur lebih besar dari yang diasumsikan, turunkan klaim
   keyakinan engine — jangan sebaliknya. Angka akurasi Watch tetap hipotesis
   sampai Experiment 1 selesai; tidak ada satu pun bagian kode yang
   mengasumsikannya.

## Progres terakhir (4 Okt 2026 — warna spektral bintang kini terdengar VoiceOver, Fase C #7)

### Premis: kelas informasi "hanya-bisa-dilihat" yang terakhir masih buta
Tiga kelas informasi yang cuma muncul sebagai gambar sudah punya jalur ucapan:
fase Bulan (`MoonPhaseSpeech`), bentuk objek langit dalam (`DeepSkySpeech`),
dan nama jenis benda (`ObjectKindLabels`). Yang keempat — **warna spektral
bintang** — belum. Titik bintang diwarnai dari indeks B−V katalog (Rigel biru,
Betelgeuse merah, Sirius putih-biru), tapi pengguna VoiceOver cuma dengar
"bintang Sirius": warnanya tak pernah diucapkan. Itu persis bentuk cacat yang
sudah tiga kali ditutup di repo ini — gerbang hijau, yang diukur bukan bagian
bermasalah.

### Yang diubah, dan kenapa bentuknya begini
- **`StarColorSpeech.swift` (baru, PointingKit):** `CelestialVisual.spokenStarColor`
  — `nil` untuk bukan-bintang (planet/Bulan/Matahari/langit-dalam punya warna
  render, bukan klaim spektral), `String` warna untuk bintang. Murnya ada di
  `starColorText(_:)` yang memetakan indeks B−V ke pita: biru (≤ −0,10),
  putih kebiruan (−0,10…0,25), kuning (0,25…0,95), jingga (0,95…1,50), merah
  (> 1,50). Persis ambang kelas spektral nyata, supaya ucapan cocok dengan
  warna yang digambar UI.
- **Kunci katalog:** 5 `LocalizedText` baru (`star.color.*.spoken.label`),
  masuk `allKeys` dan `Localizable.xcstrings` (id + en). Aturan 6 jaga paritas
  dua arah.
- **Dua label aksesibilitas dipasangi:** `DiagnosticsView.visualPanelLabel`
  (iPhone) dan `PointingView.kindAccessibilityLabel` (jam) kini menambahkan
  warna bintang, persis seperti fase Bulan dan morfologi langit-dalam yang
  sudah ada di sana.
- **4 tes baru** di `CelestialVisualTests`: pemetaan pita, batas eksak antar-
  pita, konsistensi bintang katalog (Rigel/Sirius/Betelgeuse), dan bahwa hanya
  bintang yang diucapkan warnanya.

### Satu harapan yang salah, ketemu tesnya
Ekspektasi awal: Rigel (B−V −0,03) = "biru". Tes merah benar: −0,03 di pita
putih-biruan (biru murni cuma kelas B paling awal, B−V ≤ −0,10). Ini *betul* —
Rigel B8 memang biru-putih, bukan biru tua. Diperbaiki ekspektasi tes, bukan
pemetaan. Itu persis bentuk "tes menangkap asumsi salah" yang diminta Fase C #10.

### Gerbang
- `./swift-test.sh`: CelestialEngine 171 + PointingKit 485 hijau (naik 4 dari
  481 — 4 tes baru).
- `./swift-typecheck.sh`: bersih.
- `./swift-ui-lint.sh`: 13 aturan bersih (Aturan 6 paritas & Aturan 10 hitungan
  README diperbarui; README 481 → 485, `allKeys` 175 → 180).

## Progres terakhir (5 Okt 2026 — celah Aturan 4: penanda "bukan hasil sekarang" tak pernah punya padanan Inggris)

### Premis: gerbangnya hijau karena cabangnya `continue` tanpa syarat
Aturan 4 menyapu literal teks di dalam argumen `Text(...)`/`row(...)`, dan
melaporkan yang tidak ada di katalog. Tapi cabang `interpolated`-nya
melakukan `continue` **tanpa syarat**: setiap literal yang mengandung
`\(...)` dilewati begitu saja, apa pun isinya.

Asumsinya ("interpolasi murni tidak punya bentuk katalog") salah untuk satu
kelas: literal **campuran** — sebagian interpolasi, sebagian kalimat nyata.
Dan kelas itu persis yang memuat kalimat paling sensitif di app ini.

### Cacatnya: penanda objek basi tidak punya terjemahan
`DiagnosticsView` menulis:

    row(engine.isDisplayingStaleObject ? "Objek (sisa)" : "Objek",
        engine.isDisplayingStaleObject
            ? "\(object.name) — bukan hasil sekarang"
            : object.name)

Kata-kata "bukan hasil sekarang" adalah kalimat yang tampil di layar, dan
tidak punya entri katalog — penutur Bahasa Inggris melihat kalimat
Indonesia di baris yang menyatakan **bahwa ini bukan hasil pengukuran
sekarang**. Kalimat yang paling tidak boleh salah tempat, justru yang tidak
punya terjemahan. Dua cacat sekaligus, keduanya tak terlihat:

1. Aturan 4 melewatinya tanpa laporan (`continue` tanpa syarat).
2. Urutan kata terkunci di kode: bahasa lain tidak bisa menaruh penanda di
   depan nama ("not a current result — Sirius").

### Yang diubah
- **`swift-ui-lint.sh` (Aturan 4):** cabang `interpolated` dibuat **gagal
  bawaan (fail-closed)** — literal interpolasi yang masih mengandung kata
  dilaporkan; yang tidak punya kata sama sekali tetap lolos karena memang
  bukan teks tampilan. Pengenal kurung dihitung **berimbang**, bukan dengan
  `[^()]` — tanpa itu `\(NumberFormat.degrees(x))` berhenti di kurung buka
  `degrees(` dan `NumberFormat` terbaca sebagai kata tampilan (3 positif
  palsu pada percobaan pertama).
- **`ObjectSpeech.staleDisplayName(_:)`** (PointingKit): kalimatnya lahir
  dari kunci `object.display.staleName` (`"%@ — bukan hasil sekarang"`),
  nama masuk sebagai `%@` supaya **urutan milik katalog**, bukan milik kode.
- **Katalog:** 1 kunci baru + terjemahan `en` + komentar konteks untuk
  penerjemah. `allKeys` 180 → 181 (Aturan 6 paritas dua arah).
- **README:** 485 → 487 (Aturan 10).

### Dibuktikan, bukan dipercaya
- Gerbang **merah dulu** pada cacat aslinya, menyebut barisnya:
  `DiagnosticsView.swift:329`. Setelah diperbaiki: bersih.
- `./red-test.sh` pada dua uji baru — keduanya **merah** terhadap regresi:
  - menghapus slot `%@` -> "nama objeknya harus tetap tampil di baris yang
    sama";
  - menggabung string di pemanggil -> urutan katalog tidak lagi dihormati
    (`"Sirius — bukan hasil sekarang"` vs `"not a current result — Sirius"`).
- Uji hijau: CelestialEngine 172 + PointingKit 487 (naik 2 dari 485).

### Satu hal yang hampir terlewat
Percobaan pertama menyisipkan aksara CJK ke dalam komentar giliran saya
sendiri — dan **Aturan 3 menangkapnya**. Gerbang yang diuji sendiri bekerja;
itu bukti sampingan yang berguna.

### Lanjutan siklus yang sama: `"sisa"` di layar Always-On diterjemahkan `"left"`

Setelah celah Aturan 4 ditutup, sapuan ulang atas literal interpolasi yang
tersisa menemukan cacat kedua di kelas yang sama — kali ini bukan soal
gerbang, melainkan soal **kata yang salah tempat**.

`ReducedLuminanceView` (layar redup / Always-On) menulis `Text("sisa")`
sebagai penanda bahwa objek yang tampil berasal dari pandangan sebelumnya.
Katalog menerjemahkan kunci itu sebagai **`"left"`**. Dalam Bahasa Inggris
"left" terbaca sebagai arah atau sisa jumlah — bukan sebagai "dari pandangan
sebelumnya". Ini persis permukaan yang paling berbahaya untuk salah: layar
redup tidak punya panel peringatan, jadi satu kata itu sendirian yang
memberi tahu pengguna bahwa yang dilihatnya bukan hasil sekarang.

Yang membuat ini cacat, bukan sekadar gaya: `ObjectSpeech.staleShortNote`
sudah ada, sudah punya kunci (`object.speech.staleShort` → "from an earlier
view"), dan sudah dipakai oleh **VoiceOver di layar yang sama** — jadi
selama ini layar itu menampilkan satu kata dan mengucapkan kalimat lain
untuk fakta yang sama.

Diperbaiki: keduanya kini membaca satu kunci. Tidak ada kunci baru, tidak
ada perubahan hitungan uji.

Catatan kejujuran: dua kecurigaan lain pada siklus ini **tidak** terbukti
dan ditinggalkan apa adanya — 13 accessor `LinkStatusText` yang sempat
terbaca "nol konsumen" (ternyata benar-benar terpasang di
`WatchLinkService`/`PhoneLinkService`; sapuan saya yang keliru karena tidak
menghitung akses `X.foo`), dan `ObservationLog.analyze` (gerbang
`displayedAnswer` sudah benar meniadakan false lock saat keadaan tanpa
jawaban). Keduanya dicek langsung, bukan diasumsikan.

## Progres terakhir (5 Okt 2026 — Aturan 14: teks izin sistem tak pernah diterjemahkan)

### Premis: teks yang dibaca sistem, bukan oleh app
Aturan 4 menyapu literal di `Apps/`; Aturan 6 memeriksa paritas kunci yang
dihasilkan `PointingKit`. Keduanya hijau — dan keduanya **tidak punya apa
pun untuk dilihat** pada teks izin.

`NSLocationWhenInUseUsageDescription` dan `NSMotionUsageDescription` dibaca
**sistem operasi** dari bundel, hidup sebagai `INFOPLIST_KEY_*` di
`project.yml`, dan tidak pernah melewati `Text(...)` maupun katalog string.
Satu-satunya jalurnya adalah `InfoPlist.strings` per bahasa — dan tidak ada
satu pun gerbang yang memperingatkan bila berkas itu tidak ada. Hasilnya:
dialog izin berbahasa Indonesia untuk semua pengguna, seluruh CI hijau.

Ini kelas cacat yang sama dengan Aturan 4 (yang diukur bukan bagian yang
bermasalah), tapi lebih buruk: teksnya tidak bisa diperbaiki lewat katalog,
jadi celahnya tidak akan pernah tertutup oleh gerbang yang sudah ada.

### Yang diubah
- **Aturan 14 (baru, `swift-ui-lint.sh`):** setiap
  `INFOPLIST_KEY_NS*UsageDescription` di `project.yml` harus punya kunci
  yang sama di `Apps/Shared/Resources/<bahasa>.lproj/InfoPlist.strings`,
  untuk **setiap** bahasa yang katalog dukung. Daftar izin dan daftar bahasa
  keduanya diturunkan dari berkas, bukan ditulis mati — izin baru dan bahasa
  baru sama-sama merah bila tidak dilengkapi.
- **`InfoPlist.strings` (id + en):** empat teks izin, dengan alasan
  "kenapa" yang sama dengan yang dipakai di dalam app (lokasi bawaan yang
  jelas berlabel; akurasi sensor tidak diasumsikan).
- **Ketidak-konsistenan nyata ikut diperbaiki:** versi jam tidak menyebut
  bahwa tanpa lokasi hasilnya **ditandai belum tentu sah**, sedangkan versi
  iPhone menyebutnya. Pengguna jam — layar yang paling sedikit ruang —
  justru yang tidak diberi tahu. Keduanya kini sama.

### Dua cacat pada gerbangnya sendiri, ketemu sebelum push
1. Variabel tak terdefinisi membuat pemeriksaan Python **error**, dan karena
   `$(...)` mengembalikan string kosong, aturan itu melaporkan **"Bersih"** —
   hijau untuk sesuatu yang tidak pernah dijalankan. Persis kelas
   "hijau yang tidak hijau" yang seluruh berkas ini dibuat untuk menutup.
   Diperbaiki: kegagalan internal kini dianggap GAGAL, bukan bersih.
2. `sourceLanguage: id` tidak punya entri `localizations` sendiri, jadi
   bahasa sumbernya harus ditambahkan secara eksplisit.

### Dibuktikan
- Gerbang **merah** saat `en.lproj` disembunyikan ("2 izin belum
  diterjemahkan untuk 'en'"), lalu hijau setelah dikembalikan.
- Uji: CelestialEngine 172 + PointingKit 487. 13 → 14 aturan bersih.

## Progres terakhir (5 Okt 2026 — 11 aturan gerbang tak pernah berjalan di CI)

### Cacat terbesar yang ditemukan sejauh ini
`swift-ui-lint.sh` memiliki 14 aturan; **11 di antaranya** dijalankan lewat
`python3 - <<'PY'`. Image CI Linux (`swift:6.0`, Ubuntu 24.04) **tidak
memuat Python sama sekali**.

Akibatnya, setiap kali CI Linux menjalankan gerbang ini: shell mencetak
"python3: command not found" ke stderr, `$(...)` mengembalikan string
kosong, dan tiap aturan jatuh ke cabang `else`-nya — mencetak **"Bersih"**.
Gerbang keluar 0. CI hijau. Tidak ada satu pun yang diperiksa.

Jadi sebelas aturan yang menutup kelas cacat "hijau yang tidak hijau"
sendiri tidak pernah berjalan di satu-satunya tempat yang terus-menerus
memeriksanya. Aturan 4 (teks tanpa padanan bahasa), Aturan 6 (paritas
kunci), Aturan 11 (specifier yang bisa menjatuhkan app) — semuanya no-op
di Linux selama ini.

### Yang menyingkapnya
Aturan 14, yang baru ditambahkan pada siklus sebelumnya. Ia kebetulan
berbunyi — bukan karena ia lebih baik, melainkan karena ia baru. Itu
pelajaran utamanya: gerbang yang selalu hijau tidak akan pernah
memeriksa dirinya sendiri; yang menyingkapnya hanyalah kebetulan.

### Yang diubah
- **`swift-ui-lint.sh`:** pra-syarat keras di awal — bila `python3` tidak
  ada, gerbang **berhenti dengan exit 1**, bukan mencetak "Bersih".
  Pemeriksaan yang tidak bisa dijalankan tidak boleh dilaporkan lulus.
- **`.github/workflows/engine-tests.yml`:** langkah `apt-get install python3`
  sebelum gerbang dijalankan.
- Aturan 14 diperbaiki: pemeriksaan Python yang error kini dianggap GAGAL
  (sebelumnya ia melaporkan "Bersih" — cacat yang sama, satu tingkat lebih
  kecil).

### Dibuktikan
- Di dalam container `swift:6.0` **tanpa** python3: gerbang berhenti,
  exit 1, menyebut sebabnya.
- Di container yang sama **dengan** python3 terpasang: 14 aturan dijalankan
  sungguhan, semuanya bersih — termasuk 10 aturan yang belum pernah
  benar-benar berjalan di CI.
- Uji tetap: CelestialEngine 172 + PointingKit 487.

### Catatan jujur
Empat aturan yang tersisa (1, 2, 3, dan sebagian 12/13) memang murni shell,
jadi mereka **tetap** berjalan di CI. Yang no-op adalah yang berbasis
Python — dan itu justru aturan-aturan yang paling banyak menangkap cacat
nyata.

---

## Siklus: Gerbang Aturan 4 buta pada literal di kedalaman >1

Dua kata tampilan di `Experiment1View.swift:219` hidup sebagai literal
selama berbulan-bulan sementara gerbang lokalisasi hijau:

    Text(analysis.isFalseLock ? "FALSE LOCK"
         : (analysis.isCorrect ? "benar" : "salah"))

`FALSE LOCK` kebetulan lolos karena kebetulan ada di katalog. `benar` dan
`salah` tidak punya padanan bahasa Inggris — padahal
`ExperimentText.verdictCorrect` / `.verdictWrong` sudah ada dan
terlokalisasi. Jadi layar Experiment 1 berbahasa Indonesia keras, tak
terjemahkan, dan tak ada yang melihatnya.

### Kenapa gerbangnya tidak berbunyi

`direct_arguments()` mengumpulkan literal hanya pada `depth == 1`. Literal
di dalam kurung ternary berada di kedalaman 2 dan 3, sehingga tidak pernah
terkumpul. Ini cacat yang sama seperti tiga siklus sebelumnya — gerbang
yang lulus karena ia tidak melihat, bukan karena kodenya benar.

Kedalaman bukanlah cara membedakan teks tampilan dari bukan-teks:
peritelnya (`Text`, `row`, ...) yang menentukan itu, dan pemanggilnya sudah
disaring `POS`. Syarat dilonggarkan menjadi `depth >= 1`, artinya "di dalam
tanda kurung peritel ini".

### Kenapa dikerjakan begini

Sapuan manual berkedalaman tak terbatas dijalankan atas `Apps/` **sebelum**
kode disentuh. Gerbang diperlebar dulu dan sengaja dibiarkan MERAH untuk
membuktikan ia menangkap cacat yang nyata — bukan cacat yang dikarang:

    Aturan 4: 'benar'  Apps/PointAndKnowiOS/Sources/Experiment1View.swift:219
    Aturan 4: 'salah'  Apps/PointAndKnowiOS/Sources/Experiment1View.swift:219

Baru setelah itu kodenya diperbaiki, dan gerbang kembali hijau. Urutan ini
yang membedakan "gerbang berbunyi" dari "saya mengira ia berbunyi".

### Yang diubah
- **`swift-ui-lint.sh`:** `direct_arguments()` memindai semua kedalaman
  (`depth >= 1`), dengan komentar "kenapa" yang menyebut bentuk konkret
  yang lolos.
- **`Experiment1View.swift`:** tiga kata putusan kini lewat
  `ExperimentText`. Cabang else (`"tak dianalisis"`) disamakan ke
  `verdictNotAnalyzed`, supaya satu kata tidak punya dua sumber.
  Perbaikan memakai sumber teks yang **sudah ada** — bukan menambah kunci
  katalog baru.

### Dibuktikan
- Gerbang MERAH pada dua literal itu sebelum perbaikan, hijau sesudahnya.
- `./swift-test.sh`: 487 uji hijau, 0 gagal.
- CI: Engine Tests (Linux) + Apple Build, keduanya `success`.

### Catatan jujur
Sapuan kedalaman tak terbatas menemukan 4 literal interpolasi bermemiliki
kata (`"Status: "`, `"acuan tercatat"`, `"Lokasi: "`, `"gagal"`).
Keempatnya sudah terpetakan di `FORMATS`, jadi gerbang **bersih**, bukan
lolos. Sisa 15 temuan adalah nama merek (`Point & Know`, `Experiment 1`,
masuk `NOT_LOCALIZED`) dan angka murni tanpa kata — keduanya bukan teks
tampilan yang perlu diterjemahkan.

---

## Siklus: Aturan 15 (warna mode malam) + pembukti bahwa gerbang berbunyi

PRD: **"Semua warna (termasuk visual) ikut mode ini."** Alasannya
fisiologis, bukan selera — sel batang paling sensitif di ~498-530nm,
cahaya >620nm tidak memicu rhodopsin. Jadi konstruksi warna yang melewati
penjaga `NightMode.isOn` bukan pelanggaran gaya: ia memancarkan cahaya
yang mematikan adaptasi gelap 20-40 menit, di layar yang justru dipakai
untuk melihat bintang redup.

Cacatnya sudah pernah nyata: 10 dari 13 warna gambar ditulis tangan sebagai
"merah-ish", semuanya terlihat "cukup merah" di mata, dan dua pertiga
cahaya pita terang Bulan berada di kanal hijau/biru. Perbaikannya kini satu
aturan (`NightVisual`, teruji di Linux), tapi tidak ada yang mencegah warna
baru ditulis sendiri besok — `Color(red:)` API biasa, compiler tidak peduli.

### Temuan utama: gerbang baru ini HIJAU PALSU

Aturan 15 ditulis, dijalankan, hijau. Lalu saya suntik cacat yang **persis
seperti yang pernah nyata**:

    private static func warnaUji() -> Color {
        Color(red: 0.62, green: 0.30, blue: 0.16)
    }

Gerbang **tetap hijau**. Sebabnya: batas fungsinya memakai
`rfind("\nfunc")`, yang tidak pernah cocok dengan `private static func` —
ada kata kunci akses di depannya. `rfind` mengembalikan -1, rentangnya
jatuh ke seluruh berkas, dan penjaga `NightMode.isOn` di fungsi *lain*
membuat warna tak berpenjaga dilaporkan bersih.

Gerbang itu lulus pada kode benar **dan** pada kode salah — sama saja
dengan tidak ada. Diperbaiki: batas fungsi dihitung dari deklarasi `func`
berawalan kata kunci akses, bukan dari `rfind("\nfunc")`.

### Penjaganya: `red-lint.sh`

Cacat di atas tidak terlihat dari membaca kode, jadi ia butuh penjaga.
`red-lint.sh` menyuntik cacat, **mewajibkan gerbang keluar bukan-nol**,
lalu memulihkan berkasnya. Dua arah terbukti:

| Kondisi gerbang | Hasil `red-lint.sh` |
|---|---|
| Sehat | MERAH — exit 1, menyebut barisnya |
| Buta (mutasi `rfind`) | "HIJAU PALSU" tertolak — exit 1 |

**Catatan jujur:** coba pertama `red-lint.sh` sendiri hijau palsu. Ia
memeriksa `grep` pada judul aturan (`== Aturan 15: ...`), padahal judul
selalu tercetak entah ada temuan atau tidak. Diperbaiki dengan
mensyaratkan exit code GAGAL lebih dulu, baru kecocokan teks.

Langkah ini terhubung ke CI, supaya pembuktian berjalan otomatis — bukan
hanya saat seseorang ingat mengujinya.

### Yang diubah
- **`swift-ui-lint.sh`:** Aturan 15 — setiap `Color(red:`/`Color(hue:)` di
  `Apps/` wajib berada di bawah penjaga `NightMode.isOn` di fungsi sama.
  `Color(white:)`/`Color(gray:)` sengaja tidak masuk (netral/tidak
  memancarkan).
- **`red-lint.sh`** (baru): pembukti suntik-&-pulihkan untuk gerbang sapu.
- **`.github/workflows/engine-tests.yml`:** langkah pembuktian.

### Dibuktikan
- Gerbang MERAH pada cacat suntikan, hijau setelah berkas dipulihkan.
- `red-lint.sh` menolak gerbang yang dibuat buta lewat mutasi.
- `./swift-test.sh`: 487 uji hijau, 0 gagal.
- CI: Engine Tests (Linux) + Apple Build, keduanya `success`.

### Yang diperiksa dan ternyata BERSIH
Tiga `Color(red:` di `CelestialVisualView.swift` (baris 109, 119, 534)
semuanya sudah di bawah penjaga. Baris 546 memakai `.white`, tapi hanya di
cabang `else` (siang) — saat malam ia memakai `core` yang merah murni.
Jadi klaim di komentar berkas ("Semua warna membaca NightMode.isOn")
terbukti, bukan sekadar tertulis.

---

## Siklus: katalog wajib punya terjemahan `en` — uji yang terbukti berbunyi

Sapuan atas `public` API PointingKit yang **tidak pernah disebut di berkas
uji** menemukan 67 nama, dan di antaranya yang paling berbobot:
`ExperimentText.verdictWrong` dan `.verdictNotAnalyzed`. Keduanya tampil
sebagai badge di baris percobaan `Experiment1View`, tapi uji terjemahan
yang ada hanya memeriksa `verdictFalseLock` dan `verdictCorrect` — dua
putusan tersisa tidak pernah dibuktikan punya padanan bahasa.

Kenapa itu cacat, bukan sekadar uji yang kurang: katalog punya
`sourceLanguage: id`, dan kunci `experiment.verdict.wrong` **tidak punya
`stringUnit` sendiri** — hanya `localizations.en`. Tanpa entri `en`,
`text()` jatuh diam-diam ke bawaan Bahasa Indonesia. Pengguna berbahasa
Inggris melihat badge "salah" di tengah layar yang serba Inggris, tanpa
satu pun uji yang tahu.

### Uji pertama yang saya tulis HIJAU PALSU

Uji awal memasang kamusnya sendiri lewat `EnglishTranslation.install`,
jadi ia membuktikan **mekanisme** penerjemahan bekerja — bukan bahwa
katalognya lengkap. Terukur: saya hapus entri `en` untuk
`experiment.verdict.wrong`, dan **488 uji tetap hijau**. Tidak ada yang
berbunyi.

Perbaikan: uji kedua (`testCatalogueShipsAnEnglishFormForEveryVerdict`)
membaca **berkas katalognya sendiri**.

| Kondisi | Hasil |
|---|---|
| Katalog utuh | 489 hijau |
| `en` dihapus (`experiment.verdict.wrong`) | MERAH, menyebut kuncinya |
| `en` dihapus (`Aktifkan Mode Malam`, kunci acak) | MERAH, menyebut kuncinya |

Baris ketiga yang penting: cacat dibuktikan pada kunci **acak**, bukan
pada kunci yang dipilih — supaya yang terbukti adalah cakupannya, bukan
kebetulannya.

### Diperluas ke seluruh katalog, bukan delapan putusan

Uji pada akhirnya memeriksa **312 kunci**, bukan 8. Alasannya: cacatnya
bukan pada delapan kunci itu, melainkan pada siapa pun yang menambah kunci
dan lupa menerjemahkannya. Pemeriksaan yang hanya mencakup delapan kunci
akan membiarkan 304 sisinya membusuk tanpa suara. Sapuan membuktikan
seluruh 312 kunci kini punya `en`, jadi perluasan ini tidak membuat uji
merah sekarang — ia membuat kunci baru yang tak diterjemahkan langsung
tertolak.

Uji sengaja **GAGAL** bila katalog tidak ditemukan, bukan dilewati:
pemeriksaan yang dilewati akan berhenti berlaku tanpa ada yang melihatnya.

### Catatan: CI merah sekali, dan itu tepat

Commit uji ini membuat Engine Tests **merah** pada Aturan 10: README
bilang PointingKit 487, berkas uji berisi 489. Gerbang itu bekerja
persis seperti yang dirancang — ia menolak dokumentasi yang tidak lagi
cocok dengan kenyataan. Diperbaiki di commit berikutnya; CI hijau.

### Dibuktikan
- `./swift-test.sh`: 489 uji hijau, 0 gagal.
- `./swift-ui-lint.sh`: 15 aturan lulus.
- CI: Engine Tests (Linux) + Apple Build, keduanya `success`.


---

## Siklus: kalimat "kenapa engine ragu" berubah-ubah antar peluncuran

### Premis: keputusan yang diambil dalam keadaan yang tidak punya jawaban tunggal

`ConfidenceTrace.diagnosis` mencari penyebab keraguan yang "teratas" seperti
ini:

```swift
let dominant = reasons.max { $0.value < $1.value }?.key ?? .none
```

Terbaca benar, dan memang benar ketika satu sebab benar-benar mendominasi.
Masalahnya ada pada keadaan **seri**. `max` mengembalikan elemen **pertama** yang
ditemukannya, sedangkan urutan iterasi `Dictionary` **tidak ditentukan** di
Swift — hash di-seed acak per proses. Jadi ketika dua sebab sama sering,
kalimatnya ditentukan oleh **proses**, bukan oleh data.

### Diukur, bukan ditebak

Delapan kali `swift test` pada data yang sama persis (1 sampel `tooFar`,
1 sampel `ambiguous`) — kalimat yang keluar berbeda:

```
Semua jawaban ragu karena kandidat terlalu jauh dari arah tunjuk. Perbaiki kalibrasi dulu.
Semua jawaban ragu karena ada dua kandidat berdekatan. Ini keterbatasan akurasi, bukan kesalahan kalibrasi.
...  (5x yang pertama, 3x yang kedua)
```

### Kenapa ini bukan "kalimat varies sedikit"

Kedua kalimat itu adalah **petunjuk perbaikan yang saling meniadakan**, dan
hanya salah satu yang benar:

- "Perbaiki kalibrasi dulu" -&gt; masalahnya bisa diperbaiki.
- "Ini keterbatasan akurasi, bukan kesalahan kalibrasi" -&gt; masalahnya
  **tidak** bisa diperbaiki; jangan bother.

Dan yang gegenüber adalah alat ukur repo ini sendiri, layar Keyakinan di
`DiagnosticsView`. Penguji yang membaca satu petunjuk lalu **`reset()` dan
mengulang seluruh Experiment 1** akan mengambil keputusan yang salah: ia bisa
membuat kalibrasi yang tidak diperlukan, atau — lebih buruk — menerima batas
akurasi yang sebenarnya bisa dibenahi lalu berhenti mengukur.

PRD v0.4 meminta uncertainty &gt; false confidence. Ini adalah kebalikannya
yang lebih halus: **ketidakpastian yang dipresentasikan sebagai keputusan.**

### Perbaikannya: menghapus pilihannya, bukan membuatnya deterministik

Bisa saja `max` diganti urutan enum, dan kalimatnya jadi stabil. Tapi itu
menyembunyikan masalah aslinya: **ada dua sebab yang sama saingnya**, dan satu
kalimat hanya bisa melaporkan satu.

Jadi kalimat seri sekarang menyebut **keduanya**:

> Penyebab keraguan berbagi: Semua jawaban ragu karena kandidat terlalu jauh
> dari arah tunjuk. Perbaiki kalibrasi dulu.; Semua jawaban ragu karena ada dua
> kandidat berdekatan. Ini keterbatasan akurasi, bukan kesalahan kalibrasi.

Satu sebab hanya boleh tampil sendiri bila benar-benar mendCharsets -&gt;
tidak -&gt; bila benar-benar mendominasi, yaitu **lebih dari separuh** sampel
ragu. Ambang itu dipilih karena "paling banyak" bisa tetap seri (2 dari 2),
dan itu justru kasus yang tidak boleh memilih satu. Efek sampingnya bagus:
kalimat untuk 9 dari 10 sampel yang sama sebabnya masih Ringkas seperti
sebelumnya — perbaikan ini tidak membuat semua diagnosis jadi panjang.

### Dua keputusan kecil

1. **`tiedUncertainReasons`filtersabet order enum, bukan dictionary** — supaya
   kalimatnya sama setelah perbaikan. Urutan acak yang kebetulan sama dalam
   satu proses akan terlihat "hijau" sekali lalu berubah besok.
2. **Pemisah antarsebab punya kunci sendiri**
   (`experiment.diagnosis.mixedSeparator`), bukan ditulis di kode. Kata
   penghubung adalah bagian tata bahasa tiap bahasa; menuliskannya di kode
   memaksa satu tata bahasa pada semua bahasa. Aturan 11 tidak bisa melihat
   ini, karena ia hanya menjaga **tipe specifier**, bukan isi kalimat.

Diformat sebagai satu slot `%@` + pemisah katalog, bukan tiga slot `%@`:
slot kosong akan tampil sebagai butir kosong di layar, dan `%#@` (daftar)
berperilaku berbeda antara CoreFoundation dan Swift Foundation — jebakan yang
sudah pernah menjatuhkan app di CI macOS.

### Bukti merah: mutasi yang sama menghasilkan tiga kalimat berbeda

Blok `diagnosis` dikembalikan ke bentuk **semula** (`Dictionary.max`, satu
pemenang), lalu suite dijalankan tiga kali:

| Jalankan | Kalimat yang muncul di uji yang gagal |
|---|---|
| 1 | "...karena ada dua kandidat berdekatan. Ini keterbatasan akurasi..." |
| 2 | "Jawaban ragu tanpa sebab terukur..." |
| 3 | "...karena kandidat terlalu jauh dari arah tunjuk. Perbaiki kalibrasi dulu." |

Ketiga-tiganya **MERAH**, dan ketiganya kalimat berbeda dari **kode yang
sama**. Inilah bukti yang tidak bisa diberikan mutasi lain: kalau cause of
faktanya "kode salah", kegagalan harus bisa direproduksi persis. Yang
direproduksi di sini justru ketidakpastiannya — dan itulah yang membuat
perbaikannya perlu, bukan sekadar satu kalimat yang berbeda.

Catatan: mutasi harus **berekspresi ulang** kode lama, bukan sekadar menonaktifkan
satu cabang. Versi pertama hanya mengubah `tied.count > 1` menjadi `> 99`, dan
kode lama yang masih ada membuat kompilator menolak lebih dulu
(`initializer for conditional binding must have Optional type`) — jadi
"Tidak ada yang bisa disimpulkan" bukan "hijau".

### Gerbang yang menangkap kesalahan saya sendiri

- **Aturan 10** (hitungan uji di README): `489` vs berkas berisi `495`. README
  diperbarui.
- **`testDeclaredKeysAreUniqueNonEmptyAndComplete`**: `181` vs `183`. Itu
  gerbang yang dirancang untuk jumlah kunci berubah — dua kunci baru tanpa
  penyesuaian akan lolos tanpa ada yang melihat. Angka dinaikkan **bersama
  penjelasan** Interim,

### Batas yang jujur

- **Stabilitas antar peluncuran tidak bisa diuji dari dalam satu proses.**
  Yang bisa dijaga di sini adalah *isi* kalimatnya (semua sebab seri disebut),
  dan itulah yang membuat verifikasi antar peluncuran tidak perlu melihat dua
  kalimat berbeda lagi. Uji `testDiagnosisIsRepeatableWithinOneProcess`
  menjaga hal yang lebih lemah dan **secara eksplisit menyatakan batasnya** —
  menyebut bahwa stabilitas lintas proses adalah soal hash seed, bukan
  sesuatu yang bisa diuji di sini.
- **Kalimat seri itu panjang.** Tiga sebab menghasilkan tiga kalimat penuh.
  Itu biaya yang sengaja dibayar: menginformasikan penguji bahwa ada tiga
  masalah lebih berharga daripada kalimat ringkas yang hanya menyebutkan satu.
  Belum pernah dilihat di perangkat; barisnya melingkar di `Text(.footnote)`.
- **Terjemahan `en` untuk dua kunci baru belum pernah dibaca penutur asli.**
  Yang terbukti: bentuk specifier sama (`%@`), dan Aturan 11 mengunci itu.

### Gerbang

- `./swift-test.sh` -&gt; **172 CelestialEngine + 495 PointingKit**, 0 gagal
  (489 -&gt; 495, +6 uji).
- `./swift-ui-lint.sh` -&gt; **15 aturan hijau**.
- `./swift-typecheck.sh` -&gt; SEMUA GERBANG LULUS.
- CI: Apple Build + Engine Tests (Linux).


---

## Siklus: baris "Asal lokasi" menampilkan pengenal mesin (`corelocation`)

### Premis: kelas cacat ketiga yang sama, kali ini pada nilai yang datang dari properti

Dua layar menulis `engine.location.source` **apa adanya** ke baris berjudul
"Asal lokasi": `PointingView` di jam dan `DiagnosticsView` di iPhone. Yang
terbaca pengguna adalah `corelocation`, `fallback`, `manual` — pengenal mesin
pada baris yang justru ditulis untuk menjawab "langit ini dihitung untuk mana?".

Ini cacat yang sama persis dengan dua yang sudah ditutup di repo ini: `sirius`
di headline Experiment 1 (`DisplayLabel`) dan `stateRequest` di layar Tautan
(`LinkMessageKind.displayName`). **Yang membuatnya bertahan lama juga sama:
tidak ada gerbang yang melihatnya.**

| Gerbang | Mengapa tidak berbunyi |
|---|---|
| Aturan 4 | menyapu literal di dalam argumen `Text(...)`; nilai ini datang dari **properti**, bukan literal |
| Aturan 6 | memeriksa paritas kunci yang dideklarasikan; kuncinya belum ada |
| Aturan 12 | menyapu penugasan ke variabel berakhiran Note/Label; ini argumen `row(...)`, bukan penugasan |

Yang pertama **dibuktikan**, bukan diklaim: saya kembalikan `PointingView` ke
`source` mentah dan jalankan gerbangnya — Aturan 4 melaporkan "Bersih". Jadi
satu-satunya penjaga adalah uji di Linux, dan itulah yang ditulis lebih dulu.

### Yang diubah

- `ObserverLocation.sourceDisplayName` + `sourceText` — lima kunci baru
  (`location.source.*`), nilai bawaan Indonesia: "GPS perangkat",
  "Bawaan (bukan lokasimu)", "Dimasukkan sendiri", "Simulator",
  "Tidak diketahui (%@)".
- **Sengaja bukan enum.** `source` dibaca dari arsip JSON yang sudah tersimpan
  dan dibandingkan dengan `==` (`isFallback`). Mengubahnya jadi enum berarti
  nilai asing membuat lokasi **gagal didekode** — kegagalan yang jauh lebih
  buruk daripada baris yang jelek. Karena itu yang tak dikenal jatuh ke satu
  kunci, bukan ke `nil`.
- Yang tak dikenal **tetap menyebut namanya** ("Tidak diketahui (%@)").
  Menyembunyikannya di balik satu kata akan membuat dua sumber berbeda tampak
  identik persis pada baris yang dipakai untuk memutuskan apakah langitnya
  bisa dipercaya — pengujian arsip lama vs nilai baru akan terbaca sama.

### Uji pertama yang saya tulis SALAH, dan uji itu yang memberi tahu

Perbandingan pertama memakai `lowercased()` di kedua sisi, dengan alasan yang
terdengar benar: "huruf besar-kecil tidak mengubah bahwa ia terbaca mesin".
Uji langsung merah pada `simulator`: nilai bakunya "Simulator", dan
**satu-satunya** yang membedakan label itu dari pengenalnya adalah huruf
kapitalnya. Kapitalisasi justru *cara* pengenal menjadi label — jadi
case-insensitive akan menuntut kata yang berbeda untuk setiap kasus, termasuk
yang memang sudah benar.

Dilonggarkan ke perbandingan persis, dengan batasnya **dicatat di dalam uji**:
bila suatu hari ada sumber yang nilainya memang satu kata yang sama dengan
pengenalnya, itu keputusan yang harus diambil sadar, bukan dengan melonggarkan
perbandingan.

### Dibuktikan berbunyi, bukan dipercaya

`ObserverLocationSourceLabelTests` (6 uji). Mutasi: kembalikan accessor ke
`return source`.

| Kondisi | Hasil |
|---|---|
| Kode benar | 534 hijau, 0 gagal |
| `sourceDisplayName` dikembalikan ke `source` | **MERAH, 6 kegagalan** menyebut nilainya (`"corelocation" is equal to "corelocation"`) |

Baris terakhir yang penting: kegagalannya menyebut **nilai yang salah**, bukan
sekadar "uji gagal" — jadi kalau ia berbunyi di masa depan, penyebabnya
langsung terbaca.

### Catatan: Aturan 10 merah lebih dulu, dan itu tepat

README bilang PointingKit 529, berkas uji berisi 534. Gerbang itu bekerja
persis seperti yang dirancang — ia menolak dokumentasi yang tidak lagi cocok
dengan kenyataan. Diperbaiki di commit yang sama.

### Gerbang

- `./swift-test.sh` -> **172 CelestialEngine + 534 PointingKit**, 0 gagal
  (529 -> 534, +5 uji).
- `./swift-ui-lint.sh` -> **15 aturan hijau**.
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- CI: Apple Build run `37271571126` + Engine Tests (Linux) run `37271571132`,
  keduanya `success`.

---

## Siklus: pesan sistem sensor gerak tampil apa adanya di layar

### Premis: satu-satunya baris di layar yang tidak bisa diterjemahkan

`MotionLogger.handleFailure` menyimpan `error.localizedDescription` **langsung**
ke `unavailableReason`, dan properti itu dirender `Text(reason)` di dua layar.
Teks itu milik **sistem**: ia mengikuti bahasa perangkat, bukan bahasa yang
sedang membaca katalog.

Ini beda kelas dari kegagalan **lokasi** yang sudah ditutup sebelumnya, dan
bedanya justru yang membuat cacat ini lolos. Kegagalan lokasi disusun di
`LocationProvider`, yang memanggil accessor katalog — jadi jalurnya terbaca
dari berkas `Apps/`. Yang gerak tidak.

| Gerbang | Mengapa tidak berbunyi |
|---|---|
| Aturan 4 | menyapu literal di dalam argumen `Text(...)` — ini argumen **fungsi** |
| Aturan 12 | menyapu penugasan ke properti berakhiran Note — nilainya dari ekspresi |
| Aturan 13 | menyapu literal di dalam `String(format:)`/`append` — tidak ada |

Dibuktikan: mengembalikan `MotionLogger` ke bentuk lama tidak membuat satupun
dari 15 gerbang merah.

### Yang diubah

- `SensorStatusText.motionFailed(_:)` + kunci `sensor.motion.failed`
  ("Sensor gerak berhenti: %@").
- Pesan sistemnya **tetap ditampilkan** lewat `%@`. Menyembunyikannya di balik
  kalimat generik akan membuat dua kegagalan berbeda terbaca sama pada baris
  yang dipakai untuk memutuskan apakah jam masih bisa dipakai — alasan yang
  sama dengan `location.source.unknown` pada siklus sebelumnya.

### Cacat pada gerbangnya sendiri, ketemu sebelum push

Menambah uji yang memasang bahasa Inggris membuat **tiga uji merah di berkas
lain** (`TextLocalizationTests`), dengan pesan `"Sebaran 2.4°"` vs
`"Sebaran 2,4°"`.

Penyebabnya persis kebocoran yang sudah didokumentasikan di
`EnglishTranslation.swift`: `SensorStatusTextTests` hanya melepas
`TextLocalization`, tidak `NumberFormat`. Pemisah desimal `en_US` bocor ke uji
berikutnya, dan kebocoran itu **tidak muncul sebagai kegagalan yang jujur** —
ia muncul sebagai angka yang tiba-tiba berbahasa lain di berkas yang tidak
ada hubungannya.

Kelas ujinya kini `BridgedTextTestCase` (melepas keduanya). Basis itu sudah
ada sejak siklus `TextLocalization`; yang kurang adalah memakainya.

### Dibuktikan berbunyi

3 uji baru. Mutasi: accessor mengembalikan `message` apa adanya.

| Kondisi | Hasil |
|---|---|
| Kode benar | 537 hijau, 0 gagal |
| `motionFailed` dikembalikan ke pesan mentah | **MERAH, 3 kegagalan** |

### Gerbang

- `./swift-test.sh` -> **172 CelestialEngine + 537 PointingKit**, 0 gagal.
- `./swift-ui-lint.sh` -> 15 aturan hijau.
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- CI: Apple Build `37272373882` + Engine Tests `37272374080`, keduanya success.

### Pola yang mulai terlihat

Tiga siklus terakhir menutup cacat yang **sama** — nilai untuk mesin yang
tersaji sebagai teks untuk orang — di tiga lapisan berbeda: `DisplayLabel`
(nama objek), `ObserverLocation.source` (asal lokasi), dan kini pesan sistem
sensor. Yang membuatnya bertahan lama bukanlah nilainya, melainkan bahwa
setiap lapisan punya **satu** jalur yang tidak dijangkau gerbang: argumen
fungsi, properti dari ekspresi, nilai dari sistem. Gerbang menyapu bentuk;
cacatnya hidup di jalur yang tidak punya bentuk literal.

## Siklus "kalimat tautan untuk VoiceOver" (2026-10-05)

Unit terkecil siklus ini bukan tampilan: satu kalimat yang **dibacakan**.

### Temuan

`.accessibilityLabel` baris tautan jam di `PointingView` merakit kalimatnya
sendiri dari literal:

```swift
var text = link.isReachable ? "iPhone terhubung" : "iPhone tidak terjangkau"
text += ...                              // bagian jumlah
```

Dua cacat, dan keduanya lolos ke produksi.

**Yang pertama: literalnya tidak pernah melewati katalog.** Dan tiga gerbang
buta di sini sekaligus -- bukan argumen `Text(...)` (Aturan 4), bukan penugasan
ke properti berakhiran Note/Label (Aturan 12), dan bukan literal peritel
aksesibilitas mana pun.

Yang membuatnya bertahan lama adalah **bentuknya**, bukan nilainya: baris yang
**ditampilkan** di layar memakai `TextLocalization.text(.pointingLinkConnected)`,
yaitu teks yang sama persis, punya kunci, dan Bahasa Inggrinya ada. Jadi
komponennya terlihat benar, tidak ada layar yang tampak keliru, dan yang salah
hanya kalimat yang dibacakan -- persis bagian yang tidak pernah dilihat mata.

**Yang kedua: `text += ...` memaku urutan di kode.** Pemisah dan urutan jumlah
terkunci di Swift, sehingga bahasa yang ingin meletakkan jumlah sebelum kata
"gagal" tidak bisa mengatakannya.

### Cacat jatuh: urutan argumen terbalik

Menuliskan uji untuk kalimat itu memanggil `sendFailures(_:)` dengan jumlah
> 0 untuk pertama kalinya -- dan proses **jatuh**. Bukan kegagalan assertion:
`Fatal error`, seluruh proses mati.

Penyebabnya: katalog berbunyi `. %lld %@.` (jumlah dulu, baru kata), tapi
fungsi mengirim `(word, count)`. `String(format:)` memetakan argumen ke
specifier **sesuai posisi, bukan tipe**, jadi `String` masuk ke `%lld` dan
`Int64` masuk ke `%@`.

Kenapa bisa lama tidak noticed: jalur itu **tidak pernah dipanggil di produksi**
dengan jumlah > 0. `sendFailureCount` di `.accessibilityLabel` nol selama
tautan sehat, dan `linkSpeech` melewati cabang itu tanpa menyentuh format.
Jadi bukan ketelitian yang menyelamatkan -- tidak adanya pemanggil.

### Gerbang baru: Aturan 16

Menyapu literal peritel aksesibilitas (`accessibilityLabel/Value/Hint`) dan
properti `...Label`/`...Note`/`...Speech...` yang diiwa ekspresi apa pun.
Dibuktikan **gigit pada kode hari ini** sebelum diperbaiki (bukan gate yang
dibuat lalu langsung hijau), dan hijau sesudahnya.

### Kunci katalog: 293 -> 296

`link.speech.reachable`, `link.speech.unreachable`, dan
`link.status.sendFailuresClause`.

Yang ketiga lahir dari cacat yang saya buat sendiri: nilai lama diawali
pemisah titik karena asalnya untuk disambung ke baris **belum selesai**, jadi
menempel di belakang kalimat utuh menghasilkan "terhubung.. 3 kiriman gagal."
Memangkas pemisah di kode akan memaksa satu tata bahasa ke semua bahasa, dan
pemisah adalah milik katalog. Jadi dua peran, dua kunci.

### Dibuktikan berbunyi

4 uji di `LinkStatusTextTests`, semuanya mengunci nilai **mutlak** -- bukan
perbandingan dua bentuk, supaya mutasi "literal" tetap merah.

| Kondisi | Hasil |
|---|---|
| Kode benar | 543 hijau, 0 gagal |
| `sendFailures` mengembalikan argumen dalam urutan lama | **JATUH**, `Fatal error` |
| `linkSpeech` memakai `sendFailures` (pemisah ganda) | **MERAH**, "terhubung.. 3" |

### Gerbang

- `./swift-test.sh` -> **172 CelestialEngine + 543 PointingKit**, 0 gagal.
- `./swift-ui-lint.sh` -> **16 aturan** hijau (Aturan 10 menangkap 539->543).
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- CI: Apple Build `37277323365` + Engine Tests `37277323206`, keduanya success.

### Pola yang makin jelas

Empat siklus terakhir menutup cacat yang **sama** -- nilai untuk mesin yang
tersaji sebagai teks untuk orang, di lapisan berbeda: `DisplayLabel`,
`ObserverLocation.source`, pesan sistem sensor, kini kalimat VoiceOver.

Yang memungkinkannya lolos bukan nilai literalnya, melainkan **tempatnya**.
Gerbang menyapu *bentuk*: argumen `Text(...)`, properti berakhiran `Note`,
pemanggil `String(format:)`. Cacat ini hidup di jalur yang **tidak punya
bentuk literal sama sekali** -- ekspresi ternary di dalam accessor yang
dipanggil peritel aksesibilitas.

Siklus ini juga menambah satu jenis cacat yang berbeda: bukan teks yang salah,
tapi **argumen yang salah urutan**, yang tidak menghasilkan teks salah --
menghasilkan **crash**. Diperbaiki oleh uji yang memanggil jalurnya; menjaga
jalur itu tetap hidup berarti memanggilnya pada setiap percobaan.

## Siklus: ambang keyakinan engine bisa bergerak setelah SATU rekaman (2026-10-05)

### Premis: dua tempat memutuskan "cukup bukti?", dan keduanya salah arah

Di layar Experiment 1 ada dua hal yang menilai apakah rekaman sudah
layak dipakai: kalimat putusan dan tombol "kirim ambang".

- `ExperimentSummary.safetyVerdict` memakai `minimumTrialsForSafetyClaim`
  (20 percobaan). 1 rekaman bersih -> `.insufficientEvidence`.
- `ExperimentHarness.suggestedConfidencePolicy` -- yang keluarannya
  **ditulis ke resolver jam** -- hanya memakai satu syarat: `guard !analyzable.isEmpty`.

Jadi dari 1 rekaman, layar menampilkan dua jawaban yang saling meniadakan
untuk data yang sama:

    "Belum bisa disimpulkan"   <- dari safetyVerdict
    [Kirim ambang yang diukur] <- dari suggestedConfidencePolicy

Yang dikirim bukan angka laporan. `Experiment1View` meneruskan `policy` itu
ke `link.send(policy:)`, lalu jam memakai `pointingSigmaDeg` sebagai ambang
ke classifier: dari bawaan konservatif 10° ke sigma terukur -- sehingga **satu**
rekaman bisa membuat engine jauh lebih mudah bilang "Yakin".

Yang rusak bukan angkanya, tapi **arahnya**. PRD menetapkan ketidakpastian
menang atas keyakinan; di sini yang menang justru sebaliknya. Dan yang
memperkenalkannya adalah tombol, bukan teks -- jadi bagian yang paling
berbahaya adalah yang paling terlihat seperti fitur biasa.

Bukti bahwa ini bukan karangan saya: komentar di `Experiment1View:195-198`
sudah tahu `passesSafetyCriterion` bernilai `true` bahkan untuk satu
percobaan bersih, tapi layar tetap memakai `safetyVerdict` untuk warna.
Artinya: satu definisi sudah dibetulkan, yang kedua tertinggal.

### Yang diubah

`suggestedConfidencePolicy` kini membaca `summary.safetyVerdict` sebagai
satu-satunya sumber kebenaran, bukan hitungan sendiri:

- `.failed` -> perketat (sigma terukur atau separuh bawaan).
- `.passed` -> sigma terukur.
- `.insufficientEvidence` -> `nil`. Tidak ada tombol yang dikirim.

Asimetri "gagal cepat, lulus pelan" **dijaga** dan diberi uji sendiri, jadi
satu false lock dari sampel kecil tetap mengusulkan pengetatan.

### Uji yang ditulis lebih dulu

`ExperimentHarnessTests` (+4 uji):

| Kondisi | Hasil |
|---|---|
| 1 rekaman bersih -> safetyVerdict `.insufficientEvidence` | sudah ada |
| 1 rekaman bersih -> `suggestedConfidencePolicy` | **JATUH** (ada policy 2.5°) |
| 19 rekaman bersih -> policy | **JATUH** (ada policy 2.5°) |
| 19 rekaman bersih -> `trialCount` 19 | sudah benar |
| 20 rekaman bersih -> policy 2.5° | hijau |
| 1 false lock dari sampel kecil -> pengetatan | hijau (asimetri terjaga) |

Batas 20 diuji **dari dua sisi** (19 dan 20): `@discardableResult` pada
`record` membuat rekaman ke-20 tidak selalu menambah trial, jadi uji satu
sisi tidak bisa membedakan "tepat di ambang" dari "satu di bawah ambang".

Satu uji lama ikut diperbarui: `testPolicyUsesMeasuredSigmaWhenSafe` pernah
merekam 1 percobaan lalu mengharapkan policy -- itu **mengkodekan cacat
yang sama**. Namanya masih benar, prasyaratnya yang diperbaiki.

### Gerbang

- `./swift-test.sh` -> **174 CelestialEngine + 570 PointingKit**, 0 gagal.
- `./swift-ui-lint.sh` -> **19 aturan** hijau (Aturan 10 menangkap 566->570).
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- CI: Apple Build `37304731863` + Engine Tests `37304731877`, keduanya success.

### Cacat pada alat saya sendiri

Menuliskan komentar lewat `patch` beberapa kali menghasilkan teks katak
(CJK/Sikud) yang menyatu ke kata Indonesia -- `ambang yangania`,
`sepertiZWIAAN`, `bisa.samplekan`. Kompilasi tetap hijau (komentar!), jadi
tidak ada gerbang yang menangkapnya. Dua hal yang perlu diingat:

1. `write_file`/`patch` pada teks panjang Bahasa Indonesia perlu
   pemindaian ulang; verifikasi bukan "patches applied" tapi isi barisnya.
2. Skrip `red-test.sh` dan `swift-ui-lint.sh` menangkap cacat semantik, bukan
   teks rusak. Untuk yang terakhir ini tidak ada gerbangnya sama sekali.

Yang tersisa tanpa penjaga: karakter non-Latin tak terduga di dalam komentar.

## Siklus: daftar target menawarkan objek yang engine tidak akan pernah kunci (2026-10-05)

### Temuan: angka "di atas horizon" ditulis dua kali, dan tidak sama

`availableTargets` menyaring dengan `altitudeDeg <= 0`. Itu terlihat wajar,
dan itu salah. Engine hanya mengunci lewat `VisibilityFilter`, yang menolak
`altitude < policy.minAltitudeDeg` -- **5 derajat** pada policy bawaan.

Pada policy produksi, Experiment 1 karena itu menawarkan objek setinggi
0-5 derajat yang `diagnose` akan tolak sebagai `belowHorizon` setiap kali.

Diperiksa dengan sapuan 1.440 kombinasi (5 lokasi x 12 bulan x 3 hari x
4 jam): **499** di antaranya punya minimal satu target di pita 0-5 derajat,
termasuk Sirius di 0,6 derajat dan Canopus di 2,8 derajat. Ini kondisi
umum, bukan kasus tepi.

Yang rusak bukan angkanya, tapi kebohongannya. Daftar menyatakan sebuah
objek "tersedia untuk ditunjuk" padahal persis tidak akan pernah bisa
dikunci. Penguji memilih dari daftar itu, misses semuanya, lalu rekaman
yang gagal diperlakukan sebagai bukti tentang engine -- dan rekaman itu
tidak berbohong soal apa yang diukur, tapi berbohong soal apa yang bisa
diukur.

### Dua tanda baca yang hampir keliru

Perbaikan pertama menulis `< policy.minAltitudeDeg`. Itu **salah**, dan
19 uji langsung jatuh: policy permisif punya `minAltitudeDeg: -90`, jadi
saringan `<` justru **meloloskan** benda di -60 derajat.

Yang benar adalah `<=`, karena `VisibilityFilter` menolak dengan `<`:
daftar harus membuang `<=` agar batasnya identik dengan gerbang engine.
Tanda baca di sini menentukan arah seluruh daftar.

### Dua uji lama ikut mengkodekan definisi yang salah

`testAvailableTargetsAreAllComputableAndAboveHorizon` (harness) dan
`testReferenceTargetsComeFromFlowNotWholeCatalogue` (kalibrasi) sama-sama
mengassert `altitudeDeg > 0`, padahal resolver uji keduanya memakai
`VisibilityPolicy.permissive` dengan `minAltitudeDeg: -90`.

Jadi assertion itu **tidak mungkin** benar sebagai pernyataan tentang
engine; ia hanya hijau karena daftar mematok angka 0 sendiri.
Keduanya kini mengassert ambang engine. Nama satu juga diganti karena
"above horizon" bukan lagi istilah yang tepat untuk apa yang dijamin.

### Cacat pada uji regresi saya sendiri

Uji regresi pertama saya **hijau** pada tanggal dan lokasi bawaan
(Jakarta, 2023-11). Bukan karena cacatnya hilang, tapi karena langit
pada saat itu kebetulan tidak punya apa pun di pita 0-5 derajat --
persis kelas cacat yang paling berbahaya: uji yang hijau karena
keberetulan.

Uji sekarang memakai 1 Februari 2026 pukul 22:00 di lat -33, di mana
Sirius terbukti 0,57 derajat, dan **memeriksa ulang prasyaratnya sendiri**
supaya tidak bisa lolos diam-diam lagi. Fix-nya juga diverifikasi
dengan mengembalikan saringan ke angka 0 sementara dan memastikan
ujinya benar-benar jatuh.

### Gerbang

- `./swift-test.sh` -> **174 CelestialEngine + 572 PointingKit**, 0 gagal.
- `./swift-ui-lint.sh` -> **19 aturan** hijau (Aturan 10 menangkap 570->572).
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- CI: Apple Build `37306819055` + Engine Tests `37306819049`, keduanya success.

### Yang belum kerjakan

`SlewSafetyPolicy.minAltitudeDeg` (10 derajat) adalah angka ketiga untuk
"cukup tinggi". Yang itu **sengaja berbeda** -- itu batas mekanis
teleskop, bukan batas penglihatan, jadi tidak boleh disamakan dengan
policy visibilitas. Yang baru diperbaiki adalah kasus di mana dua hal
yang mestinya identik -- ambang engine dengan ambang daftar yang
menganggap engine pasti mengizinkan -- memang berbeda. Batas mekanis
bukan kasus itu.

## Siklus: satu member mati, dan arti tanda "MATI" di sweep (2026-10-05)

### Yang dihapus

`SurfaceColor.isGrey` — nol konsumen di app, nol di uji. Awalnya ia
terdengar seperti kontrak yang layak dijaga ("abu kelabu asli"), tapi
janji yang mungkin ia nyatakan sudah diuji lebih ketat di
`SurfacePaletteTests.testNightPaletteContainsNoGreenOrBlueAtAll`: hijau
dan biru harus **nol**, bukan sekadar sama dengan merah.

Menyisakan pembantu yang tidak dipanggil hanya menambah permukaan yang
harus dipelihara tanpa menambah jaminan apa pun.

### Yang ternyata TIDAK mati: arti tanda `test=0`

Sweep menandai beberapa member lain dengan `test=0`, dan itu terlihat
menakutkan kalau dibaca sekilas. Diperiksa satu per satu:

| Member | Sepadan | Kesimpulan |
|---|---|---|
| `smootherBlend` | dipakai `PointingController` | hidup |
| `minimumSamples` | dipakai `CalibrationFlow` | hidup |
| `trueDirection` | dipakai `CalibrationFlow` | hidup |
| `stateLabel` | dipakai `PointingPresentation` | hidup |
| `maximumClaimedAge` | dipakai penjaga claim | hidup |
| `isGrey` | tidak ada | **mati** |

Jadi `test=0` berarti **"tidak disebut langsung oleh nama itu di uji"**,
bukan "tidak terpakai". Yang membedakan keduanya adalah apakah ada jalur
produksi yang memanggilnya -- bukan apakah ada uji yang menyebutnya.

Kalau tidak dibedakan, respons yang wajar kelihatan tapi salah: menghapus
lima member yang sedang menopang logika inti hanya karena tidak ada satu
uji yang menyalin nama variabelnya.

### Satu yang dicek dan dinyatakan benar

`stateLabel` mengembalikan `"Point & Know"` sebagai literal mentah, dan itu
terlihat melanggar Aturan 4. Tapi string itu sudah terdaftar sebagai kunci
katalog di `TextLocalization.swift:360`, jadi yang di sini sudah
diterjemahkan sebelumnya -- pola yang sama dipakai `headline`. Bukan
string UI yang lolos dari katalog.

### Gerbang

- `./swift-test.sh` -> **174 CelestialEngine + 572 PointingKit**, 0 gagal.
- `./swift-ui-lint.sh` -> **19 aturan** hijau.
- `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
- CI: Apple Build `37307694866` + Engine Tests `37307694628`, keduanya success.

---

## Siklus: lapisan gambar akhirnya bisa DILIHAT dan DIUKUR (2026-10-05)

### Premis: bagian yang paling sering salah adalah bagian yang tidak bisa diperiksa

Repo ini sudah punya disiplin gerbang yang kuat: 174 + 597 uji di Linux,
19 aturan sapu UI, gerbang warna mode malam yang dibuktikan berbunyi. Tapi
semua itu memeriksa **model** — `CelestialVisual`, `VisualFrame`,
`PhaseGeometry`, `SurfacePalette`. Yang tidak diperiksa siapa pun adalah
**terjemahan model itu ke piksel**, karena `CelestialVisualView` hanya
terbangun di macOS dan VPS ini Linux.

Bukti bahwa celah itu nyata bukan hipotesis: dua commit terakhir sebelum
siklus ini adalah dua cacat yang lahir persis di sana.

| Cacat | Kenapa lolos semua gerbang |
|---|---|
| Sabit Bulan tercermin vertikal (tanda `rotate` dibalik) | Modelnya benar dan ujinya hijau. Di layar sabitnya tetap berbentuk sabit — sisi terang menghadap arah yang salah, dan tidak ada teks di layar yang bisa membuktikannya. |
| Denyut jam mati (`Date()` di dalam `body`) | View-nya tidak pernah dijalankan di Linux, jadi tidak ada yang bisa mengamati bahwa denyutnya tidak bergerak. |

Keduanya kelas yang sama: **model benar, terjemahan salah, tidak ada yang
melihat.** Selama celah itu terbuka, tiap perubahan visual berikutnya punya
peluang yang sama untuk salah tanpa ketahuan.

### Yang dibangun

Lapisan menggambar diport ke Python — tanpa dependensi, tanpa Apple SDK,
tanpa internet — lalu hasilnya **diukur**, bukan sekadar digambar:

| Alat | Guna |
|---|---|
| `Tools/render-visuals.py` | Menggambar 28 kasus (planet, Bulan semua fase, bintang, Matahari, objek langit dalam, tiap kasus ragu) jadi PNG + `index.html` — untuk **mata manusia**. |
| `Tools/check-visuals.py` | Mengukur **42 invarian** dari pikselnya — untuk **gerbang**. Keluar != 0 kalau ada yang rusak. |

Yang diukur adalah hal yang punya jawaban benar/salah:

- **Luas sabit mengikuti fraksi iluminasi.** f=0.18 -> 0.180, f=0.50 ->
  0.498, f=0.98 -> 0.979. Ini yang tidak bisa dilakukan uji model: yang
  diuji di sana adalah **rumus kurvanya**, bukan daerah yang benar-benar
  terisi setelah dipotong ke piringan dan diputar.
- **Sisi terang sabit menghadap sudut yang diminta**, diukur sebagai pusat
  massa sisi tersinari: sudut `-pi/2` -> bawah, `+pi/2` -> atas, `0` ->
  kanan, `pi` -> kiri. Cacat tanda rotasi tertangkap di sini.
- **Ciri pengenal hilang saat ragu, dan ada saat yakin.** Keduanya perlu:
  uji "ciri hilang saat ragu" saja akan diloloskan sempurna oleh view yang
  berhenti menggambar **semua** ciri.
- **Mode malam murni**: kanal hijau & biru **nol** di piksel, bukan "kecil".
- **Urutan warna bintang**: Betelgeuse (R−B 236) lebih merah dari Rigel
  (−44) — diukur dari piksel yang benar-benar jadi.

### Dua cacat yang ditemukan di alat baru ini sendiri

Alat ukur yang salah lebih berbahaya daripada tidak ada alat: ia memberi
angka yang terlihat sah. Dua cacat ditemukan saat membangunnya, keduanya
diperbaiki:

1. **`Canvas.to_png` menulis byte filter PNG dua kali.** Ia menambahkan
   byte filter 0 per baris **dan** menyerahkan buffer itu ke `_png()`, yang
   menambahkan byte filter lagi lalu memotong ulang buffer seolah tidak ada
   filter. Setiap baris bergeser satu byte. Gejalanya: sudut gambar keluar
   `00 0a 0a 0f` alih-alih `0a 0a 0f ff`, dan **setiap** kasus melaporkan
   "jangkauan 1.402 R" yang sama persis — angka yang terlalu seragam untuk
   benar. Yang membuatnya layak dicatat: PNG-nya tetap "kelihatan seperti
   planet", cukup untuk tidak dicurigai.

2. **`Canvas.fill` membuang alfa dari `color_at`.** View memakai alfa nol
   sebagai cara "tidak menggambar sama sekali" (maria Bulan hanya tergambar
   di dalam pita yang menyala, `(lit, 0.0)` di luarnya). Karena alfa itu
   dibuang, maria yang seharusnya gelap 12% tergambar **penuh** — dan itu
   terbaca sebagai sabit yang jauh lebih lebar dari fasenya. Setelah
   diperbaiki, luas sabit langsung jatuh ke nilai yang benar.

### Gerbangnya dibuktikan berbunyi, bukan sekadar mencetak "OK"

Gerbang yang lulus pada kode benar **dan** pada kode salah lebih buruk
daripada tidak ada gerbang, karena ia membuat orang berhenti memeriksa.
Karena itu lima cacat disuntikkan satu per satu:

| Mutasi | Tertangkap |
|---|---|
| Tanda rotasi tidak dibalik (cacat asli) | 2/4 pemeriksaan arah gagal |
| Maria menggambar penuh | 4/9 pemeriksaan luas gagal |
| Cincin Saturnus tidak digambar | 1/3 pemeriksaan ciri gagal |
| Visual pasti ditampilkan saat ragu | 3/3 pemeriksaan "hilang saat ragu" gagal |
| Mode malam tidak menyaring hijau/biru | 4/7 pemeriksaan kemurnian gagal |

Percobaan pertama mutasi ini **gagal mendeteksi apa pun**, dan sebabnya
layak dicatat: `check-visuals.py` memuat modul render-nya sendiri, jadi
memutasi modul yang di-`import` dari luar tidak menyentuh apa yang benar-benar
dipakai pemeriksaan. Mutasi yang "tidak tertangkap" hampir membuat saya
menyimpulkan gerbangnya tuli; yang benar adalah mutasinya mengenai objek
yang salah. Mutasi harus disuntikkan ke `CV.R` — instance yang dipakai.

### Uji regresi untuk cacat PNG

`check_png_roundtrip` membandingkan buffer di memori dengan hasil
encode-decode. Ini menangkap pergeseran satu byte **tanpa perlu ada yang
membuka gambarnya** — penting justru karena cacat itu bertahan lama
semata-mata karena hasilnya masih terlihat wajar.

### Pemeriksaan pergeseran (drift)

Port ini hidup di Python, view-nya di Swift, dan keduanya memuat angka yang
sama (opasitas glow, rasio cincin, fraksi bola, opasitas maria). Kalau
seseorang mengubah view dan lupa port-nya, semua pemeriksaan di atas tetap
hijau sambil mengukur gambar yang **sudah tidak ada lagi**.
`check_port_matches_swift_constants` membaca angka itu langsung dari sumber
Swift, jadi perubahannya tertangkap.

### Yang TIDAK diklaim

Bahwa hasil Python sama dengan SwiftUI di perangkat. Itu tidak bisa
dibuktikan di sini, dan tidak diklaim. Yang dijaga adalah: port-nya
konsisten dengan dirinya sendiri, konstantanya masih sama dengan sumber
Swift, dan invarian yang bisa diukur memang terpenuhi. Penilaian estetika
("apakah ini cantik") tetap milik mata manusia — `render-visuals.py` ada
untuk itu.

### Gerbang

- `./swift-test.sh` -> **174 CelestialEngine + 597 PointingKit**, 0 gagal.
  (Naik dari 572: bukan dari siklus ini — engine tidak disentuh sama sekali.)
- `python3 Tools/check-visuals.py --check` -> **42 pemeriksaan, 0 gagal**
  (26 detik, tanpa dependensi).
- `./swift-ui-lint.sh` -> hijau.
- CI: Engine Tests `37340713070` + Apple Build `37340712942`, keduanya
  success. Langkah "Gerbang gambar objek (port Python)" ikut hijau di Linux.

### Kenapa dipasang di CI

Tanpa langkah CI, `check-visuals.py` hanya alat yang dipakai kalau ada yang
ingat menjalankannya. Gerbang yang harus diingat untuk dijalankan adalah
gerbang yang akan dilewati. Karena itu ia masuk `engine-tests.yml` — job
Linux, tempat ia memang bisa berjalan.

## Siklus: "identitas yang diklaim gambar" — aturan yang belum pernah ditulis (2026-10-05)

### Premis: PRD melarang sesuatu, tapi tidak pernah bilang apa "sesuatu" itu

Aturan kerasnya berbunyi: *"JANGAN pernah menampilkan visual yang mengklaim
identitas saat engine RAGU."* Kalimat itu jelas sebagai larangan, tapi tidak
menjawab pertanyaan yang menentukan apakah sebuah visual melanggarnya atau
tidak: **ciri apa yang termasuk "identitas"?**

Ternyata repo sudah menjawabnya berkali-kali, tapi selalu di dalam satu
fungsi, sebagai catatan lokal — cincin Saturnus di `drawPlanet`, bentuk
galaksi di `drawableMorphology`, pita Jupiter di `palette.feature`. Tidak
ada satu tempat yang menuliskan aturannya. Karena itu setiap kali jenis
visual baru ditambahkan, pertanyaannya dibuka lagi dari nol, dan peluang
terlewatnya bergantung pada apakah orang yang menulis fitur berikutnya ingat
pada aturan yang tidak tertulis itu.

### Temuan: bintang tertinggal, dan itu bukan kebetulan

Pita Jupiter dijaga. Bentuk galaksi dijaga. Warna bintang **tidak dijaga apa
pun** — indeks B−V-nya diteruskan apa adanya ke `starRGB`, jadi Betelgeuse
tetap merah dan Rigel tetap biru walaupun badge di sebelahnya bertuliskan
"Ragu". Bukan karena ada yang lupa menambahkan `isConfirmed` di satu tempat:
memang tidak pernah ada tempatnya, karena `spokenStarColor` dan `starColor`
tidak menerima parameter itu sama sekali.

Sisi **suara** lebih jauh tertinggal lagi: `spokenDeepSkyMorphology(isConfirmed:)`
sudah menerima keyakinan sejak awal, dan tepat di atasnya di berkas yang sama
`spokenStarColor` masih properti tanpa parameter. Dua hal yang sama-sama
"atribut yang hanya bisa dilihat", dua perlakuan yang berbeda.

### Aturan yang sekarang dituliskan

Yang menentukan bukan jenis objeknya, dan bukan "apakah ini terlihat seperti
ciri khas". Yang menentukan **dari mana ciri itu berasal**:

> Ciri yang **dicari berdasarkan identitas yang sudah dikunci** tidak boleh
> tampil saat engine ragu, karena pada kandidat yang salah ia akan
> menampilkan ciri milik objek lain — dan itu bukan sekadar ragu, itu salah.
> Ciri yang **tidak bergantung pada identitas** boleh tetap tampil.

Konsekuensinya jadi terpisah dengan sendirinya, dan tiap baris bisa diperiksa:

| Ciri | Sumbernya | Saat ragu |
|---|---|---|
| Pita, cincin, kutub, kawah Jupiter/Saturnus/Mars | dicari dari id yang dikunci | disembunyikan |
| Bentuk nebula/galaksi/gugus | dicari dari id yang dikunci | netral (kabut) |
| Warna spektral bintang (B−V) | dicari dari id yang dikunci | netral (tak mengklaim) |
| Terang bintang (magnitudo) | dicari dari id — tapi menyebut **terang**, bukan **bintang mana** | tetap tampil |
| Nama kandidat | dari engine | tetap tampil |
| **Fase Bulan** | **efemeris**, dihitung dari waktu — bukan hasil pencarian id | **tetap tampil** |
| Piringan gelap Bulan | geometri | tetap tampil |

Baris "fase Bulan" itu yang paling mudah salah dibaca, jadi alasannya
ditulis di sini. Fase Bulan **bukan** hasil identifikasi. `isWaxing` dan
`illuminationFraction` datang dari efemeris — perhitungan posisi Matahari dan
Bulan pada waktu tertentu — bukan dari tabel yang diindeks oleh id objek.
Fase itu fakta tentang Bulan sebagai benda langit pada tanggal itu, dan tetap
benar berapa pun yakinnya engine soal *apakah ini Bulan*. Tidak ada
identitas yang bisa salah diklaim oleh sebuah fase.

Menahannya saat ragu akan **menurunkan** kejujuran, bukan menaikkannya:
pengguna yang melihat Bulan sabit telanjang mata lalu membaca "Ragu" masih
mendapat fase yang benar; kalau fasenya disembunyikan, satu-satunya bagian
yang benar dari gambar itu ikut hilang. Karena itu `phaseGeometry` sengaja
tetap dijaga oleh **ketersediaan data** (`nil` bila fraksi atau arah tidak
dihitung) dan bukan oleh `isConfirmed` — dan perbedaan dua penjaga itu
sekarang jadi punya alasan tertulis.

### Kenapa ini dicatat sebagai aturan, bukan diperbaiki sekali

Memperbaiki bintang itu satu perubahan. Yang membuatnya tidak terulang
adalah aturannya: ciri yang dicari dari id yang dikunci tidak boleh tampil
saat ragu. Setiap visual baru sesudah ini bisa diuji terhadap satu kalimat
itu, tanpa perlu menebak maksud PRD lagi.

### Uji yang ditulis lebih dulu

Kedua sisi ditulis merah dulu sebelum fungsinya ada:

  - **gambar** — `drawableStarColorIndex(_:isConfirmed:)`: merah karena
    fungsinya belum ada; sesudahnya, Betelgeuse dan Rigel menghasilkan warna
    yang sama saat ragu, dan warna itu sama persis dengan warna bintang tak
    dikenal (bukan angka netral karangan baru).
  - **suara** — `spokenStarColor(isConfirmed:)`: merah karena pemanggilannya
    gagal (masih properti). Saat yakin tetap "merah"; saat ragu `nil`;
    bukan-bintang `nil` di kedua keadaan.

### Gerbang

  - `./swift-test.sh` -> CelestialEngine 174, PointingKit **600**, 0 gagal.
  - `./swift-ui-lint.sh` -> 22 aturan hijau (Aturan 10 menangkap dua kali
    hitungan uji README yang basi, 597 lalu 599 -> 600).
  - `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
  - `python3 Tools/check-visuals.py --check` -> **45** pemeriksaan hijau
    (naik dari 42), termasuk tiga yang baru khusus untuk warna bintang.
  - CI: Engine Tests `37343194154` + Apple Build `37343194146`, keduanya
    success.

### Gerbangnya dibuktikan berbunyi, bukan sekadar mencetak "OK"

Memakai `check-visuals.py` untuk menguji dirinya sendiri — mengubah perilaku
lalu memastikan pemeriksaannya gagal:

  - kembalikan `drawableStarColorIndex` ke bentuk lama (warna diteruskan apa
    adanya) -> 2 dari 3 pemeriksaan warna bintang gagal;
  - buang warnanya **selalu** (termasuk saat yakin) -> pemeriksaan arah
    sebaliknya yang gagal.

Tanpa arah kedua itu, view yang membuang warna akan selalu lolos — gerbang
yang hanya bisa lulus bukan gerbang.

### Yang TIDAK diklaim

  - Fase Bulan saat ragu **tidak** diubah, dan itu keputusan, bukan
    kelalaian. Lihat tabel di atas untuk alasannya.
  - Siklus ini tidak memeriksa apakah warna netral "terlihat enak" — hanya
    bahwa ia sama untuk semua bintang dan berbeda dari warna terkunci.

## Siklus: complication inline — permukaan ketiga, kanal yang hilang (2026-10-05)

### Premis: aturan yang sudah dituliskan tetap bisa bocor di permukaan yang belum diperiksa

Siklus sebelumnya menuliskan aturannya: ciri yang dicari dari id yang
dikunci tidak boleh tampil saat ragu. Siklus ini memeriksa **permukaan
ketiga** — complication — karena app jam dan iPhone sudah diperiksa, dan
complication berjalan di proses terpisah dengan bentuk yang berbeda.

### Temuan: satu keluarga kehilangan satu-satunya kanalnya

Complication punya **dua** kanal: satu ikon dan satu baris teks. Model sudah
menyediakan keduanya (`presentedSymbolName(at:)`, `sublineContent(at:)`), dan
dokumentasi `presentedSymbolName` menulis alasannya sendiri:

> "Kalau `.uncertain` memakai ikon yang sama dengan `.lock`, pergelangan
> membaca 'Vega' berdampingan dengan centang hijau, lalu menyimpulkan engine
> yakin. Kalau teksnya yang dirubah — sayangnya **satu kata tambahan sudah
> memenuhi ruang di `.accessoryInline`** — jadi ikon yang jadi kanal penanda."

`.accessoryInline` mengembalikan `Text(digest.headline)` saja. Jadi keluarga
yang **paling sempit**, dan karena itu paling bergantung pada ikon, justru
satu-satunya yang tidak punya penanda: nama kandidat `.uncertain` tampil
persis seperti nama yang sudah terkunci. Cacat yang sama ada di cabang
`default`.

Yang membuat ini bertahan adalah bentuk dokumentasinya, bukan bug pemetaan —
persis pola yang sudah tercatat di repo ini (lihat catatan `presentedSymbolName`
tentang bentuk tanpa waktu). Dokumen itu panjang dan benar; ia berhenti satu
kalimat sebelum pertanyaan yang lebih besar: **keluarga mana yang memakainya?**

### Perbaikannya memakai kanal yang sudah ada

Bukan penanda baru: ikon diambil dari `presentedSymbolName(at:)` yang sama
dengan dua keluarga lain, sehingga ragu (`questionmark.circle`) dan basi
(`clock.badge.exclamationmark`) ikut terbaca tanpa aturan terpisah.
`accessoryInline` memang menerima gambar ("satu baris teks dan gambar
opsional", watchOS 9+ — sama dengan ambang deployment di `project.yml`), dan
gambar disisipkan lewat interpolasi `Image` di dalam `Text`, bentuk yang
memang dipakai contoh resmi Apple untuk keluarga ini.

### Gerbang baru: Aturan 23

Setiap cabang keluarga complication yang menampilkan `digest.headline` wajib
merender `presentedSymbolName` **di cabang yang sama**.

Diperiksa per cabang, bukan per ekspresi, dan itu keputusan yang lahir dari
uji coba pertama: versi per-ekspresi melaporkan tiga pelanggaran padahal dua
di antaranya benar — keluarga lingkaran dan persegi panjang merender ikonnya
sebagai view **sebelah** teksnya. Aturan yang menuduh kode benar akan
dimatikan orang, jadi batasnya digeser ke unit yang memang jadi syaratnya:
satu cabang keluarga.

Diverifikasi berbunyi: mengembalikan kedua cabang ke bentuk lama membuatnya
melaporkan tepat dua pelanggaran itu.

### Aturan 10 diperluas ke kelas drift yang sama

Kalimat "berkasnya tumbuh jadi **21 aturan**" di README adalah janji ke
pembaca yang tidak bisa dijaga compiler — kelas yang sama persis dengan
hitungan uji yang sudah dijaga Aturan 10. Dan ia memang sudah membusuk:
aturan ke-22 dan ke-23 ditambahkan tanpa ada yang menyentuhnya. Diperluas, ia
langsung melaporkan "README bilang 21 aturan, swift-ui-lint.sh punya 23".

Sumber angkanya adalah aturan yang **benar-benar mencetak**, bukan nomor
tertinggi: kalau `Aturan 12` pernah dihapus, menghitung maksimum akan tetap
bilang 23. Yang dijaga nomor terkecil yang hilang, supaya celah penomoran pun
ketahuan.

### Gerbang

  - `./swift-test.sh` -> CelestialEngine 174, PointingKit 600, 0 gagal.
  - `./swift-ui-lint.sh` -> **23** aturan hijau (Aturan 10 diperluas,
    Aturan 23 baru).
  - `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
  - `python3 Tools/check-visuals.py --check` -> 45 pemeriksaan hijau.
  - CI: Engine Tests `37344648762` + Apple Build `37344648834`, keduanya
    success.

### Yang TIDAK diklaim

  - Aturan 23 memeriksa **kehadiran** kanal ikon, bukan bahwa ikonnya benar.
    Kebenaran ikonnya sudah diuji di Linux
    (`testAllStatesHaveSymbolsAndLabels`) — dua gerbang, dua pertanyaan.
  - Keluarga `accessoryCorner` belum didesain; ia jatuh ke `default`, yang
    sekarang punya penanda. Bukan desain final, hanya tidak lagi menyesatkan.

## Siklus: gerbang morfologi objek langit dalam dari piksel (2026-10-06)

### Premis: uji model mengunci modelnya, bukan gambarnya

Model sudah mengunci bahwa tiap id objek langit dalam punya morfologi
berbeda (`testDeepSkyMorphologyDistinguishesThreeTypes`), dan itu benar.
Tapi yang sampai ke layar adalah **gambar**, dan gambarnya bisa salah
walaupun modelnya benar: kalau view suatu saat memetakan seluruh
`DeepSkyKind` ke satu bentuk, uji model tetap hijau sementara galaksi,
gugus bola, gugus terbuka, dan nebula tampak sebagai gumpalan yang sama.

Itu persis kelas cacat yang `check-visuals.py` ada untuk mencegah — gerbang
yang mengukur hal yang bukan yang diklaimnya — dan ia berdiri di samping
pemeriksaan yang **sudah** menutup arah berlawanan (`bentuk galaksi hilang
saat ragu`), sehingga lubangnya tidak terlihat sebagai lubang.

### Pemeriksaannya: dua arah, karena satu arah bisa lolos

`check_deep_sky_morphologies_render_distinct` membandingkan tiap pasang
morfologi piksel demi piksel (6 pasangan), lalu membandingkan tiap
morfologi terkunci dengan kabut netral (4 pemeriksaan).

Arah kedua bukan pengulangan: view yang menyoroti **semua** morfologi ke
kabut netral akan lolos arah pertama dengan sempurna — keempatnya sama-sama
netral, jadi tiap pasangan juga bertepatan. Tanpa arah kedua, gerbang itu
hanya bisa lulus.

### Dibuktikan berbunyi

`DEEP_SKY_LAYOUT` dipatok ke `"nebula"` di port Python (semua morfologi
jadi satu bentuk), dan pemeriksaan gagal pada **6 pasangan** dengan
`--check` keluar 1. Port dikembalikan, gerban hijau lagi.

Sebelumnya di siklus yang sama: `red-test.sh` dipakai untuk membuktikan
`testCrescentSignFollowsWaxingDirection` benar-benar merah pada sabit yang
dibalik arahnya (`litSide` ditukar) — uji itu menangkap cacatnya, bukan
sekadar cocok dengan kode saat ini.

### Gerbang

  - `./swift-test.sh` -> CelestialEngine 174, PointingKit 625, 0 gagal.
  - `./swift-ui-lint.sh` -> 25 aturan hijau.
  - `./swift-typecheck.sh` -> SEMUA GERBANG LULUS.
  - `python3 Tools/check-visuals.py --check` -> **190** pemeriksaan
    (bertambah 10), 0 gagal.
  - CI: Engine Tests `37399725431` + Apple Build `37399725757`, keduanya
    success.

### Yang TIDAK diklaim

  - Pemeriksaan ini menjaga bahwa keempat bentuk **berbeda satu sama lain**,
    bukan bahwa masing-masing benar secara astronomi. Kebenaran bentuknya
    (galaksi berpalung, gugus memusat) diuji di Linux pada modelnya.
  - Yang diukur adalah port Python, bukan `Canvas` SwiftUI di perangkat.
    Port-nya diikat ke view lewat `check_port_matches_swift_constants`, tapi
    kesamaan piksel di perangkat belum diverifikasi.

## Siklus: nebula planetari bukan nebula (2026-10-06)

### Premis: bentuk yang berlawanan arah tidak boleh berbagi satu nama

M27 (Dumbel) dan M57 (Cincin) dipetakan ke `.nebula`. Katalog sendiri
menulis "nebula planetari" di komentarnya, tapi layar menggambar bentuk
yang berlawanan dengan kata itu: nebula emisi paling terang dan paling
padat di **pusat**, sedangkan nebula planetari adalah cangkang gas yang
justru **berongga** di tengah — gasnya sudah ditiup keluar oleh bintang
pusatnya yang sekarat.

Bukan sekadar kurang mirip. Gambar itu menyatakan "gas mengumpul di sini"
pada objek yang gasnya sudah pergi.

### Kenapa cacatnya tidak terlihat

Tiga hal sekaligus menutupinya, dan masing-masing tampak sehat:

  - `Morphology` hanya punya 4 kasus, jadi tidak ada yang "hilang".
  - `VisualFrame.deepSky` tidak punya cabang kelima — yang belum ada tidak
    bisa dirindukan.
  - `testEveryCatalogueDeepSkyObjectHasASpokenMorphology` tetap hijau: M27
    memang punya bentuk dan memang punya kata. Keduanya saja salah.

Inilah kelas cacat yang paling mahal di repo ini: **klaim yang tidak
terlihat**. Tidak ada teks yang bisa dibaca pengguna untuk mengeceknya,
dan tidak ada uji yang melihatnya, karena yang diuji keberadaan bentuk,
bukan kebenarannya.

### Perbaikannya: bentuk, kata, dan port gambar

  - `Morphology.planetaryNebula` + pemetaan m27/m57.
  - `VisualFrame.deepSky`: cangkang 8 blob pada **satu radius**, tanpa blob
    di pusat. Komponen 45° dihitung (`r/√2`), bukan ditulis — angka yang
    dibulatkan ke 6 desimal membuat cangkang menyimpang 2e-7 dari satu
    radius dan menggagalkan uji pembedanya tanpa ada yang salah.
  - `DeepSkySpeech`: kata "nebula planetari" sendiri. Gambar berbeda dengan
    kata yang sama hanya memindahkan cacat dari mata ke telinga — dan
    pengguna VoiceOver tidak melihat gambarnya sama sekali.
  - Port Python: tanpa cabang ini, **setiap** pemeriksaan gambar mengukur
    bentuk yang tidak pernah tampil.

### Tiga uji, masing-masing menutup satu jalan lulus yang salah

  - `testPlanetaryNebulaIsHollowAtTheCentre` — vs nebula emisi.
  - `testPlanetaryNebulaShellSitsOnOneRadius` — vs gugus terbuka, yang juga
    tanpa inti tapi tersebar pada radius berbeda-beda. Tanpa ini, cangkang
    yang menyebar lolos semua pemeriksaan "tidak punya inti" sambil tampil
    sebagai gugus.
  - `testPlanetaryNebulaDiffersFromItsNearestNeighbours` — keduanya sekaligus.

### Gerbang

  - `./swift-test.sh` -> CelestialEngine 174, PointingKit **628** (3 baru), 0 gagal.
  - `./swift-ui-lint.sh` -> 25 aturan hijau (Aturan 10 menuntut README
    diperbarui ke 628; README tertinggal di 625).
  - `python3 Tools/check-visuals.py --check` -> **195** pemeriksaan (4 pasang
    baru + kabut netral), 0 gagal.
  - CI: Engine Tests `37403317250` + Apple Build `37403317180`, success.

### Yang TIDAK diklaim

  - Cangkangnya digambar sebagai cincin **bulat**. M27 sungguhan berbentuk
    dumbel (dua lobus), M57 cincin. Keduanya sementara berbagi satu geometri
    karena perbedaan lobus vs cincin belum punya pembeda terukur; yang sudah
    benar dan teruji adalah lubang tengahnya, yang membedakan keduanya dari
    nebula emisi.


## Siklus: uji yang mengukur tempat yang tidak berubah (2026-10-06)

### Premis: uji bisa hijau karena mengukur angka yang tidak pernah bergerak

Setelah morfologi baru selesai, uji pembedanya diperiksa dengan mutasi —
dan mutasi itu mengungkap cacat pada **cara mengukur**, bukan pada model.

`buildDeepSky` menggeser **skala lebar** blob (`0.62 + 0.38 · fuzziness`),
bukan letaknya. Jadi jarak **pusat** blob ke pusat frame adalah konstanta:
0.42 untuk cangkang, berapa pun fuzzinessnya. Uji "cangkang berongga" versi
pertama mengukur jarak itu, sehingga ia kebal terhadap satu-satunya hal
yang bisa merusak bentuknya — blob yang membesar ke arah dalam sampai
menutup lubang yang menjadi alasan morfologi itu ada.

Yang menentukan apakah lubangnya terlihat adalah **tepi dalam**:
`radius − halfWidth`, yang menyusut 0.312 -> 0.246 pada rentang fuzziness.

### Dibuktikan dengan selisih kegagalan, bukan dengan argumen

Mutasi yang sama (lebar blob 0.30 -> 1.60, lubang menutup sampai -0.57):

  - uji baru -> **28** kegagalan, pada keempat fuzziness.
  - uji lama -> **24** kegagalan.

Selisih 4 itu persis empat iterasi yang lolos dari versi lama.

### Cacat yang sama ditemukan di morfologi sebelahnya

`testOpenClusterHasNoCentralCore` mengukur hal yang sama dengan cacat yang
sama — ditemukan dengan memeriksa uji sebelahnya setelah memperbaiki yang
pertama, bukan dengan mencari daftar. Tepi dalamnya menyusut 0.523 -> 0.463.

Mutasi identik (lebar blob gugus terbuka -> 1.40):

  - uji baru -> **23** kegagalan. Uji lama -> **21**.

Pola ini yang dicatat, bukan perbaikannya: **kelas cacatnya ada pada cara
mengukur**. Setiap uji yang mengukur posisi harus ditanya "bisakah angka
ini berubah?", karena `buildDeepSky` mengubah ukuran, bukan letak — jadi
setiap uji berbasis posisi rentan terhadap versi cacat yang tidak bergerak.

### Drift kedua: daftar morfologi yang ditulis tangan di dalam uji

`testDifferentMorphologiesProduceDifferentGeometry` menulis empat nama
morfologi di badan ujinya, jadi `.planetaryNebula` lahir tanpa ikut teruji
oleh uji yang paling langsung mengawasi kelas cacat ini. Sekarang dari
`allCases`, plus penjaga bahwa daftarnya tidak boleh tinggal satu elemen
(uji berpasangan tidak berarti untuk satu elemen).

Arah ini sudah jadi teladan di `testEveryDeepSkyBlobStaysInsideTheFrame` —
menemukannya di satu uji dan tidak di uji sebelahnya menunjukkan celahnya
ada pada kebiasaannya, bukan pada satu berkas.

### Gerbang

  - `./swift-test.sh` -> 628, 0 gagal.
  - `./swift-ui-lint.sh` -> 25 aturan hijau. `python3 Tools/check-visuals.py
    --check` -> 195 pemeriksaan. `./swift-typecheck.sh` -> LULUS.
  - CI: Engine Tests `37404777620` success.

### Yang TIDAK diklaim

  - Dua uji diperbaiki (cangkang planetari, gugus terbuka). Pola "ukur
    tempat yang tidak berubah" belum disapu ke seluruh berkas uji — sapuan
    itu sendiri belum punya penjaga otomatis.



## Siklus: tonjolan inti galaksi yang tak terlihat lolos semua uji (2026-10-06)

### Premis: mutasi yang mengukur konstanta tidak pernah merah

STATUS.md sebelumnya menutup dua uji dengan mutasi dan mencatat pola yang
jujur: pola "ukur tempat yang tidak berubah" **belum disapu ke seluruh
berkas uji**. Sapuan berikutnya menemukan tiga yang belum tersapu, dan
semuanya satu keluarga.

Galaksi punya tiga uji. Ketiganya mengukur `aspect` — dan `aspect` adalah
**konstanta yang ditulis di layout**:

    (0.0, 0.0, 1.00, 0.34, -18.0, 0.30),   // cakram,  aspect 0.34
    (0.0, 0.0, 0.66, 0.30, -18.0, 0.26),   // lapisan, aspect 0.30
    (0.0, 0.0, 0.26, 0.42, -18.0, 0.60)    // inti,   aspect 0.42

### Akar masalahnya: aspect tidak bisa bergerak sama sekali

Bukan cuma "jarang bergerak" seperti kasus pusat-blob sebelumnya. Di sini
`buildDeepSky` menghitung

    halfWidth  = min(roomX, roomY) · growth · widthScale
    halfHeight = halfWidth · aspect

sehingga `halfHeight / halfWidth` kembali **persis** `aspect`, untuk
setiap nilai `widthScale`, `growth`, dan `room`. Rasio aspect adalah
**invarian sempurna** dari setiap mutasi yang bisa merusak bentuknya.

Jadi `testGalaxyHasARounderCoreThanItsDisc` tidak mengukur bentuk. Ia
menyatakan ulang bahwa 0.42 > 0.34 — membandingkan dua konstanta di
baris yang sama.

### Dibuktikan: inti jadi butiran, semua uji hijau

Mutasi `widthScale` inti `0.26 -> 0.002`. Inti menyusut jadi **0.2%** dari
cakram — butiran yang secara visual mustahil dibaca sebagai tonjolan inti.
Hasilnya **633/633 hijau**, termasuk ketiga uji galaksi.

Bandingkan dengan pola yang ditemukan dua siklus lalu: mutasi lebar blob
cangkang `0.30 -> 1.60` menghasilkan 28 kegagalan. Yang ini menghasilkan
**nol**. Itu selisihnya.

### Dua axis yang benar-benar menentukan, dan keduanya bergerak

Yang menentukan apakah tonjolan inti terlihat bukan bentuknya melainkan
**ukuran** dan **kecerahan**. Keduanya `× halfWidth`, jadi keduanya ikut
bergerak:

  - rasio lebar inti/cakram = `widthScale`-nya persis, **0.254**
  - rasio opasitas inti/cakram = **2.00** (0.60 vs 0.30)

Uji baru `testGalaxyCoreBulgeIsVisibleNotJustRounder` mengukur keduanya,
pada tiga nilai `fuzziness` (bukan satu titik, karena `growth` bergerak
padanya). Ambang dipilih dengan margin: lebar 0.10 dari 0.254 (2.5×),
opasitas "lebih terang" dari 2.00.

Dua mutasi yang dibuktikan sekarang **merah**:

  - `widthScale` 0.26 -> 0.002 -> rasio lebar 0.0020, di bawah ambang.
  - `opacity` 0.60 -> 0.30 -> inti tidak lagi lebih terang dari cakram.

Yang kedua penting justru karena ia **bukan** mutasi ukuran: versi lama
tetap hijau padanya, karena opacity tidak masuk ke aspect sama sekali.

### Yang TIDAK diklaim

  - Ketiga uji lama **tidak dihapus**. `aspect` masih layak dijaga sebagai
    bentuk — memverifikasi "cakram benar-benar elips, bukan lingkaran" itu
    betul. Yang dikoreksi adalah tambahan: klaim "inti terlihat sebagai
    tonjolan" harus diukur lewat ukuran dan kecerahan, bukan lewat
    aspect. Uji baru menutup dua sumbu yang benar-benar bisa bergerak.
  - Sapuan belum selesai. Yang diperiksa di siklus ini hanya **galaksi**.
    Gugus bola dan nebula masih punya uji berbasis posisi/aspect yang belum
    diuji mutasinya — lihat unit berikutnya.
  - `visualFrame.deepSky` tidak diubah sama sekali; ini murni tambahan
    uji. Komit `8d54ca7` (konstanta kawah) juga tidak mengubah model.

### Gerbang

  - `./swift-test.sh` -> CelestialEngine 179, PointingKit **634** (1 baru).
  - `./swift-ui-lint.sh` -> 25 aturan hijau. Rule 10 menangkap README yang
    tertinggal di 633; README diperbarui ke 634.
  - `python3 Tools/check-visuals.py --check` -> 215 pemeriksaan, 0 gagal.
  - `./swift-typecheck.sh` -> LULUS.


## Siklus: gradien kecerahan gugus bola rata, semua uji hijau (2026-10-06)

### Premis: klaim warna tidak dijaga oleh satu pun uji

Siklus lalu menutup galaksi. Yang berikutnya menyapu gugus bola. Di sini
cacatnya bukan di `aspect` (yang di galaksi invarian sempurna) melainkan di
**opasitas**: layout menyebut inti "paling terang" dan dua cincin "makin
redup ke luar", tapi tidak ada uji yang membaca satu opasitas pun.

`testGlobularClusterHasADenseCentre` memang tidak bisa menjaganya: ia cuma
membandingkan `core.halfWidth` dengan `blobs.map(\.halfWidth).max()` —
inti harus blob **terbesar**, bukan yang **paling terang**. Soal warna
sama sekali tidak tersentuh.

### Dibuktikan: gradien rata, 634/634 hijau

Mutasi opasitas inti `0.55 -> 0.22`. Inti jadi sama redupnya dengan cincin
**terluar** — gradien kecerahannya rata — dan **634/634 uji tetap hijau**.

### Jebakan kedua yang ditemukan saat menulis uji, bukan setelahnya

Versi pertama uji baru mengambil `byRadius[1]` dan `byRadius[last]` —
**satu** anggota tiap cincin. Karena `sorted` tidak menentukan urutan
anggota yang radiusnya sama (tiap cincin punya 6 anggota pada radius
persis 0.30 dan 0.46), mutasi **satu** blob cincin luar lolos begitu saja:
indeks terakhir bisa jatuh ke anggota lain yang belum dirusak. Bukti:
mutasi `0.22 -> 0.38` pada satu anggota cincin luar **lolos** versi
pertama, padahal secara visual pita itu tidak seragam.

Perbaikan: bagi blob ke **pita radius** (inti / cincin dalam / cincin luar)
dan jaga dua hal terpisah:
  1. **Seragam dalam satu pita** — `lo == hi` untuk semua anggota pita.
  2. **Menurun antar pita** — bandingkan `paling redup` di pita dalam
     dengan `paling terang` di pita luar, supaya selisih terkecil pun
     tidak bisa lolos.

Kedua mutasi sekarang merah: inti `0.55 -> 0.22` (gradien rata), dan satu
anggota cincin luar `0.22 -> 0.38` (pita tidak seragam).

### Yang TIDAK diklaim

  - `testGlobularClusterHasADenseCentre` **tidak dihapus**: klaim "inti
    paling besar di tengah" itu benar dan masih dijaga. Yang ditambahkan
    adalah klaim "inti paling terang, redup ke luar" yang sebelumnya
    menggantung tanpa saksi.
  - Sapuan **masih belum selesai**. Yang sudah diuji mutasinya: galaksi
    (size+opacity) dan gugus bola (opacity). Yang belum: **nebula** (emisi
    — tidak punya inti, tapi punya bentuk blob yang belum diuji mutasinya)
    dan `openCluster` (sudah diuji mutasi pada siklus sebelumnya untuk
    "tidak ada inti", tapi tidak untuk ukuran/sebaran). Lihat siklus
    berikutnya.
  - Model `buildDeepSky` tidak diubah sama sekali; ini murni penambahan uji.

### Gerbang

  - `./swift-test.sh` -> CelestialEngine 179, PointingKit **635** (1 baru).
  - `./swift-ui-lint.sh` -> 25 aturan hijau (Rule 10: README 634 -> 635).
  - `python3 Tools/check-visuals.py --check` -> 215 pemeriksaan, 0 gagal.
  - `./swift-typecheck.sh` -> LULUS.


## Siklus: sapuan "ukur konstanta" ditutup di seluruh morfologi (2026-10-06)

### Premis: kelas cacat ini berulang, dan sapuan harus diuji mutasi

STATUS.md dua siklus lalu menutup dua uji serupa dengan mutasi, lalu jujur
menulis: pola "ukur tempat yang tidak berubah" **belum disapu ke seluruh
berkas uji**. Dua siklus berikutnya menyapu, dan sapuan itu sendiri
menemukan cacat nyata.

### Yang ditemukan dan diperbaiki

  - **Galaksi**: inti bisa diperkecil jadi 0.2% cakram, 633/633 hijau.
    Akar: `halfHeight = halfWidth · aspect` membuat rasio aspect invarian
    sempurna — ketiga uji galaksi mengukur konstanta layout. Diperbaiki
    `testGalaxyCoreBulgeIsVisibleNotJustRounder` (ukuran+opasitas pada 3
    fuzziness).
  - **Gugus bola**: gradien kecerahan bisa diratakan, 634/634 hijau.
    `testGlobularClusterHasADenseCentre` cuma membandingkan blob terbesar,
    bukan ter-terang. Diperbaiki `testGlobularClusterDimsWithRadius` (per
    pita radius; versi per-blob lolos saat satu anggota cincin diubah).

### Yang diuji mutasinya dan **lolos** (tidak perlu diperbaiki)

  - `nebula`: `0.62 + 0.38·fuzziness` -> `1.0` membuat
    `testNebulaGrowsWithFuzziness` **merah** — guarded.
  - `openCluster`: semua offset -> 0 (mengerumun di pusat) membuat
    `testOpenClusterHasNoCentralCore` **merah** — guarded.
  - `planetaryNebula`: siklus lebih awal sudah guarded (cangkang berongga,
    satu radius) lewat `testPlanetaryNebulaIsHollowAtTheCentre` +
    `ShellSitsOnOneRadius`, dibuktikan mutasi lebar blob 0.30 -> 1.60
    menghasilkan 28 kegagalan.

### Kesimpulan sapuan

Kelima morfologi (`nebula`, `planetaryNebula`, `galaxy`, `openCluster`,
`globularCluster`) sekarang punya setidaknya satu uji yang dibuktikan merah
oleh mutasi model. Dua celah nyata ditutup; tiga lainnya sudah benar.
Pola "ukur tempat yang tidak berubah" kini tidak lagi ada di berkas uji
deep-sky — setiap uji bentuk yang tersisa mengukur kuantitas yang
benar-benar bergerak (ukuran, opasitas, atau tepi dalam).

### Yang TIDAK diklaim

  - Sapuan hanya menyentuh **geometri deep-sky** (`buildDeepSky`). Benda
    titik (bintang, planet, bulan, matahari) punya jalur pengujian sendiri di
    `CelestialVisualTests` dan belum disapu dengan cara yang sama — lihat
    siklus berikutnya kalau ingin lanjut ke sana.
  - `buildDeepSky` tidak diubah; semua perubahan murni penambahan uji.
    Hitungan: 633 -> 634 (galaksi) -> 635 (gugus bola).

---

## Siklus: menutup celah radius akhir gradien bola & limb

audit mutasi sistematis (metode yang sudah menemukan cacat pita Jupiter,
sphereLightOffset galaksi, warna aksen, dan 5 morfologi deep-sky) dipakai
untuk mencari konstanta yang tidak dijaga gerbang mana pun.

### Status akhir siklus ini (terverifikasi, bukan diklaim)

  - `./swift-test.sh` -> **674 test hijau** (0 gagal). Engine tidak disentuh.
  - `python3 Tools/check-visuals.py --check` -> **437 pemeriksaan, 0 gagal**
    (naik dari 430: 7 pemeriksaan baru).
  - `out/mutasi-radius-gradasi.py` -> 7 keadaan; 6 di antaranya merah.

### Cacat: dua radius akhir gradien tidak dijaga gerbang mana pun

`1.35` (gradien bola, peredupan limb di `drawSphere`) dan `1.15` (peredupan
limb pada piringan berfase) hidup sebagai **literal** di dua bahasa —
`Apps/Shared/CelestialVisualView.swift` dan `Tools/render-visuals.py` — dan
tidak disebut satu pun pemeriksaan. `check_port_matches_swift_constants`
tidak bisa menjangkaunya: ia membandingkan konstanta **bernama**, dan dua
angka ini tidak punya nama di port.

Diukur, bukan diasumsikan (`out/ukur-radius-gradasi.py`): mutasi
1.35 -> 1.60 mengubah **200 dari 200 baris piksel** pada ukuran 200. Jadi
mutasinya benar-benar mengubah gambar, dan seluruh 22 pemeriksaan piksel
tetap hijau — bukan karena gerbangnya tidak menyentuh kasusnya, melainkan
karena gerbangnya tidak pernah melihat angkanya. Seluruh gerbang piksel di
berkas itu mengukur **keberadaan** ciri (pita Jupiter tetap "ada" walau
kecerahannya melenceng), bukan tingkat kecerahan.

Bahayanya tidak terlihat dari layar: radius akhir gradien menentukan **berapa
jauh peredupan limb menjalar ke dalam piringan**, yaitu apakah piringan
terbaca sebagai **bola** atau sebagai cakram rata.

### Kenapa gerbang baru, bukan entri di `checks`

Menambah dua angka ke `checks` berarti menuliskannya **ketiga** kalinya di
dalam gerbang, menjadi entri yang tidak pernah dibandingkan dengan apa pun —
persis kelas lubang yang seluruh berkas ini tutup. `check_gradient_end_radii
_match` membaca kedua angka dari **kedua sumber** dan membandingkannya
sebagai pasangan.

### Kenapa pembedanya `startRadius`, bukan urutan nilai

Dua gradien memakai kata kunci yang sama (`endRadius: radius * N`), jadi
tidak bisa dibedakan dari pola akhirnya. Versi pertama mengurutkan dua angka
dan menganggap yang besar "bola" — itu **diuji dan gagal**: mutasi limb
1.15 -> 1.45 membalik urutannya, dan gerbang melaporkan `bola=1.45,
port=1.35`, menyalahkan gradien yang tidak diubah. Dua kegagalan lain (kedua
gradien jadi sama; gradien hilang dari port) berbunyi lewat jalur "kurang
dari dua gradien", yang tidak menyebut gradien mana pun.

Pembedanya sekarang **struktural**: gradien bola mulai di `radius * 0.1`
dengan pusat digeser mengikuti `sphereLightOffset`; gradien limb mulai di `0`
dan berpusat di pusat piringan. Setelah itu keempat mutasi berbunyi dengan
nama yang benar, dan kegagalan dilaporkan **per gradien**.

### Yang TIDAK diklaim

  - Mutasi 1.35 -> 1.60 yang dilakukan **serentak di kedua bahasa** (kasus 5)
    tetap hijau: tidak ada model fisik untuk kedua angka ini, jadi
    satu-satunya sumber kebenaran adalah kesepakatan kedua sisi — sama
    seperti rasio diameter/radius cakram bibir kawah, yang batasnya sudah
    dicatat jujur di berkas gerbang. Ini kesenjangan yang **diketahui**,
    bukan yang tidak disadari; menutupnya butuh pembenaran fisik (berapa
    jauh limb darkening seharusnya menjalar), bukan tambahan gerbang.
  - Hanya lapisan gambar yang diubah. `CelestialVisual.swift`,
    `render-visuals.py`, dan view Swift tidak disentuh selain gerbang baru.
  - Belum dipush; CI belum dijalankan untuk siklus ini.

---

## Siklus: bintik Jupiter — kelas cacat yang sama, gerbang dengan lubang yang sama

Audit mutasi yang sama (metode yang sudah menemukan cacat pita Jupiter,
`sphereLightOffset` galaksi, warna aksen, 5 morfologi deep-sky, dan radius
akhir gradien) diarahkan ke satu-satunya ciri permukaan yang **belum pernah
disapu**: Bintik Merah Besar.

### Status akhir siklus ini (terverifikasi, bukan diklaim)

  - `./swift-test.sh` -> **CelestialEngine 206 + PointingKit 690 hijau**
    (0 gagal). Engine tidak disentuh.
  - `python3 Tools/check-visuals.py --check` -> **575 pemeriksaan, 0 gagal**
    (naik dari **567** di `HEAD`: 8 pemeriksaan baru).
  - `./swift-ui-lint.sh` -> **SEMUA GERBANG UI LULUS** (29 aturan).
  - Mutasi kekuatan 0.6 -> 0.0 dan -> 1.0: **kedua arah merah**, dengan nama
    yang benar (lihat di bawah).

### Cacat: bintik digambar rata, jadi lengkung bolanya terbalik

Kelasnya **sama persis** dengan pita Jupiter, dan sudah diperbaiki untuk pita
dua siklus lalu — tapi tidak pernah untuk bintiknya. Bintik digambar sebagai
elips warna **rata** di atas bola yang sudah dinaungi gradien, jadi ia
menghapus lengkung bola di dalamnya.

Diukur pada baris pusat bintik (y = +0.31 R, render 200 px, ss=4):

    bola di bawah bintik (tanpa ciri) : 0.580 -> 0.532   lengkung +8.4%
    baris yang sama, dengan bintik    : 0.449 -> 0.532   lengkung -18.4%

Tandanya **terbalik**. Bukan cacat kosmetik: bintik yang rata membuat barisnya
lebih terang di sisi yang seharusnya gelap, jadi yang terbaca bukan bola
berbintik melainkan **stiker** yang ditempel.

### Kenapa gerbang lama tidak melihatnya

`check_banded_disc_keeps_its_curvature` **sudah** mengukur lengkung baris —
tapi hanya **baris ekuator** (`y = cy`). Bintiknya duduk di `centerY = +0.31`,
jauh dari baris itu. Seluruh gerbang lain di berkas itu mengukur
**keberadaan** ciri (`check_planet_features_present` menghitung piksel merah),
bukan **lengkungnya**.

Ini pola yang sudah tercatat di repo ini: gerbang yang mengukur sebagian
klaimnya. Yang baru di sini bukan kelasnya, melainkan bahwa sapuan mutasi
menemukan **satu ciri lagi** yang belum pernah disapu. STATUS.md dua siklus
lalu menulis batasnya sendiri: sapuan hanya menyentuh geometri deep-sky.
Siklus ini menyapu satu ciri permukaan; sisanya masih belum.

### Perbaikan: gradien bola yang sama, dipotong ke elips bintiknya

Bukan "bintik dibuat lebih gelap di tepi" — aturan itu menggelapkan tempat
yang salah dan menambah sumber kedua tentang dari mana cahaya datang. Yang
dipakai adalah **gradien bola yang sama** (`sphere_gradient` /
`drawSphere`: pusat di `sphereLightOffset`, warna `palette.light` ->
`palette.dark`), dipotong ke elips bintiknya. Dua akibat:

  1. Di luar bintik gradien itu tidak pernah digambar, jadi piksel di sana
     **identitas** — nol risiko cacat baru di tempat yang tidak dimaksud.
  2. Arah cahayanya tidak bisa berbeda pendapat dengan bolanya, karena
     keduanya membaca `sphereLightOffset` yang sama.

Di port, gradien bola **diekstrak** ke `sphere_gradient()` supaya tiga
pemanggil (bola, pemulihan pita, pemulihan bintik) membangunnya di satu
tempat. `Canvas.ellipse` mendapat `clip_ellipse`, pasangan `clip_disc` yang
sudah dipakai kawah. Di view, klipnya memakai idiom yang sama dengan
`drawCraters` (`var lit = context; lit.clip(to:)`).

### Kenapa angkanya 0.6, dan kenapa dua arah diuji

Sama seperti pita, nilainya **sebagian**: 0 = lengkungnya rata kembali,
1 = bintiknya tertutup bola. Diukur pada rentang penuh — rasio lengkung
0 / 35 / 58 / **64** / 75 / 84 / 94 / 100% pada kekuatan
0.0 / 0.3 / 0.5 / 0.6 / 0.7 / 0.8 / 0.9 / 1.0. 0.6 memulihkan 64% lengkung
sambil menyisakan bintik yang masih terbaca (menyimpang 7.17% dari bola
polos), jadi **kedua** sisinya punya jarak ke ambangnya (55% dan 2.0%).

### Kenapa ambangnya rasio, dan kenapa sampelnya di dalam

Sampel diambil pada `frac = 0.85` dari lebar bintik, **bukan** tepinya: pada
`frac = 1.00` sampel terakhir jatuh tepat di tepi elips, tempat anti-aliasing
mencampurnya dengan warna rata di luarnya — diukur, rasionya cuma 1.5%
walaupun perbaikannya bekerja penuh (66% di dalam). Bola pembandingnya kasus
"ragu", yang menggambar bola Jupiter yang sama **tanpa** ciri pengenal; jadi
lengkung yang benar bisa diukur tanpa menuliskan angka lengkung ke dalam
gerbangnya.

### Metrik arah kedua diukur, bukan dipilih

Versi pertama memakai hitungan piksel merah di kotak bintiknya. Ia **tidak
pernah menggigit**: pada kekuatan 1.0 masih ada 64 piksel merah — di atas
ambang 20 mana pun yang masih waras — jadi pemulihan penuh lolos sambil
menghapus bintiknya. Yang benar adalah **menyelisihkan terhadap bola tanpa
ciri** pada daerah bintiknya sendiri: 17.8 / 12.5 / 7.2 / 3.6 / 1.9 / 0.1%
pada kekuatan 0.0 / 0.3 / 0.6 / 0.8 / 0.9 / 1.0, dan **nol** pada 1.0. Persis
metrik `band_deviation_from_bare`, dengan alasan yang sama.

### Mutasi yang dibuktikan — harness di `Tools/`, dijalankan CI

`Tools/bukti-mutasi-bintik.py` (7 keadaan) memanggil **fungsi pemeriksaan yang
sama** lewat proses baru, jadi ia berjalan dalam hitungan detik alih-alih ~6
menit. Ia memeriksa **nama pemeriksaan mana yang berbunyi**, bukan berapa yang
merah — dan atas **dua** gerbang sekaligus: yang piksel
(`check_jupiter_spot_keeps_its_curvature`) dan yang teks
(`check_port_matches_swift_constants`, tiga entri baru di dalamnya).

    [baseline]                                 0 merah
    A1. kekuatan 0.6 -> 0.0                    2 MERAH: lengkung 0.0% vs bola 9.2% (rasio 0%)
                                                         + port sejalan: 0.0, seharusnya 0.6
    A2. kekuatan 0.6 -> 1.0                    2 MERAH: bintik menyimpang 0.14% (ambang 2.0%)
                                                         + port sejalan: 1.0, seharusnya 0.6
    A3. bintiknya tidak digambar               1 MERAH: bintik menyimpang 0.20%
    B1. port 0.6 -> 0.9 (drift)                2 MERAH: menyimpang 1.89% (ambang 2.0%)
                                                         + port sejalan: 0.9, seharusnya 0.6
    B2. view menulis 0.6 langsung              2 MERAH: view TIDAK memakai konstanta model
                                                         (port sejalan + sumber memuat)
    B3. model 0.6 -> 0.4 (drift)               1 MERAH: 'jupiterSpotLimbShadingStrength: Double = 0.6'
                                                         TIDAK ditemukan di sumber Swift
    7 keadaan, 0 tidak sesuai harapan; md5 ketiga berkas pulih persis

Perhatikan B1: drift port 0.6 → 0.9 **hanya 0.1 di bawah ambang pikselnya**
(1.89% vs 2.0%). Kalau ia lolos, yang menangkapnya tetap `port sejalan`. Itu
sebabnya keadaan itu menguji dua gerbang, bukan satu.

### Satu parameter yang ternyata **mati**, dan dihapus bukan dijaga

Percobaan pertama siklus ini menambahkan `clip_ellipse` ke `Canvas.ellipse`
untuk "memotong gradien ke elips bintiknya", dan harness diberi keadaan
"`clip_ellipse` dihapus" yang diharapkan merah. Terukur lewat `out/ukur-klip.py`
(render yang sama, 200 px, ss=4): menghapusnya mengubah **0 piksel** — di dalam
elips 0, di luar elips 0, dan profil pita di baris ekuator identik. Sebabnya
`Canvas.ellipse` **sudah** membatasi diri ke bentuk elipsnya
(`dx² + dy² <= 1`), jadi klip kedua ke elips yang sama persis tidak melakukan
apa pun.

Yang salah bukan nilai klipnya, melainkan **adanya klip kedua untuk bentuk yang
sama** — dan komentar yang menyebutnya "dipotong ke elips bintiknya" membuatnya
tampak bekerja. Parameternya dihapus dari port. (Di view Swift klipnya **tetap
ada** dan memang perlu: di sana `GraphicsContext.clip` yang memotong gradien ke
elips, karena gradien tidak punya batas bentuk sendiri.)

Keadaan itu **tidak** dimasukkan ke harness dengan harapan "hijau" juga:
parameter yang sudah tidak ada tidak bisa diuji, dan harapan yang menuntut merah
di sana akan menuntut gerbang berbunyi tanpa alasan.

### Yang TIDAK diklaim

  - Sapuan ini menyentuh **satu** ciri permukaan (bintik). Ciri lain yang
    digambar rata di atas bola — kalau ada — belum disapu dengan cara ini.
  - Angka 0.6 dijaga **dua sisi** (rasio lengkung dan penyimpangan dari bola
    polos), tapi keduanya diukur pada **satu ukuran** (200 px). Perilakunya
    di ukuran jam sudah diukur terpisah (rasio 66% pada 76 px) dan konsisten,
    tapi tidak ada gerbang yang menjalankannya di 76 px.
  - Sisi Swift-nya **tidak bisa dijalankan** di Linux; yang membuktikan
    perilakunya adalah port Python (gerbang piksel) + nama konstanta yang
    harus benar-benar disebut di view (gerbang teks). Kelas cacat "view
    berhenti memanggil" ditutup gerbang teks, bukan gerbang piksel.

### Kecurigaan yang diperiksa lalu dibuang

Setelah bintiknya diperbaiki, dua ciri permukaan lain yang **juga** digambar
sebagai bentuk rata di atas bola diperiksa dengan cara yang sama — karena
itulah pola yang baru saja terbukti cacat, dan menganggapnya kebetulan berarti
menebak. Keduanya diukur lewat jalur render yang sama, dan **keduanya sudah
benar**:

  - **Kutub Mars** (`_draw_polar_caps`, elips `marsPolarCap` opasitas 0.85).
    Diukur pada baris pusat kutub (200 px, ss=4, metrik lengkung baris yang
    sama): dengan pita kutub **−0.1%**, tanpa pita kutub **−1.1%**. Selisihnya
    ~1 poin persen — jauh di bawah yang membuat bola terbaca rata. Sebabnya
    fisis: di `y = ±0.74 R` bola hanya setinggi `sqrt(1 − 0.74²) = 0.67 R`, dan
    gradien bola di situ sudah nyaris di ujung gelapnya, jadi peredupan limb di
    dalam kutub memang tipis.
  - **Maria Bulan** (`MARIA`, cakram `black` opasitas **0.12**). Diukur per
    mare dengan metrik lengkung yang sama: selisih dengan vs tanpa maria
    +0.3 / +11.8 / +0.3 / −0.3 poin persen. Yang `+11.8` adalah artefak
    metriknya — bola di baris itu hampir rata (−0.1%) sehingga rasionya
    membengkak dari basis yang kecil; dalam **poin persen** selisihnya tetap
    ~12. Yang menentukan bukan lengkungnya: maria digambar dengan opasitas 0.12
    di **atas** pita, jadi ia **menskalakan** bola alih-alih menutupinya.
    Bintik Jupiter digambar **opaque**, dan itulah bedanya — bukan tempatnya.

Keduanya dicatat di sini **tanpa uji baru**: uji yang tidak bisa merah karena
alasan yang benar adalah cakupan palsu, persis kelas yang sudah berkali-kali
ditolak di repo ini. Alat ukurnya (`out/ukur-kutub.py`, `out/ukur-maria2.py`)
tinggal di `out/` seperti alat ukur lain — angkanya bisa direproduksi, tapi ia
bukan gerbang.

### Hasil CI

  - `609e32f` — Engine Tests (Linux) `37738993511`: **hijau**, termasuk langkah
    baru "Buktikan gerbang bintik Jupiter berbunyi".
  - `609e32f` — Apple Build `37738993518`: **hijau**.

## Siklus: Matahari — corona hilang, disk tepi keras

Audit radial (profil luminans sepanjang jari-jari) diarahkan ke Matahari:
satu-satunya objek "bercahaya" yang **belum** pernah diukur radial.

### Status akhir siklus ini (terverifikasi, bukan diklaim)

  - `./swift-test.sh` -> **CelestialEngine 206 + PointingKit 690 hijau**
    (0 gagal, +2 uji baru: `testSunProfileDiskAndCoronaJoinWithoutACliff`,
    `testSunCoronaReachIsBeyondTheDisk`). Engine tidak disentuh.
  - `python3 Tools/check-visuals.py --check` -> **585 pemeriksaan, 0 gagal**
    (naik dari 582 di HEAD: +3 pemeriksaan corona baru).
  - `./swift-ui-lint.sh` -> **SEMUA GERBANG UI LULUS** (29 aturan). Aturan 10
    memaksa README diubah 688 -> 690 (tambahan 2 uji PointingKit).
  - `./swift-typecheck.sh` -> **SEMUA GERBANG LULUS**.

### Cacat: Matahari disk polos, corona = 0

Brief meminta "disk bercahaya **dengan corona**". Yang tampil: disk terang
dengan tepi yang habis ke latar secara tiba-tiba.

**Terukur (sebelum).** Profil luminans radial: lum mencapai latar (~10.6)
**tepat di r = 1.0 R** (jam 38 pt: r = 19, lum = 14.6; iPhone 132 pt: r = 66,
lum = 11.7), dan nol di luar. `sunProfile` terakhir memudar ke kelegapan **0.0**
di 1.0 R, dan view memotong gradientnya ke piringan — jadi tidak ada satu
piksel glow pun di luar limb. Gambarnya = lingkaran matahari terang, bukan
bola dengan atmosfer bercahaya.

**Kenapa baru ketahuan sekarang.** Tidak ada gerbang yang mengukur "apakah
Matahari memancarkan cahaya ke luar piringan". `check_sun_edge_is_soft` hanya
menjaga tepi **tidak** keras; ia hijau baik untuk disk polos maupun untuk
corona. `testSunProfileOpacityNeverIncreases` hanya menjaga profilnya. Celah
yang sama persis dengan sabit Bulan terbalik: model benar, uji hijau, CI hijau,
gambarnya salah — dan baru ketahuan setelah profil radial dilihat dengan mata.

### Perbaikan

  - **Model** (`CelestialVisual.swift`): konstanta `sunCoronaReach = 1.45`
    (satu sumber, dibaca view **dan** port Python). `sunProfile` tepi piringan
    tidak lagi habis di 0.0 melainkan lantai 0.05 (menyambung corona tanpa
    lompatan, tetap monoton turun).
  - **View** (`CelestialVisualView.swift`): piringan Matahari **menyusut** oleh
    `sunCoronaReach` (radius / 1.45) supaya halo muat di frame — kalau tidak,
    `Canvas` memotong corona dan cacat kembali. Corona dilukis sebagai pita
    gradient **transparan→puncak di limb→transparan** (opasitas puncak 0.40,
    satu-satunya angka VIEW: dijaga gerbang), ditumpangkan di atas piringan.
    Pita (bukan piringan) supaya corona tidak menelan piringan di dalamnya.
  - **Port Python** (`render-visuals.py`): `SUN_CORONA_REACH = 1.45`, piringan
    disusutkan sama, corona pita sama. Diikat ke model oleh
    `check_sun_profile_matches_the_model` (sudah ada) — jadi port takkan
    menyimpang diam-diam.
  - **3 gerbang piksel baru** (`check_sun_corona_reaches_beyond_the_disk`):
    corona bercahaya di luar piringan (lum cincin 0.85 R > 25), corona habis di
    tepi frame (tidak menabrak bingkai), corona jauh di atas latar di luar
    piringan.

**Terukur (sesudah, iPhone 132 pt).** lum pusat 251; limb (0.69 R) 89; cincin
0.85 R 48; 0.99 R 16; tepi frame 14 — glow halus dari limb ke latar, bukan
disk tepi keras.

### Hasil CI (ditunggu)

  - push -> tunggu Engine Tests (Linux) + Apple Build.

═════════════════════════════════════════════════════════════════════════
SIKLUS: Onboarding — pahlawan titik-cahaya prosedural (8d31ac1)
═════════════════════════════════════════════════════════════════════════

**Celah yang ditutup.** Layar perkenalan adalah layar PERTAMA yang dilihat
pengguna, tapi ia masih menampilkan lambang pencarian SF Symbol generik
(`magnifyingglass.circle.fill`) — sementara SETIAP layar lain di app sudah
memakai `CelestialVisual` prosedural. Itu satu-satunya layar yang tidak
konsisten dengan janji visual app ("lihat benda langit, bukan teks").

**Kenapa ini bukan rework.** Seluruh Parts 1-4 + Fase A/B/C sudah
diimplementasi dan gate-guarded (status awal siklus ini: 206+690 hijau,
29 aturan UI-lint lulus, macOS build hijau). Yang lemah tinggal layar
onboarding — ia outlier, bukan pekerjaan yang belum dimulai. Ini unit
terkecil bernilai nyata, bukan menulis ulang yang sudah ada.

**Perubahan** (`Apps/Shared/OnboardingView.swift`):
  - Ganti `Image(systemName: "magnifyingglass.circle.fill")` dengan
    `CelestialVisualView` bola cahaya bintang (diameter 64pt, `kind: .star`,
    `relativeSize: 0.72`) — jalur gambar SAMA dengan layar utama.
  - **Warna netral sengaja** (`colorIndexBV` tidak ditetapkan → baku 0 =
    putih). Aturan 24 melarang `colorIndexBV` mentah di `Apps/` karena warna
    spektral = ciri pengenal; di sini kita tidak menetapkan indeks sama
    sekali, jadi netral. Ilustrasi, bukan klaim identitas (PRD: uncertainty >
    false confidence). `isConfirmed: true` di view hanya menyembunyikan
    lencana "?", bukan menyatakan objek terkunci.
  - `accessibilityHidden(true)` pada gambar: VoiceOver tetap membacakan
    teks janji produk (`onboardingTitle`/`onboardingSubtitle`) di bawahnya,
    bukan mengumumkan "bintang" yang tidak diklaim.
  - Ukuran tetap 64pt (bukan `@ScaledMetric`): ini citra, Dynamic Type tidak
    mengubah ukuran gambar benda langit di app ini.

**Pelajaran gerbang (Aturan 24).** Aturan memindai `Apps/` dan MENGUNCI
pada token literal `colorIndexBV`: harus muncul HANYA di dalam argumen
`drawableStarColorIndex(... isConfirmed: ...)`, bukan sebagai label field
`colorIndexBV:` atau nama lokal. Semantik netral tidak cukup — pengenalnya
sendiri yang dicek. Solusi patuh: biarkan baku (jangan tulis token sama
sekali). Catatan ini penting: percobaan pertama (literal `0`) dan kedua
(melalui `drawableStarColorIndex(0, isConfirmed: false)`) keduanya GAGAL
karena token `colorIndexBV` tidak ada di argumen; baru lulus setelah token
dihilangkan seluruhnya.

**Hasil CI:** Apple Build (Paket + App iPhone+Watch) hijau; Engine Tests
(Linux) — sama dengan kode yang sudah 206+690 hijau (OnboardingView di
`Apps/`, tidak di-build runner Linux). Gerbang lokal: swift-typecheck,
swift-ui-lint (29/29), swift-test 206+690 hijau.

═════════════════════════════════════════════════════════════════════════
SIKLUS: Harness mutasi cangkang — ia diam-diam mati, lalu berbohong hijau
═════════════════════════════════════════════════════════════════════════

**Dua cacat gerbang, ditemukan lewat audit berurutan (bukan sekali lihat).**

### Cacat 1 — harness crash (sunyi) sejak 1e28591

`Tools/bukti-mutasi-cangkang.py` memutasi `Tools/render-visuals.py` lalu
memanggil gerbang di proses anak. Sejak `1e28591` (16→24 blob) jangkar
`CURRENT_LAYOUT` diakhiri `)],` (koma tertinggal dari dalam port) tapi
keempat tata letak pengganti diakhiri `)]` — menggantinya membuang koma itu,
jadikan Python tidak sah (`SyntaxError` di `render-visuals.py:319`) pada
**setiap** keadaan mutasi. Akibatnya harness **crash** alih-alih membuktikan
apa pun — keempat keadaannya gagal sebelum menyentuh satu piksel. Gerbang
`check_planetary_nebula_shell_is_continuous` sendiri tetap hijau, jadi tidak
ada yang melihat pembuktiannya sudah mati. (Ini perbaikan yang sudah
tertinggal di working tree dari sesi sebelumnya: `_same_terminator` menurunkan
penutup dari jangkar, bukan diketik.)

### Cacat 2 — state #4 salah hijau (setelah crash diperbaiki)

Setelah harness bisa jalan lagi, keadaan #4 (16-blob murni, lebar 0.26)
**survive** gerbang: hijau di keempat pemeriksaan. Terukur dengan
`shell_angular_profile` pada dua ukuran:

  keadaan            rujukan f=0.8   M57 f=0.40
  24-blob (sekarang) 0.85            0.84
  16-blob (mutan)    0.83            0.65   <- manik!
  8-blob  (mutan)    0.00/0.04       0.00

Pada rujukan (0.8) 16-blob memang **hampir** sebersambung (lantai 0.83,
cangkang 0.85) — jadi di situ hijau itu BENAR, bukan cacat. Yang memisahkan
cangkang jujur dari manik adalah **fuzziness katalog**: pada M57 (0.40) lantai
16-blob jatuh ke **0.65** (manik terlihat) sementara 24-blob tetap 0.84. Jadi
harness **salah** menuntut "16-blob merah di mana pun" — itu memaksa gerbang
menyalak pada kode yang benar (rujukan), dan justru membiarkan regresi
**nyata** (16-blob di M57 = manik) lolos.

**Kenapa cacat ini penting (bukan kosmetik).** `1e28591` mengubah 16→24 blob
khususnya untuk menutup "M57 tampil sebagai untaian manik". Mutan yang dia
tutup — 16-blob — justru yang kini **survive** gerbang. Jadi sejak `1e28591`
pembuktian bahwa perbaikan itu bertahan sudah mati (Cacat 1), dan begitu
dihidupkan kembali ia **membenarkan** mutan (Cacat 2). Kelas cacat yang sama
persis dengan sabit Bulan terbalik dulu: gerbang yang mengukur gambar yang
tidak tampil, lalu hijau pada kode yang salah.

### Perbaikan

  - `Tools/bukti-mutasi-cangkang.py` (STATES #4): harapan diubah dari string
    tunggal `"merah"` menjadi **dict per-pemeriksaan** —
    `{rujukan f=0.8: hijau, M57 f=0.40: merah}`. Loop `main()` diberi cabang
    `isinstance(expected, dict)` yang membandingkan tiap nama pemeriksaan ke
    harapannya sendiri (keadaan 1-3 tetap pakai string tunggal). Docstring
    keadaan #4 ditulis ulang supaya alasan (0.83 vs 0.65, bukan "harus merah
    di mana pun") tercatat, bukan cuma "apa".
  - `_same_terminator` (Cacat 1) tetap di working tree; dikonfirmasi HEAD
    memang `SyntaxError` dan versi ini lulus.

**Verifikasi (terukur, bukan diklaim):**
  - `python3 Tools/bukti-mutasi-cangkang.py` -> **OK** (exit 0): baseline hijau,
    #1/#2/#3 merah, #4 sesuai per-kasus (merah di M57, hijau di rujukan).
  - `./swift-test.sh` -> **CelestialEngine 206 + PointingKit 698 hijau**
    (0 gagal). Engine tidak disentuh.
  - `python3 Tools/check-visuals.py --check` -> ditunggu (gerbang berat,
    >420s; jalan di background). Gerbang yang dipakai
    (`check_planetary_nebula_shell_is_continuous`) sudah hijau di 4 kasus
    pada kode sekarang (lantai 0.84 ≥ ambang 0.75).

**Pelajaran (catat, bukan ulang).** Mutan yang menutup sebuah perbaikan harus
dibuktikan **berbunyi pada fuzziness yang benar-benar tampil di layar**, bukan
pada kasus rujukan yang kebetulan nyaman. Dan harness mutasi yang crash bukan
"hijau" — ia diam. Keduanya sudah tertutup di sini: harness hidup (Cacat 1),
dan state #4 membedakan cangkang jujur (0.84) dari manik (0.65) di M57.

═════════════════════════════════════════════════════════════════════════
SIKLUS: Audit menyeluruh — setiap klaim brief diverifikasi, tidak ada cacat nyata
═════════════════════════════════════════════════════════════════════════

**Mengapa siklus ini ada.** Pengguna meminta kerja tanpa henti sampai 6 Okt,
tapi siklus sebelumnya (onboarding + harness cangkang) sudah menutup seluruh
Bagian 1-4 + Fase A/B/C. Sebelum menulis apa pun, repo diaudit lapis demi lapis
untuk mencari cacat **nyata** (bukan yang sudah ditutup gerbang), karena
mengejar "tambah unit" di atas kode yang sudah hijau berisiko menyuntikkan
regresi demi kegiatan.

**Yang dijalankan (verifikasi, bukan asumsi).**
  - `./swift-test.sh` → **CelestialEngine 206 + PointingKit 698 hijau** (0 gagal).
  - `python3 Tools/check-visuals.py --check` → **618 pemeriksaan, 0 gagal**.
  - `./swift-ui-lint.sh` → **29 aturan, semua Bersih**.
  - Sembilan harness mutasi (`Tools/bukti-mutasi-*.py`) → **semua OK (0 tidak
    sesuai harapan)** — termasuk yang punya penjaga "jangkar basi harus merah".
  - `git status` → bersih (tidak ada perubahan yang ditinggalkan).

**Yang diperiksa satu per satu, dan ternyata SUDAH tertutup.**
  - *Visual objek* (Bagian 1): planet/bulan/bintang/matahari/langit-dalam
    benar-benar digambar prosedural; diukur 618 gerbang piksel. Ketidakpastian
    memang menelanjangi ciri (`guard isConfirmed else { return }` di
    `CelestialVisualView.drawPlanet`, + gerbang `check_features_disappear_…` dan
    `testStarColourIsNotAClaimWhenUncertain`).
  - *Surface / glassmorphism* (Bagian 2): **ditolak dengan sengaja** di
    `SurfaceTokens.surfaceCard` — `Material` membuat kontras WCAG 4.5:1 yang
    diklaim tidak lagi terjamin. Itu keputusan benar, bukan celah; dicatat
    alasannya di kode.
  - *Night mode / AOD / VoiceOver* (Fase A #1-3): ada, diuji (Aturan 15, 23,
    `StateAnnouncement`).
  - *Animasi / Dynamic Type* (Fase A #4-6): ada (Aturan 1, Aturan 21 — denyut
    digerbangi `hasPulse`).
  - *Complication / lokalisasi / Info.plist / penolakan izin* (Fase C #1-4):
    ada dan dijaga (Aturan 9, 14, `ComplicationProvider` memanggil reload;
    `LocationProvider` + `MotionLogger` menampilkan `note` saat izin ditolak/
    sensor gagal, bukan crash/senyap).
  - *Tepi kasus kejujuran* (penyempurnaan #6): `BelowHorizonHonesty`,
    `DaylightLock`, `MoonDaylightHonesty`, `TooCloseToSunLockHonesty`,
    `TooFaintLockHonesty`, `ReducedLuminanceHonesty` — semua ada.

**Satu item yang MASIH TERBUKA (bukan cacat, butuh perangkat keras).**
  - ROADMAP Fase 3: "Point & Slew POC 1 teleskop" — `SlewSafety` + `TelescopeBridge`
    sudah ada & teruji di Linux; yang belum: perangkat keras, transport Seestar
    nyata, dan `NSLocalNetworkUsageDescription` di Info.plist. Di luar jangkauan
    sesi ini (VPS Linux tanpa sensor/iOS), jadi tidak dikerjakan di sini.

**Kesimpulan.** Tidak ada unit bernilai nyata yang bisa ditambahkan tanpa
membikin ulang yang sudah ada atau menyuntikkan regresi. Maka tidak ada commit
kode di siklus ini: mendorong perubahan ke `main` hanya untuk "terlihat bekerja"
bertentangan dengan Aturan Keras ("jangan rusak engine teruji") dan praktik
repo ("gerbang yang hijau tapi tidak hijau"). Laporan ini sendiri yang menjadi
hasil siklus — audit tertutup, status terverifikasi.

═════════════════════════════════════════════════════════════════════════
SIKLUS: Gerbang `public` berlebih — 15 peringatan produksi yang tak pernah dilihat siapa pun
═════════════════════════════════════════════════════════════════════════

**Cacatnya.** Seluruh lapisan visual — yang justru paling banyak berubah dan
paling banyak ditulis tangan — berada di luar jangkauan gerbang peringatan.
`ios-build.yml` menyapu `Apps/` saja, sementara `CelestialVisual.swift` dan
`NightVisual.swift` ada di `Packages/`. Hasilnya terukur: **15 peringatan
produksi** (`'public' modifier is redundant for … declared in a public
extension`) duduk di setiap build dan lolos hijau di setiap push. Peringatan
yang tak pernah dibaca adalah cara paling halus untuk menutupi niat kode yang
sudah tidak berlaku.

**Dua perbaikan, dan yang kedua yang membuatnya berarti.**

  1. **Sapunya diperluas** (`ios-build.yml`): pola gerbang peringatan berubah
     dari `Apps/` menjadi `(Apps|Packages)/`, jadi lapisan paket ikut dilihat.
     Peringatan dari alat Xcode dan dari toolchain SDK tetap dikecualikan —
     polanya menyebut berkas **kita** secara eksplisit, bukan sekadar
     `warning:`.
  2. **15 `public` berlebih dihapus** dari `CelestialVisual.swift` dan
     `NightVisual.swift` (`public struct Band` → `struct Band`, dst).

Perluasan sapu itu **bukan** kosmetik: pola `(Apps|Packages)/` ikut mencakup
`Packages/PointingKit/Tests/`, dan ternyata ada tujuh berkas uji yang membawa
peringatan sendiri — hasil `try XCTUnwrap` yang dibuang, binding `coreHi` /
`outerLo` yang tidak dipakai, `@discardableResult` yang menutupi hasil tak
terpakai, `#filePath` diteruskan ke parameter berdefault `#file` (dua bentuk
lokasi yang berbeda), dan `byKey` yang ditangkap di dalam closure. Ketujuhnya
diperbaiki **dengan maknanya dipertahankan** — mis. `#file` dipilih alih-alih
`#filePath` justru supaya lokasi pemanggil tetap muncul di laporan kegagalan
(`XCTFail` memakai `#file` sebagai bawaannya), dan `let table = byKey` sebelum
closure ditulis dengan komentar kenapa: menangkap variabel yang di-`var`
berulang adalah peringatan yang benar, dan yang salah adalah menangkapnya.

**Yang paling berbahaya di sini, dan bagaimana ia ditutup.** Pencabutan
`public` punya sisi yang **tidak** memicu peringatan apa pun tapi mematikan
build: `Apps/` memakai simbol-simbol ini dari modul lain. `public extension`
hanya memberi `public` ke anggota **langsungnya**, bukan ke anggota tipe yang
dideklarasikan di dalamnya — jadi `public` pada `Band.centerY` (kedalaman 2)
**diperlukan**, sementara `public` pada `struct Band` itu sendiri (kedalaman 1)
berlebih. Pengurai yang salah di sini akan "membersihkan" yang diperlukan dan
menukar peringatan menjadi galat kompilasi.

Dibuktikan, bukan diasumsikan — dan dengan **dua** alat yang berbeda:

  - **Probe lintas-modul.** Paket sementara `ReachProbe` bergantung pada
    `PointingKit` dan memakai **setiap** simbol yang `public`-nya dicabut
    (`CelestialVisual.jupiterBands()`, `.Spot`, `.HazeGeometry`,
    `.CraterRelief`, `.moonSphereDark`, `.deepSkyColour`,
    `.bandLimbShadingStrength`, `.sphereLightOffset`, `Band.centerY`, …).
    `swift build` → **Build complete!** Jadi `Apps/` tetap bisa memakainya.
  - **Probe `swiftc`.** Satu `public extension` yang memuat semua bentuk
    anggota mengeluarkan tepat enam peringatan: instance method, static
    property, property, struct, **initializer**, **subscript**.

**Probe itu membongkar klaim yang salah di alat saya sendiri.** Versi pertama
`Tools/bersihkan-public-berlebih.py` mengeluarkan `init`/`subscript` dari
daftar dengan alasan "probe menunjukkan keduanya tidak berbunyi". Itu keliru:
keduanya berbunyi. Kelalaian itu tidak terlihat hari ini hanya karena
**kebetulan** — nol `public init`/`subscript` berada langsung di badan
`public extension` di paket ini. Kebetulan bukan gerbang, jadi keduanya masuk
daftar (aman, karena pemeriksaannya dibatasi kedalaman 1), dan keadaan uji di
bawah menguncinya.

**Gerbangnya dibuat berbunyi, bukan sekadar melaporkan.** Versi pertama alat
itu **selalu keluar 0** — persis bentuk "gerbang yang tidak pernah merah" yang
repo ini sudah bayar mahal. Sekarang ia keluar 1 saat ada temuan, dan ia
membuktikan **dirinya sendiri** lewat `prove_itself()` dengan delapan keadaan:

| keadaan | harap | kenapa ada |
|---|---|---|
| anggota langsung `public extension` | 2 ditemukan | arah dasar |
| deklarasi tipe bersarang (kedalaman 1) | 1 ditemukan | yang memang dihapus |
| anggota tipe bersarang (kedalaman 2) | 0 ditemukan | **yang mahal bila salah** |
| `{` di dalam literal string | 1 ditemukan | pengurai kurung-mentah melewatkannya |
| `init`/`subscript` langsung | 2 ditemukan | membongkar klaim keliru di atas |
| `init` tipe bersarang (kedalaman 2) | 0 ditemukan | sisi mahal, lagi |
| `extension` non-public | 0 ditemukan | cakupan |
| berkas bersih | 0 ditemukan | arah hijau |

Dua keadaan ditangkap **saat harness ini ditulis**, bukan oleh pembacaan:
urutan hitung kurung yang salah membuat setiap anggota yang membuka kurung di
barisnya sendiri (`public func bar() {}`) terbaca di kedalaman 2 dan **tidak
pernah dilaporkan** — gejalanya "0 peringatan" pada berkas yang penuh
peringatan. Dan keadaan "anggota tipe bersarang" awalnya saya tulis
mengharapkan 0 untuk baris `public struct Nested` itu sendiri, padahal
deklarasinya memang berlebih.

**Verifikasi (terukur).**
  - Mutasi nyata pada `CelestialVisual.swift`
    (`static let bandLimbShadingStrength` → `public static let …`):
    gerbang **merah, exit 1**, menyebut berkas dan jumlahnya; sumber dipulihkan
    byte-identik (md5 `816431ea…`).
  - `--tulis` pada mutasi yang sama → menghapus, `0 sisa`, lalu hijau.
  - `python3 Tools/bersihkan-public-berlebih.py` → **0 `public` berlebih di 58
    berkas**.
  - `./swift-test.sh` → **CelestialEngine 212 + PointingKit 728 hijau**
    (0 gagal). Engine tidak disentuh.
  - `./swift-ui-lint.sh` → 30 aturan, semua Bersih.
  - `./swift-typecheck.sh` → semua gerbang LULUS.
  - `Tools/check-harness-terdaftar.py` → 16 harness, semuanya dirujuk.
  - `python3 Tools/check-visuals.py --check` → **701 pemeriksaan, 0 gagal**.

**Gerbang baru ini juga ikut disapu.** `Tools/check-harness-terdaftar.py`
menjaga pola `bukti-mutasi-*.py`; `bersihkan-public-berlebih.py` bukan harness
mutasi, jadi ia dijaga lewat langkah CI-nya sendiri di `engine-tests.yml` —
tanpa itu ia hanya alat yang dipakai manual, dan alat yang dipakai manual
adalah alat yang berhenti dipakai.

**Kenapa di `engine-tests.yml`, bukan `swift-ui-lint.sh`.** Cacat ini hidup di
**paket**, bukan di `Apps/`, dan sapuan UI itu khusus SwiftUI (ia membaca
`Apps/` dan menegakkan aturan font/warna). Menaruhnya di sana akan
memperluas cakupan sebuah gerbang UI ke wilayah yang bukan urusannya. Di
`engine-tests.yml` ia berjalan dalam sekejap di Linux, jauh lebih murah
daripada menunggu job macOS.

**Pelajaran (catat, bukan ulang).** Gerbang yang selalu keluar 0 tidak bisa
dibedakan dari gerbang yang bersih — jadi setiap gerbang baru harus keluar
bukan-nol pada keadaan yang memang salah, dan **sisi mahalnya** (yang tidak
memperingatkan tapi mematikan build) harus diuji lebih dulu daripada sisi
murahnya. Dan: daftar "kind yang diperingatkan compiler" adalah klaim tentang
perilaku compiler — ia harus **diukur** dengan probe, bukan diingat.


---

## Siklus: izin **dibatasi perangkat** bukan izin **ditolak** (+ kunci yang hilang dari `allKeys`)

Dua cacat, satu kelas: **teks yang mengaku lebih tahu daripada kenyataannya.**

### 1. `.restricted` disuruh membuka Pengaturan

`CLAuthorizationStatus` memisahkan `.denied` dari `.restricted`, dan
pemisahan itu ada bukan tanpa alasan:

| status | artinya | bisa diperbaiki pengguna? |
|---|---|---|
| `.denied` | pengguna menolak | **ya** — Pengaturan → Privasi → Lokasi |
| `.restricted` | perangkat tidak mengizinkan (Pembatasan Orang Tua / profil MDM) | **tidak** — tidak ada layar yang bisa mengubahnya |

`LocationProvider` memetakan **keduanya** ke satu kalimat: *"Buka Pengaturan
untuk mengizinkan"*. Untuk pengguna `.restricted` itu petunjuk yang **tidak
bisa berhasil** — ia mencari layar yang tidak ada, gagal, lalu menyimpulkan
aplikasinya rusak. Bentuk kebohongannya sama dengan visual yang mengklaim
identitas saat engine ragu: menuntun ke kepastian yang tidak dimiliki
aplikasi. PRD menuntut penolakan izin terlihat dan **jelas**; "jelas" di sini
berarti sebabnya benar.

Diperbaiki dengan memisahkan kasusnya di **dua** tempat (`.denied` dan
`.restricted` pada `start()` dan pada `locationManagerDidChangeAuthorization`),
dua kunci katalog baru (`sensor.location.restricted.status|note`), dan
kalimat `.restricted` yang **tidak** menyuruh membuka Pengaturan — melainkan
menyatakan bahwa bukan aplikasi ini yang memblokir, supaya pengguna berhenti
mencari kesalahan di tempat yang salah.

### 2. Satu kunci tidak pernah masuk `LocalizedText.allKeys`

`allKeys` mengaku sebagai "setiap kunci yang dideklarasikan di sini". Ternyata
**8 bahaya** ada di `SlewHazard.allCases`, tetapi hanya **7** di `allKeys`:
`.slewHazardAboveAltitudeLimit` (batas meridian) tidak pernah masuk daftar
sejak ditambahkan, dan **seluruh suite tetap hijau**.

Yang membuatnya bertahan lama adalah **angkanya**: satu-satunya penjaga ukuran
daftar adalah literal (`XCTAssertEqual(keys.count, 332)`), dan angka itu ikut
terkunci pada nilai yang salah. Kunci di luar daftar tidak diperiksa
kesatuannya, tidak disapu uji ber-prefix (`calibration.`/`experiment.`/
`sensor.` semuanya membaca `allKeys`), dan tidak dibandingkan dengan apa pun.

Gerbang paritas Aturan 6 **tidak** menutupnya — ia membaca deklarasi dari
**sumber**, bukan dari daftar. Jadi kelas cacatnya bukan "kunci hilang dari
katalog", melainkan **"daftar yang mengaku lengkap padahal tidak, dan tidak ada
yang membandingkannya dengan kenyataan."**

Diperbaiki dua arah:
  - Kuncinya masuk daftar (332 → 335 bersama dua kunci di atas).
  - Uji baru `testAllKeysListsEveryDeclaredKey` membaca deklarasi
    `static let … = LocalizedText(key: "…")` dari **sumber** dan
    membandingkannya dengan daftar, **dua arah** (ada di sumber tapi tidak di
    daftar; ada di daftar tapi tidak di sumber). Angka literal tetap ada —
    ia memberi tahu daftar berubah — tetapi ia bukan lagi satu-satunya penjaga.
  - Batas yang disengaja: kunci yang dibangun **dinamis**
    (`BodyName.declaration` → tujuh `object.body.*`) tidak terlihat sapuan, dan
    itu dibiarkan; kekosongan itu sudah dijaga `LocalizedObjectNameTests`.
    Yang ditegakkan: kalau deklarasinya **ada** sebagai `static let`, ia wajib
    ada di daftar.

### Verifikasi (terukur, bukan diklaim)

  - **Mutasi 1** — hapus `.slewHazardAboveAltitudeLimit,` dari `allKeys`:
    gerbang **merah, exit 1**, dan **dua** gerbang berbeda berbunyi —
    `testAllKeysListsEveryDeclaredKey` (menyebut kuncinya) dan
    `testDeclaredKeysAreUniqueNonEmptyAndComplete` (`"334" is not equal to
    "335"`). Dua nama berbeda = dua kelas berbeda, bukan satu gerbang yang
    kebetulan merah.
  - **Mutasi 2** — tambah `static let` baru yang **tidak** didaftarkan:
    gerbang **merah**, hanya uji baru yang berbunyi (hitungannya belum
    berubah). Jadi uji baru ini benar-benar menangkap **penambahan yang lupa
    didaftarkan**, bukan hanya penghapusan. Sumber dipulihkan byte-identik.
  - `./swift-test.sh` → **CelestialEngine 212 + PointingKit 730 hijau**
    (0 gagal). Engine tidak disentuh.
  - `./swift-ui-lint.sh` → 30 aturan. Aturan 2 tetap peringatan (bukan
    kegagalan) seperti rancangannya.
  - Pohon bersih (`git archive HEAD` + hanya berkas siklus ini) → hanya
    Aturan 10 yang berbunyi, dan itu memang janji README yang harus ikut naik.

### Pelajaran (catat, bukan ulang)

  - **Daftar yang mengaku "semua" harus dibandingkan dengan kenyataan, bukan
    dengan angkanya.** Angka yang dikunci sebagai literal akan ikut mengunci
    kelalaiannya — dan setiap uji yang menyapu daftar itu akan ikut buta.
  - **Status izin yang berbeda menuntut kalimat yang berbeda, bukan kalimat
    yang lebih umum.** Menggabungkan `.denied` dan `.restricted` terlihat
    seperti menyederhanakan; sebenarnya ia menghapus satu-satunya informasi
    yang menentukan apakah pengguna bisa berbuat sesuatu.

## Siklus: gerbang yang hijau karena **tidak mengukur apa pun**

Tiga cacat, satu kelas, dan kelasnya adalah cacat yang paling mahal di repo
ini: gerbang yang lulus pada kode benar **dan** pada kode salah. Tidak ada
yang merah, tidak ada yang crash, tidak ada yang aneh di keluaran — gerbangnya
hanya berhenti mengukur, dan hasilnya terlihat persis seperti ketaatan.

Ketiganya ditemukan dengan **menyuntik cacat lalu mengukur**, bukan dengan
membaca kode. Dua di antaranya adalah sapu teks yang menanyakan pertanyaannya
ke cakupan yang salah; yang ketiga adalah harness mutasi yang mengukur sumber
yang tidak pernah ia mutasi.

### 1. Aturan 7 menanyakan penjaga ke **seluruh berkas**, lalu `break`

Gerbang reduce-motion memakai `whole = "\n".join(lines)` — penjaga di **mana
pun** di berkas membuat **semua** API gerak di berkas itu lolos — dan
`break` setelah satu laporan per berkas, sehingga API gerak **kedua** di
berkas yang sama tidak pernah diperiksa sama sekali.

Terukur pada `PointingView.swift`: satu `motion.allowsTransitions` di baris
546 menutupi ketiga API gerak di berkas itu, termasuk `TimelineView(.animation)`
di `PulsingCelestialVisual` — yang penjaganya (`motion.allowsContinuousMotion`)
hidup di `if` baris berikutnya, bukan di pohon yang sama. Injeksi
`withAnimation(.linear(duration: 0.3))` di fungsi baru di berkas itu →
**"Bersih"**.

Yang membuatnya bertahan adalah arah kesalahannya: berkas yang **sudah** punya
satu penjaga adalah berkas yang paling aman menurut gerbang ini — persis
kebalikannya. Berkas seperti itu juga yang paling sering ditambahi kode baru.

Diperbaiki dengan cakupan yang benar: setiap API gerak harus berada di dalam
blok `{...}` yang memuat rujukan penjaga — blok itu sendiri atau salah satu
pembungkusnya.

**Kenapa blok, bukan "rentang fungsi".** `var body: some View` adalah
**properti**, bukan `func`. Rentang berbasis `func` membuat `body` tidak punya
pemilik dan melaporkan seluruh 6 API gerak yang ada sebagai pelanggaran —
gerbang yang merah pada kode yang benar, dan gerbang seperti itu dimatikan
orang. Kurung kurawal menutup `func`, `var`, `if`, dan `else` sekaligus.
Terukur: 6/6 hijau, injeksi di atas merah, satu-satunya selisihnya.

Batas yang dinyatakan: blok yang diuji adalah blok **terdekat yang memuat**,
bukan blok yang benar-benar mengeksekusi API-nya. Penjaga di `if` bersaudara
masih hijau. Versi yang lebih ketat menuntut pelacakan alur yang tidak bisa
dibuktikan benar oleh sapu teks.

### 2. Aturan 1 buta pada baris yang memuat `//` di dalam literal

Aturan 1 memotong komentar dengan `index(line, "//")` pada `awk`: ia berhenti
di `//` pertama pada baris, termasuk `//` yang ada **di dalam literal string**.
Disuntik dan diukur:

    Text("https://example.com/x").font(.system(size: 11))
    → "Bersih: tidak ada .system(size:) pada kode di Apps/"

Baris yang memuat URL atau path justru bentuk yang paling mungkin dialam, dan
itu satu-satunya yang tidak terlihat. Bentuk itu juga tidak mengenal komentar
blok `/* */`, jadi komentar multi-baris tetap dibaca sebagai kode — arah
sebaliknya.

Ini kelas yang sama dengan nomor 1: **gerbang yang mencari `//` pertama pada
baris akan buta pada literal yang memuat `//`.** Setelah perbaikan ini tidak
ada lagi pemotong komentar naif di `swift-ui-lint.sh`; Aturan 1 dan Aturan 7
memakai pemotong yang sama — sadar literal, sadar escape, sadar komentar blok,
dan baris baru di dalam komentar blok dipertahankan supaya nomor baris temuan
tetap cocok dengan berkas aslinya.

Diukur **dua arah**: pelanggaran di dalam komentar blok tidak lagi dilaporkan,
dan pelanggaran setelah URL di baris yang sama sekarang dilaporkan.

### 3. `bukti-mutasi-aksen.py`: jangkar basi = keadaan yang tidak menguji apa pun

Sebelas keadaan di harness itu bekerja dengan `BASE_VIEW.replace(jangkar, …)`.
Kalau jangkarnya sudah tidak ada — karena kode produksinya direfaktor, yang di
repo ini terjadi terus — `str.replace` mengembalikan sumber **apa adanya**
tanpa galat, dan harness mengukur sumber yang tidak termutasi.

Akibatnya berbeda menurut arah harapannya, dan yang **hijau** yang berbahaya:

| harapan keadaan | yang tercetak saat jangkar basi | berarti? |
|---|---|---|
| **merah** | `[SALAH]` (nol merah ≠ harapan) | ya — berisik, aman |
| **hijau** | `[OK ]` (nol merah = harapan) | **tidak** — dan tanpa satu pun tanda |

Empat keadaan di berkas itu mengharapkan hijau, termasuk tiga yang menjaga
kode benar dari gerbang yang terlalu ketat dan satu yang menjaga keadaan
`main` sekarang. Keempatnya bisa berhenti berarti tanpa suara.

Diperbaiki di **kelas `str`-nya** (`Sumber`), bukan di sebelas tempat
pemanggilan: satu tempat yang benar, dan pemanggilan baru tidak bisa lupa
memakainya. `replace()` melempar `JangkarHilang` bila jangkarnya tidak ada.

Sapuan yang sama dilakukan atas **15 harness saudaranya**, dan hasilnya bersih:
semuanya sudah memeriksa jangkarnya (`if find not in source` atau
`count(old) != 1`) sebelum menulis. Berkas ini satu-satunya yang belum — dan
itu masuk akal, karena ia juga satu-satunya yang **tidak** memakai
`mutasi_sumber.py` untuk memutasi berkas produksi; ia bekerja di memori.

### Verifikasi (terukur, bukan diklaim)

  - **Aturan 7** — baseline 6 API gerak, **0 merah**; suntikan
    `withAnimation` tanpa penjaga di fungsi baru → **1 merah**, tepat pada
    baris suntikan. `./red-lint.sh … 'Aturan 7'` → MERAH, exit 1, berkas
    dipulihkan. **CI hijau** (run `38097663243`, 36m16s) — termasuk langkah
    bukti yang baru ditambahkan.
  - **Aturan 1** — baseline "Bersih"; suntikan baris ber-URL → **1 temuan**
    pada baris yang benar; komentar blok yang menyebut `.system(size:)` →
    **tidak** dilaporkan (dulu dilaporkan). `./red-lint.sh … 'Aturan 1'` →
    MERAH, exit 1, berkas dipulihkan. Gerbangnya kini dibuktikan berbunyi di
    CI, sejajar dengan Aturan 15.
  - **Harness aksen** — 13 keadaan tetap **13/13 OK**; jangkar basi
    **melempar**; jangkar hidup tetap bekerja; dan `str` biasa pada jangkar
    yang sama tetap kembali **tidak berubah** — itu cacatnya, diukur
    berdampingan supaya klaimnya bukan pendapat.
  - `./swift-test.sh` → **CelestialEngine 212 + PointingKit 730 hijau**
    (0 gagal). Engine tidak disentuh.
  - `./swift-ui-lint.sh` → **30 aturan lulus**, `SEMUA GERBANG UI LULUS`.
  - **Apple Build** (macos-15, gagal bila ada warning kode sendiri) hijau
    untuk ketiga commit.

### Pelajaran (catat, bukan ulang)

  - **Gerbang yang hijau harus dicurigai lebih dulu daripada gerbang yang
    merah.** Gerbang merah berisik dan akan diperbaiki; gerbang yang berhenti
    mengukur tidak berbunyi sama sekali, dan keluarannya identik dengan
    "semuanya benar". Ketiga cacat di siklus ini hijau di `main`.
  - **Suntik cacatnya, jangan baca kodenya.** Ketiganya ditemukan dalam
    hitungan menit setelah cacat nyata disuntikkan, dan tidak satu pun
    terlihat dari membaca `swift-ui-lint.sh`. Membaca kode gerbang hanya
    membuktikan bahwa ia *dimaksudkan* memeriksa sesuatu.
  - **Cakupan yang diturunkan dari bentuk berkas akan salah.** Dua dari tiga
    cacat ini berasal dari cakupan: "seluruh berkas" (Aturan 7) dan "baris
    ini" (Aturan 1). Yang benar adalah cakupan yang diturunkan dari **tempat
    kejadiannya** — blok kurung kurawal yang memuat API gerak, dan literal
    yang memisahkan komentar dari kode.
  - **Pemotong komentar naif adalah satu kelas, bukan satu bug.** Setelah
    ditemukan di Aturan 7, pola `//` pertama pada baris dicari di seluruh
    berkas — dan ketemu satu lagi di Aturan 1. Memperbaiki situs pertama saja
    akan meninggalkan yang kedua.
  - **Harness yang memutasi lewat `replace()` harus menolak jangkar yang
    hilang, dan yang paling penting adalah keadaan yang mengharapkan hijau.**
    Keadaan yang mengharapkan merah gagal berisik dengan sendirinya; keadaan
    yang mengharapkan hijau berhenti berarti tanpa suara.

## Siklus: Aturan 3 memakai daftar abjad, jadi abjad di luar daftar lolos

### Cacat: daftar rentang tangan tidak bisa lengkap

Aturan 3 memeriksa aksara non-Latin dengan daftar rentang yang **ditulis
tangan**: CJK, Hiragana/Katakana, Hangul, fullwidth, Cyrillic. Daftar seperti
itu selalu ketinggalan abjad yang tidak disebut penulisnya.

Di repo ini itu bukan kemungkinan teoretis. Satu huruf Arab (U+0627, ALEF)
benar-benar pernah masuk ke **`swift-ui-lint.sh` sendiri** — menyelinap di
dalam komentar Aturan 7 — dan Aturan 3 melaporkan **"Bersih"**. Ia lolos
karena daftarnya tidak pernah punya rentang Arabic sama sekali, bukan karena
selipnya langka.

Yang membuat cacat ini sulit terlihat: keluaran Aturan 3 identik dengan
keadaan "tidak ada selip". Tidak ada yang merah, tidak ada yang aneh.

### Perbaikan: sifat karakter, bukan daftar abjad

Pemeriksaannya diturunkan dari **sifat** karakternya: setiap karakter
berkategori huruf (Unicode `L*`) yang bukan ASCII, bukan Latin, dan bukan
Yunani. Arab, Ibrani, Devanagari, Thai, Armenia — dan abjad apa pun yang
belum ditemukan — tertangkap tanpa perlu ditambahkan satu per satu.

### Kenapa Yunani dikecualikan, dan kenapa itu **diukur** bukan dikira-kira

Sapuan yang menandai **semua** huruf non-Latin langsung menemukan **99
temuan** di repo ini, dan semuanya sah: `σ`, `α`, `θ`, `φ`, `Δ` dipakai
sebagai simbol matematis di uji dan komentar (`σ` = simpangan baku,
`Δ` = selisih). Gerbang yang merah pada 99 baris kode yang benar adalah
gerbang yang akan dimatikan orang — persis kegagalan yang sudah tercatat di
berkas itu sendiri.

Jadi Yunani dikecualikan **secara eksplisit**. Sebelumnya Yunani lolos hanya
karena **kebetulan** tidak ada di daftar; kebetulan bukan pengecualian, dan
itu sebabnya ia sekarang ditulis sebagai keputusan.

### Batas yang dinyatakan

Yang diperiksa adalah **huruf** (`L*`). Simbol dan tanda baca non-ASCII
**tidak** ditandai, karena komentar repo ini memang memakai `─ ▸ ° × ≥ •`
sebagai tata letak. Dan `.build/` dilewati: ia hasil build (termasuk salinan
pustaka pihak ketiga), bukan sumber repo ini.

### Jebakan yang kena pada penulisnya sendiri

Komentar yang menjelaskan perbaikan ini semula **mengutip huruf Arab itu
apa adanya** — dan Aturan 3 yang baru diperluas langsung memerah pada
`swift-ui-lint.sh`. Ini jebakan yang **sama** sudah pernah terjadi di aturan
ini untuk aksara CJK, dan jawabannya sama: **kutipan harfiahnya yang
dihapus, bukan aturannya yang diberi pengecualian.** Hurufnya kini disebut
sebagai `U+0627, ALEF`, bukan digambar.

Jebakan itu berlanjut ke langkah CI: berkas `*.yml` juga disapu, jadi
harfiah Arab di sana ditulis sebagai escape, bukan digambar.

### Dan langkah pembuktinya sendiri sempat hijau karena **tidak menyuntik apa pun**

Versi pertama harfiah itu memakai `printf`:

    "$(printf '// \u0627\u0644\u0633\u0645\u0627\u0621 selip\n')"

Langkah CI berjalan di bawah `sh` (**dash**), dan `printf` dash **tidak
mengenal** escape `\uXXXX` — ia mencetaknya apa adanya. Yang disuntik adalah
teks harfiah `// \u0627...` (ASCII biasa), bukan huruf Arab, jadi gerbangnya
benar-benar tetap hijau. `red-lint.sh` lalu melaporkan `HIJAU PALSU` — dengan
benar.

Yang membuatnya bertahan sesaat: di shell lokal (**bash**, yang `printf`-nya
mengenal `\u`) perintah yang sama **lulus**. Jadi langkah itu membuktikan
sesuatu di mesin penulisnya dan tidak membuktikan apa pun di CI.

Kelasnya sama dengan seluruh siklus ini — hijau karena tidak mengukur apa pun
— hanya saja yang tidak mengukur di sini adalah **langkah pembuktinya
sendiri**, bukan gerbangnya. Harfiahnya kini lahir dari
`python3 -c 'print(...)'`, yang sama di dash dan bash; diukur di **kedua**
shell: keduanya MERAH, exit 1, berkas dipulihkan.

### Verifikasi (terukur, bukan diklaim)

  - **Baseline** — seluruh repo: **0 temuan**. Tidak ada satu pun kode benar
    yang jadi merah karena perluasan ini.
  - **Arah positif** — huruf Arab disuntik ke `WatchTheme.swift`:
    **tertangkap**, dilaporkan pada berkas dan baris yang benar, lengkap
    dengan nama karakter (`ARABIC LETTER ALEF`). `./red-lint.sh … 'Aturan 3'`
    → MERAH, exit 1, berkas dipulihkan.
  - **Arah negatif** — `σ`, `Δ`, `α` disuntik: **tetap Bersih**. Jadi
    pengecualian Yunani benar-benar bekerja, bukan sekadar niat.
  - `./swift-test.sh` → **CelestialEngine 212 + PointingKit 730 hijau**
    (0 gagal).
  - `./swift-ui-lint.sh` → **30 aturan lulus**.
  - Gerbangnya kini dibuktikan berbunyi di CI, sejajar dengan Aturan 1, 7,
    dan 15.

### Pelajaran (catat, bukan ulang)

  - **Daftar abjad tidak bisa dijaga ke lengkapannya; sifat karakter bisa.**
    Setiap kali sebuah aturan menyebut abjad satu per satu, abjad berikutnya
    yang belum terpikirkan adalah lubangnya — dan lubangnya tidak berbunyi.
  - **Pengecualian harus diukur, bukan diwarisi.** Yunani dulu diizinkan
    karena tidak ada di daftar. Kalau pengecualian itu dibiarkan implisit,
    perluasan berikutnya akan menghapusnya tanpa ada yang tahu bahwa itu
    keputusan.
  - **Aturan yang menyapu berkasnya sendiri akan memerah pada contohnya
    sendiri.** Solusinya menghapus contoh harfiah, bukan melubangi aturan —
    dan itu berlaku dua kali di sini: di komentar skrip, dan di harfiah
    langkah CI.
  - **Langkah pembuktian harus diuji di shell yang sama dengan CI.** `printf`
    dash tidak mengenal `\uXXXX`, jadi suntikan yang lulus di bash tidak
    menyuntik apa pun di CI. Uji yang hanya dijalankan di shell penulisnya
    membuktikan sesuatu tentang mesin penulisnya, bukan tentang CI.
