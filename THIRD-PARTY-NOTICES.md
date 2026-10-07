# Lisensi pihak ketiga

Berkas ini mencatat data dan pustaka pihak ketiga yang ikut didistribusikan
bersama aplikasi ini, beserta syarat atribusinya. Ia **bukan** lisensi proyek
ini sendiri — untuk itu lihat `LICENSE`.

## Data katalog bintang

### Katalog bintang terang (`Catalogue.brightStars`)

Koordinat dan magnitudo 25 bintang terang diambil dari **HYG Database**
(versi 3), yang disusun oleh David Nash dari sumber: Hipparcos, Yale Bright
Star Catalog, dan Gliese.

- Sumber: https://github.com/astronexus/HYG-Database
- Lisensi: **Creative Commons Attribution-ShareAlike 4.0 International**
  (CC BY-SA 4.0) — https://creativecommons.org/licenses/by-sa/4.0/
  (diverifikasi dari berkas `LICENSE` di repo tersebut)
- Atribusi yang disyaratkan: sebutkan HYG Database dan penulisnya.

**Konsekuensi lisensi yang perlu diketahui.** CC BY-SA 4.0 adalah lisensi
*copyleft*: bila katalog turunan didistribusikan, ia harus tetap di bawah
CC BY-SA 4.0, dan atribusi harus disertakan. Karena itu:

- Berkas `Catalogue.swift` yang memuat baris-baris ini adalah **karya
  turunan** dan tunduk pada CC BY-SA 4.0, terpisah dari lisensi kode lain
  di repo ini.
- Siapa pun yang mengganti data bintang dengan katalog lain wajib
  memperbarui berkas ini.

## Data objek langit dalam

### `DeepSkyCatalogue` (Messier)

Koordinat objek Messier (M42, M31, M45, dan seterusnya) adalah **data
astronomi faktual** yang tidak dapat diklaim hak cipta (fakta tidak
berhak cipta). Nilai magnitudo terintegrasi dikumpulkan dari sumber
publik dan dibulatkan; tidak ada ekspresi kreatif yang disalin.

Tidak ada syarat atribusi yang mengikat untuk bilangan faktual ini, tetapi
asal-usulnya dicatat di sini untuk ketertelusuran.

## Pustaka perangkat lunak

### AstronomyKit (Swift)

Efemeris Matahari/Bulan/planet untuk presisi tinggi.

- Sumber: https://github.com/heirloomlogic/AstronomyKit
- Versi terpakai: `0.2.3+upstream-2.1.19`
  (revisi `0dd5d3115be808338d3c94f0ed5f0e20fb0ddd28`)
- Lisensi: **MIT**, Copyright (c) 2025 Heirloom Logic LLC
- Teks lisensi lengkap disertakan oleh Swift Package Manager saat
  menyelesaikan dependensi; syaratnya hanya menyertakan salinan lisensi.

### Apple SDK / SwiftUI / WatchKit / CoreMotion

Disediakan oleh sistem operasi Apple di bawah ketentuan Apple; tidak
didistribusikan ulang dalam repo ini.

## Cara memperbarui berkas ini

Setiap kali menambah atau mengganti sumber data pihak ketiga, tambahkan
entri dengan bentuk yang sama: nama, sumber, lisensi, dan — bila
lisensinya copyleft atau punya syarat atribusi — **konsekuensinya bagi
repo ini**, bukan hanya nama lisensinya. Yang mudah terlupa bukan nama
lisensinya, melainkan apa yang jadi kewajiban kita karenanya.

Berkas `Catalogue.swift` memuat koordinat bintang; berkas itu tunduk pada
lisensi yang sama dengan datanya, dan perubahannya harus diperiksa di sini.
