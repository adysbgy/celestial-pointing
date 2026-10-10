# Revisi produk v2: "tunjuk satu, tahu satu" + fenomena (ide Ady, 10 Okt 2026)

Ini analisis dan pengembangan ide Ady, berdasarkan kode dan data yang sudah ada di repo. Angka-angkanya dihitung dengan engine app sendiri; yang belum terbukti di perangkat ditandai.

## Ide Ady dalam satu paragraf

Di Indonesia biasanya hanya 1–3 bintang yang terlihat. Arahkan jam ke salah satunya, dan app langsung menyebut namanya: **satu per satu**, tidak pernah berupa daftar, termasuk saat dua bintang berdempetan. Hasilnya bisa disinkronkan dengan **Stellarium** supaya jelas bintang mana yang ditunjuk. Kasus kedua adalah **fenomena** (gerhana, konjungsi, hujan meteor):
1. app memandu dengan cara **"panas–dingin"** ke lokasinya;
2. setelah ketemu, muncul **visualisasi 3D** di iPhone, dan di jam kalau kuat;
3. dengan sekali tunjuk lagi, **teleskop bergerak sendiri** ke sana.

## 1. Kenyataan langit Indonesia, dan posisi app sekarang

- Sejak ADR-012, mode **langit kota** (batas magnitudo 3.0) menjadi bawaan. Gugus dan nebula yang tidak terlihat dari kota sudah dibuang.
- **Gladi bersih Jakarta, 9 Okt** (lihat `TonightRehearsalTests`):
  - Pukul 18.45, 19.30, dan 21.00 ada 7–8 kandidat terang. Semuanya terkunci pada dirinya sendiri, juga dengan galat pergelangan 7°.
  - Di jalan yang terang, yang benar-benar terlihat mata tinggal planet dan beberapa bintang paling terang. Hitungannya cocok dengan pengamatan Ady: 1–3 benda.
- **Kesimpulan:** prinsip "satu per satu" cocok dengan engine sekarang. Yang perlu diganti adalah *cara menampilkan keraguan*, bukan pencariannya.

## 2. Fitur A: tunjuk satu, tahu satu (termasuk saat berdempetan)

**Batas fisik yang jujur.** Akurasi tunjuk pergelangan belum terukur (sigma cadangan 10°, uji lapangan pertama yang akan menentukannya). Dua benda yang jaraknya di bawah akurasi itu **tidak bisa dibedakan hanya dari arah tangan**. Contoh pasangan berdempetan yang terlihat dari kota:
- Castor–Pollux, terpisah 4,5°;
- Bulan di dekat planet saat konjungsi;
- sabuk Orion.

**Desain yang diusulkan.** Hanya satu jawaban yang tampil, dan daftar "Mungkin salah satu ini" dihapus:
1. **Pilih yang paling mungkin terlihat.** Skor = jarak dari arah tunjuk + *bobot kecerlangan untuk langit kota*. Di kota, kalau ada dua kandidat, yang Ady lihat hampir pasti yang lebih terang.
2. **Digital Crown sebagai "bukan, yang sebelahnya".** Putar crown, dan jawaban berganti ke kandidat berikutnya, tetap satu per satu. Ketuk dua kali untuk "Ya, itu dia".
3. **Label jujur saat berdempetan.** Contoh: "Pollux. Castor juga dekat (4°), putar crown." Klaim pasti hanya muncul kalau memang terpisah. Ini aturan PRD: ragu lebih baik daripada yakin palsu.
4. **Halusan dengan panas–dingin** (Fitur C). Kalau tangan bergeser ke arah yang benar, getarannya makin rapat.

## 3. Fitur B: sinkron dengan Stellarium

Ada tiga makna "sinkron", dengan nilai yang berbeda.

| Makna | Cara | Nilai | Batas |
|---|---|---|---|
| **Layar kedua langsung** | iPhone mengirim arah tunjuk jam ke plugin *Remote Control* Stellarium desktop (HTTP di Wi-Fi lokal, port bawaan 8090). Tampilan Stellarium ikut berputar ke arah tunjuk dan menandai bendanya. | Ady dan orang lain bisa melihat di laptop **persis** bintang mana yang ditunjuk. Cocok untuk demo dan uji. | Butuh laptop/Mac dengan Stellarium di jaringan yang sama. Setahu saya, Stellarium Mobile dan Web tidak membuka API seperti ini. Perlu dicek di Mac Ady. |
| **Kebenaran acuan untuk uji** | Rekaman Pointing Lab dibandingkan dengan posisi menurut Stellarium. | Mengukur akurasi jam secara independen dari engine kita. | Hanya untuk pengembangan. |
| **Teleskop lewat Stellarium** | Stellarium memang bisa mengendalikan teleskop. | Satu aplikasi untuk semuanya. | Jalur GoTo kita (Alpaca, ADR-008/009) punya pengaman Matahari dan Stop yang selalu terlihat. Lebih aman tetap memakai jalur sendiri. |

**Rekomendasi:**
- Jadikan Stellarium **pendamping opsional**, bukan ketergantungan. Di jalan tidak ada laptop, jadi pengenalan harus tetap jalan mandiri dan luring di jam dan iPhone. Sekarang pun sudah begitu.
- Data katalog Stellarium berlisensi GPL. Kita **tidak menyalinnya** ke app, cukup berbicara lewat API-nya.

## 4. Fitur C: fenomena + "panas–dingin"

**Jenis fenomena dan sumber datanya**

| Fenomena | Sumber | Luring? |
|---|---|---|
| Fase Bulan, Bulan dekat planet, planet berdekatan (konjungsi) | efemeris yang sudah ada (AstronomyKit) | ya |
| Gerhana Bulan & Matahari (lokal) | AstronomyKit `Eclipse.searchLunar` / `searchLocalSolar` | ya |
| Elongasi maksimum Venus/Merkurius, oposisi planet | AstronomyKit | ya |
| Bulan-bulan Jupiter | AstronomyKit `JupiterMoons` | ya |
| Hujan meteor (titik radian) | tabel tahunan (kalender IMO) | ya |
| ISS/satelit, komet | TLE CelesTrak, orbit MPC/JPL | **butuh internet** |

**Contoh nyata untuk Jakarta** (dihitung dengan engine):
- **18 Jul 2027, 23.03 WIB:** gerhana Bulan penumbra. Bulan setinggi 68°, mudah dilihat dan ditunjuk.
- **22 Jul 2028, 08.55 WIB:** gerhana Matahari **sebagian 89%** dari Jakarta (total di Australia). Matahari setinggi 38°. **Wajib filter Matahari.**
- **Hujan meteor:** Orionid sekitar 21–22 Okt (radian terbit sekitar 22.00); Geminid sekitar 13–14 Des (yang terbaik setiap tahun).
- **Tidak terlihat dari Jakarta:** gerhana Bulan 20 Feb 2027 dan 17 Agu 2027, karena Bulan di bawah cakrawala. Jujur: app akan bilang "tidak terlihat dari sini".

**Desain panas–dingin.** Bagian ini dibangun di atas cincin petunjuk yang sudah ada (ADR-011).
- **Getaran seperti penghitung Geiger.** Ketukan haptik makin rapat saat makin dekat, lalu satu getaran "ketemu" saat terkunci. Mata tetap bisa ke langit, tidak perlu melihat layar.
- **Warna cincin dari biru (dingin) ke oranye/merah (panas).** Angka derajatnya tetap tampil.
- **Untuk benda yang berupa area:** radian meteor adalah daerah, bukan titik. Panduannya ke daerahnya, lalu muncul "lihat sekitar 30–40° dari sini". Teleskop tidak dipakai, karena meteor terlalu cepat.
- **Gerhana Matahari:** panas–dingin **tidak pernah** mengajak menatap Matahari tanpa filter. Ada layar peringatan filter, dan GoTo ke Matahari tetap diblokir pengaman yang sudah ada. Membukanya dengan "mode filter Matahari" adalah keputusan produk tersendiri.

## 5. Fitur D: visualisasi 3D

- **iPhone (3D penuh, layak sekarang):**
  - planet dengan cincin;
  - Bulan yang disinari dari arah Matahari yang sebenarnya, sehingga fasenya benar;
  - geometri gerhana (bayangan Matahari–Bumi–Bulan);
  - susunan planet saat konjungsi;
  - posisi bulan-bulan Jupiter.

  Semua posisinya dari efemeris yang sama dengan engine, jadi gambarnya tidak bisa berbohong.
- **Jam (versi ringan):** animasi prosedural yang sudah kita punya (CelestialVisual), dengan rotasi pelan dan sorotan fenomenanya, ditambah tombol "Buka di iPhone" untuk 3D penuh. Mesin 3D penuh di jam bisa dicoba, tapi boros baterai dan panas. Perlu diuji di Series 10 sebelum dijanjikan.

## 6. Fitur E: teleskop otomatis

**Yang sudah ada** (ADR-006/008/009):
- GoTo lewat Alpaca setelah objek dikonfirmasi;
- tombol **Stop** selalu terlihat;
- pengaman Matahari;
- teleskop selalu menuju **koordinat objek**, tidak pernah ke arah tangan mentah.

**Alur Ady:**
1. Panas–dingin sampai ketemu.
2. Ketuk dua kali (tunjuk lagi) untuk konfirmasi.
3. Teleskop bergerak sendiri dan melacak, karena Bulan dan planet bergerak.

Konfirmasi harus tetap **eksplisit**. Teleskop yang bergerak sendiri karena tangan kebetulan diam itu berbahaya.

**Seestar:** firmware 7.18+ butuh jabat tangan kriptografi (ADR-008). Jadi Seestar masih POC lewat jembatan. Mount yang mendukung Alpaca sudah bisa dipakai sekarang.

## 7. Urutan pengerjaan yang saya sarankan

| Fase | Isi | Kenapa duluan |
|---|---|---|
| **0** | Uji lapangan malam pertama (Pointing Lab + foto "Kenapa belum yakin?") | Semua fitur bergantung pada akurasi tunjuk yang belum terukur |
| **1** | Satu per satu + crown "yang sebelahnya" + getaran panas–dingin | Paling dekat dengan kode sekarang; langsung terasa di jalan |
| **2** | Kalender fenomena luring ("Malam ini ada apa") + panas–dingin ke fenomena | Datanya sudah ada di AstronomyKit |
| **3** | Pendamping Stellarium lewat iPhone | Demo dan validasi |
| **4** | 3D di iPhone, versi ringan di jam | Butuh aset dan uji performa |
| **5** | GoTo dari fenomena + jembatan Seestar | Butuh perangkat keras |
| nanti | ISS/komet (online) | Butuh sumber data dan internet |

## 8. Keputusan yang perlu Ady ambil

1. Hapus daftar "Mungkin salah satu ini" dan ganti dengan satu jawaban + crown? (Saran: **ya**.)
2. Gerhana Matahari: blokir total, atau "mode filter" dengan peringatan? (Saran: **blokir dulu**.)
3. Stellarium sebagai pendamping opsional, bukan syarat? (Saran: **ya**.)
4. Data online (ISS/komet) boleh dipakai, dengan konsekuensi butuh internet? (Saran: **nanti**, setelah fase 2.)
