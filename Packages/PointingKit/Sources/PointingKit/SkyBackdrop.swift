import Foundation
import CelestialEngine

/// Bintang **hiasan** di latar belakang — penata ruang, bukan hasil pengenalan.
///
/// **Kenapa berkas ini ada.** Setiap layar app ini dibangun di atas latar
/// gradien datar: dua warna, tanpa apa pun di antaranya. Secara fungsional
/// tidak ada yang salah — kontrasnya teruji, kartunya terbaca. Yang hilang
/// adalah **ruang**: aplikasi astronomi premium (Star Walk, Sky Tonight)
/// menempatkan informasi di atas langit, dan langit itu memberi tahu mata
/// bahwa yang dilihatnya adalah pemandangan. Tanpa itu, kartu-kartu yang
/// sudah rapi tetap terbaca sebagai daftar pengaturan, bukan sebagai jendela
/// ke langit — dan itulah keluhan "jelek" yang tidak bisa dijawab oleh
/// perbaikan kartu saja.
///
/// **Batas yang paling penting: ini bukan identifikasi.** Titik-titik di sini
/// **tidak** mewakili bintang nyata di posisi nyata. Menggambar titik acak
/// lalu membiarkannya terbaca sebagai "bintang yang dikenali engine" adalah
/// persis kebohongan yang dilarang PRD — lebih halus dari menyebut nama yang
/// salah, karena tidak ada teks yang bisa dibantah. Karena itu dua hal
/// dikunci oleh uji, bukan oleh niat:
///
///   1. **Ukuran.** Setiap titik latar **lebih kecil** dari titik terkecil
///      yang bisa dihasilkan `CelestialVisual.sizeFromMagnitude` untuk
///      benda paling redup di `Catalogue.brightStars`. Jadi tidak ada titik
///      latar yang bisa disangka bintang yang baru saja dikunci.
///   2. **Warna.** Titik latar memakai warna netral (`neutralStarBody`),
///      bukan warna spektral. Warna spektral adalah **ciri pengenal** —
///      merahnya Betelgeuse adalah penanda yang sama meyakinkannya dengan
///      cincin Saturnus — dan hiasan tidak boleh memiliki ciri pengenal.
///
/// **Kenapa modelnya di PointingKit, bukan di view.** Dua klaim di atas
/// harus diuji di Linux; `Color` dan `Canvas` tidak ada di sana. Yang
/// dihitung di sini hanya **angka** (posisi, radius, terang) dan semuanya
/// deterministik, sehingga uji bisa mengukurnya.
///
/// **Deterministik, bukan acak.** Titik dihasilkan dari seed bilangan bulat
/// lewat pembangkit lebar-64 bit, bukan `Random`/`randomElement`. Alasannya
/// nyata, bukan teori: kalau posisinya bergantung pada keadaan acak proses,
/// dua render dari cuplikan yang sama menghasilkan langit yang berbeda,
/// uji tidak bisa membandingkan apa pun, dan — yang lebih buruk — langit
/// bergeser setiap kali layar dirender ulang, yang terlihat sebagai kedip.
public enum SkyBackdrop {

    // MARK: - Keadaan yang bisa diukur

    /// Satu titik latar, dalam koordinat **terenormalisasi** 0…1.
    ///
    /// Kenapa 0…1 dan bukan piksel: ukuran layar hanya diketahui lapisan
    /// view (`Canvas`), sedangkan model ini diuji di Linux tanpa `GeometryReader`.
    /// Skala 0…1 membuat angkanya bisa diuji, dan pengalian ke piksel
    /// terjadi di satu tempat di view.
    public struct Speck: Equatable, Sendable {
        /// Posisi horizontal, 0…1 dari kiri.
        public let x: Double
        /// Posisi vertikal, 0…1 dari atas.
        public let y: Double
        /// Radius dalam satuan lebar bidang (0…1), bukan piksel.
        public let radius: Double
        /// Terang 0…1, sudah dikalikan ke keseluruhan lapisan.
        public let brightness: Double

        public init(x: Double, y: Double, radius: Double, brightness: Double) {
            self.x = x
            self.y = y
            self.radius = radius
            self.brightness = brightness
        }
    }

    /// Radius terbesar yang boleh dimiliki titik latar, dalam satuan yang
    /// sama dengan `CelestialVisual.sizeFromMagnitude`.
    ///
    /// **Kenapa angkanya diturunkan, bukan ditulis.** Batas ini adalah janji
    /// yang bisa diuji ("titik latar tidak pernah sebesar bintang yang
    /// dikenali"), jadi ia harus dihitung dari sumber yang sama dengan
    /// ukuran bintang yang dikenali — `Catalogue.brightStars`, bukan angka
    /// yang diketik sendiri. Kalau katalog ditambah satu bintang redup,
    /// batas ini ikut mengecil dengan sendirinya dan uji akan melihatnya.
    ///
    /// Dikalikan `sizeMargin` (< 1) supaya ada jarak yang terukur antara
    /// "hiasan" dan "benda terkecil yang dikenali" — kalau keduanya sama
    /// besar, perbedaan itu hanya ada di niat, tidak ada di layar.
    public static var maximumSpeckRadius: Double {
        let dimmest = Catalogue.brightStars.map { $0.magnitude }.max() ?? 0
        return CelestialVisual.sizeFromMagnitude(dimmest) * sizeMargin
    }

    /// Jarak yang sengaja dijaga antara titik latar dan benda paling redup
    /// yang bisa dikenali engine.
    ///
    /// `0.55` berarti titik latar paling besar pun cuma ~55% dari titik
    /// bintang paling redup — cukup jauh untuk terbaca sebagai tekstur,
    /// bukan sebagai benda.
    public static let sizeMargin: Double = 0.55

    /// Terang keseluruhan lapisan latar.
    ///
    /// Sengaja kecil: ini atmosfer, bukan konten. Nilai yang terlalu tinggi
    /// akan bersaing dengan kartu di atasnya dan mengurangi hierarki yang
    /// justru ingin ditegakkan.
    public static let layerOpacity: Double = 0.5

    /// Jumlah titik per satuan luas bidang (0…1 × 0…1) pada lebar acuan.
    ///
    /// Dipakai untuk menurunkan `speckCount`, supaya jam kecil tidak
    /// kebanjiran titik sementara iPhone tidak terlalu sepi.
    public static let speckDensity: Double = 90

    // MARK: - Pembangkitan

    /// Titik-titik latar untuk sebuah bidang berukuran lebar×tinggi.
    ///
    /// - Parameters:
    ///   - size: ukuran bidang dalam satuan apa pun (poin, piksel). Hanya
    ///     **rasio** dan **besarnya** yang dipakai: jumlah titik mengikuti
    ///     luas, dan posisi tetap 0…1.
    ///   - seed: pembeda bila dua lapisan berbeda perlu langit yang berbeda.
    /// - Returns: titik-titik yang **stabil** untuk `size` dan `seed` yang
    ///   sama — dipanggil ulang berkali-kali menghasilkan hal yang sama.
    public static func specks(size: CGSizeLike, seed: UInt64 = 0x9E37_79B9_7F4A_7C15) -> [Speck] {
        let area = max(0, size.width) * max(0, size.height)
        // Luas dinormalisasi terhadap bidang acuan 400×400 poin, lalu
        // diakar: tanpa akar, bidang dua kali lebih luas akan mendapat dua
        // kali lipat titik di setiap arah dan langitnya terasa penuh sesak.
        let reference: Double = 400 * 400
        let scaled = (area / reference).squareRoot()
        let count = Int((speckDensity * scaled).rounded())
        guard count > 0 else { return [] }

        let maximum = maximumSpeckRadius
        var result: [Speck] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            // Ruang pembangkit **dipotong-potong per titik**, bukan satu
            // aliran panjang. Alasannya: kalau jumlah titik berubah (layar
            // lebih besar), potongan per titik tetap di tempatnya, jadi
            // titik-titik yang sudah ada tidak berpindah — langit
            // membesar, bukan bergeser.
            // Keadaunya **diavalanche dulu**, bukan sekadar `seed + index·K`.
            //
            // **Cacat yang ditemukan dengan mengukur, bukan dengan
            // berpikir.** Bentuk lama `seed &+ index·K` membuat aliran
            // titik ke-i **bersambung** ke aliran titik ke-(i−1): karena
            // `next()` menambah K lebih dulu, nilai pertama aliran i
            // persis sama dengan nilai kedua aliran i−1 (diukur: 89 kali
            // pada 400×400). Hasilnya bukan langit, melainkan untaian
            // diagonal — mata membacanya sebagai pola, dan pola pada
            // latar mengundang pengguna mencari arti yang tidak ada.
            //
            // Menyisipkan satu nilai yang dibuang (percobaan pertama)
            // **tidak** menyembuhkannya: rantainya ada di antara aliran,
            // bukan di antara nilai berturutan dalam satu aliran. Yang
            // menyembuhkan adalah membuat keadaan tiap aliran benar-benar
            // tak berkaitan — karena itu indeksnya dilewatkan finalizer
            // SplitMix64 dulu. Tetap per-indeks, jadi sifat "bidang
            // membesar tanpa menggeser titik yang sudah ada" terpelihara.
            var local = SplitMix64(state: Self.mix(seed ^ (UInt64(index) &* 0x9E37_79B9_7F4A_7C15)))
            let x = local.nextUnit()
            let y = local.nextUnit()
            // Radius: sebagian titik dibuat sangat kecil supaya ada
            // kedalaman. `unit²` memiringkan sebaran ke arah kecil —
            // kebanyakan titik redup, sedikit yang menonjol, seperti
            // langit sungguhan dan tidak seperti pola seragam.
            let base = local.nextUnit()
            let radius = maximum * base * base
            // Terang: tidak proporsional terhadap radius. Titik kecil yang
            // terang terbaca seperti bintang jauh; menautkan keduanya
            // membuat seluruh lapisan tampak seperti satu tekstur datar.
            let brightness = 0.25 + 0.75 * local.nextUnit()
            result.append(Speck(x: x, y: y, radius: radius, brightness: brightness))
        }

        return result
    }

    // MARK: - Mode malam

    /// Terang sebuah titik latar **dalam mode malam**.
    ///
    /// **Kenapa titik hiasan pun harus ikut merah.** Aturan mode malam
    /// bukan "yang penting tidak ada biru di kartu": seluruh tujuannya
    /// adalah menjaga rhodopsin, dan cahaya biru dari ratusan titik kecil
    /// sama merusaknya dengan cahaya biru dari satu tombol besar — bahkan
    /// lebih mudah luput, karena tidak ada yang akan memeriksa warna
    /// hiasan. Titik latar memakai `neutralStarBody` yang akromatik, dan
    /// di bawah ini dipetakan lewat `NightVisual.surface` — jalur **yang
    /// sama** dengan warna benda, bukan jalur sendiri.
    public static func nightBrightness(_ day: Double) -> Double {
        let components = CelestialVisual.RGBComponents(
            red: day, green: day, blue: day)
        return NightVisual.surface(components).red
    }

    // MARK: - Bantu

    /// Finalizer SplitMix64: menyebarkan bit sebuah bilangan ke seluruh
    /// lebarnya.
    ///
    /// **Kenapa diperlukan terpisah dari `SplitMix64.next`.** Membuat satu
    /// aliran per titik berarti keadaan awal tiap aliran hanya berbeda
    /// sedikit (indeks yang dikalikan konstanta), dan `next()` — yang
    /// menambah konstanta itu lebih dulu — lalu menghasilkan nilai yang
    /// **sama** dengan nilai kedua aliran sebelumnya. Rantai itu tidak
    /// putus walau nilainya dibuang satu: ia ada di antara aliran, bukan
    /// di dalamnya. Mengavalanche keadaan awal membuat dua aliran yang
    /// berdekatan tidak punya hubungan yang bisa ditebak.
    static func mix(_ value: UInt64) -> UInt64 {
        var z = value
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Ukuran dua dimensi yang tidak bergantung `CoreGraphics`.
    ///
    /// `CGSize` tidak ada di Linux, jadi model ini tidak boleh
    /// menyebutnya; view mengubah `CGSize`-nya menjadi bentuk ini di
    /// batas pemanggilan.
    public struct CGSizeLike: Equatable, Sendable {
        public var width: Double
        public var height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }
}

// MARK: - Pembangkit deterministik

/// Pembangkit bilangan semu-acak 64-bit (SplitMix64).
///
/// **Kenapa tidak `SystemRandomNumberGenerator`.** Posisi titik yang
/// berubah setiap proses membuat dua hal mustahil: uji tidak bisa
/// membandingkan hasil, dan layar yang dirender ulang (setiap kali
/// SwiftUI mengevaluasi `body`) menghasilkan langit yang berbeda —
/// kedip yang tidak bisa dijelaskan. Pembangkit berseod mengembalikan
/// urutan yang sama untuk seed yang sama, di Linux maupun di perangkat.
struct SplitMix64 {

    var state: UInt64

    /// Nilai berikutnya, seluruh lebar 64 bit.
    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Nilai berikutnya sebagai pecahan 0…1.
    ///
    /// Diambil dari 53 bit atas, bukan dari sisa pembagian: sisa pembagian
    /// terhadap bilangan bulat kecil akan mengulang pola yang sama
    /// berkali-kali, dan pola yang berulang terbaca sebagai kisi, bukan
    /// sebagai langit.
    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
