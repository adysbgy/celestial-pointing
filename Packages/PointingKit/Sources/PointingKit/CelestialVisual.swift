import Foundation
import CelestialEngine

/// Model visual prosedural untuk sebuah benda langit.
///
/// **Kenapa modelnya ada di `PointingKit`, bukan di `Apps/`.** Dua hal di sini
/// bisa salah dengan cara yang tidak terlihat dari layar, dan keduanya harus
/// bisa diuji di Linux:
///
/// 1. **Identitas.** Memilih "Jupiter" dari sebuah `CelestialObject` terdengar
///    sepele, tapi kalau pemilihannya salah, UI akan menggambar pita Jupiter
///    pada Saturnus — tampak meyakinkan, sepenuhnya salah. PRD melarang
///    tampilan yang mengklaim identitas yang tidak dimiliki engine, dan
///    "gambar yang salah" adalah bentuk klaim yang paling halus: tidak ada
///    teks yang bisa dibaca pengguna untuk mengeceknya.
/// 2. **Geometri fase Bulan.** Sabit harus menghadap ke arah yang benar.
///    Geometri itu murni angka, jadi ia bisa diuji — dan kalau ia salah,
///    pengguna melihat Bulan sabit yang terbalik tanpa ada peringatan apa pun.
///
/// Yang **tidak** ada di sini: warna, gradien, `Canvas`, apa pun dari SwiftUI.
/// Itu semua ada di `Apps/Shared/CelestialVisualView.swift`. Pemisahannya
/// sengaja: model ini diuji di Linux, sedangkan warnanya tidak bisa.
public struct CelestialVisual: Equatable, Sendable {

    /// Jenis gambar yang harus digambar lapisan UI.
    public enum Kind: String, Equatable, Sendable {
        case planet
        case moon
        case star
        case sun
        case deepSky
    }

    /// Planet yang dikenali secara spesifik.
    ///
    /// Sengaja **bukan** nama tampilan: nama bisa berubah, id tidak. Pemetaan
    /// dilakukan dari `CelestialObject.id`, yang diisi resolver dari
    /// `EphemerisBody.rawValue` (lihat
    /// `PointingResolver.catalogueObject(for:sample:)`) — jadi keduanya tidak
    /// bisa berbeda pendapat tentang apa itu "jupiter".
    public enum Planet: String, Equatable, Sendable, CaseIterable {
        case mercury
        case venus
        case mars
        case jupiter
        case saturn
        case uranus
        case neptune

        /// Apakah planet ini menampakkan **fase** dari Bumi.
        ///
        /// Hanya planet **dalam** — Merkurius dan Venus, yang orbitnya di
        /// dalam orbit Bumi. Dari Bumi keduanya terlihat berayun dari sabit
        /// tipis ke cakram hampir penuh, dan itulah ciri paling khas mereka
        /// di teleskop: Venus pada elongasi timur tampak seperti bulan
        /// setengah, bukan bola penuh.
        ///
        /// Planet luar (Mars…Saturnus) **tidak pernah** tampak berfase: sudut
        /// fasenya, dilihat dari Bumi, tidak pernah cukup jauh dari purnama
        /// untuk terlihat — Mars paling ekstrem hanya ~85% iluminasi, dan itu
        /// pun nyaris tak terbedakan dari bola penuh pada ukuran yang
        /// digambar aplikasi ini.
        ///
        /// **Kenapa ini properti, bukan daftar di view.** View yang memutuskan
        /// planet mana yang berfase berarti aturan itu hidup di berkas yang
        /// tidak bisa diuji di Linux — dan kalau salah, Mars akan tampil
        /// sebagai sabit, gambar yang menyatakan sesuatu yang tidak pernah
        /// terjadi di langit. Di sini ia bisa dikunci uji.
        public var showsPhase: Bool {
            switch self {
            case .mercury, .venus: return true
            case .mars, .jupiter, .saturn, .uranus, .neptune: return false
            }
        }
    }

    public var kind: Kind
    /// Planet spesifik, bila `kind == .planet` dan id-nya dikenali.
    public var planet: Planet?

    // MARK: - Bulan

    /// Fraksi piringan yang menyala, 0…1 (dari engine, bukan tebakan).
    ///
    /// Untuk selain Bulan nilainya `nil`, karena UI tidak boleh menggambar
    /// fase pada benda yang fasenya tidak dihitung.
    public var illuminationFraction: Double?
    /// Apakah sabit membesar (waxing) — menentukan sisi mana yang menyala.
    ///
    /// `nil` bila arah fasenya tidak diketahui. Saat `nil`,
    /// `phaseGeometry` mengembalikan `nil` dan UI menggambar piringan **tanpa
    /// fase** — bukan sabit yang memilih sisi. Sabit yang menghadap ke arah
    /// yang salah jauh lebih buruk daripada piringan tanpa fase, karena yang
    /// pertama terbaca sebagai fakta sedangkan yang kedua jujur tidak tahu.
    public var isWaxing: Bool?

    /// Sudut sisi terang Bulan **di langit**, dalam radian.
    ///
    /// `0` = sisi terang ke kanan, `+pi/2` = ke atas, `pi` = ke kiri,
    /// `-pi/2` = ke bawah. Diukur dari proyeksi vektor Bulan→Matahari ke
    /// bidang gambar.
    ///
    /// **Kenapa arah saja tidak cukup, dan `isWaxing` tidak bisa
    /// menggantikannya.** `isWaxing` hanya memberi dua kemungkinan (kanan
    /// atau kiri), dan itu benar hanya bila sabitnya berdiri tegak —
    /// keadaan yang berlaku di lintang tinggi, bukan di Indonesia. Jakarta
    /// berada di lintang -6.2 derajat, di dekat ekuator, tempat sabit
    /// muda justru terlihat "terlentang": sisi terangnya menghadap **bawah**
    /// ke tempat Matahari terbenam. Menggambarnya sebagai sabit tegak
    /// menghadap kanan bukan sekadar kurang mirip — itu gambar yang salah
    /// arah pada aplikasi yang seluruh nilainya bergantung pada tidak
    /// menampilkan klaim yang keliru.
    ///
    /// Aturan fisisnya tunggal dan berlaku di mana saja: **sisi terang
    /// selalu menghadap Matahari.** Sudut inilah terjemahan aturan itu ke
    /// bidang gambar, jadi tidak ada cabang per-belahan-bumi di sini —
    /// lintang sudah masuk lewat posisi Matahari dan Bulan yang dihitung
    /// engine.
    ///
    /// `nil` berarti "tidak diketahui", dan UI lalu **tidak memutar**
    /// gambar (kembali ke perilaku lama), bukan menebak sudutnya.
    public var brightLimbAngleRadians: Double?

    // MARK: - Bintang

    /// Indeks warna B−V. Positif = merah, negatif = biru.
    ///
    /// Diisi dari **tabel warna nyata per bintang**, bukan dari magnitudo:
    /// magnitudo mengatakan seberapa terang, bukan warna apa. Merah dan biru
    /// yang tertukar akan terlihat "cukup masuk akal" bagi kebanyakan
    /// pengguna, jadi kesalahannya tidak akan pernah dilaporkan — persis
    /// jenis klaim tanpa dasar yang harus diuji, bukan diasumsikan.
    public var colorIndexBV: Double
    /// Radius relatif untuk digambar, 0…1 (1 = benda paling terang yang ada
    /// di katalog).
    public var relativeSize: Double

    // MARK: - Objek langit dalam

    /// Objek langit dalam: seberapa menyebar objeknya (0 = titik, 1 = kabut lebar).
    ///
    /// Nebula dan galaksi tidak punya tepi, jadi ukurannya tidak bisa
    /// diturunkan dari magnitudo seperti bintang. Angka ini yang membedakan
    /// "titik kabur" dari "kabut lebar".
    public var fuzziness: Double

    /// Fraksi piringan yang menyala untuk **Venus dan Merkurius**.
    ///
    /// **Kenapa planet butuh fase sama seperti Bulan.** Venus dan Merkurius
    /// adalah planet dalam: dari Bumi, piringannya sebagian besar waktu
    /// **tidak** menyala penuh. Venus berayun dari sabit 1% (saat di antara
    /// Bumi dan Matahari) sampai cakram 99% (di sisi jauh) — bentuk yang
    /// berubah drastis dan itulah ciri yang paling dikenal orang tentang
    /// Venus di teleskop. Merkurius bahkan lebih ekstrem: fase terbesarnya
    /// hanya ~30% iluminasi.
    ///
    /// **Cacat yang ditutup medan ini.** Sebelumnya `phaseGeometry` menolak
    /// setiap benda yang bukan Bulan, dan `PointingEngine` hanya meneruskan
    /// fraksi untuk Bulan. Akibatnya Venus digambar sebagai **bola penuh yang
    /// menyala** pada setiap keadaan — termasuk saat engine menghitung
    /// iluminasinya 2%. Gambar itu menyatakan sesuatu yang engine justru
    /// sedang menyangkal, dan tidak ada satu teks di layar yang bisa dibaca
    /// pengguna untuk memeriksanya. Ini kelas cacat yang sama dengan pita
    /// Jupiter pada Saturnus, hanya dalam arah sebaliknya: bukan ciri yang
    /// ditambahkan, melainkan fakta yang dihilangkan.
    ///
    /// Nilainya `nil` untuk benda selain Venus/Merkurius — fase planet luar
    /// (Mars…Saturnus) memang tidak pernah terlihat dari Bumi, jadi tidak ada
    /// yang hilang dengan membiarkannya `nil`.
    public var planetPhaseFraction: Double?

    /// Id objek dari engine, bila ada.
    ///
    /// **Kenapa id ikut ke model, padahal "bentuk" sudah ada di `fuzziness`.**
    /// `fuzziness` hanya mengatur **lebar**; bentuknya (nebula vs galaksi vs
    /// gugus) tidak bisa dipulihkan dari satu angka. Tanpa id, lapisan gambar
    /// hanya bisa menggambar satu bentuk untuk seluruh kelas objek langit
    /// dalam — galaksi, gugus terbuka, dan gugus bola tampil identik. Id ini
    /// yang membuat view bisa menanyakan `DeepSkyCatalogue.morphology`
    /// (teruji di Linux) alih-alih menebak bentuk dari lebarnya.
    ///
    /// `nil` untuk benda tata surya: bentuk mereka sudah ditentukan
    /// `kind`/`planet`, jadi id tidak menambah apa pun di sana.
    ///
    /// **Bintang sekarang terisi, dan itu koreksi.** Catatan lama di sini
    /// menyatakan `nil` juga untuk bintang karena "id tidak menambah apa pun".
    /// Itu benar untuk **gambar** — warna bintang sudah sampai lewat
    /// `colorIndexBV` — dan salah untuk **ucapan**: `spokenStarColor` dan
    /// `spokenStarClassLine` menanyakan id untuk membangunkan tabel, jadi tanpa
    /// id keduanya `nil` dan VoiceOver hanya mengucapkan "bintang". Satu
    /// properti dengan dua konsumen; ramalan yang hanya membaca salah satunya
    /// adalah cara cacat itu bertahan.
    public var objectID: String?

    /// Apakah gambar ini perlu denyut sama sekali.
    ///
    /// **Kenapa ini milik model, bukan milik view.** Hanya glow bintang yang
    /// benar-benar berubah dari waktu ke waktu; planet, Bulan, Matahari, dan
    /// nebula digambar dari konstanta saja. Tapi pemanggil tidak bisa
    /// menanyakan itu ke view: `TimelineView` harus dipasang **sebelum**
    /// tahu apa yang akan digambar, jadi jalan yang tersedia tanpa properti
    /// ini adalah menjalankannya untuk semua jenis dan berharap pengoptimasian
    /// menyusul. Properti ini membuat pertanyaannya punya satu jawaban yang
    /// bisa diuji di Linux.
    ///
    /// Yang dilindungi di sini bukan nilai boolean-nya. Yang dilindungi
    /// adalah jumlah redraw: `TimelineView` 30 fps di sekitar planet berarti 30
    /// frame yang identik per detik, terus-menerus, sementara pengguna
    /// menatap bola yang diam.
    public var hasPulse: Bool { kind == .star }

    public init(kind: Kind,
                planet: Planet? = nil,
                illuminationFraction: Double? = nil,
                isWaxing: Bool? = nil,
                brightLimbAngleRadians: Double? = nil,
                colorIndexBV: Double = 0,
                relativeSize: Double = 0.5,
                fuzziness: Double = 0,
                planetPhaseFraction: Double? = nil,
                objectID: String? = nil) {
        self.kind = kind
        self.planet = planet
        self.illuminationFraction = illuminationFraction
        self.isWaxing = isWaxing
        self.brightLimbAngleRadians = brightLimbAngleRadians
        self.colorIndexBV = colorIndexBV
        self.relativeSize = relativeSize
        self.fuzziness = fuzziness
        self.planetPhaseFraction = planetPhaseFraction
        self.objectID = objectID
    }

    // MARK: - Pembuatan dari objek engine

    /// Bangun model visual untuk sebuah objek hasil resolusi.
    ///
    /// - Parameters:
    ///   - object: objek yang dijawab engine.
    ///   - moonIlluminationFraction: fraksi fase Bulan dari `SkyContext`.
    ///     Hanya dipakai bila objeknya benar-benar Bulan — meneruskannya ke
    ///     benda lain akan menggambar fase Bulan pada planet.
    ///   - isWaxing: arah fase Bulan, bila diketahui.
    ///   - brightLimbAngleRadians: sudut sisi terang **di langit pengamat**,
    ///     bila diketahui — berlaku untuk Bulan dan planet dalam, karena
    ///     aturannya satu (sisi terang menghadap Matahari).
    ///   - planetIlluminationFraction: fraksi piringan yang menyala untuk
    ///     planet **dalam** (Venus, Merkurius), dari efemeris. Hanya dipakai
    ///     bila planetnya memang punya fase yang terlihat dari Bumi
    ///     (`Planet.showsPhase`) — Mars dan planet luar tidak pernah tampak
    ///     berfase, jadi meneruskan angkanya ke sana akan menggambar sabit
    ///     yang tidak pernah ada.
    public init(object: CelestialObject,
                moonIlluminationFraction: Double? = nil,
                isWaxing: Bool? = nil,
                brightLimbAngleRadians: Double? = nil,
                planetIlluminationFraction: Double? = nil) {
        switch object.kind {
        case .moon:
            self.init(kind: .moon,
                      illuminationFraction: moonIlluminationFraction,
                      isWaxing: isWaxing,
                      brightLimbAngleRadians: brightLimbAngleRadians,
                      relativeSize: 1.0)
        case .planet:
            let planet = Planet(objectID: object.id)
            self.init(kind: .planet,
                      planet: planet,
                      isWaxing: isWaxing,
                      brightLimbAngleRadians: brightLimbAngleRadians,
                      relativeSize: Self.sizeFromMagnitude(object.magnitude),
                      // Fase planet hanya diteruskan bila planetnya memang
                      // menampakkan fase dari Bumi. Planet luar (Mars…
                      // Saturnus) tidak pernah — jadi angkanya dibuang di
                      // sini, bukan di view, supaya view tidak perlu tahu
                      // planet mana yang berfase.
                      planetPhaseFraction: planet?.showsPhase == true
                          ? planetIlluminationFraction : nil)
        case .star:
            self.init(kind: .star,
                      colorIndexBV: Self.colorIndex(forStarID: object.id),
                      relativeSize: Self.sizeFromMagnitude(object.magnitude),
                      // **Id diteruskan juga untuk bintang**, walaupun bentuk
                      // gambarnya tidak memerlukannya.
                      //
                      // Cacat yang ditutup: jalur ini dulu mengisi id hanya
                      // untuk objek langit dalam, jadi setiap bintang sampai
                      // ke lapisan ucapan tanpa id — dan seluruh rantai warna
                      // (`starColorText`, `spokenStarColor`) berakhir `nil`.
                      // Yang terdengar untuk Rigel hanyalah "bintang": bukan
                      // salah warna, melainkan diam. Gambarnya tidak berubah
                      // satu piksel pun (warna tetap lewat `colorIndexBV`),
                      // dan itulah sebabnya cacat ini tidak punya jejak visual
                      // sama sekali.
                      //
                      // Ramalan lama di catatan `objectID` ("`nil` untuk …
                      // bintang: id tidak menambah apa pun di sana") benar
                      // untuk gambar dan salah untuk ucapan — dua konsumen
                      // yang berbeda dibaca sebagai satu.
                      objectID: object.id)
        case .sun:
            self.init(kind: .sun, relativeSize: 1.0)
        case .deepSky:
            // Objek langit dalam tidak punya magnitudo yang sebanding dengan
            // bintang (magnitudonya terintegrasi, bukan titik), jadi ukurannya
            // tidak diturunkan dari angka itu. Yang membedakan satu objek dari
            // yang lain adalah **bentuknya**, dan itu datang dari dua tempat:
            // `fuzziness` (seberapa lebar) dan id objek (bentuk apa). Id
            // diteruskan supaya lapisan gambar bisa menanyakan morfologinya
            // (`DeepSkyCatalogue.morphology`, teruji di Linux) -- tanpa id,
            // galaksi, gugus terbuka, dan gugus bola digambar identik.
            self.init(kind: .deepSky, relativeSize: 0.7,
                      fuzziness: DeepSkyCatalogue.fuzziness(forObjectID: object.id),
                      objectID: object.id)
        }
    }

    // MARK: - Geometri fase Bulan

    /// Geometri terminator Bulan, siap digambar oleh `Canvas`.
    ///
    /// **Kenapa ini dihitung di sini, bukan di view.** Sabit Bulan adalah
    /// selisih dua kurva: piringan Bulan dikurangi separuh elips terminator
    /// yang membentang dari kutub atas ke kutub bawah. Elips itu bernilai
    /// `x = terminatorOffset · R · √(1 − (y/R)²)`, dan daerah yang menyala
    /// adalah pita **antara** kurva itu dengan limb di sisi yang terang.
    /// Kalau tanda `terminatorOffset` terbalik, sabitnya menghadap ke
    /// belakang — dan tidak ada teks di layar yang memberitahu pengguna
    /// bahwa gambarnya terbalik. Karena itu **tanda**-nya diuji
    /// (`CelestialVisualTests`), bukan hanya besarnya.
    public struct PhaseGeometry: Equatable, Sendable {
        /// Posisi x terminator di ekuator, dalam satuan radius piringan (−1…1).
        ///
        /// Pita yang menyala adalah daerah **antara** kurva terminator ini dan
        /// limb pada `litSide`. Untuk fase sabit nilainya positif (terminator
        /// berada di sisi yang terang, menyisakan pita tipis); untuk gibbous
        /// nilainya negatif (terminator sudah melewati pusat ke sisi gelap,
        /// menyisakan pita lebar).
        public var terminatorOffset: Double

        /// Sisi piringan yang menyala: `+1` kanan, `−1` kiri.
        ///
        /// Sengaja terpisah dari tanda `terminatorOffset`, karena untuk fase
        /// gibbous keduanya **berlawanan**: sabit membesar yang hampir
        /// purnama punya terminator di kiri sementara sisi yang menyala tetap
        /// kanan. Mengambil sisi dari tanda `terminatorOffset` akan
        /// membalikkan arah sabit tepat pada fase yang paling mudah dikenali.
        public var litSide: Double

        /// Apakah fase-nya gibbous (lebih dari setengah).
        public var isGibbous: Bool

        /// Lebar pita yang menyala di ekuator, dalam satuan radius (0…2).
        ///
        /// Berguna untuk uji dan untuk memastikan sabit tidak pernah melebar
        /// melebihi piringan: untuk bulan baru nilainya nol.
        ///
        /// **Peringatan: nilai ini bukan ukuran yang benar-benar digambar.**
        /// Ia hanya selisih antara limb dan terminator di ekuator, dan ia
        /// **tetap positif pada fase gibbous** — padahal kurvanya sudah
        /// terbalik ke sisi gelap. Lebar yang benar harus dihitung dari luas
        /// kurva (lihat `testLitBandAreaMatchesTheIlluminatedFraction`).
        public var litBandWidth: Double { abs(litSide - terminatorOffset) }

        // MARK: Kurva batas (satuan: radius piringan = 1.0)

        /// Titik limb pada ketinggian tertentu, dalam satuan radius.
        ///
        /// - Parameter h: tinggi ternormalisasi, −1 (kutub bawah) … +1
        ///   (kutub atas).
        public func limbX(atNormalizedHeight h: Double) -> Double {
            return litSide * sqrt(max(0, 1 - h * h))
        }

        /// Titik terminator pada ketinggian tertentu, dalam satuan radius.
        ///
        /// **Kenapa tanda `terminatorOffset` dipakai apa adanya di sini.**
        /// Nilainya sudah `litSide · (1 − 2f)`, jadi **tandanya sudah
        /// menentukan sisi** terminator: positif untuk sabit (terminator di
        /// sisi yang menyala, menyisakan pita tipis), negatif untuk gibbous
        /// (sudah menyeberang ke sisi gelap, menyisakan pita lebar).
        ///
        /// Mengambil nilai mutlaknya lalu mengalikan lagi dengan `litSide`
        /// membuang tanda itu — dan hasilnya bukan sekadar beda rasa, tapi
        /// komplemen: untuk f > 0.5 terminator terpaku kembali ke sisi yang
        /// menyala, sehingga pita yang digambar sebesar `1 − f`. Geometri
        /// itu menampilkan bulan 85% sebagai sabit 15%, dan bulan purnama
        /// sebagai piringan gelap, sementara angka "Fase Bulan 100%" tampil
        /// persis di atasnya.
        ///
        /// Karena itu rumus kurvanya **tidak boleh tinggal di view**: view
        /// tidak bisa diuji di Linux, dan bug seperti ini lolos `swiftc
        /// -parse`, lolos seluruh uji yang hanya memeriksa `litSide` dan
        /// lebar pita, serta tidak punya satu pun teks layar yang bisa dibaca
        /// pengguna untuk memeriksanya.
        ///
        /// - Parameters:
        ///   - h: tinggi ternormalisasi, −1 … +1.
        ///   - offset: offset terminator. Sengaja opsional (bukan nilai
        ///     bawaan yang membaca properti instans — Swift melarang
        ///     instance member sebagai nilai default parameter), supaya uji
        ///     bisa mengunci cacat lama dengan memanggil
        ///     `abs(terminatorOffset)` secara eksplisit.
        public func terminatorX(atNormalizedHeight h: Double,
                                offset explicitOffset: Double? = nil) -> Double {
            let offset = explicitOffset ?? terminatorOffset
            return offset * sqrt(max(0, 1 - h * h))
        }
    }

    /// Hitung geometri fase dari fraksi iluminasi.
    ///
    /// Lebar pita terang di ekuator berbanding lurus dengan fraksi iluminasi,
    /// yaitu `|litSide − terminatorOffset| = 2f`, sehingga
    /// `terminatorOffset = litSide · (1 − 2f)`.
    ///
    /// **Kenapa planet dalam ikut di sini.** Venus dan Merkurius berfase
    /// persis seperti Bulan, dan gambarnya memakai kurva yang sama — jadi
    /// rumusnya pun satu, bukan dua. Yang berbeda hanya **sumber fraksinya**
    /// (`planetPhaseFraction`, dari efemeris, vs `illuminationFraction`,
    /// dari `SkyContext`) dan **arah sisi terangnya** (lihat
    /// `phaseGeometryForPlanet`). Planet luar sengaja tidak ikut: fase
    /// mereka tidak pernah terlihat dari Bumi, jadi menggambarnya berarti
    /// mengarang bentuk yang tidak ada.
    ///
    /// - Parameter waxing: arah fase. **`nil` menghasilkan `nil`**: tanpa arah,
    ///   gambar apa pun yang digambar akan memihak ke satu sisi, dan itu
    ///   pernyataan yang tidak dihitung engine.
    /// - Returns: `nil` bila fase tidak bisa digambar (benda yang tidak
    ///   berfase, fraksi tidak tersedia, atau arah tidak diketahui). UI lalu
    ///   menggambar piringan tanpa fase — bukan sabit yang memilih sisi.
    public func phaseGeometry(waxing: Bool?) -> PhaseGeometry? {
        guard let f = fractionForPhase, let waxing else { return nil }
        return Self.phaseGeometry(fraction: f, waxing: waxing)
    }

    /// Fraksi iluminasi yang dipakai menggambar fase benda ini.
    ///
    /// Bulan mengambilnya dari `illuminationFraction`; planet dalam dari
    /// `planetPhaseFraction`. Satu aksesor supaya `phaseGeometry` tidak
    /// memilih cabang berdasarkan `kind` — dan supaya menambah benda
    /// berfase berikutnya hanya berarti satu baris di sini.
    public var fractionForPhase: Double? {
        switch kind {
        case .moon: return illuminationFraction
        case .planet: return planetPhaseFraction
        case .star, .sun, .deepSky: return nil
        }
    }

    /// Geometri fase dari fraksi — fungsi murni, tanpa membaca properti.
    ///
    /// Dipisah supaya planet bisa memakainya dengan arah sisi terang yang
    /// **berbeda**: untuk Bulan arahnya dihitung dari efemeris
    /// (`brightLimbAngle`), sedangkan untuk planet dalam belum ada sumber
    /// sudut yang teruji — jadi planet memakai konvensi `isWaxing` yang
    /// sama dengan Bulan, bukan sudut yang dikarang. Pemisahan ini membuat
    /// rumus kurvanya tetap **satu** untuk kedua jenis benda.
    public static func phaseGeometry(fraction: Double, waxing: Bool) -> PhaseGeometry {
        let clamped = min(1, max(0, fraction))
        let litSide: Double = waxing ? 1 : -1
        let offset = litSide * (1 - 2 * clamped)
        return PhaseGeometry(terminatorOffset: offset,
                             litSide: litSide,
                             isGibbous: clamped > 0.5)
    }

    // MARK: - Earthshine (cahaya Bulan dari Bumi)

    /// Kekuatan earthshine pada sisi gelap Bulan, 0…1.
    ///
    /// Earthshine adalah cahaya Matahari yang dipantulkan Bumi ke sisi gelap
    /// Bulan. Ia **hanya** ada bila ada sisi gelap untuk diterangi — artinya
    /// saat Bulan **sebagian** tersinari. Dua keadaan di mana earthshine
    /// harus **nol**:
    ///
    /// - `fraction == 1` (purnama): tidak ada sisi gelap; menggambar
    ///   earthshine berarti menambah cahaya di mana langit tidak
    ///   memilikinya, dan pada ukuran kecil jam akan terbaca sebagai
    ///   "piringan menyala penuh" — klaim yang salah.
    /// - `fraction == 0` (bulan baru): seluruh piringan gelap, tapi
    ///   earthshine pada bulan baru nyaris tak terlihat (Bumi juga hampir
    ///   baru dilihat dari Bulan) dan, lebih penting, nilai `0` juga
    ///   dipakai sebagai "fase tak diketahui" di kartu ragu — di sana kita
    ///   **tidak** boleh menggambar cahaya apa pun yang menyatakan sabit.
    ///
    /// Antara keduanya earthshine paling kuat saat sabit tipis (sisi gelap
    /// paling luas) dan meredup menuju purnama. Kurva `1 - f` memenuhi
    /// semua syarat di atas: `0` di `f = 1`, maksimum di `f → 0`, dan
    /// monoton turun. Diuji di Linux (`testEarthshineOnlyOnPartiallyLitMoon`).
    public static func earthshineStrength(illuminationFraction fraction: Double) -> Double {
        let f = min(1, max(0, fraction))
        return 1 - f
    }

    // MARK: - Warna bintang

    /// Sudut sisi terang Bulan **di bidang gambar** — fungsi murni, tanpa
    /// efemeris.
    ///
    /// **Kenapa ada di sini, bukan di `PointingResolver`.** Efemeris tidak
    /// tersedia saat uji di Linux (tidak ada `AstronomyKit`), jadi rumus
    /// yang tinggal di dalamnya **tidak bisa diuji sama sekali** — padahal
    /// justru rumus inilah yang menentukan apakah sabit menghadap arah yang
    /// benar. Dengan dipisah, geometrinya diuji memakai alt/az yang ditulis
    /// tangan; yang tersisa di lapisan tak-teruji hanyalah pemanggilan
    /// efemerisnya.
    ///
    /// **Kenapa sudut, bukan boolean kanan/kiri.** `isWaxing` hanya benar
    /// bila sabitnya berdiri tegak — keadaan lintang tinggi. Di dekat
    /// ekuator (Jakarta, lintang -6.2 derajat) sabit muda justru terlentang,
    /// sisi terangnya menghadap **bawah**. Jadi `isWaxing` bukan aproksimasi
    /// kasar untuk sudut ini; ia jawaban yang salah di tempat aplikasi ini
    /// dipakai.
    ///
    /// Langkah-langkahnya:
    ///
    /// 1. Vektor Bulan→Matahari dalam kerangka ENU (x = Timur, y = Utara,
    ///    z = Atas), dari **beda vektor satuan** — bukan beda sudut alt/az,
    ///    yang punya titik singular di kutub dan di zenit.
    /// 2. Buang komponen sepanjang garis pandang, sisakan proyeksi di bidang
    ///    gambar. **Tanpa langkah ini**, vektor dengan komponen mendalam
    ///    besar menghasilkan arah yang menunjuk keluar layar: sudutnya
    ///    berayun liar saat Bulan dekat zenit, padahal yang dilihat mata
    ///    justru berubah paling lambat di sana.
    /// 3. Ukur sudutnya dari "kanan" dengan "atas" positif (konvensi sudut
    ///    layar, searah jarum jam karena y layar menghadap ke bawah).
    ///
    /// Karena kerangkanya lokal, **tidak ada cabang per-belahan-bumi di
    /// sini**: lintang sudah masuk lewat posisi Matahari dan Bulan.
    ///
    /// - Returns: `nil` bila Bulan dan Matahari berimpit (tidak ada arah),
    ///   atau bila vektor Bulan→Matahari tepat sepanjang garis pandang
    ///   (tidak ada sudut di bidang gambar). UI lalu **tidak memutar**
    ///   gambar, bukan menebak sudutnya.
    ///
    /// **Kenapa parameternya `body:` dan bukan `moon:`.** Aturannya satu dan tidak
    /// menyebut Bulan sama sekali: **sisi terang selalu menghadap Matahari.**
    /// Itu berlaku untuk Bulan, untuk Venus yang berfase, dan untuk Merkurius.
    /// Menamai parameternya `moon` membuat fungsi ini tampak hanya sah untuk
    /// satu benda, dan versi berikutnya akan menyalinnya untuk planet —
    /// dua salinan rumus yang sama, yang cepat atau lambat akan berbeda.
    /// (Fungsi ini dulu memang bernama begitu; yang berubah hanya namanya,
    /// perhitungannya tidak.)
    ///
    /// - Parameters:
    ///   - body: benda yang piringannya digambar (posisi horizontal).
    ///   - sun: posisi Matahari dari pengamat yang sama.
    public static func brightLimbAngle(body: HorizontalCoord,
                                       sun: HorizontalCoord) -> Double? {
        func enu(_ h: HorizontalCoord) -> (e: Double, n: Double, u: Double) {
            let alt = SkyMath.deg2rad(h.altitudeDeg)
            let az = SkyMath.deg2rad(h.azimuthDeg)
            return (cos(alt) * sin(az), cos(alt) * cos(az), sin(alt))
        }

        let m = enu(body)
        let s = enu(sun)
        let delta = (e: s.e - m.e, n: s.n - m.n, u: s.u - m.u)
        let length = (delta.e * delta.e + delta.n * delta.n
                      + delta.u * delta.u).squareRoot()
        guard length > 1e-9 else { return nil }

        let depth = delta.e * m.e + delta.n * m.n + delta.u * m.u
        let screenE = delta.e - depth * m.e
        let screenN = delta.n - depth * m.n
        let screenU = delta.u - depth * m.u
        guard screenE * screenE + screenN * screenN + screenU * screenU > 1e-18
        else { return nil }

        // Pengamat menghadap Bulan. Basis gambar diturunkan sebagai vektor,
        // bukan dari sudut alt/az: `right = m x atas-dunia`, `up = right x m`.
        // Dijumlahkan sebagai vektor, jadi sahih untuk azimut berapa pun --
        // termasuk saat Bulan tepat di zenit, tempat rumus berbasis sudut
        // kehilangan acuan. (Versi pertama fungsi ini menulis kedua basis
        // dari tangan dan keduanya salah: `right` terbalik, dan `up` bahkan
        // tidak tegak lurus terhadap `m`. Itu ketahuan dari uji, bukan dari
        // membaca ulang rumusnya.)
        let right = screenE * m.n + screenN * (-m.e)
        let up = screenE * (-m.e * m.u)
               + screenN * (-m.n * m.u)
               + screenU * (m.e * m.e + m.n * m.n)
        guard right != 0 || up != 0 else { return nil }
        return atan2(up, right)
    }

    /// Sudut putaran untuk **terminator** sebuah benda berfase, dalam radian
    /// (konvensi model; lihat `drawRotationRadians` untuk argumen `rotate`).
    ///
    /// **Kenapa tidak boleh memakai `brightLimbAngleRadians` langsung.**
    /// `brightLimbAngle` menunjuk arah **Matahari** dari benda itu: vektor
    /// keluar dari piringan menuju sumber cahaya. Sementara `PhaseGeometry`
    /// menggambar pita terang yang, pada sudut nol, berada di **kanan** untuk
    /// sabit (`litSide = +1`) tetapi di **kiri** untuk gibbous
    /// (`litSide = −1`) — lihat `phaseGeometry(fraction:waxing:)`. Jadi
    /// meneruskan sudut Matahari apa adanya memasang sabit dan gibbous ke
    /// sisi yang berlawanan: satu dari keduanya selalu salah.
    ///
    /// Yang benar: pita terang membentang dari **terminator** ke **limb yang
    /// menyala**, dan garis tengahnya menghadap Matahari. Karena `litSide`
    /// sudah memberi tahu sisi mana yang menyala, sudut putarannya adalah
    /// sudut Matahari, **dibalik ketika sisi yang menyala justru kiri** —
    /// sehingga sisi kiri dibawa ke kanan dulu sebelum diputar.
    ///
    /// Kenapa ini di sini, bukan di view: view tidak diuji di Linux, dan
    /// kesalahannya tidak terlihat di layar — sabit yang terbalik tetap
    /// berbentuk sabit. Uji model yang menguncinya:
    /// `testTerminatorRotationPutsLitSideTowardTheSun`.
    ///
    /// - Returns: `nil` bila sudut Matahari tidak diketahui, atau bila benda
    ///   ini tidak punya fase. UI lalu menggambar tanpa putaran.
    public var terminatorRotationRadians: Double? {
        guard let sunAngle = brightLimbAngleRadians,
              let phase = phaseGeometry(waxing: isWaxing) else { return nil }
        // `litSide = −1` (pita ada di kiri pada sudut nol) → balik dulu.
        return phase.litSide < 0 ? sunAngle + .pi : sunAngle
    }

    /// Sudut yang harus diteruskan ke `GraphicsContext.rotate(by:)` untuk
    /// memutar pita terang ke arah `brightLimbAngle`.
    ///
    /// **Kenapa ada, dan kenapa tandanya dibalik.** `brightLimbAngle`
    /// memakai konvensi **matematis**: sudut positif berarti sisi terang
    /// menghadap **atas**, diukur berlawanan arah jarum jam dari arah kanan.
    /// Konvensi itu yang diuji (`testPolarCrescentFacesUpWhenSunIsHigher`).
    ///
    /// `GraphicsContext` SwiftUI memakai koordinat **layar** (y ke bawah),
    /// dan di sana sudut positif berputar **searah jarum jam** — Apple
    /// mendokumentasikannya di `CGContext.rotate(by:)`: pada konteks yang
    /// sudah dibalik, "positive values appear to rotate the coordinate
    /// system in the clockwise direction". Jadi meneruskan sudut model apa
    /// adanya mencerminkan sabit secara **vertikal**: sisi terang yang
    /// seharusnya menghadap bawah tampil menghadap atas.
    ///
    /// Cacat itu **tidak bisa ditangkap uji model** (modelnya benar) dan
    /// **tidak terlihat di layar**, karena sabitnya tetap berbentuk sabit.
    /// Ia juga paling sering muncul tepat di tempat aplikasi ini dipakai:
    /// di lintang rendah (Jakarta) sisi terang justru menghadap bawah atau
    /// atas, bukan ke samping — jadi kesalahan tanda di sini bukan
    /// perbedaan kosmetik di sana. Karena itu konversinya tinggal di sini,
    /// di tempat ia bisa diuji, bukan sebagai satu tanda minus di view yang
    /// tidak pernah dieksekusi di Linux.
    ///
    /// - Parameter angle: sudut dari `brightLimbAngle(body:sun:)`.
    /// - Returns: argumen untuk `rotate(by: .radians(_:))`.
    public static func drawRotationRadians(brightLimbAngleRadians angle: Double) -> Double {
        return -angle
    }

    /// Apakah sebuah piringan **membesar**, dari elongasinya terhadap Matahari.
    ///
    /// **Kenapa fungsi ini ada, padahal `isMoonWaxing` sudah menghitungnya.**
    /// `isMoonWaxing` membaca efemeris sendiri, jadi ia hanya bisa dipakai di
    /// tempat efemeris tersedia — dan aturannya karena itu tidak pernah diuji.
    /// Planet dalam butuh aturan yang **sama** (Venus membesar pada elongasi
    /// 0°–180°, persis seperti Bulan), tetapi menulis ambang 180° untuk kedua
    /// kalinya berarti dua konstanta yang cepat atau lambat berbeda: sabit
    /// Venus dan sabit Bulan lalu membesar ke arah yang berlawanan pada malam
    /// yang sama, dan tidak ada teks di layar yang bisa membantah keduanya.
    ///
    /// Fungsi murni ini membuat **satu** ambang yang dipakai kedua benda, dan
    /// satu-satunya hal yang tersisa di lapisan efemeris adalah menghitung
    /// selisih bujurnya — bukan memutuskan arahnya.
    ///
    /// - Parameter elongationDegrees: selisih bujur ekliptika benda terhadap
    ///   Matahari, sudah dinormalisasi ke 0…360 (lihat `normalizedDegrees`).
    public static func isWaxing(elongationDegrees: Double) -> Bool {
        normalizedDegrees(elongationDegrees) < 180
    }

    /// Bungkus sudut ke rentang 0…360.
    ///
    /// **Kenapa pindah ke `CelestialVisual`, padahal dulu ada di
    /// `PointingResolver`.** Ia sekarang hanya dipakai oleh aturan elongasi
    /// bersama (`isWaxing`), dan aturan itu harus bisa diuji di Linux tanpa
    /// efemeris — jadi pembungkusnya harus hidup di tempat yang sama dengan
    /// ambangnya, bukan di ekstensi yang hanya punya akses ke efemeris.
    static func normalizedDegrees(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    /// Indeks warna B−V untuk bintang yang ada di katalog.
    ///
    /// Nilainya dari katalog warna bintang terang yang sudah mapan. Yang
    /// penting di sini bukan presisi dua desimal, melainkan **tanda**-nya:
    /// Betelgeuse (M1, B−V ≈ +1.85) harus merah, Rigel (B8, B−V ≈ −0.03)
    /// biru, Sirius (A1, B−V ≈ 0.00) putih-biru. Tanda yang terbalik tidak
    /// akan pernah dilaporkan pengguna — karena itu ia diuji.
    ///
    /// Bintang yang tidak ada di tabel mengembalikan `unknownStarColorIndex`,
    /// yang **bukan** warna spektral apa pun (lihat catatan di sana).
    ///
    /// **Koreksi docstring.** Sampai siklus ini kalimatnya berbunyi "Bintang
    /// yang tidak ada di tabel mengembalikan `0` (putih), bukan warna
    /// karangan: putih netral tidak mengklaim apa-apa." Itu **salah dua kali**.
    /// `0` bukan putih: `starRGB(0)` = (0,69, 0,74, 0,85), putih kebiruan
    /// dengan R−B = −0,15 — kelas spektral A, warna Sirius dan Vega. Dan
    /// karena warnanya spektral, ia **mengklaim**. Yang benar: nilai tak
    /// dikenal harus di luar rentang B−V, supaya tidak ada bintang nyata yang
    /// bisa menghasilkannya.
    public static func colorIndex(forStarID id: String) -> Double {
        Self.starColorIndex[id] ?? Self.unknownStarColorIndex
    }

    /// Indeks "tidak ada klaim" untuk warna bintang.
    ///
    /// **Kenapa bukan `0`.** Cacat yang ditutup nilai ini: `0` adalah B−V yang
    /// **sah** — kelas A0, warna Sirius dan Vega. Memakainya sebagai sentinel
    /// berarti "bintang tak dikenal" dan "Sirius terkonfirmasi" menghasilkan
    /// gambar yang identik piksel demi piksel (diukur di port: keduanya
    /// (0,693, 0,742, 0,846)). Untuk dua bintang itu, seluruh jalur "ciri
    /// hilang saat ragu" tidak mencapai tujuannya — dan tidak ada uji yang
    /// bisa melihatnya, karena yang diukur "apakah ragu == tak dikenal",
    /// bukan "apakah nilainya tidak mengklaim".
    ///
    /// `NaN` dipilih karena ia **tidak bisa** dihasilkan oleh B−V bintang
    /// mana pun, jadi ia tidak bisa kebetulan menunjuk bintang — persis alasan
    /// yang sama yang membuat `neutralBody` planet dipakai alih-alih angka
    /// baru. `starRGB` menanganinya sebagai kasus khusus: hasilnya abu-abu
    /// akromatik (R=G=B), dan nilai akromatik tidak bisa menjadi warna
    /// spektral. Karena `NaN != NaN`, cabang ini **wajib** ditangani sebelum
    /// perbandingan apa pun di `starRGB`.
    public static let unknownStarColorIndex = Double.nan

    /// Ukuran "tidak mengklaim" untuk bintang ragu — satu nilai tengah yang
    /// bukan ukuran magnitudo bintang mana pun.
    ///
    /// **Kenapa bukan 0,15 atau 0,98.** Kedua ujung itu **adalah** magnitudo:
    /// 0,15 adalah lantai yang dipakai bintang paling redup yang bisa
    /// dikenali, sementara 0,98 adalah Sirius. Memakai salah satunya berarti
    /// klaimnya cuma berpindah nama. 0,5 bukan hasil `sizeFromMagnitude`
    /// magnitudo apa pun di katalog 25 bintang ini — terukur, bukan dinyatakan.
    /// Yang terdekat adalah Vega (+0,03) pada 0,4943, yaitu 0,0057 dari 0,5;
    /// Arcturus (−0,05) 0,5129. Tidak ada yang sama persis.
    ///
    /// **Batas yang diakui: 0,0057 itu kecil.** Ukuran ragu 0,5 memang dekat
    /// dengan ukuran Vega, jadi "ragu" masih lebih mirip Vega daripada Sirius.
    /// Yang dijaga bukan kemiripan dengan bintang tertentu — mustahil dihindari
    /// untuk satu nilai tengah — melainkan bahwa **semua** bintang ragu punya
    /// ukuran yang sama, sehingga ukuran tidak lagi bisa membedakan Sirius
    /// dari bintang redup. Gerbang ukuran-by-pixel di `check-visuals.py`
    /// mengukur jarak itu, bukan mendeklarasikannya.
    ///
    /// **Kenapa bukan deterministik-dari-id.** Sudut `scatterRotated` bintang
    /// dapat dipakai karena ia tidak mengubah jumlah, ukuran, maupun opasitas
    /// satu blob pun. Membuat ukuran ragu bervariasi per-id akan membawa pulih
    /// kegunaan magnitudo lewat pintu lain: "ragu" jadi tetap menyebut bintang,
    /// hanya dengan nama yang lebih kecil.
    public static let unknownStarSize: Double = 0.5

    /// Indeks warna yang boleh **digambar**, mengingat keyakinan engine.
    ///
    /// **Kenapa ini ada.** Warna spektral adalah ciri pengenal: biru pada
    /// Rigel dan merah pada Betelgeuse adalah penanda yang sama meyakinkannya
    /// dengan cincin Saturnus atau bentuk galaksi berpalung. Aturan untuk dua
    /// yang terakhir sudah lama berlaku — saat engine belum pasti, hanya warna
    /// netral yang boleh tampil, cirinya tidak. Bintang tertinggal: pita
    /// planet dijaga `palette.feature`, bentuk objek langit dalam dijaga
    /// `drawableMorphology`, sementara warna bintang diteruskan apa adanya.
    ///
    /// Kesalahannya tidak terlihat, dan itu yang membuatnya bertahan. Badge di
    /// sebelah gambar bisa bertuliskan "Ragu" sementara titik di sebelahnya
    /// berwarna merah khas Betelgeuse; mata membaca gambar lebih dulu daripada
    /// badge, dan tidak ada teks di layar yang bisa membuktikan titik merah
    /// itu tidak diklaim.
    ///
    /// Saat `isConfirmed == false` hasilnya adalah `unknownStarColorIndex` —
    /// indeks "tidak ada klaim" yang **di luar** rentang B−V, bukan `0`.
    ///
    /// **Kenapa bukan `0`, padahal `0` juga dipakai untuk bintang tak
    /// dikenal.** Dulu memang begitu, dan itu bagian dari cacatnya: `0` adalah
    /// B−V sah (A0 — warna Sirius dan Vega), jadi "ragu" dan "Sirius
    /// terkonfirmasi" menghasilkan gambar yang sama. Mengganti nilainya
    /// sekaligus di sini dan di `colorIndex(forStarID:)` menjaga sifat yang
    /// memang benar — warna ragu == warna bintang tak dikenal — tanpa ikut
    /// mewarisi klaim spektralnya. Yang tetap tampil saat ragu hanyalah
    /// **terang** (ukuran dari magnitudo), dan terang bukan identitas.
    /// Ukuran gambar bintang yang **belum mengklaim** identitas.
    ///
    /// **Kenapa `relativeSize` butuh gerbang keyakinan.** Warna spektral sudah
    /// ditahan oleh `drawableStarColorIndex`, palet planet oleh
    /// `Palette.drawable`, morfologi objek langit dalam oleh
    /// `drawableMorphology`. `relativeSize` tidak — dan docstring ketiga fungsi
    /// itu menyatakan premis yang dibantah pengukuran: "Yang tetap tampil saat
    /// ragu hanyalah terang (ukuran dari magnitudo), dan terang bukan
    /// identitas."
    ///
    /// Diukur pada katalog 25 bintang repo ini. `sizeFromMagnitude` memberi
    /// **24 ukuran berbeda untuk 25 bintang**: Sirius (−1.46) -> 0.982,
    /// Polaris (+1.98) -> 0.201 — hampir 5x. Jadi di katalog ini magnitudo
    /// praktis adalah sidik jari. Di piksel (render 200 px, ss=2) bintang ragu
    /// bermagnitudo Sirius membawa **1725** satuan cahaya sementara bintang
    /// redup **1095** — selisih 57%. Titik besar dan terang di samping badge
    /// "Ragu" tetap menyebut Sirius, dan mata membaca ukuran sebelum lencana.
    ///
    /// **Bukan memadatkan seluruh skala.** Ukuran ragu satu nilai untuk semua
    /// bintang: nilai "tidak mengklaim", sama seperti `unknownStarColorIndex`
    /// untuk warna. Nilai itu **tengah** rentang (0,5): bukan 0,15 (yang
    /// merupakan magnitudo tertentu) dan bukan 0,98.
    ///
    /// **Yang TIDAK diklaim.** Ukuran tetap wajar saat engine **yakin** — itu
    /// memang fiturnya, magnitudo -> besar glow. Yang ditahan hanya klaim lewat
    /// ukuran saat identitas belum pasti.
    public static func drawableStarSize(_ visual: CelestialVisual,
                                        isConfirmed: Bool) -> Double {
        guard isConfirmed else { return Self.unknownStarSize }
        return visual.relativeSize
    }

    public static func drawableStarColorIndex(_ colorIndexBV: Double,
                                              isConfirmed: Bool) -> Double {
        guard isConfirmed else { return Self.unknownStarColorIndex }
        return colorIndexBV
    }

    /// Apakah **peredupan permukaan** Bulan (maria + kawah) boleh digambar.
    ///
    /// Cacat yang ditutup (terukur): `drawMoon` di view **tidak menerima
    /// `isConfirmed` sama sekali** — nol kemunculan di badannya — sehingga
    /// bercak maria dan kawah digambar untuk Bulan yang belum dikunci.
    /// Maria adalah ciri pengenal: pola gelap-terang itu menyebut **muka**
    /// yang mana, dan hanya Bulan yang memilikinya. Gambar yang
    /// memperlihatkannya lebih yakin daripada badge "Ragu" di sebelahnya,
    /// persis yang dilarang PRD §2.
    ///
    /// **Kenapa gerbangnya di sini, bukan di view.** `Apps/` tidak pernah
    /// dibangun di Linux, jadi aturan yang hidup hanya di badan view tidak
    /// bisa diuji di sini. Yang bisa diuji: keputusan "boleh atau tidak",
    /// dan itu yang diuji (`testMoonSurfaceShadingIsGatedByCertaintyLikeEveryOtherIdentityCue`).
    /// Gerbang pikselnya ada di `Tools/check-visuals.py` dan mengukur render
    /// yang sesungguhnya.
    ///
    /// **Yang TIDAK diklaim.** Saat belum pasti, piringan tetap **bola** dan
    /// sabitnya tetap gambar fase yang benar — bentuk fase bukan identitas
    /// (semua benda berfase punya sabit), sedangkan pola maria adalah
    /// identitas. Yang dibuang hanya pola itu.
    public static func drawsMoonSurfaceShading(isConfirmed: Bool) -> Bool {
        isConfirmed
    }

    /// Tabel B−V per id bintang di `Catalogue.brightStars`.
    ///
    /// Sengaja `internal` (bukan `private`) supaya uji bisa menegakkan bahwa
    /// **setiap** bintang di katalog punya entri warna. Tanpa uji itu,
    /// menambah bintang ke katalog akan menghasilkan bintang putih yang
    /// tampak sah padahal warnanya tidak diketahui.
    static let starColorIndex: [String: Double] = [
        "sirius":      0.00,   // A1 — putih kebiruan
        "canopus":     0.15,   // F0 — putih
        "arcturus":    1.23,   // K0 — jingga
        "vega":        0.00,   // A0 — putih kebiruan
        "capella":     0.80,   // G8 — kuning
        "rigel":      -0.03,   // B8 — biru
        "procyon":     0.42,   // F5 — putih kekuningan
        "achernar":   -0.16,   // B6 — biru
        "betelgeuse":  1.85,   // M1 — merah
        "hadar":      -0.23,   // B1 — biru
        "altair":      0.22,   // A7 — putih
        "acrux":      -0.24,   // B0 — biru
        "aldebaran":   1.54,   // K5 — jingga kemerahan
        "spica":      -0.23,   // B1 — biru
        "antares":     1.83,   // M1 — merah
        "pollux":      1.00,   // K0 — jingga
        "fomalhaut":   0.09,   // A3 — putih
        "deneb":       0.09,   // A2 — putih
        "regulus":    -0.11,   // B8 — biru keputihan
        "castor":      0.03,   // A1 — putih
        "bellatrix":  -0.22,   // B2 — biru
        "alioth":     -0.02,   // A1 — putih
        "alnitak":    -0.21,   // O9 — biru
        "dubhe":       1.07,   // K0 — jingga
        "polaris":     0.60    // F7 — putih kekuningan
    ]

    /// Warna **"tidak ada klaim"** untuk bintang: abu-abu akromatik.
    ///
    /// Dipakai saat identitas belum dikunci (`drawableStarColorIndex`
    /// mengembalikan `unknownStarColorIndex`) dan untuk bintang yang tidak ada
    /// di tabel. R=G=B disengaja: nilai akromatik **tidak bisa** menjadi warna
    /// spektral mana pun, jadi tidak ada bintang nyata yang bisa dikira
    /// terlihat di situ. Sebelumnya jalur ini memakai B−V 0,00 — yang justru
    /// adalah warna Sirius dan Vega (putih kebiruan), sehingga ketidaktahuan
    /// dan identifikasi Sirius tampak sama persis.
    ///
    /// Terangnya dipilih **lebih rendah** dari bintang paling redup di
    /// katalog **bukan** tujuannya di sini — ukuran titik tetap dari
    /// magnitudo, dan yang berubah hanya warna. Nilainya diletakkan di tengah
    /// rentang kanal `starRGB` supaya titik "tidak mengklaim" tidak tampak
    /// menyala dibanding bintang sekitar.
    public static let neutralStarBody = RGBComponents(red: 0.78, green: 0.78, blue: 0.78)

    /// Menjepit satu komponen kanal ke 0...1.
    private static func unit(_ value: Double) -> Double { min(1, max(0, value)) }

    /// RGB **siang** untuk sebuah indeks B−V, sebagai komponen mentah.
    ///
    /// Indeks `unknownStarColorIndex` (`NaN`) adalah kasus khusus dan
    /// **ditangani lebih dulu**, sebelum penjepitan apa pun — karena
    /// `min`/`max` meneruskan `NaN`, sehingga tanpa cabang ini seluruh
    /// perhitungan di bawah akan menghasilkan `NaN` dan titiknya menghilang.
    ///
    /// Monokromatik: panjang gelombang "berat" = merah. B−V positif
    /// (Betelgeuse, Arcturus, Aldebaran) → hangat; negatif (Rigel, Alnitak,
    /// Acrux) → dingin. Trennya benar secara astronomi dan cukup untuk
    /// perbedaan yang dilihat pengguna mata telanjang.
    ///
    /// **Kenapa rumusnya pindah dari view ke sini.** Ini satu-satunya
    /// persamaan warna yang masih tersisa di `CelestialVisualView`, dan
    /// yang diawasi bukan hanya "apakah warnanya masuk akal" tapi satu yang
    /// lebih halus: **apakah urutan luminansinya masih benar**. Mode malam
    /// membuang hue seluruhnya, jadi yang tersisa hanyalah terang. Kalau
    /// konversi ini membuat Rigel lebih terang dari Aldebaran, maka di malam
    /// keduanya menjadi titik merah dengan ukuran yang sama -- dan informasi
    /// yang hilang bukan hanya warna, tapi terang juga. Itu tidak bisa dibaca
    /// dari layar mana pun, jadi harus diuji, bukan diklaim.
    ///
    /// **Kenapa rentangnya `-0.35 … 2.10`, bukan `1.70`.** Cacat yang ditutup
    /// siklus ini: kanal merah `0.62 + 0.38·warmth` mencapai 1,0 pada B−V
    /// 1,35, dan katalog memuat **tiga** bintang di atas garis itu —
    /// Aldebaran (1,54), Antares (1,83), Betelgeuse (1,85). Ketiganya dijepit
    /// ke merah yang persis sama, 1,000, sehingga raksasa merah paling terang
    /// di langit tak bisa dibedakan satu sama lain di mode malam. Penjepitan
    /// itu benar sebagai pengaman (`Color` tidak punya kanal di atas 1) tetapi
    /// salah sebagai **desain**: yang seharusnya dijepit adalah *rentang
    /// masukan*, bukan hasilnya, supaya B−V nyata tidak pernah habis di dinding.
    /// Rentang 2,10 dipilih, bukan 2,50: ia mengosongkan dataran itu untuk
    /// setiap bintang katalog dengan sisa ruang (merah tertinggi 0,961 di
    /// Betelgeuse), sementara melebarkannya lebih jauh mulai menekan
    /// perbedaan antar-bintang biru yang justru lebih sering terlihat. Dijaga
    /// `testCatalogueStarsDoNotSaturateTheNightChannel`.
    public static func starRGB(forColorIndex index: Double) -> RGBComponents {
        // Sentinel "tidak ada klaim". Dicek dengan `isNaN`, bukan `==`,
        // karena `NaN == NaN` selalu salah — perbandingan tidak akan pernah
        // mengenalinya.
        if index.isNaN { return neutralStarBody }
        let clamped = min(2.0, max(-0.5, index))
        // −0.35 … +2.10 → 0 … 1 (biru ke merah), lalu dingatkan sedikit di
        // ujung biru supaya Rigel tidak tampak ungu. Batas atas 2,10 (bukan
        // 1,70) menjaga B−V nyata tertinggi di katalog (Betelgeuse, 1,85) tetap
        // di bawah dinding kanal; lihat docstring di atas.
        let warmth = (clamped + 0.35) / 2.45
        // Kanal **tetap** dijepit ke 0...1 sebagai pengaman, walau rentang di
        // atas sudah menjaga B−V katalog tidak menyentuh dinding. Alasannya
        // tetap sama seperti dulu: `Color(red:green:blue:)` tidak punya nilai
        // di luar 1, jadi tanpa penjepit hasilnya bergantung pada perilaku
        // penjepitan diam-diam milik SwiftUI. Yang berubah adalah siapa yang
        // menanggung beban: **rentang masukan** yang mengatur hampir semua
        // kasus, dan penjepit ini hanya menyapu B−V ekstrem di luar katalog
        // (sampai 2,0 lewat `clamped`) supaya tidak ada kanal yang melewati 1.
        return RGBComponents(red: unit(0.62 + 0.38 * warmth),
                             green: unit(0.78 - 0.16 * warmth),
                             blue: unit(1.00 - 0.72 * warmth))
    }

    /// Warna **inti** bintang: tint spektral yang dipanaskan ke putih.
    ///
    /// **Cacat yang ditutup fungsi ini, diukur dari piksel bukan dari kode.**
    /// Sampai siklus ini inti bintang digambar dengan `starRGB` mentah — yaitu
    /// tint-nya sendiri. Terukur pada render 200 px, `ss=2`, mode siang,
    /// puncak luminansi `0,2126·R + 0,7152·G + 0,0722·B` skala 0…255:
    ///
    /// ```
    /// bintang          sebelum   sesudah
    /// Sirius (m −1,46)  190,03    251,56
    /// redup  (m +3,50)  189,59    214,61
    /// Betelgeuse (+0,50) 173,39   218,52
    /// Rigel    (+0,13)  190,06    229,00
    /// ```
    ///
    /// Kolom **sebelum** itu bukan ingatan: `check_star_core_docstring_quotes_measured_values`
    /// merender ulang keduanya setiap kali gerbang berjalan — kolom pertama
    /// dengan `starCoreRGB` diganti tint mentah, kolom kedua apa adanya — lalu
    /// membandingkan setiap angka di tabel ini dengan pikselnya. Jadi tabel ini
    /// tidak bisa membusuk diam-diam saat geometri bintang berubah.
    ///
    /// Yang terbaca dari kolom pertama: Sirius dan bintang magnitudo +3,5
    /// berpuncak **190,03 lawan 189,59** — bintang paling terang di langit dan
    /// bintang yang nyaris tak terlihat mata punya inti yang sama terangnya.
    /// Selisih 0,4/255 tidak bisa dibaca siapa pun. Lebih buruk, Betelgeuse
    /// (raksasa merah) berpuncak **173,39**, jauh di bawah bintang redup: jadi
    /// bintang yang **lebih terang** justru berinti **lebih gelap**, dan urutan
    /// terang di inti berbalik dari urutan magnitudo.
    ///
    /// Penyebabnya satu, dan ia bukan "kanal yang jumlahnya berbeda". Tint
    /// spektral membawa luminansi yang berbeda-beda menurut hue-nya sendiri:
    /// `starRGB(0.00)` berjumlah 0,7496 sementara `starRGB(1.85)` berjumlah
    /// 0,6850. Artinya kecerahan inti **tercemar oleh warna** — dua bintang
    /// dengan magnitudo sama tapi hue berbeda tergambar beda terang. Padahal
    /// yang menandakan "bintang ini terang" adalah **seberapa putih** intinya,
    /// bukan seberapa pekat hue-nya. Di langit sungguhan, bintang terang tampak
    /// memutih karena mata kelebihan cahaya; hue-nya baru terbaca di pinggiran.
    /// Gambar yang mewarnai inti dengan hue mentah kehilangan justru isyarat
    /// terang itu — dan isyarat itu satu-satunya yang tersisa setelah mode
    /// malam membuang hue.
    ///
    /// **Kenapa campuran ke putih, bukan menaikkan semua kanal.** Menaikkan
    /// kanal secara proporsional hanya membuat hue yang sama lebih terang; ia
    /// tidak pernah membuat inti putih, jadi bintang terang tetap tampak
    /// sebagai titik berwarna pekat. Mencampur ke putih `(1,1,1)` menaikkan
    /// kanal **terendah** paling banyak — dan itulah yang mengubah hue menjadi
    /// "terlalu terang untuk berwarna", persis seperti mata melihatnya.
    ///
    /// **Kenapa `whiteness` berasal dari ukuran, bukan dari B−V.** Ukuran
    /// diturunkan dari magnitudo (`sizeFromMagnitude`), jadi ia urutan terang
    /// yang benar menurut definisinya. Menurunkannya dari B−V akan menjadikan
    /// raksasa merah terang seperti Betelgeuse (B−V 1,85, m +0,50) lebih
    /// putih daripada Sirius (B−V 0,00, m −1,46) — kebalikan dari langit.
    /// Dijaga `testStarCoreWhitenessFollowsMagnitudeNotHue`.
    ///
    /// - Parameters:
    ///   - colorIndex: indeks B−V, atau `NaN` untuk "tidak mengklaim".
    ///   - relativeSize: ukuran gambar relatif 0…1 (dari magnitudo).
    /// - Returns: warna inti, kanal 0…1.
    public static func starCoreRGB(forColorIndex colorIndex: Double,
                                   relativeSize: Double) -> RGBComponents {
        let tint = starRGB(forColorIndex: colorIndex)
        // Sentinel "tidak ada klaim" tetap **akromatik**: memanaskannya ke
        // putih akan menaikkan ketiga kanal sama rata, jadi R=G=B tetap
        // berlaku dan gerbang `warna tak dikenal benar-benar akromatik` tidak
        // dilanggar. Yang berubah hanya terangnya, dan terang bukan klaim.
        let whiteness = starCoreWhiteness(relativeSize: relativeSize)
        return RGBComponents(red: unit(tint.red + (1 - tint.red) * whiteness),
                             green: unit(tint.green + (1 - tint.green) * whiteness),
                             blue: unit(tint.blue + (1 - tint.blue) * whiteness))
    }

    /// Seberapa putih inti bintang, 0…1, dari ukuran relatifnya.
    ///
    /// **Kenapa tidak mulai dari 0.** Bintang paling redup di katalog tetap
    /// harus punya inti yang lebih terang daripada glow-nya, kalau tidak ia
    /// terbaca sebagai gumpalan kabur, bukan titik. `floorWhiteness` menjaga
    /// itu; `rangeWhiteness` yang membuat Sirius benar-benar putih.
    ///
    /// **Kenapa lantainya 0,30 dan bukan 0,55.** Nilai itu diukur, bukan
    /// dipilih: pada 0,55 bintang magnitudo +3,5 (inti 0,85·putih) sudah
    /// tampak putih, sehingga "putih = terang" berhenti membedakan apa pun di
    /// paruh redup katalog. Pada 0,30 inti redup masih jelas berwarna dan inti
    /// Sirius praktis putih (0,30 + 0,70 = 1,00).
    public static func starCoreWhiteness(relativeSize: Double) -> Double {
        let clamped = min(1, max(0, relativeSize))
        return floorWhiteness + rangeWhiteness * clamped
    }

    /// Putih minimum pada inti bintang paling redup.
    public static let floorWhiteness: Double = 0.30
    /// Tambahan putih dari bintang paling redup ke paling terang.
    public static let rangeWhiteness: Double = 0.70

    // MARK: - Ukuran dari magnitudo

    /// Radius gambar relatif dari magnitudo tampak, 0…1.
    ///
    /// Skala magnitudo **logaritmik dan terbalik**: makin kecil angkanya,
    /// makin terang. Karena itu ukurannya diturunkan dari
    /// `10^(−0.2·(m − mTerang))`, bukan dari selisih linear — memakai skala
    /// linear membuat Sirius dan Deneb nyaris sama besar padahal selisihnya
    /// 2.7 magnitudo (≈ 12× terang).
    ///
    /// Dijepit ke 0.15…1: benda paling redup masih harus terlihat sebagai
    /// titik, bukan menghilang.
    public static func sizeFromMagnitude(_ magnitude: Double) -> Double {
        let brightest: Double = -1.5
        let raw = pow(10.0, -0.2 * (magnitude - brightest))
        return min(1, max(0.15, raw))
    }
}

// MARK: - Palet & ciri pengenal planet

public extension CelestialVisual {

    /// Warna mentah (0…1 per kanal) — **bukan** `SwiftUI.Color`.
    ///
    /// Sengaja bukan `Color`: model ini hidup di `PointingKit` supaya bisa
    /// diuji di Linux, dan `Color` tidak ada di sana. Lapisan UI yang
    /// mengubahnya menjadi `Color` (dan yang mewarnainya ulang menjadi merah
    /// saat mode malam).
    struct RGBComponents: Equatable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// Kecerahan **dalam mode malam**: kanal merahnya.
        ///
        /// Bukan luminance penuh (0.2126R + 0.7152G + 0.0722B), dan itu
        /// disengaja. Mode malam membuang hijau & biru sepenuhnya, jadi yang
        /// benar-benar sampai ke mata hanyalah kanal merah — urutan terang
        /// yang dilihat pengguna **harus** diturunkan dari kanal itu.
        /// Memakai luminance penuh justru salah: planet abu terang seperti
        /// Merkurius punya luminance tinggi karena hijau-birunya, dan saat
        /// dikunci ke merah ia akan tampak **lebih** terang dari Mars —
        /// kebalikan dari apa yang terjadi pada bola di langit.
        ///
        /// Uji `testNightModeKeepsBrightnessOrdering` mengunci urutan ini, jadi
        /// koreksi palet tidak bisa diam-diam membalik urutan terang di malam.
        public var nightModeBrightness: Double { red }
    }

    /// Ciri pengenal yang **hanya boleh digambar bila identitasnya pasti**.
    ///
    /// Kenapa ini dipisah dari warna: warna bola masih boleh tampil saat engine
    /// ragu (ia tidak menunjuk planet tertentu), tetapi **ciri** ini menunjuk
    /// planet tertentu dengan keyakinan yang sama seperti teks namanya.
    /// Cincin Saturnus pada kandidat yang belum dikonfirmasi adalah klaim
    /// identitas, bukan sekadar gaya — karena itu ia dikunci oleh uji.
    enum DistinguishingFeature: String, Equatable, Sendable {
        /// Tidak ada ciri khusus: bola polos (planet yang tidak dikenali).
        case none
        /// Pita sejajar ekuator + Bintik Merah Besar.
        case bands
        /// Cincin.
        case rings
        /// Tudung es di kedua kutub.
        case polarCaps
        /// Permukaan berkawah.
        case craters
        /// Kabut tebal yang menutupi permukaan.
        case haze
        /// Piringan pucat hampir polos (Uranus): sedikit sabuk horizontal.
        case paleDisk
        /// Piringan biru dengan titik gelap (Neptunus).
        case blueDisk
    }

    /// Palet sebuah planet: warna bola + ciri pengenalnya.
    struct Palette: Equatable, Sendable {
        public var light: RGBComponents
        public var dark: RGBComponents
        public var feature: DistinguishingFeature

        public init(light: RGBComponents, dark: RGBComponents, feature: DistinguishingFeature) {
            self.light = light
            self.dark = dark
            self.feature = feature
        }

        /// Palet yang boleh **digambar**, mengingat keyakinan engine.
        ///
        /// **Cacat yang ditutup ini.** Sampai siklus ini `drawPlanet` hanya
        /// menutup **ciri**-nya saat engine ragu (`guard isConfirmed` sebelum
        /// pita/cincin/kutub), sementara **warna bolanya** diteruskan apa
        /// adanya. Alasannya tertulis di view dan sudah usang:
        ///
        /// > warna bola masih boleh tampil saat engine ragu (ia tidak menunjuk
        /// > planet tertentu)
        ///
        /// Kalimat itu benar untuk kelas planet yang **tidak berwarna**, dan
        /// salah untuk yang berwarna. Diukur dari piksel pada kasus
        /// `planet-*-uncertain` (300 px): Mars tampil (120, 55, 36) — merah
        /// khas Mars — dan Jupiter (129, 102, 76) — cokelat pita Jupiter.
        /// Jarak warna antar-kandidat tetap 62…112, jadi mata tetap bisa
        /// membaca "itu Mars" dari sebelah badge "Ragu". Persis cacat yang
        /// dilarang PRD, dan persis yang sudah ditutup untuk tiga permukaan
        /// lain: Bulan (`moonPhaseUnknown`), bintang
        /// (`drawableStarColorIndex`), dan benda langit dalam
        /// (`drawableMorphology`).
        ///
        /// **Kenapa warna planet memang ciri pengenal.** Aturannya sudah
        /// dinyatakan repo ini untuk bintang — "warna spektral **adalah** ciri
        /// pengenal … penanda yang sama meyakinkannya dengan cincin Saturnus"
        /// — dan planet tidak berbeda: oker Mars dan cokelat Jupiter adalah
        /// cara tercepat mengenalinya, lebih cepat daripada teks di bawahnya.
        /// Yang tersisa saat ragu karena itu hanya **bentuk dan terang**:
        /// piringan bola dengan gradien netral, tanpa satu pun warna yang
        /// menunjuk planet tertentu.
        ///
        /// Palet netralnya **dipinjam dari token yang sudah ada** untuk planet
        /// tak dikenal (`neutralBody`/`neutralShadow` di view,
        /// `NEUTRAL_BODY`/`NEUTRAL_SHADOW` di port), bukan angka baru: nilai
        /// itu sudah lama dianggap tidak mengklaim apa pun, dan
        /// `check_unknown_planet_is_a_neutral_sphere` sudah menahannya tetap
        /// netral. Angka baru masih bisa kebetulan berupa warna planet.
        ///
        /// - Parameter isConfirmed: apakah engine sudah mengunci identitasnya.
        public func drawable(isConfirmed: Bool) -> Palette {
            guard !isConfirmed else { return self }
            return Palette(light: CelestialVisual.neutralBody,
                           dark: CelestialVisual.neutralShadow,
                           feature: .none)
        }
    }

    /// Warna bola netral — satu-satunya palet yang boleh tampil saat engine
    /// ragu, dan palet untuk planet yang id-nya tidak dikenali.
    ///
    /// **Kenapa di model, bukan di view.** Sebelumnya angka ini hidup **dua
    /// kali**: `neutralBody`/`neutralShadow` di `CelestialVisualView.swift`
    /// dan `NEUTRAL_BODY`/`NEUTRAL_SHADOW` di `Tools/render-visuals.py`.
    /// `check_port_matches_swift_constants` sudah membandingkan keduanya,
    /// jadi nilainya tidak bisa diam-diam berbeda — tetapi **sumbernya tetap
    /// view**, dan view tidak bisa diuji di Linux. Selama warna netral hanya
    /// dipakai planet tak dikenal, itu cukup. Sekarang ia menentukan seluruh
    /// jalur "ragu" planet, dan jalur itu harus terukur di Linux; karena itu
    /// ia pindah ke model, dan view/port membacanya dari sini.
    static let neutralBody = RGBComponents(red: 0.74, green: 0.72, blue: 0.68)
    static let neutralShadow = RGBComponents(red: 0.28, green: 0.27, blue: 0.26)
}

// MARK: - Batas gambar: berapa jauh tiap bentuk keluar dari frame

/// Batas kerangka gambar -- satu-satunya tempat yang tahu ukuran `Canvas`.
///
/// **Kenapa model ini ada.** `Canvas` di SwiftUI memotong apa pun di luar
/// `frame`-nya sendiri, dan ia memotong dengan **tepi lurus**, bukan dengan
/// memudar. Cacat yang paling mudah lolos karena begitu: cincin Saturnus
/// digambar selebar `3.8 x radius` -- hampir dua kali frame -- sehingga
/// `Canvas` memotong kedua ujungnya tegak. Hasilnya bukan cincin, melainkan
/// dua garis lurus yang berhenti mendadak di tepi kotak.
///
/// Kenapa ia bertahan lama: `swiftc -parse` tidak melihatnya, `swift test`
/// tidak melihatnya (warnanya tidak bisa diuji di Linux), dan di kartu jam
/// 38pt ujungnya bisa saja tidak disadari. Yang bisa menutupnya hanya satu:
/// memindahkan **angka batas** ke tempat yang bisa diuji, lalu membuat view
/// memakai angka itu alih-alih punya rumus sendiri.
///
/// Satuan semua angka: **1.0 = setengah lebar frame** (yaitu `radius`).
/// Frame adalah persegi, jadi batasnya sama di keempat sisi.
public enum VisualFrame {

    /// Batas luar yang boleh dicapai bentuk sebelum terpotong tegak.
    ///
    /// `Canvas` memakai frame persegi, bukan lingkaran -- jadi bentuk yang
    /// keluar sampai 1.0 di keempat arah masih utuh, dan lebih dari itu
    /// terpotong. Bentuk simetris (cincin, kutub) tidak membedakan dua hal
    /// itu, tapi bentuk yang digeser (blob nebula) berbeda jauh.
    public static let halfExtent: Double = 1.0

    /// Berapa jauh sebuah bentuk keluar dari frame, dalam satuan radius.
    ///
    /// - Parameters:
    ///   - centerX: jarak pusat bentuk dari tengah frame, sumbu x.
    ///   - centerY: jarak pusat bentuk dari tengah frame, sumbu y.
    ///   - halfWidth: setengah lebar bentuk, sumbu x.
    ///   - halfHeight: setengah tinggi bentuk, sumbu y.
    /// - Returns: nilai **>= 0**. `0` berarti seluruh bentuk di dalam frame;
    ///   nilai lebih besar adalah bagian yang akan terpotong tegak.
    public static func overflow(centerX: Double,
                                centerY: Double,
                                halfWidth: Double,
                                halfHeight: Double) -> Double {
        max(centerX + halfWidth, centerY + halfHeight) - halfExtent
    }

    /// Cincin Saturnus: bentuk elips terluar, dalam satuan radius.
    ///
    /// Satu tipe untuk **kedua** belahan cincin (belakang dan depan), bukan
    /// dua rumus terpisah -- kelas kesalahan yang sama yang membuat kutub
    /// Mars tidak simetris (satu rumus untuk utara, satu lagi untuk selatan).
    public struct RingGeometry: Equatable, Sendable {
        /// Setengah lebar cincin (sumbu x), satuan radius.
        public var halfWidth: Double
        /// Setengah tinggi cincin (sumbu y), satuan radius.
        public var halfHeight: Double

        public init(halfWidth: Double, halfHeight: Double) {
            self.halfWidth = halfWidth
            self.halfHeight = halfHeight
        }

        /// Lebar cincin yang tampil di layar: ujung elips berada di
        /// `x = +/-halfWidth`, jadi lebar penuhnya `2 x halfWidth` --
        /// bukan nilai ini dikali 1.9 seperti versi lama.
        public var fullWidth: Double { 2 * halfWidth }
        /// Tinggi cincin yang tampil di layar (2 x halfHeight).
        public var fullHeight: Double { 2 * halfHeight }
    }

    /// Cincin Saturnus yang **pas di frame**.
    ///
    /// Lebar cincin dipilih agar ujung elips terluar menyentuh tepi frame
    /// **tepat pada batasnya**: `halfWidth = halfExtent`. Mengapa 1.9R bukan
    /// pilihan yang benar: ujung elips di `x = +/-1.9` berada 0.9R **di luar**
    /// frame, jadi `Canvas` memotongnya tegak.
    ///
    /// Konsekuensi yang harus disadari: bola harus **mengecil** supaya cincin
    /// muat. Saturnus sungguhan memang tidak sebesar itu dibanding
    /// cincinnya -- tapi membesarkan cincin sampai keluar frame hanya
    /// memindahkan cacat ke tempat lain, bukan menutupnya.
    ///
    /// - Parameters:
    ///   - frameHalfExtent: setengah lebar frame (1.0 untuk `Canvas` persegi).
    ///   - axialRatio: setengah tinggi dibagi setengah lebar. Cincin Saturnus
    ///     sungguhan tampak miring saat menghadap kita, dan untuk ikon 2D
    ///     rasio sekitar 1:3 terbaca sebagai "cincin" -- asal **tidak** penuh,
    ///     karena elips penuh terbaca sebagai piring.
    public static func saturnRing(frameHalfExtent: Double = halfExtent,
                           axialRatio: Double = 1.0 / 3.2) -> RingGeometry {
        let halfWidth = frameHalfExtent
        return RingGeometry(halfWidth: halfWidth,
                            halfHeight: halfWidth * axialRatio)
    }

    /// Satu pita cincin Saturnus: dari radius mana ke radius mana, dan
    /// seberapa pekat.
    ///
    /// Radius dalam satuan **setengah lebar cincin** (jadi `1.0` = tepi luar
    /// cincin, `bodyFraction` = tepi bola). Opasitas adalah nilai untuk
    /// **paruh depan**; paruh belakang memakai `backHalfOpacityScale`.
    public struct RingBand: Equatable, Sendable {
        /// Radius dalam tepi pita, satuan setengah lebar cincin.
        public var innerRadius: Double
        /// Radius luar tepi pita, satuan setengah lebar cincin.
        public var outerRadius: Double
        /// Opasitas pita di paruh depan, 0…1.
        public var opacity: Double

        public init(innerRadius: Double, outerRadius: Double, opacity: Double) {
            self.innerRadius = innerRadius
            self.outerRadius = outerRadius
            self.opacity = opacity
        }

        /// Lebar pita.
        public var width: Double { outerRadius - innerRadius }
    }

    /// Pita cincin Saturnus — **dari data cincin nyata**, bukan dari rasa.
    ///
    /// **Cacat yang ditutup fungsi ini.** Sampai siklus ini cincin digambar
    /// sebagai **satu elips pekat** untuk paruh belakang dan satu untuk paruh
    /// depan, lalu sebuah elips hitam disisipkan untuk "pembelah Cassini".
    /// Tiga hal salah sekaligus:
    ///
    ///   1. Strukturnya **dikarang di view**. Cincin Saturnus punya pita yang
    ///      punya nama (D, C, B, celah Cassini, A); view menggambar satu
    ///      bidang rata. Karena angkanya hidup di view, tidak ada uji Linux
    ///      yang bisa memeriksanya — persis pola yang sudah tiga kali
    ///      dilaporkan di repo ini.
    ///   2. Celahnya **tidak di tepi luar**. Pembelah Cassini nyata berada di
    ///      antara pita B dan A (≈0.89 R cincin), sedangkan elips hitam itu
    ///      diletakkan 0.34 x radius bola dari tepi luar — jauh di luar
    ///      tempatnya, sehingga ia memotong pita A, bukan memisahkan B dari A.
    ///   3. Celahnya **tidak simetris**: elips itu digambar hanya di dalam
    ///      klip paruh bawah, jadi paruh belakang tidak punya celah sama
    ///      sekali. Cincin yang pembelahnya hanya ada di separuh depannya
    ///      bukan cincin yang sama dipandang dari dua sisi.
    ///
    /// Angka di bawah adalah radius cincin Saturnus nyata dalam satuan radius
    /// Saturnus (D 1.11–1.236, C 1.236–1.525, B 1.525–1.95, celah Cassini
    /// 1.95–2.025, A 2.025–2.269), dipetakan ke rentang yang tersedia di
    /// frame: tepi dalam cincin = tepi bola (`bodyFraction`), tepi luar =
    /// `1.0`. **Rasio antar-pita dipertahankan**; yang dipetakan hanya
    /// rentangnya.
    ///
    /// **Satu angka sengaja dilebihkan.** Lebar celah Cassini yang sebenarnya
    /// (0.031 R cincin) hanya 0.6 pt di kartu jam 38 pt — tidak terlihat,
    /// sehingga pita B dan A akan menyatu kembali dan pembelahnya hilang lagi.
    /// Celahnya karena itu dilebarkan menjadi `cassiniWidth` dengan
    /// **pusatnya tetap** (0.886 R), mengambil sedikit dari pita B dan A.
    /// Ini pengorbanan yang sama yang sudah tercatat untuk Bintik Merah Besar:
    /// ukuran boleh dikorbankan demi keterbacaan, **posisi tidak**.
    ///
    /// - Parameters:
    ///   - bodyFraction: radius bola sebagai pecahan setengah lebar cincin.
    ///   - cassiniWidth: lebar celah Cassini yang dipakai (lihat catatan di
    ///     atas — bukan angka nyata, dan itu disengaja).
    public static func saturnRingBands(bodyFraction: Double = 0.53,
                                       cassiniWidth: Double = 0.06) -> [RingBand] {
        // Batas pita nyata dalam radius Saturnus.
        let realEdges = [1.11, 1.236, 1.525, 1.95, 2.025, 2.269]
        let inner = realEdges[0], outer = realEdges[realEdges.count - 1]
        // Petakan [inner, outer] -> [bodyFraction, 1.0], rasio dipertahankan.
        func mapped(_ r: Double) -> Double {
            bodyFraction + (r - inner) / (outer - inner) * (1 - bodyFraction)
        }
        var edges = realEdges.map(mapped)

        // Lebarkan celah Cassini (indeks 3 -> 4) dengan pusat tetap.
        let cassiniCenter = (edges[3] + edges[4]) / 2
        let half = cassiniWidth / 2
        edges[3] = cassiniCenter - half
        edges[4] = cassiniCenter + half

        // Opasitas mengikuti kepadatan pita yang sebenarnya: D sangat tipis,
        // C tipis, B paling pekat, celah Cassini hampir kosong, A pekat.
        let opacities = [0.14, 0.34, 0.78, 0.04, 0.62]
        return (0..<opacities.count).map { index in
            RingBand(innerRadius: edges[index],
                     outerRadius: edges[index + 1],
                     opacity: opacities[index])
        }
    }

    /// Seberapa pekat paruh belakang cincin dibanding paruh depan.
    ///
    /// Bukan efek cahaya: cincin belakang memang lebih redup karena dilihat
    /// dari sisi yang tidak tersinari. Nilainya di model supaya view dan port
    /// tidak bisa berbeda pendapat tentang seberapa gelap "belakang".
    public static let ringBackHalfOpacityScale: Double = 0.55

    /// Jari-jari bola di dalam cincin Saturnus, dalam satuan radius frame.
    ///
    /// **Dipisah dari `saturnRing` dengan alasan yang bisa diuji.** Jari-jari
    /// bola harus mengikuti lebar cincin: kalau cincin mengisi frame
    /// (`halfWidth = 1.0`) sementara bola tetap memakai radius frame penuh,
    /// bola menutupi cincin dan hasilnya piring. Mengambil dari lebar cincin
    /// membuat proporsi itu benar **secara konstruktif**, dan mengubah lebar
    /// cincin tanpa harus mengingat memperkecil bola secara terpisah.
    ///
    /// - Parameters:
    ///   - ring: cincin dari `saturnRing`.
    ///   - bodyFraction: jari-jari bola sebagai pecahan dari setengah lebar
    ///     cincin.

    public static func saturnBodyRadius(for ring: RingGeometry,
                                 bodyFraction: Double = 0.53) -> Double {
        ring.halfWidth * bodyFraction
    }

    /// Bayangan bola Saturnus pada cincinnya — satu elips yang digeser
    /// **menjauh dari sumber cahaya**.
    ///
    /// **Cacat yang ditutup ini.** Sampai siklus ini cincin Saturnus digambar
    /// sebagai pita yang terang rata di kedua paruhnya, tanpa satu pun tanda
    /// bahwa bola menghalangi cahaya. Akibatnya cincin terbaca sebagai
    /// **stiker yang mengapung di depan bola**, bukan benda yang mengelilingi
    /// bola — dan itu justru satu-satunya isyarat kedalaman yang dimiliki
    /// gambar Saturnus di layar 38 pt. Bola yang memakai gradien (cahaya dari
    /// kiri-atas) bersebelahan dengan cincin yang terang merata di kedua sisi
    /// adalah dua gambar yang menyatakan arah cahaya berbeda.
    ///
    /// **Kenapa geometrinya di model, bukan di view.** Sama alasannya dengan
    /// `craterRelief`: bayangan yang arahnya ditentukan di dalam `Canvas`
    /// tidak bisa diuji di Linux, dan repo ini sudah membayar kelas cacat itu
    /// berkali-kali. Di sini arahnya diturunkan dari `sphereLightOffset` yang
    /// sama dengan gradien bola, jadi bola dan cincin tidak bisa berbeda
    /// pendapat tentang dari mana cahaya datang.
    ///
    /// **Bentuknya.** Bola menghalangi cahaya, jadi bayangan yang jatuh di
    /// cincin adalah **proyeksi bola** sepanjang arah cahaya — bukan lingkaran
    /// di sekitar bola. Karena cincinnya miring (elips), bayangannya juga
    /// elips dengan rasio sumbu yang sama, digeser sejauh proyeksi itu.
    ///
    /// **Yang TIDAK diklaim.** Ini bukan perhitungan geometri 3D sungguhan:
    /// jarak geser adalah pilihan gambar, dan bayangan tidak memendek di tepi
    /// cincin seperti pada benda nyata. Yang dijamin: bayangannya ada, berada
    /// di sisi yang **menjauhi** cahaya, dan tidak pernah menutupi sisi yang
    /// menghadap cahaya.
    ///
    /// - Parameters:
    ///   - ring: cincin dari `saturnRing`.
    ///   - bodyFraction: jari-jari bola, pecahan dari setengah lebar cincin.
    ///   - lightDirection: arah sumber cahaya (lihat `sphereLightOffset`).
    ///   - reach: jarak geser pusat bayangan, pecahan dari jari-jari bola.
    public struct RingShadow: Equatable, Sendable {
        /// Ujung **jauh** bayangan relatif pusat cincin, satuan radius frame.
        ///
        /// Bayangan mulai di pusat (tepi bola yang menghadap cahaya) dan
        /// membentang ke arah menjauhi cahaya. Satu titik saja tidak cukup:
        /// bayangan bola yang hanya digeser satu radius terbaca sebagai
        /// bercak, bukan sebagai bayangan yang **membentang** — dan itulah
        /// bentuk yang membuat cincin Saturnus terlihat punya kedalaman.
        public var offsetX: Double
        public var offsetY: Double
        /// Jari-jari bayangan pada sumbu x, satuan radius frame.
        public var radius: Double
        /// Jari-jari bayangan pada sumbu y (sudah dikalikan rasio cincin).
        public var radiusY: Double

        public init(offsetX: Double, offsetY: Double,
                    radius: Double, radiusY: Double) {
            self.offsetX = offsetX
            self.offsetY = offsetY
            self.radius = radius
            self.radiusY = radiusY
        }

        /// Apakah titik `(ux, uy)` — satuan radius frame — jatuh di bayangan.
        ///
        /// **Kenapa jarak ke ruas garis, bukan ke titik.** Bayangan bola yang
        /// disinari dari satu arah adalah **silinder**, jadi jejaknya di
        /// bidang cincin adalah kapsul: semua titik yang berjarak ≤ jari-jari
        /// bola dari ruas `pusat → ujung jauh`. Menggeser satu lingkaran
        /// menghasilkan bayangan yang 30% lebih sempit dan tidak pernah
        /// mencapai tepi luar cincin, sehingga tidak terbaca sebagai bayangan.
        ///
        /// **Kenapa y dibagi rasio cincin dulu.** Cincin digambar sebagai
        /// elips (dipipihkan pada y), jadi lingkaran di bidang cincin menjadi
        /// elips di layar. Jarak diukur di bidang cincin — tempat bayangannya
        /// memang lingkaran — supaya bayangan ikut memipih bersama cincinnya.
        /// Mengukur jarak langsung di layar akan memberi bayangan yang terlalu
        /// lebar pada arah y.
        public func contains(ux: Double, uy: Double,
                             axialRatio: Double) -> Bool {
            let safeRatio = axialRatio > 1e-9 ? axialRatio : 1e-9
            // Ke bidang cincin: y dikembalikan ke skala x.
            let px = ux, py = uy / safeRatio
            let dx = offsetX, dy = offsetY / safeRatio
            let lengthSquared = dx * dx + dy * dy
            var t = 0.0
            if lengthSquared > 1e-18 {
                t = (px * dx + py * dy) / lengthSquared
                t = min(max(t, 0.0), 1.0)
            }
            let cx = dx * t, cy = dy * t
            let qx = px - cx, qy = py - cy
            return (qx * qx + qy * qy).squareRoot() <= radius
        }
    }

    /// Seberapa pekat bayangan bola pada cincin Saturnus.
    ///
    /// **Kenapa di model, bukan angka di view.** Port Python
    /// (`Tools/render-visuals.py`) menggambar gambar yang sama, dan gerbang
    /// piksel mengukur **port**-nya. Angka opasitas yang hidup hanya di view
    /// berarti gerbang mengukur bayangan yang lebih pekat atau lebih pucat
    /// daripada yang dilihat pengguna — kelas cacat yang sudah dibayar repo
    /// ini berkali-kali (lihat `ringBackHalfOpacityScale`).
    ///
    /// **Kenapa 0.62, bukan lebih pekat.** Cincin Saturnus nyata tembus
    /// pandang, jadi bayangannya tidak hitam: cukup untuk terbaca sebagai
    /// bayangan, tidak sampai menghapus pita di bawahnya. Angka ini
    /// **diukur, bukan dipilih dengan mata**: gerbang
    /// `check_saturn_rings_carry_the_planet_shadow` menuntut rasio
    /// dalam/luar < 0.85, dan pada 0.62 terukur 0.565. Pada 0.0 (bayangan
    /// dimatikan) rasio itu 0.969 — jadi angkanya memang yang membuat
    /// bayangan itu ada, bukan gerbang yang longgar.
    ///
    /// Di mode malam nilainya dipetakan lewat aturan `shadow` yang sama
    /// dengan piringan gelap Bulan, supaya bayangan tidak menambah cahaya di
    /// layar merah.
    public static let ringShadowOpacity: Double = 0.62

    public static func saturnRingShadow(for ring: RingGeometry,
                                        bodyFraction: Double = 0.53,
                                        lightDirection: (x: Double, y: Double)
                                            = CelestialVisual.sphereLightOffset,
                                        reach: Double = 0.95) -> RingShadow? {
        // Arah cahaya nol tidak punya arah: bayangannya akan jatuh ke pusat
        // dan menutupi bola itu sendiri. Menolaknya di sini lebih baik
        // daripada menghasilkan gambar yang "masuk akal".
        let length = (lightDirection.x * lightDirection.x
                      + lightDirection.y * lightDirection.y).squareRoot()
        guard length > 1e-9 else { return nil }
        let body = saturnBodyRadius(for: ring, bodyFraction: bodyFraction)
        // Bayangan jatuh **berlawanan** arah datangnya cahaya.
        let shift = body * reach
        let offsetX = -(lightDirection.x / length) * shift
        let offsetY = -(lightDirection.y / length) * shift
        // Rasio sumbu mengikuti cincinnya: bayangan yang bulat di atas cincin
        // miring akan terbaca sebagai lubang, bukan bayangan.
        let axialRatio = ring.halfHeight / ring.halfWidth
        return RingShadow(offsetX: offsetX, offsetY: offsetY,
                          radius: body, radiusY: body * axialRatio)
    }

    /// Geometri kabut objek langit dalam: sekumpulan blob tanpa tepi keras.
    ///
    /// **Kenapa ini di model, bukan di view.** Blob digeser dari pusat
    /// (supaya kabut tidak simetris sempurna, yang justru terlihat
    /// "digambar"). Geseran itu membuat batasnya **berbeda per sumbu**:
    /// blob yang terpusat aman dicek secara radial, blob yang digeser
    /// keluar frame lebih cepat. Karena itu ukurannya dihitung dari sisa
    /// ruang ke tepi frame, bukan dari radius mentah.
    ///
    /// Nama `NebulaGeometry` dipertahankan karena satu kelas blob yang sama
    /// dipakai untuk **semua** bentuk objek langit dalam (nebula, galaksi,
    /// gugus terbuka, gugus bola) — yang berbeda hanya susunannya. Lihat
    /// `deepSky(morphology:fuzziness:)`.
    public struct NebulaGeometry: Equatable, Sendable {
        public struct Blob: Equatable, Sendable {
            /// Geseran pusat blob dari tengah frame, sumbu x & y (satuan radius).
            public var offsetX: Double
            public var offsetY: Double
            /// Setengah lebar blob (sumbu x, satuan radius).
            ///
            /// **Kenapa lebar & tinggi dipisah, bukan satu `radius`.** Galaksi
            /// harus digambar sebagai **cakram miring** — elips, bukan
            /// lingkaran. Dengan satu radius, satu-satunya bentuk yang bisa
            /// dihasilkan adalah lingkaran, jadi galaksi tampil sama dengan
            /// nebula. Dua angka ini yang membuat rasionya bisa dinyatakan
            /// dan diuji.
            public var halfWidth: Double
            /// Setengah tinggi blob (sumbu y, satuan radius).
            public var halfHeight: Double
            /// Rotasi blob terhadap sumbu x, derajat. `0` = lebar mendatar.
            ///
            /// Dipakai galaksi supaya cakramnya miring, bukan mendatar
            /// sempurna — cakram mendatar pada ikon persegi terbaca sebagai
            /// garis, bukan sebagai galaksi.
            public var angleDegrees: Double
            /// Opasitas puncak blob (di pusatnya; memudar ke 0 di tepi).
            public var opacity: Double
        }

        public var blobs: [Blob]

        public init(blobs: [Blob]) { self.blobs = blobs }
    }

    // MARK: - Bintang: glow + diffraction spike

    /// Geometri bintang: inti, glow berlapis, dan empat diffraction spike.
    ///
    /// **Kenapa ini ikut dihitung di model, padahal bintang "cuma titik".**
    /// Bintang justru bentuk yang paling mudah keluar frame tanpa terasa:
    /// intinya kecil, tapi glow dan spike-nya dikalikan **3×** dari inti itu.
    /// Jadi inti yang nyaman di 0.5R menghasilkan ujung terluar di 1.8R —
    /// hampir dua kali frame — dan `Canvas` memotongnya **tegak**, karena ia
    /// memotong dengan tepi lurus, bukan dengan memudar. Yang tampil lalu
    /// bukan bintang bercahaya, melainkan bola cahaya yang berhenti
    /// mendadak di keempat tepi kartu.
    ///
    /// Ini cacat yang sama dengan cincin Saturnus (0.9R keluar) dan blob
    /// nebula (0.28R keluar) — dan untuk **24 dari 25 bintang di katalog**,
    /// dihitung bukan ditebak.
    public struct StarGeometry: Equatable, Sendable {
        /// Radius inti bintang, satuan radius frame.
        public var coreRadius: Double
        /// Pengali radius untuk tiap lapis glow (dari terluar ke terdalam).
        public var glowScales: [Double]
        /// Pengali panjang diffraction spike, dari radius inti.
        public var spikeScale: Double
        /// Amplitudo denyut: ujung terluar mengembang `1 + amplitude` kali.
        public var pulseAmplitude: Double

        /// Tebal diffraction spike di **pangkal** (dekat inti), dari radius inti.
        public var spikeRootWidthFactor: Double
        /// Tebal diffraction spike di **ujung luar**, dari radius inti.
        ///
        /// **Kenapa spike harus menyempit, dan kenapa angkanya tinggal di
        /// model.** Versi sebelumnya menggambar keempat spike sebagai satu
        /// `Path` yang di-stroke dengan `lineWidth` tetap. Hasilnya bukan
        /// cahaya melainkan **garis silang**: batang sama tebal dari pangkal
        /// ke ujung, berujung rata, dan opasitasnya rata di sepanjang batang.
        /// Pada ukuran kartu jam (38 pt) ia terbaca sebagai penanda bidik.
        ///
        /// Cahaya yang terdifraksi menyempit dan memudar ke luar. Yang
        /// menentukan seberapa tajam penyempitannya adalah **nisbah** antara
        /// lebar pangkal dan lebar ujung — jadi nisbah itulah yang harus bisa
        /// diuji, dan karena itu ia hidup di sini, bukan sebagai dua angka
        /// lepas di dalam closure `Canvas` yang tidak bisa dibaca uji Linux
        /// maupun gerbang gambar.
        public var spikeTipWidthFactor: Double
        /// Opasitas spike di pangkal. Ujung luarnya selalu `0`: spike yang
        /// berhenti dengan opasitas sisa tampak terpotong, bukan memudar.
        public var spikeOpacity: Double

        public init(coreRadius: Double,
                    glowScales: [Double],
                    spikeScale: Double,
                    pulseAmplitude: Double,
                    spikeRootWidthFactor: Double = 0.18,
                    spikeTipWidthFactor: Double = 0.035,
                    spikeOpacity: Double = 0.45) {
            self.coreRadius = coreRadius
            self.glowScales = glowScales
            self.spikeScale = spikeScale
            self.pulseAmplitude = pulseAmplitude
            self.spikeRootWidthFactor = spikeRootWidthFactor
            self.spikeTipWidthFactor = spikeTipWidthFactor
            self.spikeOpacity = spikeOpacity
        }

        /// Tebal pangkal spike dalam radius frame.
        public var spikeRootWidth: Double {
            coreRadius * spikeRootWidthFactor
        }

        /// Tebal ujung spike dalam radius frame.
        public var spikeTipWidth: Double {
            coreRadius * spikeTipWidthFactor
        }

        /// Pengali terbesar dari inti ke ujung terluar yang digambar.
        public var outermostScale: Double {
            max(glowScales.max() ?? 0, spikeScale)
        }

        /// Ujung terluar yang benar-benar tampil, **sudah termasuk denyut
        /// puncak**, dalam satuan radius frame.
        ///
        /// Denyut harus ikut dihitung di sini, bukan di view: frame-nya
        /// berukuran tetap, sedangkan denyut mengembangkan gambar **setelah**
        /// ukuran inti dipilih. Menghitung batas dari keadaan diam berarti
        /// gambar muat saat diam dan terpotong setiap kali denyut memuncak —
        /// cacat yang muncul dan hilang, jadi paling mudah tidak disadari.
        public var outerRadius: Double {
            coreRadius * outermostScale * (1 + pulseAmplitude)
        }
    }

    /// Bintang yang **pas di frame**, untuk ukuran relatif tertentu.
    ///
    /// Inti dihitung **mundur dari ruang yang tersedia**, bukan maju dari
    /// ukuran yang diinginkan. Itu yang membuat batas ini konstruktif:
    /// memperbesar glow atau spike tanpa sengaja tidak bisa lagi mendorong
    /// ujungnya keluar frame, karena inti menyusut sendiri mengikutinya.
    ///
    /// Urutan terang tetap terjaga — bintang yang lebih terang mendapat
    /// ujung terluar **dan** inti yang lebih besar (`outerFraction` naik
    /// bersama `relativeSize`). Itu penting: memotong inti dengan plafon
    /// tetap justru akan meratakan Sirius dan Polaris menjadi dua titik
    /// yang sama, dan "ukuran mengikuti magnitudo" hilang.
    ///
    /// - Parameters:
    ///   - relativeSize: 0 = bintang paling redup, 1 = paling terang.
    ///   - pulseAmplitude: amplitudo denyut (0.10 = ±10%).
    ///   - glowScales: pengali tiap lapis glow.
    ///   - spikeScale: panjang spike dari radius inti.
    ///   - frameHalfExtent: setengah lebar frame.
    ///   - outerFraction: ujung terluar sebagai pecahan frame, pada
    ///     `relativeSize` 0 → 1.
    public static func star(relativeSize: Double,
                            pulseAmplitude: Double = 0.10,
                            glowScales: [Double] = [3.0, 1.9, 1.0],
                            spikeScale: Double = 3.2,
                            frameHalfExtent: Double = halfExtent,
                            outerFraction: (faint: Double, bright: Double) = (0.62, 0.92)) -> StarGeometry {
        let clamped = min(1, max(0, relativeSize))
        let outer = frameHalfExtent * (outerFraction.faint
                                       + (outerFraction.bright - outerFraction.faint) * clamped)
        // Ruang yang tersedia sudah termasuk denyut puncak, jadi inti
        // dibagi lagi dengan `(1 + pulseAmplitude)`.
        let growth = max(glowScales.max() ?? 1, spikeScale) * (1 + pulseAmplitude)
        return StarGeometry(coreRadius: outer / growth,
                            glowScales: glowScales,
                            spikeScale: spikeScale,
                            pulseAmplitude: pulseAmplitude)
    }

    /// Kabut nebula yang **pas di frame**.
    ///
    /// Ini bentuk **netral** yang dipakai bila morfologi objek tidak diketahui
    /// (lihat `deepSky(morphology:fuzziness:)`). Ia sengaja tidak menyatakan
    /// "galaksi" maupun "gugus": satu-satunya klaim yang jujur dari sebuah
    /// kabut tanpa identitas adalah "ada sesuatu yang menyebar di sini".
    ///
    /// Jari-jari tiap blob dipotong supaya blob tidak pernah keluar dari frame:
    /// `radius <= jarak tersisa ke tepi terdekat`. Konsekuensinya ukuran
    /// maksimal bergantung pada geseran -- blob yang digeser jauh harus
    /// lebih kecil. Itu **benar**, dan itulah alasan rumusnya begini:
    /// memakai radius tetap membuat blob yang digeser terpotong tegak,
    /// sementara gradiennya belum selesai memudar di situ.
    ///
    /// - Parameters:
    ///   - fuzziness: 0 = titik, 1 = kabut paling lebar.
    ///   - frameHalfExtent: setengah lebar frame.
    public static func nebula(fuzziness: Double,
                       frameHalfExtent: Double = halfExtent) -> NebulaGeometry {
        // Geseran ditulis tetap: bentuk kabut yang asimetris adalah yang
        // membuatnya tidak tampak seperti lingkaran yang digambar.
        let layout: [(Double, Double, Double, Double, Double, Double)] = [
            // (offsetX, offsetY, skala lebar, rasio sumbu, sudut°, opasitas)
            (-0.18, 0.12, 1.00, 1.0, 0.0, 0.42),
            ( 0.22, -0.16, 0.68, 1.0, 0.0, 0.30),
            ( 0.05, -0.04, 0.40, 1.0, 0.0, 0.55)
        ]
        return buildDeepSky(layout: layout, fuzziness: fuzziness,
                            frameHalfExtent: frameHalfExtent)
    }

    /// Kabut **netral** — satu-satunya bentuk yang boleh tampil saat engine
    /// RAGU, dan karenanya yang harus paling redup.
    ///
    /// **Cacat yang ditutup fungsi ini, diukur bukan dikira.** Sampai siklus
    /// ini `deepSky(morphology: nil)` mengembalikan `nebula(fuzziness:)` —
    /// **persis** geometri nebula emisi. Jadi kabut ragu memancarkan terang
    /// **1.197** pada fuzziness 0.8, lebih terang daripada setiap morfologi
    /// yang boleh diklaim (nebula planetari 0.827, gugus bola 0.510, galaksi
    /// 0.368, gugus terbuka 0.149). Satu-satunya keadaan yang tidak berhak
    /// mengklaim apa pun justru yang paling menarik mata, sementara badge
    /// "Ragu" di sebelahnya mengatakan hal sebaliknya. Mata membaca gambar
    /// lebih dulu; urutannya terbalik dari "visual samar" yang diminta PRD.
    ///
    /// **Kenapa bukan sekadar `nebula()` yang diredupkan.** `.nebula` adalah
    /// morfologi yang **sah diklaim** (M42 memang nebula emisi). Meredupkan
    /// `nebula()` akan ikut memadamkan jawaban yang benar — dan itu
    /// menyelesaikan masalah dengan merusak yang bukan masalah. Dua keadaan,
    /// dua geometri.
    ///
    /// **Kenapa tiga blob kecil, bukan satu blob besar yang diredupkan.**
    /// Kabut satu blob terbaca sebagai titik yang diburamkan — bulat dan
    /// simetris, persis yang membuat gambar terlihat "digambar". Tiga blob
    /// berselisih tetap memberi siluet asimetris yang kabur tanpa mengklaim
    /// bentuk apa pun: tidak berongga seperti nebula planetari, tidak
    /// berlengan seperti galaksi, tidak memusat seperti gugus bola.
    ///
    /// Nilainya diukur, bukan dirasa: pada setiap fuzziness 0…1 hasilnya
    /// **0.456×** terang morfologi paling redup, jadi ia selalu lebih redup
    /// tanpa pernah menghilang — objek yang tidak digambar sama sekali
    /// terbaca sebagai "tidak ada objek di sini", dan itu klaim yang lebih
    /// kuat daripada "ada sesuatu, tapi belum pasti".
    public static func uncertainFog(fuzziness: Double,
                                    frameHalfExtent: Double = halfExtent) -> NebulaGeometry {
        let layout: [(Double, Double, Double, Double, Double, Double)] = [
            // (offsetX, offsetY, skala lebar, rasio sumbu, sudut°, opasitas)
            ( 0.00,  0.00, 0.34, 1.0, 0.0, 0.14),
            ( 0.10,  0.06, 0.26, 1.0, 0.0, 0.10),
            (-0.08, -0.05, 0.20, 1.0, 0.0, 0.11)
        ]
        return buildDeepSky(layout: layout, fuzziness: fuzziness,
                            frameHalfExtent: frameHalfExtent)
    }

    /// Bentuk objek langit dalam untuk morfologi tertentu.
    ///
    /// **Kenapa satu fungsi untuk semua bentuk, bukan satu per jenis.**
    /// Susunan blob-lah yang membedakan galaksi dari gugus bola, bukan kode
    /// gambar yang berbeda: semuanya kabut tanpa tepi keras, hanya jumlah,
    /// letak, dan rasio sumbunya yang berubah. Menaruhnya di satu tempat
    /// membuat aturan "jangan keluar frame" berlaku untuk **semua** bentuk
    /// sekaligus. Kalau tiap bentuk punya fungsi sendiri, bentuk yang
    /// ditambahkan belakangan bisa lupa memeriksanya -- dan itu justru bentuk
    /// yang paling jarang dilihat.
    ///
    /// - Parameters:
    ///   - morphology: bentuk objek. `nil` = tidak diketahui → kabut netral.
    ///   - fuzziness: 0 = titik, 1 = paling lebar.
    ///   - elongation: rasio sumbu **minor : mayor** siluet — 1.0 bulat,
    ///     0.60 = memanjang seperti M27 dilihat dari samping. Lihat
    ///     `DeepSkyCatalogue.elongationByID`.
    ///   - objectID: id objek katalog, **hanya** untuk memberi susunan
    ///     bintang yang khas pada gugus terbuka. `nil` = susunan bawaan.
    ///   - frameHalfExtent: setengah lebar frame.
    public static func deepSky(morphology: DeepSkyCatalogue.Morphology?,
                               fuzziness: Double,
                               elongation: Double = 1.0,
                               objectID: String? = nil,
                               frameHalfExtent: Double = halfExtent) -> NebulaGeometry {
        guard let morphology else {
            // Tidak tahu bentuknya: gambar kabut netral yang **paling redup**,
            // **jangan** menebak salah satu jenis. Lihat
            // `DeepSkyCatalogue.morphology(forObjectID:)`.
            //
            // **Bukan `nebula(fuzziness:)` lagi.** Dulu memang begitu, dan
            // akibatnya kabut ragu identik dengan nebula emisi — paling
            // terang dari seluruh katalog, padahal ia satu-satunya keadaan
            // yang tidak berhak mengklaim apa pun. Lihat `uncertainFog`.
            return uncertainFog(fuzziness: fuzziness,
                                frameHalfExtent: frameHalfExtent)
        }
        switch morphology {
        case .nebula:
            return nebula(fuzziness: fuzziness, frameHalfExtent: frameHalfExtent)

        case .planetaryNebula:
            // Cangkang gas **berongga**: cincin blob pada satu radius, dan
            // **tidak ada blob di tengah**. Ketiadaan pusat inilah intinya —
            // nebula emisi memusat, nebula planetari justru kosong di situ
            // karena bintang pusatnya sudah meniup gasnya keluar.
            //
            // Yang membedakannya dari `openCluster` (yang juga tanpa inti)
            // bukan ketiadaan pusat, melainkan **keteraturannya**: semua blob
            // duduk pada radius yang sama, karena cangkangnya memang sebuah
            // kulit bola. Gugus terbuka tersebar pada radius yang berbeda-
            // beda. Jadi `.planetaryNebula` boleh punya blob rapat tanpa
            // tampak sebagai "kerumunan bintang", dan perbedaan itu terukur
            // (`testPlanetaryNebulaShellSitsOnOneRadius`).
            // **Kenapa 24 titik pada 15°, bukan 16 pada 22.5°.** Enam belas
            // titik **beririsan** — uji geometri di bawah menuntutnya, dan ia
            // benar — tetapi beririsan ternyata **belum cukup**. Yang terukur
            // di piksel bukan "apakah tepinya bertemu", melainkan "apakah
            // **lantai** di antara dua puncak masih tinggi". Dengan gradien
            // yang turun ke nol di tepi tiap blob, dua blob yang bertemu di
            // satu titik hanya menyisakan **satu** piksel tinggi di
            // persinggungannya; sisanya tetap turun jauh. Hasilnya: 16 blob
            // menyisakan **16 puncak lokal** yang terlihat mata — jumlah yang
            // sama dengan jumlah maniknya.
            //
            // Angka pada fuzziness katalog yang sebenarnya (M57 = 0.40, lebar
            // blob hanya 1.46× jaraknya, bukan 1.75× seperti kasus rujukan
            // 0.8):
            //
            //     tata letak          lantai/puncak    puncak lokal terlihat
            //     8 blob @45°            0.00              8  (manik)
            //     16 blob @22.5°         0.60             16  (masih manik)
            //     24 blob @15°           0.84             12  (cangkang)
            //
            // Ambang gerbangnya **0.75**, bukan 0.50 — selisih 0.60 vs 0.50
            // terlalu tipis untuk memisahkan manik dari cangkang, dan ambang
            // yang lebih rendah itulah yang membuat cacat ini lolos selama
            // gerbang hanya menggambar kasus rujukan (0.77, hijau) sementara
            // yang tampil di layar adalah M57 (0.60, manik).
            //
            // **Yang tidak berubah: lubangnya dan satu radiusnya.** Radius
            // tiap blob tetap 0.42 R (sebarannya 0 — uji "satu radius" tetap
            // hijau), dan tepi dalamnya tetap 0.307 R (fuzziness 0) sampai
            // 0.237 R (fuzziness 1) — jauh di atas ambang 0.2 yang menjaga
            // "berongga di tengah". Yang berubah hanya **kerapatan** titik di
            // sepanjang cincin, bukan tempat cincinnya.
            //
            // Radius dan komponennya **dihitung**, bukan ditulis: 15° pada
            // radius `r` adalah `(r·cos 15°, r·sin 15°)`, dan kelipatannya
            // diturunkan dari satu sudut supaya tidak ada dua puluh empat
            // posisi tangan yang bisa tertinggal separuh saat cangkangnya
            // dirapikan. Satu angka (`shellRadius`) dipakai kedua sumbu.
            let shellRadius = 0.42
            let shellStep = 15.0
            let ring: [(Double, Double)] = (0..<24).map { index in
                let angle = shellStep * Double(index) * .pi / 180
                return (shellRadius * cos(angle), shellRadius * sin(angle))
            }
            // Opasitasnya tidak seragam: cangkang yang rata sempurna tampak
            // seperti donat yang digambar. Bedanya kecil dan sengaja
            // asimetris (sisi atas sedikit lebih tebal). Enam belas nilai
            // tetap dipakai berputar untuk dua puluh empat blob — bukan
            // diperpanjang menjadi dua puluh empat, karena yang dibutuhkan
            // adalah **variasi**, dan pola yang berulang tiap 16 sudah
            // cukup untuk itu tanpa menambah satu pun angka yang harus
            // dijaga gerbang drift.
            let shellOpacity = [0.54, 0.48, 0.52, 0.46, 0.50, 0.44, 0.53, 0.47,
                                0.51, 0.45, 0.49, 0.44, 0.52, 0.46, 0.50, 0.45]
            // **`elongation` memepetkan cangkangnya, dan itu justru benar.**
            // Cangkang planetari adalah **kulit bola**; objek yang sama
            // dilihat dari kutub tampak bulat (M57), dari samping tampak
            // lonjong (M27). Jadi yang berubah karena sudut pandang bukan
            // jenisnya, melainkan **bentuk proyeksinya** — dan proyeksi bola
            // yang miring memang elips.
            //
            // Yang dipetkan adalah **kedua** komponen y: posisi **dan** tinggi
            // tiap blob. Kalau hanya posisinya yang dipetkan (blob tetap
            // bulat), cangkangnya jadi deretan lingkaran pada elips, dan
            // makin pipih makin banyak celah gelap yang terbuka di antara
            // mereka. Kalau hanya tingginya yang dipetkan (posisi tetap
            // lingkaran), tepi dalamnya justru **naik** dan lubangnya
            // menutup — itu yang dulu diukur: pada rasio 0.71 tepi dalam
            // jatuh dari 0.237 R ke 0.041 R, cangkang berongga berubah jadi
            // gumpalan pekat. Memetkan keduanya sekaligus membuat lubangnya
            // **ikut terskala**: tepi dalam diukur tetap terbuka (kekosongan
            // tengah 1.000) pada setiap nilai elongation yang dicoba.
            //
            // Diukur pada kedua ukuran yang dipakai app, dengan fuzziness
            // katalog M27 (0.68):
            //
            //     elongation   siluet      rasio    beda dari M57
            //       1.000      108×108     1.000        —
            //       0.750      108×92      0.852        —
            //       0.600      108×76      0.704    19.7% (200 px)
            //       0.558      108×70      0.648        —
            //
            // 0.60 dipakai karena **0.704 mendekati rasio M27 yang
            // sebenarnya (8.0′ : 5.7′ = 0.71)**, dan pada 76 px siluetnya
            // masih **20.5%** berbeda dari M57 — jauh di atas ambang 8%
            // gerbangnya. Nilai 0.558 dulu dipilih untuk bentuk dua-cuping
            // yang terpisah; untuk cangkang yang dipetkan, 0.60 yang jujur.
            // Opasitas diambil **berputar** (`index % shellOpacity.count`),
            // bukan lewat `zip`: `zip` berhenti pada yang terpendek, jadi
            // menggabungkan 24 posisi dengan 16 opasitas akan diam-diam
            // memotong cangkangnya kembali menjadi 16 blob — persis cacat
            // yang baru saja diperbaiki, dan tanpa satu pun galat kompilasi.
            let layout: [(Double, Double, Double, Double, Double, Double)] =
                ring.enumerated().map { index, offset in
                    (offset.0, offset.1 * elongation, 0.26, 1.0 * elongation,
                     0.0, shellOpacity[index % shellOpacity.count])
                }
            return buildDeepSky(layout: layout, fuzziness: fuzziness,
                                frameHalfExtent: frameHalfExtent)

        case .galaxy:
            // Cakram miring + tonjolan inti. Dua hal yang membuatnya terbaca
            // sebagai galaksi, bukan nebula lonjong: rasio sumbu tiap lapisan
            // < 1 (elips), dan lapisan **makin bulat ke dalam** (inti 0.42,
            // cakram 0.34) -- tonjolan pusat yang khas.
            let layout: [(Double, Double, Double, Double, Double, Double)] = [
                (0.0, 0.0, 1.00, 0.34, -18.0, 0.30),
                (0.0, 0.0, 0.66, 0.30, -18.0, 0.26),
                (0.0, 0.0, 0.26, 0.42, -18.0, 0.60)
            ]
            return buildDeepSky(layout: layout, fuzziness: fuzziness,
                                frameHalfExtent: frameHalfExtent)

        case .spiralGalaxy:
            // Lengan yang benar-benar terbaca: dua lengan pada spiral
            // logaritmik `r = 0.20·e^(0.30θ)`, dari θ = 0.35 rad sampai
            // 3.35 rad. Sudut itu bukan pilihan bebas -- ia berhenti
            // sebelum setengah putaran, sehingga **dua** lengan terpisah
            // 180° membentuk huruf S, bukan cincin penuh. Cincin penuh
            // akan terbaca sebagai nebula planetari, bukan galaksi.
            //
            // **Kenapa 12 blob, bukan 4.** Pada ukuran jam (38 pt), empat
            // titik terpisah tidak lagi terbaca sebagai lengkung: jarak
            // antar-titik jatuh di bawah satu piksel dan yang tersisa hanya
            // empat bintik yang posisinya tampak acak.
            //
            // **Kenapa 5 titik per lengan, bukan 4.** Spiral logaritmik
            // memberi jarak antar-titik yang **membesar** ke luar (Δr =
            // 0.078 → 0.105 → 0.142) sementara lebar blob justru menyusut
            // (0.24 → 0.16). Dengan 4 titik, gradien blob terluar sudah
            // meredup sebelum bertemu tetangganya, dan lengkungnya **bolong**
            // tepat di antara dua titik terluar. Diukur pada 76 px, `ss=8`:
            //
            //     r=0.45   38° di atas ambang    menyambung
            //     r=0.50    6°                   BOLONG
            //     r=0.55   12°                   menyambung
            //
            // Satu jari-jari penuh tanpa goresan di antara dua yang bergoresan
            // — di layar itu gumpalan bergerigi, bukan galaksi berlengan.
            // Titik sisipan (θ = 2.85) memakai lebar & opasitas yang
            // **diinterpolasi** dari tetangganya, bukan dipilih supaya lulus.
            // Dijaga `check_spiral_arms_stay_continuous`.
            //
            // Angka-angkanya ditulis penuh (bukan lewat `cos`/`exp` seperti
            // `.planetaryNebula`) karena port Python menyimpan hasilnya
            // sebagai angka, dan `check_deep_sky_layouts_match_the_model`
            // membandingkan **nilai** di kedua berkas. Rumus yang dihitung
            // dua kali di dua bahasa adalah tempat pembulatan menyimpang.
            let layout: [(Double, Double, Double, Double, Double, Double)] = [
                // Tonjolan inti: yang tersisa paling terang saat spiral
                // dilihat dari jauh, dan yang membedakannya dari gugus bola
                // (inti gugus tidak punya lengan sama sekali).
                (0.000000, 0.000000, 0.32, 1.0, 0.0, 0.60),
                // Kabut cakram yang menyatukan lengannya: **sempit**, sangat
                // redup, dan di bawah lengan supaya tidak menenggelamkan
                // kontrasnya.
                //
                // **Kenapa 0.45, bukan 0.95.** Versi pertama memakai 0.95 —
                // "cakram lebar" seperti `.galaxy` — dan uji menolaknya
                // dengan alasan yang benar: pada fuzziness 0.9 kabut itu
                // melebar ke 0.914 R, sementara lengan terjauh hanya 0.546 R,
                // jadi **seluruh lengan terkurung di dalam kabut** dan yang
                // tampil kembali gumpalan bulat. Diukur (`out/ukur-lengan-
                // baca.py`): kabut harus ≤ 0.50 supaya lengan menonjol keluar
                // siluet. Pada 0.45 profil kecerahannya turun 444 → 313 → 149
                // → 68 (pusat ke tepi, satuan 1/1000) — cakram berstruktur,
                // bukan blob rata.
                (0.000000, 0.000000, 0.45, 1.0, 0.0, 0.13),
                // Lengan A (θ = 0.35, 1.35, 2.35, 2.85, 3.35) — makin ke luar
                // makin kecil dan makin redup. Lebarnya **menyusut**, jadi
                // jarak antar-titik tidak boleh ikut melebar tanpa titik
                // sisipan; lihat catatan di atas.
                //
                // Dua blob terluar sedikit lebih terang daripada interpolasi
                // murni (0.175/0.25 dan 0.16/0.22) — dinaikkan supaya jari-jari
                // terluar menyisakan 17° di atas ambang, bukan 12° yang pas di
                // batas. Gerbang yang lulus dengan margin nol akan berkedip
                // begitu ada perubahan kecil di tempat lain.
                (0.208674, 0.076172, 0.24, 1.0, 0.0, 0.34),
                (0.065671, 0.292581, 0.22, 1.0, 0.0, 0.32),
                (-0.284437, 0.287983, 0.19, 1.0, 0.0, 0.28),
                (-0.450423, 0.135194, 0.18, 1.0, 0.0, 0.26),
                (-0.534559, -0.113047, 0.17, 1.0, 0.0, 0.24),
                // Lengan B — titik-ke-titik cermin lengan A (180°), jadi
                // bentuknya simetris dan tidak tampak sebagai satu tangan.
                (-0.208674, -0.076172, 0.24, 1.0, 0.0, 0.34),
                (-0.065671, -0.292581, 0.22, 1.0, 0.0, 0.32),
                (0.284437, -0.287983, 0.19, 1.0, 0.0, 0.28),
                (0.450423, -0.135194, 0.18, 1.0, 0.0, 0.26),
                (0.534559, 0.113047, 0.17, 1.0, 0.0, 0.24)
            ]
            return buildDeepSky(layout: layout, fuzziness: fuzziness,
                                frameHalfExtent: frameHalfExtent)

        case .openCluster:
            // Bintang tersebar **jarang**, tanpa inti: blob-blobnya kecil,
            // tersebar sampai dekat tepi, dan **tidak ada yang di tengah**.
            // Yang membedakannya dari gugus bola adalah ketiadaan pusat,
            // bukan ukurannya — jadi tidak ada blob di sekitar pusat, dan
            // ukurannya nyaris seragam supaya tidak ada yang tampak sebagai
            // inti.
            //
            // **Kenapa susunannya diputar per objek.** Dua gugus terbuka
            // katalog, M7 (Gugus Ptolemy) dan M41, bertabrakan di seluruh
            // sinyal bentuk yang ada — sama `.openCluster`, sama
            // `fuzziness` 0,50, elongasi bawaan 1,0 — sehingga digambar
            // **identik**. Menurunkan `fuzziness` m41 dicoba dan ditolak:
            // ia hanya mengubah lebar tiap blob, sementara **letaknya**
            // tetap, jadi render-nya cuma bergeser ~7% piksel dengan delta
            // kanal ~0,09 — tak terbaca di kartu jam 38 pt. Itu hijau palsu:
            // ujinya lulus, matanya tidak.
            //
            // Bentuk memipih juga **tidak** dipakai di sini, walaupun
            // `elongation` tersedia: M7 dan M41 sama-sama nyaris bulat,
            // jadi memipihkan salah satunya berarti mengarang bentuk demi
            // lulus uji. Yang dipakai adalah derajat kebebasan yang memang
            // nyata: **arah sebaran** bintangnya. Memutar susunan tidak
            // mengubah sebaran, jumlah, ukuran, maupun opasitas apa pun —
            // hanya arahnya — dan dua gugus terbuka sungguhan memang tidak
            // punya pola bintang yang sama. Sudutnya diturunkan dari id
            // (deterministik, `hashValue` tidak dipakai karena ia diacak
            // per proses di Swift), jadi objek yang sama selalu tampil
            // sama, dan `nil` tetap menghasilkan susunan bawaan.
            let stars: [(Double, Double, Double, Double, Double, Double)] = [
                ( 0.000000, -0.620000, 0.34, 1.0, 0.0, 0.55),
                (-0.560000, -0.300000, 0.31, 1.0, 0.0, 0.50),
                ( 0.520000, -0.340000, 0.33, 1.0, 0.0, 0.45),
                (-0.680000,  0.180000, 0.29, 1.0, 0.0, 0.52),
                ( 0.620000,  0.220000, 0.31, 1.0, 0.0, 0.48),
                (-0.340000,  0.580000, 0.33, 1.0, 0.0, 0.42),
                ( 0.300000,  0.620000, 0.29, 1.0, 0.0, 0.55)
            ]
            let layout = Self.scatterRotated(stars, byObjectID: objectID)
            return buildDeepSky(layout: layout, fuzziness: fuzziness,
                                frameHalfExtent: frameHalfExtent)

        case .globularCluster:
            // Inti padat di tengah (blob terbesar & paling terang), dikelilingi
            // dua cincin bintang yang makin redup ke luar. Bentuk **memusat**
            // inilah yang membedakannya dari gugus terbuka.
            let layout: [(Double, Double, Double, Double, Double, Double)] = [
                ( 0.000000,  0.000000, 0.46, 1.0, 0.0, 0.55),
                ( 0.289778,  0.077646, 0.22, 1.0, 0.0, 0.38),
                ( 0.077646,  0.289778, 0.22, 1.0, 0.0, 0.38),
                (-0.212132,  0.212132, 0.22, 1.0, 0.0, 0.38),
                (-0.289778, -0.077646, 0.22, 1.0, 0.0, 0.38),
                (-0.077646, -0.289778, 0.22, 1.0, 0.0, 0.38),
                ( 0.212132, -0.212132, 0.22, 1.0, 0.0, 0.38),
                ( 0.325269,  0.325269, 0.17, 1.0, 0.0, 0.22),
                (-0.119057,  0.444326, 0.17, 1.0, 0.0, 0.22),
                (-0.444326,  0.119057, 0.17, 1.0, 0.0, 0.22),
                (-0.325269, -0.325269, 0.17, 1.0, 0.0, 0.22),
                ( 0.119057, -0.444326, 0.17, 1.0, 0.0, 0.22),
                ( 0.444326, -0.119057, 0.17, 1.0, 0.0, 0.22)
            ]
            return buildDeepSky(layout: layout, fuzziness: fuzziness,
                                frameHalfExtent: frameHalfExtent)
        }
    }

    // MARK: - Inti bintang di dalam gugus

    /// Bintang-bintang **terbaca** di dalam gugus, siap digambar `Canvas`.
    ///
    /// **Kenapa ini ada, padahal gugus sudah punya blob.** Sebuah gugus
    /// bintang *adalah* bintang-bintangnya: yang membuat Pleiades terbaca
    /// sebagai Pleiades bukan kabut di sekelilingnya, melainkan **titik-titik
    /// cahaya yang terpisah** di dalamnya. Sampai siklus ini gugus terbuka dan
    /// gugus bola digambar sebagai kabut lembut saja — sama seperti nebula,
    /// hanya susunannya berbeda. Diukur pada render: tujuh blob kabur tanpa
    /// satu pun titik tajam, dan bentuk itu terbaca sebagai noda, bukan sebagai
    /// gugus. Nebula emisi memang kabut; gugus justru sebaliknya — bagian
    /// terpentingnya adalah bintang yang bisa dipisahkan mata.
    ///
    /// **Kenapa geometrinya diturunkan dari blob, bukan ditulis sendiri.**
    /// Inti yang punya daftar posisi sendiri bisa menyimpang dari blob yang
    /// digambar di bawahnya — dan penyimpangan itu tidak terlihat sebagai
    /// kesalahan, hanya sebagai bintang yang "agak meleset". Menurunkannya dari
    /// blob yang sama (`deepSky(morphology:fuzziness:)`) membuat keduanya
    /// **tidak bisa** berpisah: menggeser sebuah blob menggeser bintangnya.
    ///
    /// **Kenapa jari-jarinya selalu aman di dalam frame.** Inti diambil
    /// `min(halfWidth, halfHeight) * fraksi` dengan `fraksi <= 1`, jadi inti
    /// selalu **lebih kecil** dari blob yang menaunginya di kedua sumbu. Karena
    /// `testEveryDeepSkyBlobStaysInsideTheFrame` sudah membuktikan setiap blob
    /// muat di frame, inti yang lebih kecil di pusat yang sama ikut muat —
    /// tanpa satu pun perhitungan luberan baru yang bisa salah. Inilah alasan
    /// `min` dipakai, bukan `halfWidth`: blob galaksi pipih punya
    /// `halfHeight < halfWidth`, dan inti sebesar `halfWidth` akan menonjol
    /// keluar dari cakramnya sendiri.
    ///
    /// **Hanya gugus, dan hanya saat terkunci.** Morfologi lain mengembalikan
    /// daftar kosong: nebula emisi tidak punya bintang tajam, galaksi
    /// bintangnya tidak terpisah pada skala ini. Dan karena pemanggilnya
    /// membaca morfologi lewat `drawableMorphology` (yang `nil` saat engine
    /// ragu), gugus yang belum pasti tidak pernah mendapat inti — gambar yang
    /// lebih yakin daripada badge "Ragu" tetap dilarang.
    public struct ClusterCoreGeometry: Equatable, Sendable {
        public struct Core: Equatable, Sendable {
            /// Geseran pusat inti dari tengah frame, sumbu x & y (satuan radius).
            public var offsetX: Double
            public var offsetY: Double
            /// Jari-jari inti bintang (satuan radius frame).
            public var radius: Double
            /// Opasitas puncak inti.
            public var opacity: Double
            /// Setengah-bentang terkecil blob yang menaungi inti ini (satuan
            /// radius frame) — **batas keras** ukuran inti.
            ///
            /// Ikut dibawa, bukan dihitung ulang oleh pemanggil: lantai
            /// keterbacaan (`readableCorePointRadius`) harus dipotong pada
            /// batas ini, dan pemanggil yang tidak tahu batasnya akan menaikkan
            /// inti sampai keluar dari kabutnya sendiri.
            public var blobExtent: Double
        }

        public var cores: [Core]

        public init(cores: [Core]) { self.cores = cores }
    }

    /// Fraksi jari-jari blob yang dipakai sebagai jari-jari inti bintangnya.
    ///
    /// **Kenapa 0.30, dan kenapa angka ini di model.** Ia mengatur seberapa
    /// "tajam" gugus terlihat: terlalu besar dan intinya menelan blobnya
    /// (kembali jadi noda), terlalu kecil dan bintangnya hilang di ukuran
    /// kartu jam. Pada kartu jam (38 pt, radius frame 19 pt) radius blob gugus
    /// adalah 0.09–0.11 R, jadi inti 0.30 dari itu ≈ **0.55 pt** — di bawah
    /// satu piksel pada layar @1x, tetapi 1.1 px pada @2x yang dipakai semua
    /// Apple Watch. Diukur pada render 76 px (@2x): inti tetap menonjol 0.73
    /// di atas kabutnya, jadi gugusnya terbaca sebagai bintang — dan angka ini
    /// **tidak** boleh diturunkan, karena pada 0.20 gugus bola jatuh ke 0.17
    /// dan kembali tampil sebagai noda.
    ///
    /// Angkanya hidup di sini, bukan sebagai literal di `Canvas`, supaya uji
    /// Linux dan port Python membacanya dari sumber yang sama.
    public static let clusterCoreRadiusFraction: Double = 0.30

    /// Penambahan opasitas inti bintang gugus di atas blob yang menaunginya.
    ///
    /// **Kenapa angka ini pindah dari `Canvas` ke model.** Ia dulu hidup
    /// sebagai literal `0.25` di **dua** bahasa sekaligus —
    /// `core.opacity(min(1, star.opacity + 0.25))` di view dan `op + 0.25` di
    /// port — tanpa satu pun gerbang yang menjaganya. Terukur
    /// (`Tools/bukti-mutasi-inti-opasitas.py`): mengganti literal di **view**
    /// menjadi `0.55` membiarkan seluruh 22 gerbang yang membaca view hijau
    /// (0 merah), jadi jam bisa kehilangan inti gugusnya tanpa suara;
    /// mengganti di **port** hanya berbunyi karena kebetulan ada docstring
    /// yang mengutip angka piksel yang bergeser, bukan karena ada yang
    /// menjaga angkanya.
    ///
    /// Bentuk cacatnya sama persis dengan `moonSphereGradientEndRadius`:
    /// **satu angka, dua bahasa, nol penjaga**. Yang membedakan hanya kelas
    /// objeknya — Bulan vs gugus bintang.
    ///
    /// Angka ini **bukan** hiasan: inti tanpa penambahan opasitas tenggelam ke
    /// dalam blob yang menaunginya, dan gugus kembali tampil sebagai noda
    /// kabur — persis cacat yang dijaga `clusterCoreRadiusFraction` dari sisi
    /// ukuran.
    public static let clusterCoreBrighten: Double = 0.25

    /// Plafon jari-jari inti bintang gugus, **diturunkan dari tata letaknya**.
    ///
    /// **Kenapa plafon ini perlu.** Fraksi di atas diambil dari blob yang
    /// menaungi bintang. Itu benar untuk gugus terbuka — bintangnya kecil dan
    /// tersebar — tetapi **salah untuk blob pusat gugus bola**, yang terbesar
    /// di seluruh katalog (0.46 R pada fuzziness 1.0): 30% darinya menjadi
    /// cakram 0.138 R, dan diukur pada render 520 px inti itu tampil sebagai
    /// **satu bola cahaya raksasa** yang dinilai "bokeh", bukan gugus bintang.
    ///
    /// **Kenapa plafonnya `median`, bukan angka tetap.** Secara fisis, inti
    /// gugus bola lebih terang karena **lebih banyak bintang per satuan luas**,
    /// bukan karena bintangnya lebih besar — dan kerapatan itu sudah dinyatakan
    /// oleh blobnya (blob pusat memang paling besar & paling pekat). Memberi
    /// inti yang ikut membesar berarti menghitung kerapatan itu **dua kali**.
    /// Jadi yang benar: tidak ada bintang yang jauh lebih besar dari bintang
    /// **biasa** di gugus itu. `median` (bukan `mean`) dipakai justru karena
    /// yang harus dikecualikan adalah si pencilan itu sendiri — `mean` masih
    /// tertarik ke atas olehnya, jadi plafonnya ikut membengkak.
    ///
    /// Angka tetap (percobaan pertama: 0.055 R) **gagal** dan itu terukur:
    /// plafon absolut tidak bisa mengikuti `fuzziness`, jadi pada f=0 rasio
    /// inti pusat terhadap bintang cincin menjadi **1.71** sementara pada f=1.0
    /// hanya 1.06 — satu angka yang terlalu ketat di ujung yang satu dan terlalu
    /// longgar di ujung yang lain. Diturunkan dari tata letak, rasionya **1.0
    /// di setiap fuzziness**.
    ///
    /// - Parameter extents: setengah-bentang terkecil tiap blob.
    /// - Returns: plafon dalam satuan radius frame; 0 kalau tidak ada blob.
    public static func clusterCoreReferenceExtent(_ extents: [Double]) -> Double {
        let sorted = extents.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[middle] }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// Jari-jari inti bintang minimum agar masih terbaca sebagai **titik**, dalam
    /// poin pada perangkat terkecil.
    ///
    /// **Kenapa lantai ini perlu, dan kenapa angkanya 0.8 — ini TERUKUR, bukan
    /// diperkirakan.** Tanpa lantai, inti bintang gugus di kartu jam (38 pt,
    /// radius frame 19 pt) berukuran **0.67–0.99 pt**. Diukur sebagai piksel
    /// pada layar @2x yang dipakai seluruh Apple Watch, itu 1.34–1.98 px; pada
    /// @1x — layar yang tidak dipakai perangkat ini — 0.67–0.99 px, **di bawah
    /// satu piksel**, sehingga inti tidak punya piksel sendiri dan gugusnya
    /// kembali tampil sebagai kabut. Percobaan pertama saya justru menyimpulkan
    /// lantai ini tidak perlu, karena probe-nya membandingkan **nisbah
    /// ketajaman** inti terhadap kabutnya (yang tetap tinggi) alih-alih
    /// **ukuran** inti (yang sub-piksel). Uji Linux
    /// `testClusterCoresStayInsideTheirBlobsAndAreVisible` menangkapnya: 24 inti
    /// gagal ambang 1 px.
    ///
    /// **Kenapa dinyatakan dalam poin, bukan pecahan radius.** Keterbacaan
    /// adalah sifat perangkat, bukan sifat bentuk: ambangnya harus tetap 0.8 pt
    /// baik di kartu 38 pt maupun panel 200 pt. Kalau ia ditulis sebagai
    /// pecahan, ia akan berarti ukuran berbeda di tiap layar dan gerbang piksel
    /// harus mengukur ambang yang berbeda pula di tiap ukuran — persis jenis
    /// ketergantungan yang membuat ambang gambar rapuh.
    ///
    /// **Lantai ini tidak boleh menang atas batas blob.** Pemanggil memotongnya
    /// pada `blobExtent`, jadi di frame yang lebih kecil dari lantainya sendiri
    /// yang menang adalah batas blob — dan pembuktian "blob muat di frame"
    /// tetap menutupi intinya. Lantai yang boleh melebihi blob akan membuat
    /// bintang menonjol keluar dari kabutnya sendiri, dan itu terlihat sebagai
    /// bintang yang salah tempat, bukan sebagai gugus yang lebih tajam.
    public static let readableCorePointRadius: Double = 0.8

    /// Jari-jari inti yang benar-benar dipakai, setelah lantai keterbacaan
    /// dan batas blob sama-sama diterapkan.
    ///
    /// Dipisah supaya invariannya bisa diuji langsung: hasilnya **selalu**
    /// `<= blobExtent`, berapa pun lantai dan fraksinya.
    public static func readableCoreRadius(fraction: Double,
                                          extent: Double,
                                          reference: Double,
                                          frameHalfExtent: Double) -> Double {
        let scaled = fraction * min(extent, reference)
        guard frameHalfExtent > 0 else { return scaled }
        let floor = readableCorePointRadius / frameHalfExtent
        return min(extent, max(scaled, floor))
    }

    /// Inti bintang untuk sebuah morfologi gugus; kosong untuk yang lain.
    ///
    /// **Kenapa `frameHalfExtent` tidak punya nilai bawaan.** Ia dipakai
    /// lantai keterbacaan, dan lantai itu dinyatakan dalam poin. Pemanggil
    /// yang membiarkannya pada 1.0 akan membuat lantai 0.8 "poin" dibaca
    /// sebagai 0.8 radius — dan karena 0.8 radius lebih besar dari setiap
    /// blob, `min` akan mengembalikan **seluruh blob** sebagai inti: gugusnya
    /// berubah menjadi kumpulan cakram pekat, bukan kabut berbintang. Nilai
    /// bawaan yang salah lebih berbahaya daripada tidak ada nilai bawaan,
    /// jadi parameter ini wajib — pemanggil harus tahu seberapa besar frame
    /// yang sedang digambarnya.
    ///
    /// - Parameters:
    ///   - morphology: bentuk objek. `nil` = tidak diketahui → tanpa inti.
    ///   - fuzziness: 0 = titik, 1 = paling lebar (sama dengan blob-nya).
    ///   - frameHalfExtent: setengah lebar frame **dalam poin**.
    public static func clusterCores(morphology: DeepSkyCatalogue.Morphology?,
                                    fuzziness: Double,
                                    frameHalfExtent: Double) -> ClusterCoreGeometry {
        guard morphology == .openCluster || morphology == .globularCluster else {
            return ClusterCoreGeometry(cores: [])
        }
        let blobs = deepSky(morphology: morphology, fuzziness: fuzziness).blobs
        let reference = clusterCoreReferenceExtent(
            blobs.map { min($0.halfWidth, $0.halfHeight) })
        // **Opasitas ikut blob-nya, dan itu yang membuat gugus bola terbaca
        // memusat.** Inti yang sama terang di mana-mana akan membuat gugus bola
        // tampak sebagai cincin bintang yang rata; memakai opasitas blob
        // mempertahankan inti padat di tengah yang memang jadi pembedanya.
        //
        // **Jari-jari tidak pernah melebihi blobnya** (`min` dengan bentang
        // blob itu sendiri, lihat `readableCoreRadius`), jadi setiap inti muat
        // di dalam blob yang `testEveryDeepSkyBlobStaysInsideTheFrame` sudah
        // buktikan muat — tanpa satu pun perhitungan luberan baru yang bisa
        // salah. `min` atas `halfWidth` **dan** `halfHeight` dipakai karena blob
        // galaksi yang pipih punya `halfHeight < halfWidth`; inti sebesar
        // `halfWidth` akan menonjol keluar dari cakramnya sendiri.
        let cores = blobs.map { blob in
            let extent = min(blob.halfWidth, blob.halfHeight)
            return ClusterCoreGeometry.Core(
                offsetX: blob.offsetX,
                offsetY: blob.offsetY,
                radius: readableCoreRadius(fraction: clusterCoreRadiusFraction,
                                           extent: extent,
                                           reference: reference,
                                           frameHalfExtent: frameHalfExtent),
                opacity: blob.opacity,
                blobExtent: extent)
        }
        return ClusterCoreGeometry(cores: cores)
    }

    /// Menyusun blob dari layout, **tanpa pernah** membiarkannya keluar frame.
    ///
    /// Lebar & tinggi dikecilkan **bersama** (`room`), bukan tiap sumbu
    /// dipotong terpisah: memotong sumbu secara terpisah akan mengubah rasio
    /// sumbu galaksi persis pada blob yang paling dekat tepi -- bentuk yang
    /// justru paling terlihat.
    ///
    /// **Rotasi ikut dihitung.** Elips yang diputar `θ` tidak lagi sejajar
    /// sumbu: bentangnya menjadi `hw·(|cos θ| + aspect·|sin θ|)` di x dan
    /// `hw·(|sin θ| + aspect·|cos θ|)` di y. Mengabaikan suku `sin θ` membuat
    /// cakram galaksi yang miring **keluar frame** justru pada bentuk yang
    /// paling terlihat -- dan itu memang terjadi sebelum rumus ini diperbaiki
    /// (cakram 18° keluar 0.056 R, ditemukan oleh
    /// `testEveryDeepSkyBlobStaysInsideTheFrame`).
    ///
    /// - Parameter layout: (offsetX, offsetY, skala lebar, rasio sumbu,
    ///   sudut°, opasitas). `rasio sumbu` = setengah tinggi / setengah lebar.
    ///
    /// **Yang TIDAK diklaim:** sudut ini bukan bentuk gugus yang sebenarnya.
    /// Sebaran aslinya tidak dikenal katalog ini, jadi yang dijaga hanya
    /// bahwa dua objek berbeda **tidak tampil identik**, bukan bahwa
    /// posisinya akurat secara astronomis.
    static func scatterRotated(_ stars: [(Double, Double, Double, Double, Double, Double)],
                               byObjectID objectID: String?) -> [(Double, Double, Double, Double, Double, Double)] {
        guard let objectID, !objectID.isEmpty else { return stars }
        var mixed: UInt32 = 2_166_136_261
        for byte in objectID.utf8 {
            mixed = (mixed ^ UInt32(byte)) &* 16_777_619
        }
        let angle = Double(mixed % 3600) / 3600.0 * 2 * Double.pi
        let cosA = cos(angle)
        let sinA = sin(angle)
        return stars.map { star in
            let x = star.0 * cosA - star.1 * sinA
            let y = star.0 * sinA + star.1 * cosA
            return (x, y, star.2, star.3, star.4, star.5)
        }
    }

    private static func buildDeepSky(
        layout: [(Double, Double, Double, Double, Double, Double)],
        fuzziness: Double,
        frameHalfExtent: Double) -> NebulaGeometry {
        let clamped = min(1, max(0, fuzziness))
        // Lebar kabut mengikuti `fuzziness`, tetapi tidak pernah melebihi
        // ruang yang tersisa (lihat `nebula`).
        let growth = 0.62 + 0.38 * clamped
        let blobs = layout.map { offsetX, offsetY, widthScale, aspect, angle, opacity in
            let headroomX = frameHalfExtent - abs(offsetX)
            let headroomY = frameHalfExtent - abs(offsetY)
            let theta = angle * .pi / 180
            let cosT = abs(cos(theta))
            let sinT = abs(sin(theta))
            // Berapa setengah-lebar yang diizinkan tiap sumbu, setelah rotasi.
            let roomX = headroomX / max(cosT + aspect * sinT, 1e-9)
            let roomY = headroomY / max(sinT + aspect * cosT, 1e-9)
            let halfWidth = min(roomX, roomY) * growth * widthScale
            return NebulaGeometry.Blob(offsetX: offsetX,
                                       offsetY: offsetY,
                                       halfWidth: halfWidth,
                                       halfHeight: halfWidth * aspect,
                                       angleDegrees: angle,
                                       opacity: opacity)
        }
        return NebulaGeometry(blobs: blobs)
    }

    // MARK: - Penanda kandidat (lencana tanda tanya)

    /// Geometri lencana tanda tanya untuk objek yang **belum pasti**.
    ///
    /// **Kenapa lencana ini ikut dihitung, padahal ia "cuma lencana".** Ia
    /// adalah satu-satunya penanda di layar yang mengatakan "engine ragu".
    /// Kalau ia terpotong tegak oleh `Canvas`, yang tersisa hanyalah gambar
    /// objeknya **tanpa** penanda — dan gambar tanpa penanda terbaca sebagai
    /// identitas yang pasti. Jadi cacat pada bentuk ini justru membatalkan
    /// alasan bentuk ini ada: pelanggaran PRD yang ingin dicegahnya
    /// ("JANGAN tampilkan visual yang mengklaim identitas saat engine ragu").
    ///
    /// Jebakannya sama dengan bentuk-bentuk sebelumnya, tapi lebih licin:
    /// lencana diletakkan di **sudut**, jadi dua sisinya dekat tepi frame
    /// sekaligus. Versi lama menaruh pusatnya di `0.846 · lebar` dengan
    /// radius `0.22 · lebar`, sehingga sisi kanan **dan** sisi atasnya keluar
    /// 0.132 R — 30% dari radius lencana hilang, di dua sisi sekaligus.
    /// Lingkarannya lalu tampil sebagai busur yang berhenti mendadak, bukan
    /// sebagai lingkaran.
    public struct CandidateMarker: Equatable, Sendable {
        /// Jarak pusat lencana dari tengah frame, sumbu x (satuan radius).
        public var centerX: Double
        /// Jarak pusat lencana dari tengah frame, sumbu y (satuan radius;
        /// negatif = ke atas, karena lencana berada di sudut kanan atas).
        public var centerY: Double
        /// Radius lencana (satuan radius).
        public var radius: Double
        /// Radius glif tanda tanya sebagai pecahan radius lencana.
        public var glyphFraction: Double
        /// Tebal garis glif sebagai pecahan radius lencana.
        ///
        /// **Kenapa ada di model, bukan di dua tempat gambar.** Sebelum ini
        /// tebal garis hidup sebagai literal `0.28` di view Swift dan dua
        /// kali di port Python, dan nilainya **salah**: 0.28 · radius lencana
        /// = 1.70 pt pada kartu jam 38 pt, sedangkan tinggi lengkung glif
        /// hanya 1.74 pt (`0.55 · 0.52 · radius`). Garis yang selebar
        /// lengkungnya sendiri mengisi rongga lengkung itu, jadi satu-satunya
        /// penanda "engine ragu" di layar tergambar sebagai **gumpalan
        /// pejal** — bukan tanda tanya. Terukur pada render 114 px: 5.10 px
        /// garis lawan 5.21 px lengkung.
        ///
        /// Tidak ada gerbang yang bisa menangkapnya: `check-visuals.py`
        /// mencatat sendiri bahwa mutasi VIEW `0.28 → 0.60` meninggalkan
        /// **313 pemeriksaan hijau**. Paritas port↔view hanya menuntut kedua
        /// bahasa sepakat pada angka yang sama — dan keduanya sepakat pada
        /// angka yang salah.
        public var strokeFraction: Double

        public init(centerX: Double, centerY: Double,
                    radius: Double, glyphFraction: Double,
                    strokeFraction: Double) {
            self.centerX = centerX
            self.centerY = centerY
            self.radius = radius
            self.glyphFraction = glyphFraction
            self.strokeFraction = strokeFraction
        }

        /// Radius glif tanda tanya (satuan radius).
        public var glyphRadius: Double { radius * glyphFraction }

        /// Tebal garis glif (satuan radius).
        public var glyphStroke: Double { radius * strokeFraction }

        /// Tinggi lengkung glif di atas garis tengahnya (satuan radius).
        ///
        /// `0.55 · glyphRadius` — lengkungnya turun dari `top` sejauh
        /// `0.55 · r` (lihat bentuk Bézier-nya di view & port).
        public var glyphHookHeight: Double { glyphRadius * 0.55 }

        /// Rasio tebal garis terhadap tinggi lengkung yang harus diisinya.
        ///
        /// Di atas ~0.5 rongga lengkung tertutup dan glif terbaca sebagai
        /// gumpalan. Nilainya dijaga uji, bukan komentar: lihat
        /// `testGlyphStrokeIsThinEnoughToLeaveTheHookOpen`.
        public var strokeToHookRatio: Double {
            guard glyphHookHeight > 0 else { return .infinity }
            return glyphStroke / glyphHookHeight
        }

        /// Berapa jauh lencana keluar dari frame, satuan radius. `<= 0` aman.
        ///
        /// `frameHalfExtent` ikut sebagai argumen, **bukan** dibaca dari
        /// `VisualFrame.halfExtent`: lencana dihitung untuk frame yang
        /// diberikan ke `candidateMarker`, jadi batasnya harus diukur
        /// terhadap frame itu juga. Mengunci ke 1.0 membuat uji untuk frame
        /// lain melaporkan "keluar" padahal tidak ada yang keluar.
        public func overflow(frameHalfExtent: Double = halfExtent) -> Double {
            max(abs(centerX) + radius, abs(centerY) + radius) - frameHalfExtent
        }
    }

    /// Lencana kandidat yang **pas di frame**, diletakkan di sudut kanan atas.
    ///
    /// Sama seperti `star`: radius dihitung dari **sudut yang diizinkan**,
    /// bukan dari lebar yang diinginkan lalu dibiarkan meluber. Karena
    /// `pusat + radius = corner` secara konstruktif, memperbesar lencana
    /// tidak bisa lagi mendorongnya keluar — ia akan menempel makin dekat ke
    /// tengah, bukan makin keluar dari tepi.
    ///
    /// - Parameters:
    ///   - frameHalfExtent: setengah lebar frame.
    ///   - cornerFraction: radius lencana sebagai pecahan jarak ke sudut
    ///     yang diizinkan.
    ///   - inset: jarak minimum dari tepi frame ke tepi lencana, sebagai
    ///     **pecahan** `frameHalfExtent` (bukan angka mutlak). Pecahan, bukan
    ///     tetap: lencana digambar pada kartu 38pt dan panel 132pt, dan jarak
    ///     yang tetap akan menempel pada bingkai di ukuran besar.
    ///   - glyphFraction: radius glif tanda tanya terhadap radius lencana.
    ///   - strokeFraction: tebal garis glif terhadap radius lencana.
    public static func candidateMarker(frameHalfExtent: Double = halfExtent,
                                       cornerFraction: Double = 0.34,
                                       inset: Double = 0.06,
                                       glyphFraction: Double = 0.52,
                                       strokeFraction: Double = 0.13) -> CandidateMarker {
        let corner = max(0, frameHalfExtent * (1 - min(1, max(0, inset))))
        let radius = corner * min(1, max(0, cornerFraction))
        // `d + radius == corner`, jadi lencana tidak mungkin keluar.
        let d = corner - radius
        return CandidateMarker(centerX: d, centerY: -d,
                               radius: radius, glyphFraction: glyphFraction,
                               strokeFraction: strokeFraction)
    }

    // MARK: Bulan — kawah

    /// Satu kawah Bulan: di mana ia berada dan seberapa besar.
    ///
    /// Koordinatnya dalam satuan radius cakram (1.0 = tepi cakram), sumbu X ke
    /// kanan dan sumbu Y ke **bawah** — sama seperti kanvas SwiftUI, dan sama
    /// seperti `DeepSkyCatalogue` yang sudah memakai konvensi ini.
    ///
    /// Kenapa sebuah model, bukan angka di dalam view: port Python
    /// (`Tools/render-visuals.py`) menggambar kawah yang sama untuk gerbang
    /// gambar repo ini. Dua bahasa yang tidak sepakat tentang **di mana** kawah
    /// berada menghasilkan gambar yang berbeda dari yang diukur gerbang — dan
    /// selisih itu tidak akan terlihat, karena kawah tetap "ada".
    public struct Crater: Equatable, Sendable {
        /// Jarak pusat dari pusat cakram, dalam satuan radius cakram.
        public var offsetX: Double
        public var offsetY: Double
        /// Radius kawah, dalam satuan radius cakram.
        public var radius: Double
        /// Seberapa gelap kawah terhadap maria. 1.0 = maria penuh.
        public var darkness: Double

        public init(offsetX: Double, offsetY: Double,
                    radius: Double, darkness: Double) {
            self.offsetX = offsetX
            self.offsetY = offsetY
            self.radius = radius
            self.darkness = darkness
        }
    }

    /// Kawah Bulan — tujuh bentuk, dipilih supaya **jaraknya** dari tepi cakram
    /// dan dari satu sama lain cukup besar untuk terbaca pada kartu jam 38 pt.
    ///
    /// **Kenapa kawah sama sekali.** Sebelum ini Bulan digambar sebagai
    /// piringan + pita terang berfase + maria; pada sabit ia terbaca sebagai
    /// benda dengan **dua** bentuk saja — terang dan gelap. Cacatnya halus dan
    /// justru terlihat di layar kecil: sabit tipis dan cembung sama-sama
    /// "lengkung terang di atas gelap", sehingga pengguna yang mengangkat jam
    /// untuk membedakan Bulan **muda** dari Bulan **tua** tidak punya apa pun
    /// untuk dipegang. Permukaan bertekstur memberi satu-satunya penanda
    /// identitas yang tidak bergantung arah Matahari.
    ///
    /// **Kenapa maria lebih dulu, kawah hanya di dalam maria.** Sebaran kawah
    /// yang merata akan membuat Bulan berbintik seperti batu, bukan seperti
    /// Bulan: yang terlihat dari Bumi nyaris seluruhnya maria gelap, dan kawah
    /// besar yang benar-benar menonjol hampir semuanya berada **di dalam**
    /// maria (Tycho, Copernicus, Plato berbatasan dengannya). Bentuknya karena
    /// itu dipilih agar sebagian besar kawah jatuh di area maria, dengan dua
    /// di antaranya di belahan yang selalu menghadap Bumi.
    ///
    /// **Yang TIDAK diklaim.** Posisinya **bukan** koordinat selenografis
    /// sungguhan; ia komposisi yang dipilih supaya terbaca pada 38 pt. Dan ia
    /// digambar tanpa arah rotasi Bulan, jadi pada sabit besar ia bisa jatuh di
    /// bagian yang tidak menyala. Itu terlihat seperti kekurangan dan memang
    /// kekurangan — tetapi **lebih baik** daripada memindahkannya mengikuti
    /// sudut sabit, karena memindahkan kawah mengikuti arah Matahari berarti
    /// mengklaim orientasi Bulan terhadap Bumi yang engine ini tidak punya.
    /// Ketidakakuratan yang diam tetap lebih jujur daripada akurasi palsu.
    public static let moonCraters: [Crater] = [
        // Tycho — yang paling terang dari Bumi (sistem sinarnya), di selatan.
        Crater(offsetX: -0.06, offsetY: 0.62, radius: 0.09, darkness: 0.95),
        // Copernicus — utara-tengah, di barat maria yang menghadap kita.
        Crater(offsetX: -0.30, offsetY: -0.05, radius: 0.13, darkness: 0.90),
        // Plato — ujung utara, lingkaran kecil yang gelap dan tegas.
        Crater(offsetX: 0.28, offsetY: -0.66, radius: 0.11, darkness: 0.88),
        // Kepler — di antara maria barat; kawah pertama yang lewat sabit.
        Crater(offsetX: -0.50, offsetY: 0.30, radius: 0.08, darkness: 0.92),
        // Grimaldi — ujung barat, yang gelapnya mengejutkan.
        Crater(offsetX: -0.78, offsetY: 0.44, radius: 0.10, darkness: 0.97),
        // Langrenus / kraton timur — sisi yang muncul jelas saat cembung.
        Crater(offsetX: 0.70, offsetY: 0.16, radius: 0.12, darkness: 0.86),
        // Clavius — cekungan besar di selatan, di tepi cakram.
        Crater(offsetX: -0.22, offsetY: 0.78, radius: 0.14, darkness: 0.84),
    ]

    /// Kawah dikecilkan ini kali di tepi cakram, supaya proyeksi bola dihitung
    /// alih-alih diabaikan.
    ///
    /// Cakram Bulan adalah proyeksi **bola**. Kawah yang sama besar di dekat
    /// tepi tampak lenyap, bukan karena digambar lebih kecil oleh seniman,
    /// melainkan karena geometri: kelihatannya nol pada batas cakram. Tanpa
    /// faktor ini, kawah Clavius (0.86 R dari pusat) akan tampak sebesar
    /// kawah di tengah — dan Bulan terbaca sebagai koin datar bertekstur,
    /// bukan bola.
    ///
    /// Bentuknya `sqrt(1 - r²)` adalah jejak proyeksi: satu satuan lingkup,
    /// dilihat dari arah z, menunjukkan tepi pada jari-jari `r` yang
    /// terkompresi sebesar komponen z-nya. Ia murni fungsi dari jarak pusat,
    /// jadi ia juga menjaga kawah yang jatuh **di luar** 1 R tidak pernah
    /// membesar secara keliru (faktornya nol di sana, bukan negatif).
    ///
    /// Batas yang diakui: ini **bukan** drop-off sudut pandang yang benar
    /// (kawah seharusnya juga menjadi elips), dan pada radius 1.0 hasilnya
    /// nol — jadi kawah di tepi persis tidak terlihat. Menutup keduanya berarti
    /// memproyeksikan setiap kawah melalui matriks bola; ia tidak dilakukan di
    /// sini karena hasilnya identik pada lingkaran yang dilihat lurus ke depan,
    /// dan satu-satunya perbedaan yang terlihat adalah bentuk elips yang tidak
    /// diklaim model ini miliki.
    public static func craterForeshortening(radiusFromCentre: Double) -> Double {
        let r = min(1, max(0, radiusFromCentre))
        return (1 - r * r).squareRoot()
    }

    // MARK: Matahari

    /// Corona Matahari menjangkau ini kali radius gambar (disk penuh = 1.0),
    /// diukur dari pusat.
    ///
    /// **Satu angka, satu sumber.** Baik view SwiftUI (`drawSun` melukis
    /// halo tambahan selebar ini) maupun port Python (`_draw_sun`) membaca
    /// konstanta ini, bukan menulis ulang angkanya — sama seperti
    /// `moonSphereGradientEndRadius`, supaya dua bahasa tidak pernah menyimpang
    /// diam-diam.
    ///
    /// **Kenapa 1.45, bukan lebih lebar.** Corona nyata membengkak beberapa
    /// juta kilometer, tapi di kartu jam 38 pt jangkauan >1.6 R sudah menabrak
    /// bingkai kartu (dan menutupi teks di sebelahnya), sementara <1.3 R hampir
    /// tidak terlihat sebagai glow. 1.45 memberi halo yang terbaca sebagai
    /// cahaya tanpa membanjiri kartu. Lihat `testSunCoronaReachIsBeyondTheDisk`.
    public static let sunCoronaReach: Double = 1.45

    /// Satu perhentian gradient piringan Matahari: warnanya, dan pada radius
    /// berapa ia berada.
    ///
    /// `radiusFraction` dalam satuan radius gambar (disk penuh = 1.0), jadi
    /// model ini tidak perlu tahu ukuran yang sedang digambar.
    public struct SunStop: Equatable, Sendable {
        public var radiusFraction: Double
        public var color: CelestialVisual.RGBComponents
        /// Kelegapan stop itu. **Wajib turun monoton** sepanjang larik; lihat
        /// `sunProfile()`.
        public var opacity: Double

        public init(radiusFraction: Double,
                    color: CelestialVisual.RGBComponents,
                    opacity: Double) {
            self.radiusFraction = radiusFraction
            self.color = color
            self.opacity = opacity
        }
    }

    /// Profil radial piringan Matahari — **satu** gradient, bukan dua piringan.
    ///
    /// **Cacat yang ditutup bentuk ini.** Versi sebelumnya menggambar dua
    /// piringan: fotosfer penuh selebar 0.72 R, lalu corona selebar 1.0 R yang
    /// dimulai di 0.6 R dengan kelegapan 0.42. Di tepi fotosfer karena itu
    /// kelegapan **melompat dari 1.0 ke 0.42 dalam satu piksel** — terukur
    /// 175 dari 255 langkah antar-piksel bersebelahan pada render 110 px,
    /// jauh di atas ambang persepsi. Yang terlihat bukan tepi Matahari,
    /// melainkan **dua benda bertumpuk**: piringan terang di atas halo gelap
    /// yang tepinya sendiri terlihat. Itu bukan soal rasa, karena Matahari
    /// tidak punya tepi seperti itu.
    ///
    /// Perbaikannya bukan "haluskan gradientnya", melainkan **satu gradient
    /// dengan kelegapan yang tidak pernah naik**: piringan penuh 1.0 R, dengan
    /// perhentian di 0.72 R yang nilainya (warna & kelegapan) sama dengan
    /// batas dalam, jadi tidak ada lompatan di sana sama sekali. Yang tersisa
    /// hanyalah penurunan berangsur dari 0.94 ke 0.05 antara 0.72 R dan 1.0 R.
    /// Terukur: langkah terbesar turun ke 14 dari 255 — 92% lebih halus.
    ///
    /// **Corona, bukan tepi keras.** Larik ini **hanya** piringan fotosfer
    /// (berhenti di 1.0 R, tapi dengan kelegapan lantai 0.05 — bukan 0.0 —
    /// supaya ia menyambung tanpa lompatan dengan halo corona yang dilukis
    /// terpisah oleh view lewat `sunCoronaReach`). Tanpa lantai itu, tepi
    /// piringan kembali menjadi tepi keras: gambarnya disk terang lalu latar
    /// mendadak, persis yang dilarang cacat di atas. Lihat
    /// `testSunProfileDiskAndCoronaJoinWithoutACliff`.
    ///
    /// **Kenapa di model, bukan di view.** Profilnya adalah angka, dan angka
    /// yang hanya hidup di `Canvas` tidak bisa diuji di Linux: satu-satunya
    /// cara mengetahuinya adalah melihat jam. Di sini `sunProfile()` diuji
    /// untuk monotonisitas dan kontinuitasnya, dan port Python menggambar
    /// larik yang sama supaya gerbang piksel mengukur gambar yang benar-benar
    /// tampil di jam.
    ///
    /// - Parameters:
    ///   - core: warna inti fotosfer (dipakai sampai 0.72 R).
    ///   - photosphere: warna tepi fotosfer (dipakai menuju tepi corona).
    public static func sunProfile(core: CelestialVisual.RGBComponents,
                                  photosphere: CelestialVisual.RGBComponents) -> [SunStop] {
        [
            SunStop(radiusFraction: 0.00, color: core, opacity: 1.00),
            SunStop(radiusFraction: 0.55, color: core, opacity: 1.00),
            // 0.72 R adalah **batas fotosfer**, dan pasangan 0.72/0.72 inilah
            // yang menghapus lompatan 1.0 -> 0.42 yang lama.
            SunStop(radiusFraction: 0.72, color: core, opacity: 0.95),
            SunStop(radiusFraction: 0.80, color: core, opacity: 0.66),
            SunStop(radiusFraction: 0.88, color: photosphere, opacity: 0.34),
            SunStop(radiusFraction: 0.94, color: photosphere, opacity: 0.13),
            // Tepi piringan memudar ke **lantai 0.05**, bukan 0.0: ia harus
            // menyambung dengan halo corona yang dimulai di sini. Kelegapan
            // tetap turun monoton, jadi gerbang monoton tetap hijau.
            SunStop(radiusFraction: 1.00, color: photosphere, opacity: 0.05),
        ]
    }
}

// MARK: - Geometri ciri planet

public extension CelestialVisual {

    /// Geometri kabut Venus: elips kabut + arah gradiennya.
    ///
    /// **Cacat yang ditutup geometri ini — dan yang membuatnya akhirnya
    /// ditemukan.** Di port Python, elips kabut digambar **0.14 R lebih ke
    /// bawah** daripada di view Swift: port memakai `cy + radius * 0.14`,
    /// sementara view menaruh sudut atas `CGRect` di `center.y − radius *
    /// 0.72`, yaitu **pusat** `center.y` dengan separuh tinggi 0.72 R. Jadi
    /// seluruh gambar Venus berfase yang diukur gerbang piksel adalah gambar
    /// yang **tidak pernah tampil di jam** — dan tidak ada satu pun
    /// pemeriksaan yang bisa melihatnya: `grep haze Tools/check-visuals.py`
    /// tidak menemukan apa pun. Kabut Venus satu-satunya ciri planet yang
    /// tidak dijaga di sana, jadi ia juga satu-satunya yang bisa bergeser
    /// tanpa suara.
    ///
    /// Angkanya pindah ke model supaya kelas cacat ini tertutup: satu rumus,
    /// dibaca kedua bahasa, dan `check-visuals.py` bisa menahan keduanya
    /// terhadapnya.
    ///
    /// **Kenapa `centerY` bernilai 0 dan bukan angka lain.** Pusat elipsnya
    /// memang pusat bola. Nilai 0.14 di port bukan pergeseran yang disengaja —
    /// ia kekeliruan penulisan saat geometrinya disalin dari `CGRect`
    /// (yang memuat **sudut**) ke `Canvas.ellipse` (yang memuat **pusat**).
    /// Kesalahan yang sama pernah terjadi pada Bintik Merah Besar, dan itu
    /// sebabnya `Spot` sudah menyebut satuannya sebagai pusat.
    struct HazeGeometry: Equatable, Sendable {
        /// Pusat elips, satuan radius bola (positif = ke bawah).
        public var centerY: Double
        /// Setengah lebar elips, satuan radius.
        public var halfWidth: Double
        /// Setengah tinggi elips, satuan radius.
        public var halfHeight: Double

        public init(centerY: Double, halfWidth: Double, halfHeight: Double) {
            self.centerY = centerY
            self.halfWidth = halfWidth
            self.halfHeight = halfHeight
        }

        /// Titik terjauh elips dari **pusatnya**, satuan radius.
        ///
        /// Dipakai uji supaya kabut tidak menjulur keluar piringan: kabut di
        /// luar bola akan tergambar di atas latar, dan itu klaim yang salah
        /// tentang di mana ia berada.
        ///
        /// **Kenapa sumbu mayor, bukan akar jumlah kuadrat.** Titik terjauh
        /// sebuah elips dari pusatnya adalah puncak **sumbu mayor**-nya, bukan
        /// sudut kotak pembatasnya — `max(halfWidth, halfHeight)`. Bentuk akar
        /// jumlah kuadrat akan menghitung sudut kotak, yang justru **di luar**
        /// elipsnya, jadi ia menuduh kabut menjulur keluar padahal tidak.
        /// Untuk kabut Venus keduanya kebetulan sama (lebar < tinggi, jadi
        /// sumbu mayornya tegak), dan kebetulan yang tidak dijelaskan adalah
        /// cara paling mudah melahirkan cacat berikutnya.
        public var farthestCorner: Double {
            max(halfWidth, halfHeight)
        }
    }

    /// Geometri kabut Venus. Lihat `HazeGeometry` untuk kenapa ia di model.
    ///
    /// Bentuknya **lonjong tegak** (0.72 R tinggi separuh, 0.55 R lebar
    /// separuh) dan seluruhnya **di dalam** piringan: tinggi penuhnya 1.44 R
    /// terhadap piringan 2 R. Yang membatasinya tetap klip ke bagian yang
    /// menyala, supaya kabutnya tidak pernah menonjol keluar sabit dan
    /// membuatnya tampak lebih lebar daripada fraksi yang dihitung engine.
    static func venusHaze(centerY: Double = 0.0,
                                 halfWidth: Double = 0.55,
                                 halfHeight: Double = 0.72) -> HazeGeometry {
        HazeGeometry(centerY: centerY, halfWidth: halfWidth, halfHeight: halfHeight)
    }

    /// Pita samar Uranus — satu sabuk horizontal, dalam satuan radius.
    ///
    /// **Kenapa Uranus tidak diberi pita seperti Jupiter.** Uranus memang
    /// punya sabuk, tetapi di teleskop kecil ia tampak sebagai **piringan
    /// nyaris polos**: inilah alasan ia dijuluki "planet tanpa ciri" sebelum
    /// Voyager 2. Menggambar tujuh pita kontras seperti Jupiter akan
    /// menyatakan tingkat rincian yang tidak pernah terlihat pada ukuran
    /// yang digambar aplikasi ini — klaim yang terlalu percaya diri, padahal
    /// yang membedakan Uranus dari Neptunus justru **kepolosannya** plus
    /// warnanya.
    ///
    /// Angkanya hidup di model, bukan di view, karena port Python dan
    /// pemeriksa piksel harus membaca angka yang sama: satu rumus di dua
    /// tempat adalah dua rumus yang akan berbeda.
    static func uranusBand(centerY: Double = 0.0,
                           halfWidth: Double = 0.62,
                           halfHeight: Double = 0.30) -> HazeGeometry {
        HazeGeometry(centerY: centerY, halfWidth: halfWidth, halfHeight: halfHeight)
    }

    /// Opasitas pita Uranus.
    ///
    /// Sangat rendah (0.18) **bukan** pilihan rasa: pada opasitas ini pita
    /// masih menambah tekstur yang bisa dilihat, tetapi piringannya tidak
    /// lagi terbaca sebagai "berpita". Batas yang dipakai gerbang adalah
    /// "Uranus lebih polos daripada Jupiter", jadi nilai yang terlalu tinggi
    /// akan membuatnya gagal.
    static let uranusBandOpacity: Double = 0.18

    /// Titik gelap Neptunus (Great Dark Spot), dalam satuan radius.
    ///
    /// **Kenapa satu titik, bukan pita.** Neptunus menampakkan pita awan yang
    /// jauh lebih redup daripada Jupiter atau Saturnus; yang benar-benar
    /// membedakannya dalam pengamatan amatir adalah **bintik gelap** besar di
    /// belahan selatannya. Menggambar pita saja akan membuat Neptunus tampak
    /// sama dengan Uranus yang berwarna biru — dan dua planet yang tampak
    /// identik berarti ciri pengenalnya berhenti menjadi ciri pengenal.
    ///
    /// Sengaja **di bawah pusat** (`centerY` positif = ke bawah), karena
    /// bintik gelap Neptunus yang tercatat ada di belahan selatan. Arahnya
    /// tidak bisa dibaca dari teks mana pun di layar, jadi ia hanya bisa
    /// dijaga di model yang bisa diuji di Linux.
    static func neptuneSpot(centerY: Double = 0.22,
                            halfWidth: Double = 0.34,
                            halfHeight: Double = 0.22) -> HazeGeometry {
        HazeGeometry(centerY: centerY, halfWidth: halfWidth, halfHeight: halfHeight)
    }

    /// Pusat horizontal titik gelap Neptunus, satuan radius.
    ///
    /// Terpisah dari `neptuneSpot` karena `HazeGeometry` hanya memuat sumbu
    /// tegak; bintik ini juga digeser menyamping, dan menyimpan `centerX`
    /// sebagai angka terpisah di view akan kembali menciptakan dua sumber.
    static let neptuneSpotCenterX: Double = 0.18

    /// Opasitas titik gelap Neptunus.
    static let neptuneSpotOpacity: Double = 0.55

    /// Kutub es planet, dalam satuan radius dan relatif terhadap pusat bola.
    ///
    /// **Kenapa bentuknya elips beririsan, bukan persegi panjang.** Versi
    /// pertama menggambarkan satu kutub sebagai **elips datar** yang tepi
    /// atasnya ditempelkan di tepi bola (`topY = -1`), dengan lebar tetap
    /// 0.55 R dan tinggi 0.52 R. Yang tergambar bukan kutub di permukaan
    /// bola, melainkan **elips yang mengambang di dalam piringan**: karena
    /// lebar tetapnya lebih sempit dari bola pada baris mana pun di sekitar
    /// kutub, selalu ada **rim merah** di atas dan di sisi kiri-kanan
    /// kutubnya. Diukur pada render 400 px: pada baris terlebar kutub,
    /// tepi bola 0.675 R sementara tepi kutub 0.550 R — selisih 0.125 R,
    /// 25 px, terlihat mata telanjang sebagai "stiker yang ditempel agak ke
    /// dalam". Kutub adalah **ciri pengenal Mars**, jadi ini bukan soal rasa:
    /// gambar yang salah adalah **klaim yang salah**, persis yang PRD larang.
    ///
    /// **Cacat kedua, yang ditutup belakangan: tepi dalam yang mendadak.**
    /// Setelah lebar dan irisan diperbaiki, tepi **luar** kutub mengikuti
    /// lengkung bola — tetapi tepi **dalamnya** (batas elips yang menghadap
    /// ekuator) tetap merupakan batas geometris sempurna, karena isinya
    /// warna rata. Diukur pada kolom tengah render 400 px, di
    /// `centerY + halfHeight` = 0.48 R:
    ///
    ///     y=103   luminans 223.5   (240, 220, 210)   <- kutub
    ///     y=104   luminans 112.0   (198,  92,  57)   <- Mars
    ///
    /// Lompatan **111.5 luminans dalam satu piksel**, sementara bola Mars di
    /// bawahnya hanya bergerak 0.9 luminans per piksel di baris yang sama
    /// (diukur pada `planet-mars-bare`). Embun beku di Mars menipis ke arah
    /// ekuator, jadi batasnya kabur; elips bertepi tajam terbaca sebagai
    /// **stiker putih yang ditempel** — kata yang persis dipakai pengukuran
    /// mata, dan persis kelas cacat yang sudah dibayar repo ini untuk kawah
    /// Merkurius dan Bintik Merah Besar. **Kutub selatan lebih parah lagi:
    /// 139.8 luminans** (y=295 → 296), diukur pada render yang sama.
    ///
    /// Perbaikannya **gradien**, bukan warna rata: opasitas penuh di pusat
    /// kutub, meluruh ke nol di tepi dalamnya. Tiga angka di bawah ini hidup
    /// di model, bukan di view, karena view dan port Python harus membacanya
    /// dari tempat yang sama — satu angka di dua tempat adalah dua angka yang
    /// akan berbeda.
    ///
    /// **Angka tanpa pemanggil bukan perbaikan.** Ketiga konstanta ini sempat
    /// ditulis dan diuji di Linux sementara **tidak satu pun** penggambar
    /// memakainya: view masih `capColor.opacity(0.85)` dan port masih
    /// `accent_fn(…, POLAR_CAP_OPACITY)`, keduanya warna **rata**. Diukur
    /// sesudah konstanta itu ada: lompatan tepi dalamnya **tetap 111.4
    /// luminans** — persis seperti sebelum konstanta itu ada. Uji Linux hijau
    /// di atas gambar yang belum berubah adalah bentuk paling sunyi dari kelas
    /// cacat yang repo ini kejar. Sekarang view (`polarCapFade(cap:)`) dan
    /// port (`polar_cap_fade`) sama-sama membacanya; diukur sesudahnya,
    /// lompatan terbesar di kolom tengah **4.0 luminans** (0.35) dan **3.2**
    /// (0.45) — turun dari 139.8.
    static let polarCapOpacity: Double = 0.85

    /// Titik awal luruhnya tepi dalam kutub, sebagai pecahan kedalaman kutub
    /// (`depthFraction`), diukur dari **tepi dalam** ke arah pusat kutub.
    ///
    /// 0.45 berarti: 45% kedalaman kutub yang terdekat dengan ekuator adalah
    /// pita luruhan, dan 55% sisanya (ke arah kutub) tetap pekat. Sisanya
    /// tetap penuh bukan sekadar pilihan rasa: baris **terlebar** kutub ada di
    /// tengah kedalamannya (50%), jadi pita luruhan yang lebih lebar dari 50%
    /// membuat baris terlebar itu ikut redup — dan
    /// `check_mars_caps_touch_the_limb` mengenali kutub lewat ambang warna
    /// tetap, sehingga kutub yang benar-benar menyentuh tepi bola berhenti
    /// terbaca menyentuh. Diukur pada render 400 px (kutub utara, baris pusat
    /// `centerY`): 0.45 → bola 0.680 R lawan kutub 0.670 R, rim 2 px
    /// (1.0% R), **hijau**; 0.55 → 0.390 R lawan 0.680 R, rim 58 px
    /// (29.0% R), **merah**; 0.60 → kutub 0.000 R, **merah**. Batas 0.5 yang
    /// dijaga uji Linux karena itu tepat di antara keduanya.
    ///
    /// Fisisnya juga begitu: embun beku yang tebal ada di atas kutub, dan
    /// yang menipis hanya batasnya.
    static let polarCapFadeStart: Double = 0.45

    /// Opasitas kutub di **tepi dalamnya** (menghadap ekuator).
    ///
    /// Nol, bukan angka kecil: luruhan yang berhenti di 0.05 tetap
    /// meninggalkan langkah sepersepuluh dari 111.5 luminans (≈11), dan
    /// langkah itu masih terukur. Yang membuat tepinya benar-benar luruh
    /// adalah mencapai nol di tepi, lalu dibiarkan bertemu bola yang memang
    /// sudah ada di sana.
    static let polarCapEdgeOpacity: Double = 0.0

    /// Opasitas kutub pada satu ketinggian, satuan radius dari pusat bola.
    ///
    /// **Satu rumus, dibaca tiga bahasa** (view SwiftUI, port Python, uji
    /// Linux). Yang dihitung: luruhan **linear** dari
    /// `polarCapEdgeOpacity` di tepi dalam kutub ke `polarCapOpacity` sejauh
    /// `polarCapFadeStart` dari kedalaman kutub, lalu **tetap penuh** di
    /// sisanya. `height` di luar rentang kutub dijepit, jadi pemanggil tidak
    /// perlu tahu batasnya.
    ///
    /// **Kenapa di model, bukan di view.** Ini bagian kutub yang paling
    /// mudah salah tanpa terlihat: luruhan yang arahnya terbalik menaruh tepi
    /// kaburnya di **kutub** dan tepi tajamnya di ekuator — persis cacat yang
    /// baru ditutup, hanya berpindah ujung. Arahnya tidak bisa dibaca dari
    /// teks mana pun di layar, jadi ia hanya bisa dijaga di tempat yang bisa
    /// diuji di Linux.
    ///
    /// **Kenapa geometrinya sekaligus, bukan hanya opasitas di satu titik.**
    /// Penggambar butuh **dua titik** untuk sebuah gradient, dan kalau ia
    /// menghitung titik keduanya sendiri dari `polarCapFadeStart`, aturan
    /// luruhannya hidup dua kali lagi — di view dan di port. Yang dikirim
    /// karena itu batas luruhannya (`innerEdgeY`, `span`, `towardPole`) plus
    /// kedua opasitasnya; tidak ada satu angka pun yang tersisa untuk
    /// ditulis ulang di sisi penggambar.
    struct PolarCapFade: Equatable, Sendable {
        /// Ketinggian tepi dalam kutub (menghadap ekuator), satuan radius.
        public var innerEdgeY: Double
        /// Arah ke kutub: −1 belahan utara, +1 belahan selatan.
        public var towardPole: Double
        /// Jarak dari tepi dalam ke arah kutub sampai opasitasnya penuh.
        public var span: Double
        /// Opasitas **di tepi dalam**.
        public var edgeOpacity: Double
        /// Opasitas setelah luruhan selesai (ke arah kutub).
        public var fullOpacity: Double

        public init(innerEdgeY: Double, towardPole: Double, span: Double,
                    edgeOpacity: Double, fullOpacity: Double) {
            self.innerEdgeY = innerEdgeY
            self.towardPole = towardPole
            self.span = span
            self.edgeOpacity = edgeOpacity
            self.fullOpacity = fullOpacity
        }

        /// Ketinggian tempat opasitasnya mencapai `fullOpacity`.
        public var fullY: Double { innerEdgeY + towardPole * span }

        /// Opasitas pada satu ketinggian. Di luar rentang luruhan dijepit.
        public func opacity(atHeight height: Double) -> Double {
            guard abs(span) > 1e-12 else { return fullOpacity }
            let t = min(1.0, max(0.0, (height - innerEdgeY) / (fullY - innerEdgeY)))
            return edgeOpacity + (fullOpacity - edgeOpacity) * t
        }
    }

    /// Geometri luruhan tepi dalam satu kutub.
    ///
    /// Arah ke kutub dibaca dari tanda `centerY`; satu tanda yang terbalik
    /// menaruh pita luruhannya di ujung yang salah.
    static func polarCapFade(cap: PolarCaps.Cap) -> PolarCapFade {
        let towardPole: Double = cap.centerY < 0 ? -1 : 1
        let innerEdge = cap.centerY - towardPole * cap.halfHeight
        return PolarCapFade(innerEdgeY: innerEdge,
                            towardPole: towardPole,
                            span: cap.halfHeight * 2 * polarCapFadeStart,
                            edgeOpacity: polarCapEdgeOpacity,
                            fullOpacity: polarCapOpacity)
    }

    /// Kutub es planet, dalam satuan radius dan relatif terhadap pusat bola.
    ///
    /// Perbaikannya dua bagian, dan keduanya perlu:
    ///
    ///   1. **Lebar diturunkan dari tepi bola**, bukan ditulis sebagai angka.
    ///      Satu-satunya lebar yang membuat kutub benar-benar menyentuh tepi
    ///      di baris `centerY` adalah setengah-lebar bola pada ketinggian itu
    ///      — `√(1 − y²)`, rumus proyeksi yang sama dengan `jupiterBands`.
    ///      Menulisnya sebagai konstanta berarti angka itu hanya benar untuk
    ///      satu ukuran/posisi, dan salah tanpa suara saat posisinya bergeser.
    ///   2. **Irisan dengan piringan.** Elips dengan lebar di atas tetap
    ///      menjulur keluar bola di dekat kutub (pada y = −0.9 R, elipsnya
    ///      0.530 R sementara bola 0.436 R), jadi ia harus dipotong oleh
    ///      piringan — kalau tidak, kutubnya justru **keluar** dari planet.
    ///      Itu sebabnya `CelestialVisualView` menggambar lewat klip piringan,
    ///      dan kenapa uji di Linux memeriksa dua arah sekaligus: menyentuh
    ///      tepi **dan** tidak melewatinya.
    ///
    /// Satu tipe untuk **kedua** kutub, bukan satu angka per kutub: kutub
    /// selatan dihitung sebagai cermin kutub utara, bukan dari rumus kedua.
    struct PolarCaps: Equatable, Sendable {
        /// Sisi utara: `centerY` negatif (ingat: di `Canvas` y bertambah ke
        /// bawah).
        public var north: Cap
        /// Sisi selatan: cermin utara terhadap ekuator.
        public var south: Cap
        /// Satu kutub: elips batasnya, sebelum diiris dengan piringan.
        public struct Cap: Equatable, Sendable {
            /// Pusat elips, sumbu y, relatif terhadap pusat bola.
            public var centerY: Double
            /// Separuh tinggi elips, satuan radius.
            public var halfHeight: Double
            /// Separuh lebar elips, satuan radius. **Selalu** setengah-lebar
            /// bola pada `centerY`; lihat `polarCaps(pinchY:depthFraction:)`.
            public var halfWidth: Double

            public init(centerY: Double, halfHeight: Double, halfWidth: Double) {
                self.centerY = centerY
                self.halfHeight = halfHeight
                self.halfWidth = halfWidth
            }
        }

        public init(north: Cap, south: Cap) {
            self.north = north
            self.south = south
        }
    }

    /// Geometri kutub yang **benar secara konstruktif**: lebarnya diturunkan
    /// dari tepi bola, dan kutub selatan adalah cermin kutub utara.
    ///
    /// **Kenapa ini di model, bukan di view.** Kutub adalah ciri pengenal
    /// Mars, dan PRD melarang visual yang mengklaim identitas — jadi bentuk
    /// yang salah adalah **klaim yang salah**, bukan sekadar rasa. Tapi
    /// bentuk yang salah mustahil dibaca dari teks mana pun di layar, jadi
    /// ia hanya bisa dijaga di tempat yang bisa diuji di Linux.
    ///
    /// - Parameters:
    ///   - pinchY: ketinggian tempat kutub menyentuh tepi bola, sekaligus
    ///     pusat elipsnya. Negatif = belahan utara.
    ///   - depthFraction: separuh tinggi elips, satuan radius — seberapa
    ///     dalam kutub menjangkau ke arah ekuator.
    ///
    /// Hasil dalam **satuan radius** (bukan poin): view yang sudah punya
    /// radius cukup mengalikannya sendiri, jadi model ini tidak perlu tahu
    /// satuan apa yang sedang digambar.
    static func polarCaps(pinchY: Double = -0.74,
                          depthFraction: Double = 0.26) -> PolarCaps {
        // Setengah-lebar bola pada ketinggian itu — rumus proyeksi, bukan
        // pilihan. Inilah yang membuat kutub **menyentuh** tepi, bukan
        // mengambang di dalamnya.
        let halfWidth = (1 - pinchY * pinchY).squareRoot()
        func cap(_ centerY: Double) -> PolarCaps.Cap {
            PolarCaps.Cap(centerY: centerY,
                          halfHeight: depthFraction,
                          halfWidth: halfWidth)
        }
        // Selatan = cermin utara: satu tanda, bukan rumus kedua.
        return PolarCaps(north: cap(pinchY), south: cap(-pinchY))
    }

    /// Bintik Merah Besar Jupiter: elipsnya di mana, selebar apa.
    ///
    /// **Kenapa geometrinya pindah ke model.** Sampai siklus ini posisinya
    /// hidup **dua kali dengan dua tafsir yang berbeda**, dan tidak ada satu
    /// pun gerbang yang bisa melihatnya:
    ///
    /// ```swift
    /// // Apps/Shared/CelestialVisualView.swift — CGRect, jadi ini SUDUT
    /// let spot = CGRect(x: center.x - radius * 0.36,
    ///                   y: center.y + radius * 0.18,
    ///                   width: radius * 0.52, height: radius * 0.26)
    /// ```
    /// ```python
    /// # Tools/render-visuals.py — diperlakukan sebagai PUSAT
    /// SPOT_RECT = (-0.36, 0.18, 0.52, 0.26)
    /// canvas.ellipse(cx + dx * radius, cy + dy * radius, w * radius / 2, h * radius / 2, …)
    /// ```
    ///
    /// Jadi bintik yang **benar-benar terlihat di jam** berpusat di
    /// (−0.10, +0.31) R, sementara gambar yang diukur seluruh gerbang visual
    /// berpusat di (−0.36, +0.18) R — selisih 0.26 R di sumbu x, yaitu
    /// **setengah lebar bintiknya sendiri**. Semua pemeriksaan tetap hijau
    /// karena keduanya menggambar elips yang sama besarnya; yang berbeda
    /// hanya di mana. Ini persis pola yang sudah tiga kali tercatat di
    /// `STATUS.md`: gerbang yang mengukur sebagian dari klaimnya — di sini
    /// mengukur **bentuk** bintik, bukan **letaknya**.
    ///
    /// Dan letaknya bukan detail kosmetik: Bintik Merah Besar ada di belahan
    /// **selatan** Jupiter. Satu tanda yang terbalik memindahkannya ke utara
    /// tanpa satu pun teks di layar yang bisa membuktikannya.
    ///
    /// Angka di sini adalah **pusat**, dalam satuan radius bola, relatif
    /// terhadap pusat bola (y positif = ke bawah, seperti `Canvas`). Satu
    /// konvensi, satu tempat — view dan port Python sama-sama membacanya dari
    /// sini, jadi tidak ada lagi dua tafsir untuk satu larik angka.
    ///
    /// Ukurannya sengaja jauh lebih besar dari kenyataan (Bintik Merah Besar
    /// sungguhan hanya ≈0.11 R): di kartu jam 38 pt, ukuran yang benar adalah
    /// 4 pt dan hilang sama sekali. Yang dikorbankan ukuran, bukan posisi.
    struct Spot: Equatable, Sendable {
        /// Pusat elips, sumbu x, satuan radius bola.
        public var centerX: Double
        /// Pusat elips, sumbu y, satuan radius bola (positif = ke bawah).
        public var centerY: Double
        /// Lebar penuh elips.
        public var width: Double
        /// Tinggi penuh elips.
        public var height: Double

        public init(centerX: Double, centerY: Double, width: Double, height: Double) {
            self.centerX = centerX
            self.centerY = centerY
            self.width = width
            self.height = height
        }

        /// Jarak pusat bintik dari pusat bola, satuan radius.
        public var distanceFromCenter: Double {
            (centerX * centerX + centerY * centerY).squareRoot()
        }

        /// Titik terjauh elips dari pusat bola.
        ///
        /// Dipakai uji untuk memastikan bintik tidak menjulur keluar piringan:
        /// bintik yang keluar bola akan tergambar di atas latar, bukan di atas
        /// Jupiter — dan itu klaim yang salah tentang di mana ia berada.
        public var farthestCorner: Double {
            let dx = abs(centerX) + width / 2
            let dy = abs(centerY) + height / 2
            return (dx * dx + dy * dy).squareRoot()
        }
    }

    /// Geometri Bintik Merah Besar. Lihat `Spot` untuk kenapa ia di model.
    ///
    /// `centerY` positif: belahan selatan. Bukan pilihan rasa — Bintik Merah
    /// Besar memang di selatan, dan tanda itu yang paling mudah terbalik tanpa
    /// terlihat.
    static func jupiterSpot(centerX: Double = -0.10,
                                   centerY: Double = 0.31,
                                   width: Double = 0.52,
                                   height: Double = 0.26) -> Spot {
        Spot(centerX: centerX, centerY: centerY, width: width, height: height)
    }

    // MARK: - Pita Jupiter

    /// Satu pita Jupiter: di ketinggian berapa, selebar apa.
    ///
    /// Dalam satuan radius bola, relatif terhadap pusatnya. `centerY` negatif
    /// = belahan utara (ingat: di `Canvas` y bertambah ke bawah).
    struct Band: Equatable, Sendable {
        /// Ketinggian pusat pita, −1…+1 (satuan radius bola).
        public var centerY: Double
        /// Separuh lebar pita di ketinggian itu (satuan radius bola).
        public var halfWidth: Double
        /// Separuh tinggi pita.
        public var halfHeight: Double

        public init(centerY: Double, halfWidth: Double, halfHeight: Double) {
            self.centerY = centerY
            self.halfWidth = halfWidth
            self.halfHeight = halfHeight
        }
    }

    /// Geometri pita Jupiter — **dihitung dari bola, bukan dari kosinus**.
    ///
    /// **Kenapa ini pindah dari view ke model.** View dulu memakai
    /// `cos((t - 0.5) * .pi * 0.92)` sebagai separuh lebar pita, dan
    /// komentarnya sendiri menjanjikan bentuk yang lain: *"pita mengikuti
    /// keliling bola: makin dekat kutub, makin pendek"*. Bola yang
    /// diproyeksikan berjari-jari `sqrt(1 − y²)`; kosinus dengan busur 0.92π
    /// bukan aproksimasi yang baik untuknya — ia kebetulan sama di ekuator
    /// (keduanya 1.0) dan menyimpang makin jauh ke kutub.
    ///
    /// Diukur pada kartu jam (radius 19 pt):
    ///
    /// | Pita | y | Tepi pita | Tepi bola | Selisih |
    /// |---|---|---|---|---|
    /// | teratas | −0.857R | 0.326R | 0.515R | **3.6 pt (19% R)** |
    /// | kedua | −0.571R | 0.678R | 0.821R | 2.7 pt |
    /// | ekuator | 0.000R | 1.000R | 1.000R | 0 pt |
    ///
    /// Jadi pita terluar berhenti jauh di dalam piringan, dan yang terlihat
    /// adalah bola berwarna polos di kedua kutub dengan pita mengambang di
    /// tengahnya. Cacat ini tidak bisa dibaca dari layar mana pun — "bola
    /// dengan pita" tetap terbaca sebagai Jupiter — dan tidak ada teks yang
    /// bisa dibaca pengguna untuk memeriksanya.
    ///
    /// **Kenapa `sqrt` dan bukan konstanta yang dikalibrasi.** Angka yang
    /// dipilih agar "kelihatan benar" hanya benar pada satu ukuran frame;
    /// pita yang sama digambar di kartu jam 38 pt dan di panel iPhone 132 pt.
    /// Bentuk bola adalah satu-satunya nilai yang benar di keduanya, dan ia
    /// bisa diuji di Linux (lihat `CelestialVisualTests`).
    ///
    /// - Parameters:
    ///   - count: jumlah pita, dari kutub ke kutub. Ganjil supaya ada pita
    ///     yang tepat di ekuator — itu yang membuat susunannya simetris.
    ///   - heightFraction: tinggi tiap pita (2 × separuh tinggi), satuan
    ///     radius bola. `nil` = pita **bersambung**: tingginya diambil dari
    ///     jarak antar pusat pita (`2/count`), sehingga tidak ada bola polos
    ///     yang bocor di antaranya. Lihat catatan di bawah.
    ///
    /// **Kenapa bawaannya `nil` (bersambung), bukan angka 0.11.** Sampai
    /// siklus ini bawaannya `0.11` dengan tujuh pita: jarak antar pusat
    /// 2/7 = 0.2857 R, tinggi pita 0.11 R, jadi **0.1757 R** di antaranya
    /// adalah bola polos. Ditimbang lebar tali busur, pita hanya menutupi
    /// **39.1%** piringan — 60.9% adalah bola beige. Yang tergambar karena
    /// itu bukan Jupiter ber-pita melainkan bola beige bergaris tipis, dan
    /// penilaian manusia atas render 256 px-nya: "washed-out beige".
    ///
    /// Seluruh gerbang piksel yang ada tetap hijau pada keadaan itu, karena
    /// masing-masing mengukur **satu pita** (ada, sampai limb, mengikuti
    /// busur, terpisah) dan tidak ada yang bertanya apakah ada bola di
    /// antaranya. Karena itu invariannya sekarang diuji di Linux
    /// (`testJupiterBandsCoverTheDisc`), bukan diserahkan ke mata.
    ///
    /// Angka `heightFraction` eksplisit tetap diterima supaya pemanggil bisa
    /// meminta pita bergaris (mis. untuk eksperimen), tetapi bawaan produk
    /// adalah pita bersambung — itulah yang membuat piringan terbaca sebagai
    /// gas giant.
    static func jupiterBands(count: Int = 7,
                             heightFraction: Double? = nil) -> [Band] {
        guard count > 0 else { return [] }
        // Jarak antar pusat pita. Pita bersambung = tingginya persis jarak
        // itu, jadi tepi bawah satu pita bertemu tepi atas pita berikutnya.
        let spacing = 2.0 / Double(count)
        let halfHeight = (heightFraction ?? spacing) / 2
        return (0..<count).map { index in
            let t = (Double(index) + 0.5) / Double(count)
            // −1 … +1, dari kutub utara ke selatan.
            let y = -1 + 2 * t
            // Tepi bola pada ketinggian itu — rumus proyeksi, bukan pilihan.
            let halfWidth = (1 - y * y).squareRoot()
            return Band(centerY: y, halfWidth: halfWidth, halfHeight: halfHeight)
        }
    }

    /// Pita bola Saturnus — geometri, bukan warna.
    ///
    /// **Cacat yang ditutup fungsi ini — diukur, bukan dinilai dengan mata.**
    /// Bola Saturnus digambar di dalam `drawRings`/`_draw_rings`, dan sampai
    /// siklus ini ia digambar sebagai **bola polos** tanpa satu pun pita:
    /// `STATUS.md` mencatatnya sebagai "Saturnus masih bola polos tanpa pita".
    /// Seluruh gerbang pita yang ada mengukur `planet-jupiter-confirmed`, jadi
    /// Saturnus tidak pernah masuk jangkauan satu pun dari mereka. Terukur pada
    /// port Python, render 200 px, ss=2, kolom x = +0.20 R pada paruh atas bola
    /// (dari tepi 0.53 R ke ekuator): **0 titik balik**, terang 141.3 → 159.4 —
    /// monoton, yaitu gradien bola saja. Jupiter pada kolom yang sama memberi
    /// titik balik.
    ///
    /// **Kenapa Saturnus tidak memakai `jupiterBands()`.** Tujuh pita Jupiter
    /// dengan tinggi `2/7` R dan tiga nada kontrasnya adalah **Jupiter**: zona
    /// dan sabuknya tajam, dan itu ciri pengenalnya. Saturnus berpita jauh
    /// lebih samar dan lebih lebar — memakai geometri Jupiter berarti menukar
    /// satu identitas dengan identitas planet lain, persis yang PRD larang
    /// ("JANGAN salah identifikasi demi magic"). Di sini pitanya lebih sedikit,
    /// lebih lebar, dan nadanya hanya dua: cukup untuk terbaca berpita di kartu
    /// jam, tidak cukup untuk berpura-pura seberpita Jupiter.
    ///
    /// Jumlah pita (`5`) dipilih dari pengukuran, bukan dari atmosfer: dengan
    /// tiga pita, tiap pita setinggi 0.67 R dan yang terbaca hanya dua bidang
    /// warna besar, bukan pita. Dengan tujuh, tiap pita setinggi 0.29 R dan di
    /// bola 0.53 R milik Saturnus (kartu jam 38 pt → ~20 pt) pitanya lebih
    /// tipis dari satu piksel. Lima memberi 0.40 R per pita.
    ///
    /// **Yang TIDAK diklaim.** Ini bukan peta atmosfer Saturnus: jumlah dan
    /// posisi pita di sini adalah pilihan gambar. Yang dijamin adalah pitanya
    /// **ada**, **menutupi bola**, dan **mengikuti busur limb** — semuanya
    /// diukur uji, bukan diklaim prosa.
    static func saturnBands(count: Int = 5) -> [Band] {
        guard count > 0 else { return [] }
        // Sama seperti Jupiter: pita bersambung, jadi tidak ada bola polos yang
        // bocor di antara pita.
        let spacing = 2.0 / Double(count)
        let halfHeight = spacing / 2
        return (0..<count).map { index in
            let t = (Double(index) + 0.5) / Double(count)
            let y = -1 + 2 * t
            // Tepi bola pada ketinggian itu — rumus proyeksi, bukan pilihan.
            let halfWidth = (1 - y * y).squareRoot()
            return Band(centerY: y, halfWidth: halfWidth, halfHeight: halfHeight)
        }
    }

    /// Warna pita Saturnus pada ketinggian `centerY` — dua nada berganti.
    ///
    /// **Kenapa dua nada, bukan tiga.** Jupiter punya tiga (kutub redup, sabuk
    /// gelap, zona terang) karena itu yang membuatnya terbaca sebagai Jupiter.
    /// Saturnus tidak: pita yang terlalu kontras membuat bolanya terbaca
    /// sebagai Jupiter berwarna pucat. Dua nada berganti memberi pita yang
    /// **terpisah** (syarat yang sama dengan `check_jupiter_bands_read_as_separate_stripes`)
    /// tanpa mengklaim struktur yang tidak dimilikinya.
    ///
    /// Nada terang mengembalikan `saturnBand` yang lebih gelap dari bola, dan
    /// nada gelap mengembalikan versi lebih gelapnya lagi — keduanya **di
    /// bawah** terang bola, jadi pitanya tidak pernah lebih terang dari
    /// permukaan yang diaturnya.
    static func saturnBandColour(for centerY: Double) -> RGBComponents {
        let bands = saturnBands()
        guard let index = bands.firstIndex(where: { abs($0.centerY - centerY) < 1e-9 }) else {
            // Di luar pita yang dikenal: nada terang, bukan `nil`. Pemanggil
            // yang menggambar selalu punya pita; warna yang hilang akan
            // menggambar pita transparan tanpa ada yang tahu.
            return accents.saturnBand
        }
        return index % 2 == 0 ? accents.saturnBand : accents.saturnBandDeep
    }

    /// Setengah-lebar bola pada ketinggian `height` (satuan radius, 0 = ekuator),
    /// dengan **tanda** yang berarti sisi: negatif = belahan utara layar.
    ///
    /// **Cacat yang ditutup fungsi ini — diukur, bukan diperkirakan.** Pita
    /// digambar sebagai **elips**: lebarnya konstan sepanjang tinggi pita.
    /// Yang benar di bola bukan begitu. Lingkaran lintang pada lintang φ
    /// memproyeksi ke ruas garis `y = sin φ`, `|x| ≤ cos φ = sqrt(1 − y²)`,
    /// jadi tepi pita pada tiap ketinggian mengikuti **busur limb**, bukan
    /// dinding vertikal. Diukur sebagai IoU terhadap bentuk yang benar pada
    /// render 200 px: tiap elips hanya menutupi **79%** pita yang benar, dan
    /// yang hilang **20,5–22,1%** — dua sudut di dekat limb, di mana bola
    /// tetap polos sementara pita sudah berhenti.
    ///
    /// Itu bukan sekadar angka kecil: bentuknya persis yang membuat piringan
    /// terbaca sebagai **stiker rata**, dan pada pita bawah — yang terlebar —
    /// ia juga menggantung di luar tepi bola yang sudah menyempit.
    ///
    /// **Kenapa `height`, bukan `offset` dari pusat pita.** Versi pertama
    /// fungsi ini menerima jarak dari pusat pita plus setengah-lebar pusatnya,
    /// lalu memulihkan ketinggiannya dengan `sqrt(1 − hw²)`. Akar itu
    /// **kehilangan tandanya**: pita di `y = −0,857` dan pita di `y = +0,857`
    /// punya setengah-lebar yang sama, jadi tepi atas pita utara dihitung
    /// dengan lebar tepi **bawah**-nya. Pada pita 0 itu 0,597 alih-alih 0,410
    /// — pita utara jadi lebih lebar di atas, persis kebalikan dari yang
    /// seharusnya, dan piringannya terlihat miring. Tanda itu memang ada di
    /// model: `Band.centerY` **adalah** ketinggian bola yang bertanda, jadi
    /// pemanggil cukup meneruskannya.
    static func bandHalfWidthAt(height: Double) -> Double {
        min(1, max(0, 1 - height * height)).squareRoot()
    }

    /// Satu titik tepi pita: ketinggiannya di bola dan separuh lebarnya.
    struct BandEdge: Equatable, Sendable {
        /// Ketinggian di bola, −1…+1 (satuan radius). Bertanda, seperti
        /// `Band.centerY`: negatif = belahan utara layar.
        public var height: Double
        /// Setengah-lebar pita pada ketinggian itu.
        public var halfWidth: Double

        public init(height: Double, halfWidth: Double) {
            self.height = height
            self.halfWidth = halfWidth
        }
    }

    /// Berapa ruas yang dipakai menaksir busur tepi satu pita.
    ///
    /// **Kenapa tidak 1 (dua titik).** Dua titik per tepi **adalah** trapesium
    /// — bentuk yang membuat pita memotong ke dalam busur. Tepi pita harus
    /// berupa **poligon** yang mengikuti lingkaran, dan jumlah ruasnya
    /// menentukan seberapa dekat ia ke busur.
    ///
    /// **Kenapa 8, dan angka yang salah di sini sebelumnya.** Versi pertama
    /// docstring ini menulis "panahnya ≈ 1.6·10⁻⁴ R", dihitung dari `Δy²/8`
    /// dengan `Δy = 0.0357`. Angka itu **salah 56×**, dan salahnya berarah
    /// menjemukan: `Δy²/8` adalah panah tali busur terhadap **busur
    /// parameternya sendiri**, sedangkan tepi pita dibaca sebagai
    /// **separuh-lebar di ketinggian tetap** — jarak horizontal dari pusat,
    /// bukan jarak tegak-lurus ke busur. Di dekat kutub kedua ukuran itu
    /// berbeda jauh: `x(y) = √(1−y²)` punya turunan tak hingga di `y → 1`.
    ///
    /// **Dan angka `Δy²/8` itu sendiri hanya benar bila sampelnya seragam
    /// dalam busur.** Dengan sampel seragam dalam `y` — cara fungsi ini dulu
    /// bekerja — galat menumpuk justru di ruas terakhir pita kutub: diukur
    /// tegak-lurus, **8.97·10⁻³ R**, bukan 1.6·10⁻⁴ R. Menyampel seragam
    /// dalam **sudut** (`asin(y)`, lihat `jupiterBandEdges`) membuat tiap ruas
    /// membentang busur sama panjang dan panahnya jatuh ke **1.17·10⁻³ R**
    /// dengan jumlah ruas yang sama. Di kartu jam (radius 19 pt) itu 0.022 pt
    /// — jauh di bawah satu piksel, dan kali ini karena panahnya memang kecil,
    /// bukan karena radiusnya kecil.
    static let bandEdgeSteps = 8

    /// Tepi satu pita sebagai **poligon yang mengikuti busur limb**.
    ///
    /// **Cacat yang ditutup fungsi ini — diukur, bukan diperkirakan.**
    /// View sudah memakai `bandHalfWidthAt` untuk tepi atas dan bawahnya,
    /// tetapi pita digambar sebagai **empat simpul**. Empat simpul tidak bisa
    /// mengikuti lingkaran: ruas garis lurus antara tepi atas dan tepi bawah
    /// memotong ke dalam busur, dan potongannya paling dalam di tengah pita.
    /// Pada pita kutub — yang kini setinggi jarak antar pusatnya, 0.2857 R —
    /// tepi kirinya di baris tengah jatuh di **0.350 R** sementara bola di
    /// ketinggian itu **0.515 R**. Selisih 0.165 R itu persis yang dilaporkan
    /// CI: *"jangkauan 0.355 R, bola 0.519 R di baris 14, selisih 16.4% R"*,
    /// dan pita 6 kembarannya 16.7% R.
    ///
    /// **Kenapa di model, bukan di view.** Tepi ini dipakai **dua** bahasa
    /// (view Swift dan port Python yang mengukur gambar), jadi kalau bentuk
    /// yang benar hanya hidup di Swift, renderer Python tetap boleh
    /// menyimpang dan gerbangnya akan mengukur gambar yang tidak ada di
    /// layar. Satu rumus, dua bahasa, dan `check_port_matches_swift_constants`
    /// menahan keduanya agar sama.
    ///
    /// **Batas yang dinyatakan.** Ini taksiran busur dengan 8 ruas, bukan
    /// busur eksak. Diukur **tegak-lurus ke busur** (jarak sesungguhnya dari
    /// ruas garis ke lingkaran), panahnya **1.17·10⁻³ R** dengan 8 ruas —
    /// 0.022 pt di kartu jam radius 19 pt, 0.12 px di render gerbang 100 px.
    /// Angka `1.6·10⁻⁴ R` yang dulu tertulis di sini salah 56×; ia dihitung
    /// dari `Δy²/8` dengan sampel seragam dalam `y`, padahal justru
    /// pensampelan itulah yang membuat galat menumpuk di kutub (lihat
    /// `bandEdgeSteps`).
    ///
    /// Fungsi ini tidak mengembalikan titik di luar bola: `halfWidth` dihitung
    /// dari `bandHalfWidthAt`, jadi tepi pita selalu **di dalam atau tepat di**
    /// busur, tidak pernah menggantung di luarnya.
    static func jupiterBandEdges(centerY: Double, halfHeight: Double,
                                 steps: Int = bandEdgeSteps) -> [BandEdge] {
        let count = max(1, steps)
        // Sampel seragam dalam SUDUT (`asin(y)`), bukan dalam `y`: dengan `y`
        // seragam, tiap ruas membentang busur yang panjangnya berbeda-beda dan
        // galat menumpuk di ruas terakhir pita kutub. Seragam dalam sudut
        // membuat tiap ruas membentang busur sama panjang, sehingga panahnya
        // terbagi rata — 7.6× lebih kecil tanpa menambah satu simpul pun.
        // `asin` butuh |y| ≤ 1, dan pita kutub menyentuh tepat 1.0, jadi
        // pembulatan floating point bisa melewatinya sedikit.
        let start = asin(max(-1.0, min(1.0, centerY - halfHeight)))
        let end = asin(max(-1.0, min(1.0, centerY + halfHeight)))
        return (0...count).map { index in
            let theta = start + (end - start) * Double(index) / Double(count)
            let height = sin(theta)
            return BandEdge(height: height, halfWidth: bandHalfWidthAt(height: height))
        }
    }

    /// Lebar pita yang dilembutkan di tepinya, sebagai fraksi tinggi pita.
    ///
    /// **Cacat yang ditutup angka ini.** Pita Jupiter digambar sebagai poligon
    /// warna **rata** yang bersambung, jadi batas antar pita adalah langkah
    /// satu piksel. Diukur pada port Python, render 200 px, ss=2, di dalam
    /// piringan: lompatan terang terbesar **132.32/255** sementara median
    /// langkah antar piksel bersebelahan **0.93/255** — 142×. Pada ukuran yang
    /// benar-benar dikirim ke jam (76 px) lompatannya masih **83.63/255**
    /// terhadap median 2.00. Di mata itu terbaca sebagai pita isolasi yang
    /// ditempel, bukan atmosfer sebuah planet.
    ///
    /// Sesudah dilembutkan pada 0.18: **32.44/255** (200 px) dan
    /// **40.81/255** (76 px). Nadanya masih terpisah — pusat pita tidak
    /// berubah sama sekali — tetapi tidak ada lagi dinding satu piksel.
    ///
    /// **Kenapa angka di atas persis angka gerbang.** Dua gerbang di
    /// `Tools/check-visuals.py` mengukur ulang keduanya tiap kali suite jalan
    /// (`check_band_feather_softens_the_edge`, dan
    /// `check_band_feather_docstring_quotes_measured_values` yang membaca
    /// docstring ini lalu membandingkannya dengan hasil ukur). Versi pertama
    /// docstring ini mengutip 117.4 / 23.3 / 76.4 / 37.2 — angka yang **tidak
    /// pernah dihasilkan pengukuran mana pun**; yang cocok hanya mediannya,
    /// jadi definisinya benar dan puncaknya saja yang salah tulis. Gerbang
    /// paritas itu ada supaya kekeliruan seperti itu tidak bisa bertahan
    /// sebagai prosa yang terdengar terukur.
    ///
    /// **Kenapa hanya warna yang dilembutkan, bukan geometri.** Geometri pita
    /// sudah dijaga gerbang lain (`jupiterBandEdges`, keterpisahan pita, dan
    /// lengkung bola). Yang tidak dijaga siapa pun adalah **ketajaman tepi**
    /// warna, dan justru itu yang merusak kesan realistis. Melembutkan warna
    /// di dalam bentuk yang sudah benar tidak bisa menggeser satu pun dari
    /// angka yang sudah diukur.
    ///
    /// **Yang TIDAK diklaim.** Ini bukan model atmosfer: tidak ada hamburan,
    /// tidak ada tinggi skala, dan tidak ada ketergantungan panjang gelombang.
    /// Ia hanya menghapus langkah warna yang tidak mungkin muncul di citra
    /// teleskop mana pun.
    static let bandFeatherFraction: Double = 0.18

    /// Seberapa jauh piksel di dalam satu pita bercampur ke nada tetangganya.
    ///
    /// `t` adalah posisi tegak di dalam pita: 0 di tepi atas, 1 di tepi bawah.
    /// Hasilnya 0 di tengah pita dan **0.5 tepat di tepi**, sehingga dua pita
    /// bersebelahan bertemu di titik tengah nada keduanya — bukan di salah
    /// satunya. Itu yang membuat langkahnya hilang: keduanya menyumbang sama
    /// besar di bidang batas.
    ///
    /// Mengembalikan 0…0.5. Nilai 0.5 (bukan 1.0) disengaja: campuran penuh
    /// akan membuat tiap pita kehilangan nadanya sendiri di tepi dan pitanya
    /// berhenti terpisah.
    static func bandFeatherWeight(atFraction t: Double,
                                 width: Double = bandFeatherFraction) -> Double {
        guard width > 0 else { return 0 }
        let clamped = max(0.0, min(1.0, t))
        if clamped < width {
            return 0.5 * (1.0 - clamped / width)
        }
        if clamped > 1.0 - width {
            return 0.5 * (1.0 - (1.0 - clamped) / width)
        }
        return 0
    }

    /// Kurva pelembutan sebagai **titik-titik gradien**: `(lokasi, berat)`.
    ///
    /// **Kenapa kurvanya dipindah ke sini, bukan tinggal di pemanggil.**
    /// `bandFeatherWeight` di atas adalah fungsi; view SwiftUI dan port Python
    /// sama-sama perlu menggambarnya sebagai gradien, dan keduanya dulu
    /// menyusun titiknya sendiri. Hasilnya terukur: port memakai **dataran**
    /// (berat 0.5 di tepi, nol pada 18%, nol sampai tepi seberang), sementara
    /// view memakai **segitiga** (berat 0.5 di tepi, nol di tengah) — dan
    /// `check_port_matches_swift_constants` tetap hijau karena yang ia
    /// bandingkan adalah konstanta `0.18`, bukan bentuk kurvanya. Dua bahasa,
    /// satu nama, dua gambar.
    ///
    /// Empat titik ini mereproduksi `bandFeatherWeight` **persis**, bukan
    /// mendekatinya: interpolasi linear antara `(0, 0.5)` dan `(w, 0)` adalah
    /// fungsi linear yang sama dengan cabang pertama, dataran `(w, 0)`–`(1-w, 0)`
    /// adalah cabang kedua, dan cabang ketiga adalah cermin cabang pertama.
    /// `BandFeatherTests` menuntutnya pada 201 sampel, bukan pada empat titik
    /// yang sama — membandingkan titik yang sama dengan dirinya sendiri tidak
    /// membuktikan apa pun tentang bagian di antaranya.
    ///
    /// **Kenapa pasangan (lokasi, berat), bukan `Gradient`.** Tipe itu milik
    /// SwiftUI; model ini bebas Apple API supaya bisa diuji di Linux. Yang
    /// dipindahkan adalah **angkanya**, dan pemanggil memetakannya ke tipe
    /// gambarnya sendiri.
    ///
    /// **Yang TIDAK diklaim.** Ini bukan model atmosfer. Ia hanya menghapus
    /// langkah warna satu piksel di batas pita.
    static func bandFeatherStops(width: Double = bandFeatherFraction) -> [(location: Double, weight: Double)] {
        // Lebar ≥ 0.5 berarti dua tepi bertemu atau melewatinya: kurvanya
        // berhenti berupa dataran dan gradiennya jadi tak monoton. Yang
        // dikembalikan adalah kurva tanpa pelembutan, bukan kurva yang
        // dilipat — melipat akan menghasilkan warna negatif di satu sisi,
        // yaitu garis gelap, cacat yang lebih buruk daripada yang diperbaiki.
        guard width > 0, width < 0.5 else {
            return [(location: 0.0, weight: 0.0), (location: 1.0, weight: 0.0)]
        }
        return [(location: 0.0, weight: bandFeatherWeight(atFraction: 0.0, width: width)),
                (location: width, weight: 0.0),
                (location: 1.0 - width, weight: 0.0),
                (location: 1.0, weight: bandFeatherWeight(atFraction: 1.0, width: width))]
    }

    /// Berat pelembutan pada posisi `t`, dibaca dari `bandFeatherStops`.
    ///
    /// Ini pembaca gradien yang sama dengan yang dipakai view, jadi uji yang
    /// membandingkannya dengan `bandFeatherWeight` menguji **bentuk yang
    /// benar-benar digambar**, bukan fungsi yang mungkin tidak dipanggil
    /// siapa pun.
    static func bandFeatherWeightFromStops(atFraction t: Double,
                                           width: Double = bandFeatherFraction) -> Double {
        let stops = bandFeatherStops(width: width)
        guard let first = stops.first, let last = stops.last else { return 0 }
        let clamped = max(first.location, min(last.location, t))
        for index in 1..<stops.count {
            let lower = stops[index - 1]
            let upper = stops[index]
            guard clamped <= upper.location else { continue }
            let span = upper.location - lower.location
            guard span > 0 else { return upper.weight }
            let k = (clamped - lower.location) / span
            return lower.weight + (upper.weight - lower.weight) * k
        }
        return last.weight
    }

    /// Nada satu pita Jupiter.
    ///
    /// **Kenapa ini ada di model, bukan di view.** Peta indeks→warna hidup
    /// **dua kali** sampai siklus ini: `switch index % 3` di
    /// `CelestialVisualView.drawBands` dan larik yang sama di
    /// `render-visuals.py`. Dua salinan itu tidak bisa berbeda hari ini, tetapi
    /// tidak ada satu pun gerbang yang membandingkannya — kelas cacat yang
    /// sudah berulang di repo ini. Yang lebih penting: **polanya** sendiri
    /// tidak bisa diuji di view, dan polanya yang menentukan apakah pitanya
    /// terbaca.
    ///
    /// Tiga nada, bukan satu per pita: yang perlu dibedakan adalah **peran**
    /// pita (kutub redup, sabuk gelap, zona terang), dan peran itu yang punya
    /// arti astronomi. Warnanya tetap datang dari `accents`, jadi mode malam
    /// tidak perlu tahu apa-apa tentang nada.
    enum JupiterBandTone: CaseIterable, Equatable, Sendable {
        /// Sabuk gelap — paling gelap, `jupiterBandRust`.
        case belt
        /// Zona terang — `jupiterBandCream`.
        case zone
        /// Daerah kutub, lebih redup dari zona tetapi lebih terang dari sabuk
        /// — `jupiterBandTan`.
        case pole
    }

    /// Pola nada dari kutub utara ke selatan, satu entri per pita.
    ///
    /// **Kenapa `pole, zone, belt, zone, belt, zone, pole` dan bukan pola
    /// berulang tiga.** Yang dijaga bukan kerapian, melainkan dua fakta:
    ///
    /// 1. **Zona ekuator Jupiter terang, dan diapit sabuk gelap** (NEB/SEB).
    ///    Pola `cream, rust` berulang juga memberi ekuator terang, tetapi
    ///    kutubnya menjadi **terang** — dan itu kebalikan dari Jupiter.
    /// 2. **Dua pita bersebelahan harus berbeda nada.** Pola lama
    ///    (tan→rust→cream berulang) terukur memberi dL 0.020 dan dS 0.012
    ///    antar tetangga pada render 200 px: pitanya ada, tetapi tidak
    ///    terpisah, dan yang terbaca adalah bola beige.
    ///
    /// Pola ini terukur memberi **dL 0.140** pada render yang sama — tujuh
    /// kali lebih terpisah dari 0.020 — sambil mempertahankan lengkung
    /// (gerbang `check_banded_disc_keeps_its_curvature`, ambang 70%) dan
    /// pemakaian ketiga aksen.
    ///
    /// **Yang TIDAK diklaim.** Ini bukan peta atmosfer Jupiter yang
    /// sebenarnya: tujuh pita seragam tidak bisa mewakili zona/sabuk yang
    /// jumlahnya puluhan dan lebarnya tidak sama. Yang dijaga adalah urutan
    /// peran (kutub redup, sabuk gelap mengapit zona terang) pada jumlah pita
    /// yang dipakai gambar ini.
    static let jupiterBandTones: [JupiterBandTone] = [
        .pole, .zone, .belt, .zone, .belt, .zone, .pole,
    ]

    /// Nada pita pada ketinggian `centerY` (satuan radius bola, −1…+1).
    ///
    /// Dipetakan lewat **indeks pita**, bukan lewat ketinggiannya: pita
    /// dihitung dari `jupiterBands(count:)`, jadi kalau jumlahnya berubah,
    /// polanya yang harus berubah bersama — dan itu terlihat di satu tempat.
    /// Ketinggian di sini hanya dipakai untuk menemukan indeksnya, dengan
    /// toleransi 1e-9 supaya pita yang dihitung ulang tetap cocok.
    ///
    /// Di luar ketujuh pita (mis. `count` lain) jawabannya **`belt`**, bukan
    /// `nil`: pemanggil yang menggambar selalu punya pita, dan nada yang
    /// hilang akan membuat pitanya transparan tanpa ada yang tahu.
    static func jupiterBandTone(at centerY: Double) -> JupiterBandTone {
        let bands = jupiterBands()
        if let index = bands.firstIndex(where: { abs($0.centerY - centerY) < 1e-9 }) {
            return jupiterBandTones[index % jupiterBandTones.count]
        }
        return .belt
    }

    /// Warna siang untuk satu nada pita.
    ///
    /// Satu-satunya jalan dari nada ke aksen. View dan port sama-sama
    /// memakainya lewat nama aksen yang sama, jadi menukar `pole` dan `belt`
    /// hanya bisa dilakukan di sini — dan `testEachJupiterBandToneMapsToItsOwnAccent`
    /// memerahkannya.
    static func jupiterBandColour(for tone: JupiterBandTone) -> RGBComponents {
        switch tone {
        case .belt: return accents.jupiterBandRust
        case .zone: return accents.jupiterBandCream
        case .pole: return accents.jupiterBandTan
        }
    }

    /// Opasitas pita Jupiter saat digambar di atas bola, 0…1.
    ///
    /// **Kenapa angkanya naik dari 0.55, dan kenapa bukan 1.0.** Pita digambar
    /// sebagai warna **rata** di atas gradien bola, jadi opasitas rendah
    /// membiarkan gradien bola menembusnya — dan gradien itulah yang
    /// menyeragamkan pita. Diukur pada render 200 px dengan pola nada yang
    /// sekarang dipakai:
    ///
    ///     opasitas   dL minimum antar pita   lengkung vs bola polos
    ///       0.55            0.053                    92%
    ///       0.75            0.111                    84%
    ///       0.85            0.140                    72%
    ///       1.00            0.148                    75%
    ///
    /// 0.85 dipilih karena **kedua** sisinya punya jarak: pitanya terpisah
    /// 7× lebih jelas dari keadaan sebelumnya (0.020), sementara lengkungnya
    /// masih 72% — di atas ambang gerbang `check_banded_disc_keeps_its_curvature`
    /// (70%) dengan jarak yang cukup. Angka lengkung itu diukur pada opasitas
    /// ini **dan** kekuatan pemulihan 0.75; menurunkan kekuatan pemulihan ke
    /// 0.6 (yang cukup saat opasitas 0.55) menjatuhkan lengkung ke 57% dan
    /// gerbangnya merah, jadi kedua angka saling mengunci.
    ///
    /// **Yang TIDAK diklaim.** Angka ini diukur pada port Python (200 px,
    /// ss=2). Renderer Apple memakai Gaussian dan supersampling yang berbeda;
    /// yang dijamin adalah **model**-nya satu, bukan pikselnya sama.
    static let jupiterBandOpacity: Double = 0.85

    /// Opasitas pita Saturnus saat digambar di atas bola, 0…1.
    ///
    /// **Kenapa lebih rendah dari Jupiter (0.85).** Pita Saturnus di alam nyata
    /// jauh lebih samar: kontrasnya sekitar 1:1.1, sementara Jupiter ~1:1.6.
    /// Memakai 0.85 membuat bolanya terbaca sebagai **Jupiter berwarna pucat** —
    /// salah identifikasi, dan itu tepat yang PRD larang.
    ///
    /// **Kenapa tidak lebih rendah lagi.** Pita yang terlalu samar tidak
    /// menambah satu pun titik balik pada kolom ukur, jadi gerbangnya tidak
    /// bisa membedakan "pita samar" dari "tidak ada pita" — dan `STATUS.md`
    /// kembali ke "bola polos". 0.55 adalah angka terendah yang masih
    /// menghasilkan titik balik terukur di render 200 px, ss=2.
    ///
    /// **Yang TIDAK diklaim.** Angka ini diukur pada port Python; renderer
    /// Apple memakai Gaussian dan supersampling berbeda. Yang dijamin adalah
    /// **model**-nya satu, bukan pikselnya sama.
    static let saturnBandOpacity: Double = 0.55

    /// Kekuatan **naungan bola di dalam pita**, 0…1 — dipotong ke bentuk tiap
    /// pita, bukan ditumpuk ke seluruh cakram.
    ///
    /// **Cacat yang ditutup angka ini — diukur, bukan diperkirakan.** Pita
    /// Jupiter digambar sebagai elips warna **rata** di atas bola yang sudah
    /// dinaungi gradien. Karena tiap pita menutupi 55% piksel di bawahnya, ia
    /// **menghapus** lengkung bola yang ada di situ. Diukur pada baris ekuator
    /// render 200 px: selisih terang pusat-ke-limb turun dari **50.6%** (bola
    /// polos) menjadi **20.8%** (bola ber-pita), dan pada 0.96 R pitanya
    /// justru **+62.6** lebih terang daripada bola yang sama tanpa pita.
    /// Hasilnya bukan bola berpita, melainkan **stiker rata** yang ditempel di
    /// piringan — persis kata yang dipakai pengukuran mata pada render 400 px.
    ///
    /// **Kenapa dipotong ke pita, bukan ke seluruh cakram.** Sempat ada versi
    /// yang menggambar ulang gradien bola di atas **seluruh** piringan. Ia
    /// memulihkan lengkung, tetapi mencuci warna pitanya: setiap pita harus
    /// mengalah pada gradien bola di seluruh lebarnya. Diukur pada port yang
    /// sama (200 px, ss=2, ambang lengkung 70% dan keterpisahan pita 0.05):
    ///
    ///     opasitas 0.85, tutup ulang 0.75 : lengkung 71.9%, residual 0.002
    ///     opasitas 0.85, tutup ulang 0.60 : lengkung 57.4%, residual 0.093
    ///     opasitas 0.55, tutup ulang 0.60 : lengkung 71.3%, residual 0.007
    ///     naungan **per pita** (sekarang)   : lengkung 99.6%, residual 0.095
    ///
    /// Tiga baris pertama berlawanan arah: tiap nilai lolos satu ambang dan
    /// gagal yang lain, karena kontras pita tinggal di tepi piringan sementara
    /// lengkung justru diukur sebagai gelapnya tepi itu. Satu konstanta
    /// opasitas **tidak bisa** memenuhi keduanya. Memotong naungan ke bentuk
    /// tiap pita memutus persaingan itu: lengkung jadi intrinsik (tidak ada
    /// yang terhapus, jadi tidak ada yang perlu dipulihkan) dan hue pita tetap
    /// utuh karena gradien hanya menutupi satu pita pada satu waktu.
    ///
    /// Nilainya **sebagian**, bukan 1: pada 1.0 satu pita tertutup gradien
    /// bola sama sekali dan pitanya berhenti terbaca, pada 0 lengkungnya
    /// kembali rata. Dijaga `testBandLimbShadingIsPartial`
    /// di Linux dan gerbang piksel `check_banded_disc_keeps_its_curvature`.
    static let bandLimbShadingStrength: Double = 0.75

    /// Kekuatan **pemulihan peredupan limb** di atas Bintik Merah Besar, 0…1.
    ///
    /// **Kelas cacat yang sama dengan pita di atas, dan gerbangnya punya lubang
    /// yang sama.** Bintik digambar sebagai elips warna **rata** di atas bola
    /// yang sudah dinaungi gradien, jadi ia menghapus lengkung bola di
    /// dalamnya. Yang menjaganya, `check_banded_disc_keeps_its_curvature`,
    /// mengukur **baris ekuator** saja — sementara bintiknya duduk di
    /// `centerY = +0.31`, jauh dari baris itu. Jadi cacat ini tidak pernah
    /// tersentuh pemeriksaan mana pun.
    ///
    /// Diukur pada baris pusat bintik (y = +0.31 R, render 200 px, ss=4):
    ///
    ///     bola di bawah bintik (tanpa ciri) : 0.580 → 0.532   lengkung **+8.4%**
    ///     baris yang sama, dengan bintik    : 0.449 → 0.532   lengkung **−18.4%**
    ///
    /// Tandanya **terbalik**. Itu bukan cacat kosmetik: bintik yang rata
    /// membuat barisnya lebih terang di sisi yang seharusnya gelap, jadi yang
    /// terbaca bukan bola berbintik melainkan **stiker** yang ditempel — persis
    /// kata yang dipakai pengukuran mata pada render 400 px, dan persis cacat
    /// yang sudah diperbaiki untuk pitanya.
    ///
    /// Perbaikannya **sama**: pakai kembali gradien bola yang sama (pusat di
    /// `sphereLightOffset`, warna `palette.light` → `palette.dark`), dipotong
    /// ke elips bintiknya. Karena gradiennya sama, yang dipulihkan adalah
    /// lengkung yang tadi terhapus, dan arah cahayanya tidak bisa berbeda
    /// pendapat dengan `drawSphere`.
    ///
    /// Nilainya **sebagian**, bukan 1: pada 0 lengkungnya rata kembali
    /// (cacatnya utuh), pada 1 bintiknya tertutup bola. Nilai 0.6 memulihkan
    /// 84% lengkung sambil menyisakan warna bintik yang masih terbaca
    /// (≥ 20 piksel merah di kotak bintiknya). Dijaga
    /// `testJupiterSpotLimbShadingIsPartial` di Linux dan gerbang piksel
    /// `check_jupiter_spot_keeps_its_curvature`.
    static let jupiterSpotLimbShadingStrength: Double = 0.6

    // MARK: - Peredupan limb piringan Bulan

    /// Kekuatan peredupan limb piringan Bulan, 0…1.
    ///
    /// **Cacat yang ditutup angka ini — diukur dari piksel, bukan diperkirakan.**
    /// Pita terang Bulan digambar sebagai isian **warna rata**: satu warna
    /// `moonLit` penuh dari pusat sampai limb. Planet tidak begitu —
    /// `drawSphere` memberi mereka gradien bola. Diukur pada 200 px, ss=2,
    /// kekuatan 0.40:
    ///
    ///     kasus               metrik                 rata (0)   dipakai (0.40)
    ///     Bulan purnama       lengkung ekuator        +0.0%        +33.5%
    ///     Fase tak diketahui  lengkung ekuator        +0.0%        +33.4%
    ///     Bulan sabit         sebaran pita             0.0          24.1
    ///     Mars (pembanding)   lengkung ekuator       +54.8%        +54.8%
    ///
    /// Artinya pita terang Bulan **rata sempurna** sementara planet di
    /// sebelahnya melengkung 55%. Yang terlihat bukan bola yang disinari dari
    /// satu sisi, melainkan **stiker rata** — kata yang sama dipakai
    /// pengukuran mata atas render yang sama, dan kata yang sama sudah dipakai
    /// untuk cacat pita Jupiter di atas.
    ///
    /// **Kenapa sabit butuh metrik lain.** Baris ekuator hanya menyampel pita
    /// terang kalau pita itu **melintasi** ekuator. `moon-crescent-jakarta`
    /// punya sisi terang ke **bawah**, jadi seluruh baris ekuatornya jatuh di
    /// piringan gelap dan metrik lengkung mengembalikan **+0.0%** untuk gambar
    /// yang benar — angka yang sempat dipakai sebagai bukti di sini dan
    /// membuat gerbangnya merah pada kode yang benar. Untuk kasus itu yang
    /// diukur adalah sebaran luminans (p95 − p5) piksel yang terklasifikasi
    /// menyala: pita rata → 0.0, pita yang dinaungi bola → 24.1.
    ///
    /// **Kenapa Bulan, padahal ia yang paling terang.** Justru karena ia yang
    /// paling sering muncul: fase adalah satu-satunya informasi **bentuk** yang
    /// dimiliki Bulan, dan piringan rata membuat fase itu terbaca sebagai
    /// guntingan kertas, bukan sebagai bola.
    ///
    /// **Batas atasnya diukur, bukan dipilih.** Pengklasifikasi yang dipakai
    /// gerbang fase (`classify_centroid`) memutuskan "menyala" versus "gelap"
    /// pada jarak-warna RGB, jadi pada gradien yang terlalu dalam piksel limb
    /// jatuh ke sisi **gelap** dan luas pita yang terukur menyusut — bukan
    /// karena gambarnya salah, melainkan karena alat ukurnya berganti
    /// jawaban. Disapu pada 200 px, ss=2, toleransi gerbang 0.10:
    ///
    ///     kekuatan   luas pita merah   lengkung purnama
    ///     0.45            0/9              +37.6%
    ///     0.50            0/9              +41.6%
    ///     0.60            7/9              +50.2%   <- gerbang merah
    ///
    /// 0.60 **merah**: `f=0.18` terukur 0.053, `f=0.35` terukur 0.198,
    /// `f=0.50` terukur 0.335 — ketiganya melewati toleransi 0.10. Dijaga
    /// `testMoonLimbShadingIsPartial` di Linux (batas atasnya) dan gerbang
    /// piksel `check_moon_disc_keeps_its_curvature` (lengkungnya benar-benar
    /// sampai ke gambar).
    ///
    /// **Piringan gelap Bulan sengaja tetap rata**, dan itu bukan kelalaian.
    /// Percobaan pertama memberi gradien yang sama ke piringan gelap, dan
    /// hasilnya menyingkap dua hal: (1) earthshine dilukis sebagai cakram
    /// warna rata di atasnya, jadi gradiennya terhapus justru di fase tempat
    /// sisi gelap paling terlihat — terukur, `moon-new` tetap **+0.0%** di
    /// setiap kekuatan; dan (2) memperdalamnya mematikan gerbang
    /// `check_earthshine` pada kekuatan **0.20** (4/5 lulus). Sisi gelap Bulan
    /// memang disinari sumber yang **lebar** (Bumi, bukan Matahari), jadi
    /// piringan rata di sana bukan gambar yang salah — sedangkan pita
    /// terangnya disinari sumber titik, dan di situlah lengkungnya berarti.
    static let moonLimbShadingStrength: Double = 0.40

    /// Radius akhir gradien bola Bulan, dalam satuan radius piringan.
    ///
    /// **Berbeda dari bola planet (1.35), dan angkanya diukur.** Piringan
    /// Bulan digambar di dalam `drawLayer` yang **diputar** sebesar sudut sisi
    /// terang (`terminatorRotationRadians`). Gradien yang berpusat di pusat
    /// piringan tidak punya arah, jadi putaran itu tidak menggesernya — tetapi
    /// ia menggeser **sisi terangnya**: pada sabit dengan sisi terang ke
    /// bawah, seluruh pita yang menyala jatuh di dekat tepi piringan, tempat
    /// gradien 1.35 sudah nyaris mencapai ujung gelapnya. Diukur pada 200 px,
    /// ss=2, kekuatan 0.40 — metriknya **sebaran pita** untuk sabit (lihat
    /// `moonLimbShadingStrength`: baris ekuator sabit jatuh di piringan gelap):
    ///
    ///     radius akhir   purnama (lengkung)   sabit (sebaran)
    ///     1.15               +33.5%                24.1
    ///     1.35               +28.5%                20.9
    ///
    /// Purnama **dan** sabit dua-duanya turun di 1.35 — jadi gradien yang
    /// terlalu lebar melemahkan keduanya, dan 1.15 menjaga lengkung purnama
    /// lebih dekat ke patokan Mars (+54.8%) sekaligus mempertahankan
    /// kedalaman pita sabit. 1.15 dipakai di kedua bahasa; gerbang piksel
    /// mengukurnya lewat **kedua** kasus, karena satu kasus saja tidak
    /// menangkapnya.
    ///
    /// **Dua pemanggil, satu angka.** Piringan Bulan *dan* pita terang planet
    /// dalam (Venus, Merkurius) memakai radius akhir yang sama, karena
    /// keduanya digambar di dalam `drawLayer` yang diputar sebesar sudut sisi
    /// terang. Sampai siklus ini jalur planet menulis `1.15` sendiri sebagai
    /// literal, sehingga mengubah konstanta ini memindahkan **nol piksel** di
    /// Venus dan Merkurius (terukur) — konstanta ini ada, dinamai, diuji di
    /// Linux, dan tidak mengatur apa pun di sana. Dijaga
    /// `check_planet_phase_limb_reads_the_model_constant`, yang sengaja
    /// mengukur lewat **konstantanya**, bukan lewat literalnya.
    static let moonSphereGradientEndRadius: Double = 1.15

    /// Ujung gelap gradien bola Bulan: warna yang sama, diredupkan sebagian.
    ///
    /// Ada sebagai fungsi supaya **satu** aturan peredupan dipakai kedua
    /// tempat yang memakainya (pita terang dan piringan fase tak diketahui)
    /// dan tidak ada yang menulis angka peredupannya sendiri di view. Port
    /// Python memakai fungsi yang sama (`moon_sphere_dark`), jadi gambar yang
    /// diukur gerbang piksel tidak bisa menyimpang dari gambar yang tampil di
    /// jam.
    static func moonSphereDark(_ base: RGBComponents) -> RGBComponents {
        let k = 1 - Swift.min(1, Swift.max(0, moonLimbShadingStrength))
        return .init(red: base.red * k, green: base.green * k, blue: base.blue * k)
    }

    // MARK: - Arah cahaya bola

    /// Arah datang cahaya pada bola planet, dalam satuan radius, relatif
    /// terhadap pusat piringan. y **positif ke bawah** — konvensi layar,
    /// sama dengan `Canvas`.
    ///
    /// **Kenapa ini ada di model, padahal ia "cuma titik gradien".** Dua
    /// gambar memakainya: gradien bola (`drawSphere`) dan bayangan kawah
    /// (`CraterRelief`). Keduanya **harus** sepakat dari mana cahaya datang,
    /// karena kawah yang gelapnya menghadap sumber cahaya terbaca sebagai
    /// **gundukan**, bukan cekungan. Versi sebelumnya menulis `-0.32` di
    /// view dan di port Python sebagai dua angka yang kebetulan sama —
    /// bentuk yang sudah berkali-kali tercatat di repo ini: satu angka di
    /// dua tempat adalah dua angka yang akan berbeda.
    ///
    /// Arahnya juga **bukan** bebas: sumbu-y yang dibalik membuat seluruh
    /// bayangan kawah terbalik, dan kawah terbalik tetap terlihat seperti
    /// kawah — kelas cacat yang tidak bisa dilihat mata, hanya bisa dihitung.
    static let sphereLightOffset = (x: -0.32, y: -0.32)
}

public extension CelestialVisual {

    /// Geometri bayangan **satu** kawah, relatif terhadap pusat kawah.
    ///
    /// **Cacat yang ditutup bentuk ini.** Kawah digambar sebagai satu cakram
    /// gelap rata. Di ukuran sebenarnya di jam (38 pt, 76 px @2x) hasilnya
    /// bukan "permukaan berkawah" melainkan **stiker abu-abu yang ditempel**
    /// pada bola: pengukuran mata pada render itu menyebutnya persis begitu,
    /// dan alasannya fisis — cekungan selalu punya sisi yang menghadap cahaya
    /// dan sisi yang membelakanginya, sementara cakram rata tidak punya
    /// keduanya. Merkurius adalah planet yang ciri pengenalnya justru kawah,
    /// jadi gambar yang tidak membacanya sebagai kawah adalah gambar yang
    /// gagal menyampaikan satu-satunya hal yang ia punya.
    ///
    /// Perbaikannya bukan "beri gradien": gradien yang sama untuk **semua**
    /// kawah akan membuat yang di sisi gelap bola ikut terang di sisi yang
    /// sama — menambah detail yang salah. Yang benar adalah bayangan yang
    /// **bergantung pada posisi kawah terhadap sumber cahaya**.
    ///
    /// Bentuk yang dipakai adalah cekungan yang sesungguhnya: **dasar yang
    /// lebih gelap** plus **bibir yang punya sisi terang dan sisi gelap**.
    /// Arah bibir terangnya itulah yang disimpan di sini sebagai vektor
    /// satuan, bukan sebagai satu angka kecerahan — karena satu angka tidak
    /// bisa menyatakan "terang di kiri-atas" tanpa ikut menyatakan arahnya.
    ///
    /// Tanda yang membuatnya bekerja: bibir terang selalu menghadap **sumber
    /// cahaya** (`-lightUnit`) — untuk **semua** kawah, bukan hanya yang di
    /// sisi terang.
    ///
    /// **Kenapa arahnya tidak boleh berbalik di sisi gelap.** Intuisi pertama
    /// di siklus ini adalah membalik arahnya untuk kawah yang berada di sisi
    /// gelap bola ("di sana cahayanya dari arah lain"). Itu salah, dan
    /// salahnya fisis: Matahari berjarak 0,39–1,5 AU sementara piringan
    /// Merkurius di layar berdiameter beberapa puluh piksel, jadi vektor
    /// cahaya di seluruh piringan **praktis sama**. Cekungan selalu
    /// meninggikan dinding yang menghadap cahaya dan menaungi dinding yang
    /// membelakanginya, di mana pun cekungan itu berada. Yang berubah di sisi
    /// gelap bukan **arah** bibirnya, melainkan **kontrasnya** — di sana tidak
    /// ada cahaya langsung yang bisa menerangi dinding mana pun.
    ///
    /// Kekeliruan ini tidak bisa ditangkap mata: kawah dengan bibir terbalik
    /// tetap terbaca sebagai kawah, hanya terbaca sebagai kawah yang
    /// **menonjol keluar** alih-alih cekung. Karena itu arahnya dihitung di
    /// model dan diuji di Linux.
    struct CraterRelief: Equatable, Sendable {
        /// Titik pusat kawah, satuan radius bola, relatif pusat piringan.
        public var centerX: Double
        public var centerY: Double
        /// Jari-jari kawah, satuan radius bola.
        public var radius: Double
        /// Komponen-x arah **bibir yang lebih terang**, vektor satuan di
        /// koordinat layar (y positif ke bawah). Disimpan sebagai dua
        /// `Double` terpisah, bukan `(x: y:)` — tupel berlabel sebagai
        /// *stored property* tidak bisa menyintesis `Equatable` di Swift 6,
        /// dan sisi sebaliknya otomatis lebih gelap.
        public var rimDirectionX: Double
        /// Komponen-y arah bibir yang lebih terang (lihat `rimDirectionX`).
        public var rimDirectionY: Double
        /// Seberapa kuat bibir terang/gelapnya, pecahan kecerahan permukaan.
        public var rimStrength: Double
        /// Seberapa gelap dasar cekungannya terhadap permukaan sekitarnya.
        /// Selalu positif — nilainya dipakai sebagai kelegapan lapisan hitam,
        /// jadi "lebih dalam" berarti angka yang lebih besar.
        public var floorDepth: Double

        public init(centerX: Double, centerY: Double, radius: Double,
                    rimDirectionX: Double, rimDirectionY: Double,
                    rimStrength: Double,
                    floorDepth: Double) {
            self.centerX = centerX
            self.centerY = centerY
            self.radius = radius
            self.rimDirectionX = rimDirectionX
            self.rimDirectionY = rimDirectionY
            self.rimStrength = rimStrength
            self.floorDepth = floorDepth
        }
    }

    /// Bayangan kawah untuk setiap kawah di `craters`.
    ///
    /// Lihat `CraterRelief` untuk alasannya. Fungsi ini yang memutuskan
    /// **arah** bayangannya, jadi arah itu tidak bisa berbeda antara view
    /// Swift dan port Python — dan tidak bisa berbeda antara satu kawah dan
    /// kawah berikutnya, karena semuanya diturunkan dari `lightDirection`
    /// yang sama.
    ///
    /// - Parameters:
    ///   - craters: pusat & jari-jari kawah (satuan radius bola), urutan
    ///     `(x, y, r)` — sama dengan yang sudah dipakai view.
    ///   - lightDirection: arah sumber cahaya, satuan radius. Lihat
    ///     `sphereLightOffset`.
    ///   - strength: kekuatan bibir pada kawah yang paling menghadap cahaya,
    ///     dalam pecahan kecerahan.
    ///   - depth: kedalaman dasar cekungan yang paling menghadap cahaya.
    static func craterRelief(craters: [(Double, Double, Double)],
                                    lightDirection: (x: Double, y: Double)
                                        = CelestialVisual.sphereLightOffset,
                                    strength: Double = 0.55,
                                    depth: Double = 0.22) -> [CraterRelief] {
        // Panjang arah cahaya tidak boleh nol: kalau nol, arahnya tidak
        // terdefinisi dan setiap kawah akan mendapat bibir terang di arah
        // yang sama secara acak. Menolaknya di sini lebih baik daripada
        // membiarkannya menghasilkan gambar yang "masuk akal".
        let length = (lightDirection.x * lightDirection.x
                      + lightDirection.y * lightDirection.y).squareRoot()
        guard length > 1e-9 else { return [] }
        let lightX = lightDirection.x / length
        let lightY = lightDirection.y / length

        return craters.map { dx, dy, size in
            // Panjang vektor kawah dari pusat bola, dijepit ke 1: kawah di
            // tepi piringan tidak punya arah yang lebih ekstrem dari tepi.
            let distance = min(1, (dx * dx + dy * dy).squareRoot())
            // Seberapa searah kawah dengan cahaya: +1 = kawah di sisi yang
            // paling terang, −1 = di sisi tergelap.
            let alignment = dx * lightX + dy * lightY
            // Kawah di sisi tergelap kehilangan kontrasnya, bukan berbalik
            // tanda: di sana tidak ada cahaya langsung yang bisa menerangi
            // dinding mana pun. Faktor `0.6 + 0.4 · alignment` memberi
            // kekuatan penuh di sisi terang dan 20% di sisi tergelap — tidak
            // pernah nol, supaya kawah tidak pernah hilang sama sekali.
            let fade = 0.6 + 0.4 * alignment
            // Kawah di tepi piringan permukaannya sudah miring, jadi
            // bibirnya tidak lagi punya dua sisi yang setara.
            let limb = 1 - 0.6 * distance
            return CraterRelief(centerX: dx, centerY: dy, radius: size,
                                // Bibir terang **selalu** menghadap sumber
                                // cahaya. Lihat `CraterRelief`: arahnya tidak
                                // berbalik di sisi gelap, yang berubah hanya
                                // `fade` di atas.
                                rimDirectionX: -lightX, rimDirectionY: -lightY,
                                rimStrength: strength * fade * limb,
                                floorDepth: depth * (1 - 0.5 * distance))
        }
    }
}

public extension CelestialVisual.Planet {

    /// Palet warna + ciri pengenal planet ini.
    ///
    /// **Kenapa ada di `PointingKit`, bukan di view.** Pemetaan planet → ciri
    /// adalah pernyataan identitas: `saturn → rings` berkata "Saturnus
    /// bercincin". Salah memetakan (mis. cincin pada Jupiter) akan terlihat
    /// sama meyakinkannya dengan yang benar bagi pengguna, dan tidak ada teks
    /// di layar yang bisa mengeceknya. Karena itu pemetaannya diuji
    /// (`CelestialVisualTests`), bukan hanya diklaim di komentar.
    var palette: CelestialVisual.Palette {
        switch self {
        case .mercury:
            return .init(light: .init(red: 0.72, green: 0.70, blue: 0.68),
                         dark:  .init(red: 0.26, green: 0.25, blue: 0.24),
                         feature: .craters)
        case .venus:
            return .init(light: .init(red: 0.99, green: 0.94, blue: 0.76),
                         dark:  .init(red: 0.62, green: 0.53, blue: 0.30),
                         feature: .haze)
        case .mars:
            return .init(light: .init(red: 0.88, green: 0.42, blue: 0.26),
                         dark:  .init(red: 0.38, green: 0.13, blue: 0.08),
                         feature: .polarCaps)
        case .jupiter:
            return .init(light: .init(red: 0.90, green: 0.78, blue: 0.61),
                         dark:  .init(red: 0.45, green: 0.29, blue: 0.17),
                         feature: .bands)
        case .saturn:
            return .init(light: .init(red: 0.93, green: 0.84, blue: 0.62),
                         dark:  .init(red: 0.44, green: 0.36, blue: 0.22),
                         feature: .rings)
        case .uranus:
            // Piringan pucat kehijauan, nyaris polos (sabuk sangat samar).
            return .init(light: .init(red: 0.68, green: 0.85, blue: 0.88),
                         dark:  .init(red: 0.24, green: 0.40, blue: 0.44),
                         feature: .paleDisk)
        case .neptune:
            // Piringan biru dalam, dengan titik gelap (Great Dark Spot).
            return .init(light: .init(red: 0.28, green: 0.42, blue: 0.92),
                         dark:  .init(red: 0.08, green: 0.16, blue: 0.42),
                         feature: .blueDisk)
        }
    }

    /// Kenali planet dari `CelestialObject.id`.
    ///
    /// `nil` untuk id yang tidak dikenal — UI lalu menggambar bola generik,
    /// **bukan** memilih planet secara acak. Bola generik tidak mengklaim
    /// planet mana pun; pita Jupiter pada planet yang bukan Jupiter
    /// mengklaim sesuatu yang tidak diketahui engine.
    init?(objectID: String) {
        guard let planet = Self(rawValue: objectID) else { return nil }
        self = planet
    }
}

// MARK: - Arah fase Bulan

public extension PointingResolver {

    /// Arah fase Bulan saat ini: apakah sabitnya membesar (waxing).
    ///
    /// **Kenapa ini dihitung, bukan diasumsikan.** `SkyContext` hanya membawa
    /// `moonIlluminationFraction` — besar fase, tanpa arah. Padahal sabit
    /// yang mengarah ke kiri dan ke kanan adalah dua gambar yang berbeda,
    /// dan keduanya tampak sama meyakinkannya bagi pengguna. Menggambar yang
    /// salah berarti UI menyatakan sesuatu yang tidak dihitung engine —
    /// persis yang dilarang PRD.
    ///
    /// Caranya: Bulan membesar selama **elongasinya** (selisih bujur
    /// ekliptika terhadap Matahari) berada di 0°–180°. Selisih RA dipakai
    /// sebagai proksi bujur: keduanya naik ke arah yang sama, dan yang
    /// dibutuhkan di sini hanya **tanda**-nya (waxing vs waning), bukan
    /// nilai tepatnya. Proksi ini hanya bisa salah dalam rentang sangat
    /// sempit di sekitar bulan baru/purnama, tempat fraksinya mendekati 0
    /// atau 1 dan sabitnya nyaris tidak terlihat.
    ///
    /// - Returns: `nil` bila efemeris tidak tersedia atau perhitungannya
    ///   gagal. UI lalu menggambar fase **simetris**, bukan menebak sisi.
    func isMoonWaxing(at date: Date = Date()) -> Bool? {
        guard let ephemeris else { return nil }
        guard let moon = try? ephemeris.apparent(.moon, at: date),
              let sun = try? ephemeris.apparent(.sun, at: date) else { return nil }
        // Ambangnya **bukan** di sini: `CelestialVisual.isWaxing` dipakai
        // bersama planet dalam supaya dua benda tidak bisa membesar ke arah
        // yang berlawanan. Yang tersisa di sini hanya menghitung elongasinya.
        return CelestialVisual.isWaxing(elongationDegrees: moon.raDeg - sun.raDeg)
    }

    /// Arah fase sebuah **planet dalam** saat ini: apakah sabitnya membesar.
    ///
    /// **Kenapa ini ada, padahal `planetIlluminationFraction` sudah memberi
    /// besarnya.** Besar tanpa arah menghasilkan `phaseGeometry(waxing: nil)`
    /// = `nil`, jadi fraksi yang dihitung tidak pernah digambar: Venus tampil
    /// sebagai bola penuh di setiap keadaan, termasuk saat engine menghitung
    /// iluminasinya 2%. Itu bukan gambar yang "kurang rinci" — ia menyatakan
    /// kebalikan dari apa yang sedang dihitung engine, dan tidak ada teks di
    /// layar yang bisa membantahnya.
    ///
    /// **Kenapa pakai elongasi, bukan sudut sisi terang.** Sudut sisi terang
    /// (`planetBrightLimbAngle`) menentukan **ke mana** sabit diputar; arah
    /// membesar/mengecil menentukan **sisi piringan mana yang menyala** pada
    /// gambar dasar. Dua hal yang berbeda, dan `phaseGeometry` butuh keduanya.
    /// Mengisi yang satu dari yang lain akan memutar sabit ke arah yang benar
    /// sambil menyalakan sisi yang salah pada sebagian fase.
    ///
    /// - Returns: `nil` bila planetnya tidak berfase atau efemeris tidak
    ///   tersedia. UI lalu menggambar piringan **tanpa fase**, bukan sabit
    ///   yang memihak ke satu sisi.
    func isPlanetWaxing(_ planet: CelestialVisual.Planet,
                        at date: Date = Date()) -> Bool? {
        guard planet.showsPhase else { return nil }
        guard let ephemeris,
              let body = EphemerisBody(rawValue: planet.rawValue),
              let planetSample = try? ephemeris.apparent(body, at: date),
              let sun = try? ephemeris.apparent(.sun, at: date)
        else { return nil }
        // Ambangnya satu, dipakai bersama Bulan (lihat `isMoonWaxing`).
        return CelestialVisual.isWaxing(
            elongationDegrees: planetSample.raDeg - sun.raDeg)
    }

    /// Fraksi piringan Bulan yang menyala, dari efemeris yang sama.
    ///
    /// Diambil di sini — bukan dari `SkyContext` — supaya fraksi dan arahnya
    /// berasal dari **satu** sampel efemeris.Kalau fraksi diambil dari
    /// konteks berjangka 30 detik sedangkan arahnya dihitung sekarang,
    /// keduanya bisa berasal dari menit yang berbeda.
    func moonIlluminationFraction(at date: Date = Date()) -> Double? {
        guard let ephemeris else { return nil }
        guard let moon = try? ephemeris.apparent(.moon, at: date) else { return nil }
        return min(1, max(0, moon.illuminationFraction))
    }

    /// Fraksi piringan **planet** yang menyala, dari efemeris yang sama.
    ///
    /// **Kenapa planet dalam perlu ini.** Venus mengayun dari sabit 1% ke
    /// cakram 99% dalam satu siklus sinodik, dan Merkurius lebih ekstrem lagi.
    /// Itu bukan detail hiasan: bagi pengamat, Venus yang "salah bulan" adalah
    /// salah satu pemandangan paling dikenal di langit — dan menggambarnya
    /// sebagai bola penuh berarti UI menyatakan fase yang tidak ada.
    ///
    /// **Kenapa hanya planet dalam.** Mars sampai Saturnus tidak pernah
    /// tampak berfase dari Bumi; `Planet.showsPhase` yang memutuskan, dan
    /// fungsi ini mengembalikan `nil` untuk mereka — **bukan** angkanya.
    /// Mengembalikan angka untuk Mars akan membuat pemanggil berikutnya bisa
    /// menggambar sabit Mars, dan kesalahan itu tidak terlihat di layar.
    ///
    /// **Kenapa `nil` juga saat fraksinya tidak masuk akal.** Efemeris bisa
    /// mengembalikan nilai di luar 0…1 pada geometri tepi (mis. elongasi
    /// ekstrem). Nilai seperti itu digambar menjadi pita terang dengan lebar
    /// negatif, jadi ia ditolak di sini alih-alih dijepit diam-diam di view.
    ///
    /// - Parameter planet: planet yang ditanyakan.
    /// - Returns: fraksi 0…1, atau `nil` bila planet tidak berfase,
    ///   efemeris tidak tersedia, atau fraksinya di luar rentang.
    func planetIlluminationFraction(for planet: CelestialVisual.Planet,
                                    at date: Date = Date()) -> Double? {
        guard planet.showsPhase else { return nil }
        guard let ephemeris,
              let body = EphemerisBody(rawValue: planet.rawValue),
              let sample = try? ephemeris.apparent(body, at: date)
        else { return nil }
        let fraction = sample.illuminationFraction
        guard fraction.isFinite, (0...1).contains(fraction) else { return nil }
        return fraction
    }

    /// Sudut sisi terang sebuah **planet** di langit pengamat, dalam radian.
    ///
    /// Planet berfase punya masalah orientasi yang sama dengan Bulan: sabit
    /// Venus bisa menghadap ke kanan, ke bawah, atau ke atas, tergantung di
    /// mana Matahari berada relatif terhadapnya di langit pengamat. Karena
    /// aturannya satu (**sisi terang menghadap Matahari**), perhitungannya
    /// memakai fungsi yang sama dengan Bulan — bukan rumus kedua yang harus
    /// dijaga agar tetap cocok.
    ///
    /// - Returns: `nil` bila planetnya tidak berfase, efemeris tidak
    ///   tersedia, atau sudutnya tidak bisa ditentukan. UI lalu menggambar
    ///   fase **tanpa putaran** — sabit yang belum berorientasi, bukan sabit
    ///   yang menghadap arah karangan.
    func planetBrightLimbAngle(for planet: CelestialVisual.Planet,
                               at date: Date = Date(),
                               observer: Observer) -> Double? {
        guard planet.showsPhase else { return nil }
        guard let ephemeris,
              let body = EphemerisBody(rawValue: planet.rawValue),
              let sample = try? ephemeris.apparent(body, at: date, from: observer),
              let sun = try? ephemeris.apparent(.sun, at: date, from: observer)
        else { return nil }

        let jd = SkyMath.julianDate(from: date)
        let planetHorizontal = SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg),
            observer: observer, jd: jd)
        let sunHorizontal = SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: sun.raDeg, decDeg: sun.decDeg),
            observer: observer, jd: jd)
        return CelestialVisual.brightLimbAngle(body: planetHorizontal, sun: sunHorizontal)
    }

    /// Sudut sisi terang Bulan **di langit pengamat**, dalam radian.
    ///
    /// **Kenapa ini ada, padahal `isWaxing` sudah ada.** `isWaxing` hanya
    /// memberi dua kemungkinan: sisi terang di kanan atau di kiri. Itu benar
    /// hanya bila sabitnya berdiri tegak — keadaan lintang tinggi. Di dekat
    /// ekuator (dan Jakarta ada di lintang -6.2 derajat) sabit muda justru
    /// terlihat terlentang, dengan sisi terang menghadap **bawah** ke tempat
    /// Matahari terbenam. Jadi `isWaxing` bukan aproksimasi kasar untuk
    /// sudutnya; ia jawaban yang **salah** pada lintang tempat aplikasi ini
    /// dipakai.
    ///
    /// Aturan fisisnya tunggal: **sisi terang selalu menghadap Matahari.**
    /// Sudut ini adalah terjemahan aturan itu ke bidang gambar, dan karena
    /// kerangkanya lokal (alt/az pengamat), **tidak ada cabang
    /// per-belahan-bumi di sini**: lintang sudah masuk lewat posisi Matahari
    /// dan Bulan yang dihitung engine.
    ///
    /// - Returns: `nil` bila efemeris tidak tersedia, perhitungannya gagal,
    ///   atau arahnya tidak bisa ditentukan. UI lalu **tidak memutar**
    ///   gambar, bukan menebak sudutnya.
    func moonBrightLimbAngle(at date: Date = Date(),
                             observer: Observer) -> Double? {
        guard let ephemeris else { return nil }
        guard let moon = try? ephemeris.apparent(.moon, at: date, from: observer),
              let sun = try? ephemeris.apparent(.sun, at: date, from: observer)
        else { return nil }

        let jd = SkyMath.julianDate(from: date)
        let moonHorizontal = SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: moon.raDeg, decDeg: moon.decDeg),
            observer: observer, jd: jd)
        let sunHorizontal = SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: sun.raDeg, decDeg: sun.decDeg),
            observer: observer, jd: jd)
        return CelestialVisual.brightLimbAngle(body: moonHorizontal, sun: sunHorizontal)
    }

}
