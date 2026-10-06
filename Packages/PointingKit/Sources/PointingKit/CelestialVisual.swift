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
            case .mars, .jupiter, .saturn: return false
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
    /// `nil` untuk benda tata surya & bintang: bentuk mereka sudah ditentukan
    /// `kind`/`planet`, jadi id tidak menambah apa pun di sana.
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
                      relativeSize: Self.sizeFromMagnitude(object.magnitude))
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

    /// Indeks warna B−V untuk bintang yang ada di katalog.
    ///
    /// Nilainya dari katalog warna bintang terang yang sudah mapan. Yang
    /// penting di sini bukan presisi dua desimal, melainkan **tanda**-nya:
    /// Betelgeuse (M1, B−V ≈ +1.85) harus merah, Rigel (B8, B−V ≈ −0.03)
    /// biru, Sirius (A1, B−V ≈ 0.00) putih-biru. Tanda yang terbalik tidak
    /// akan pernah dilaporkan pengguna — karena itu ia diuji.
    ///
    /// Bintang yang tidak ada di tabel mengembalikan `0` (putih), bukan
    /// warna karangan: putih netral tidak mengklaim apa-apa.
    public static func colorIndex(forStarID id: String) -> Double {
        Self.starColorIndex[id] ?? 0
    }

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
    /// Saat `isConfirmed == false` hasilnya adalah nilai yang **sudah** dipakai
    /// untuk bintang yang tidak ada di katalog — bukan angka netral baru.
    /// Bedanya penting: nilai baru masih bisa kebetulan berupa warna spektral
    /// yang khas, sedangkan nilai ini sudah lama dianggap tidak mengklaim
    /// apa pun. Yang tetap tampil saat ragu hanyalah **terang** (ukuran dari
    /// magnitudo), dan terang bukan identitas: ia tidak menyebut bintang mana.
    ///
    /// - Parameters:
    ///   - colorIndexBV: indeks B−V bintang, dari `colorIndex(forStarID:)`.
    ///   - isConfirmed: apakah engine sudah mengunci identitasnya.
    public static func drawableStarColorIndex(_ colorIndexBV: Double,
                                              isConfirmed: Bool) -> Double {
        guard isConfirmed else { return colorIndex(forStarID: "") }
        return colorIndexBV
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

    /// RGB **siang** untuk sebuah indeks B−V, sebagai komponen mentah.
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
    /// Menjepit satu komponen kanal ke 0...1.
    private static func unit(_ value: Double) -> Double { min(1, max(0, value)) }

public static func starRGB(forColorIndex index: Double) -> RGBComponents {
        let clamped = min(2.0, max(-0.5, index))
        // −0.35 … +1.35 → 0 … 1 (biru ke merah), lalu dingatkan sedikit di
        // ujung biru supaya Rigel tidak tampak ungu.
        let warmth = (clamped + 0.35) / 1.70
        // Kanal **harus** dijepit ke 0...1. Tanpa itu, B−V >= ~1.35
        // menghasilkan kanal merah > 1 -- dan itu bukan "sedikit terlalu
        // terang": `Color(red:green:blue:)` tidak punya nilai di luar 1, jadi
        // hasilnya bergantung pada perilaku penjepitan diam-diam milik
        // SwiftUI. Untuk Betelgeuse (B−V 1.85) warna siang yang keluar
        //literally 1.11 di kanal merah: lebih terang dari putih, dan
        // luminance-nya ikut terangkat sehingga urutannya terhadap bintang
        // lain ikut berubah. Dijepit di sini supaya "merah" berarti merah.
        return RGBComponents(red: unit(0.62 + 0.38 * warmth),
                             green: unit(0.78 - 0.16 * warmth),
                             blue: unit(1.00 - 0.72 * warmth))
    }

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
    }
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

        public init(coreRadius: Double,
                    glowScales: [Double],
                    spikeScale: Double,
                    pulseAmplitude: Double) {
            self.coreRadius = coreRadius
            self.glowScales = glowScales
            self.spikeScale = spikeScale
            self.pulseAmplitude = pulseAmplitude
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
    ///   - frameHalfExtent: setengah lebar frame.
    public static func deepSky(morphology: DeepSkyCatalogue.Morphology?,
                               fuzziness: Double,
                               frameHalfExtent: Double = halfExtent) -> NebulaGeometry {
        guard let morphology else {
            // Tidak tahu bentuknya: gambar kabut netral, **jangan** menebak
            // salah satu jenis. Lihat `DeepSkyCatalogue.morphology(forObjectID:)`.
            return nebula(fuzziness: fuzziness, frameHalfExtent: frameHalfExtent)
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
            // Radius dan komponennya **dihitung**, bukan ditulis: 45° pada
            // radius `r` adalah `r/√2`, dan angka yang dibulatkan ke enam
            // desimal membuat cangkangnya menyimpang 2e-7 dari satu radius —
            // cukup untuk membuat uji "satu radius" merah tanpa ada yang
            // salah. Satu angka (`shellRadius`) yang dipakai kedua sumbu.
            let shellRadius = 0.42
            let diagonal = shellRadius / 2.0.squareRoot()
            let ring: [(Double, Double)] = [
                ( shellRadius,  0.0),
                ( diagonal,  diagonal),
                ( 0.0,  shellRadius),
                (-diagonal,  diagonal),
                (-shellRadius,  0.0),
                (-diagonal, -diagonal),
                ( 0.0, -shellRadius),
                ( diagonal, -diagonal)
            ]
            // Opasitasnya tidak seragam: cangkang yang rata sempurna tampak
            // seperti donat yang digambar. Bedanya kecil dan sengaja
            // asimetris (sisi atas-sedikit lebih tebal).
            let shellOpacity = [0.54, 0.48, 0.52, 0.46, 0.50, 0.44, 0.53, 0.47]
            let layout: [(Double, Double, Double, Double, Double, Double)] =
                zip(ring, shellOpacity).map { offset, opacity in
                    (offset.0, offset.1, 0.30, 1.0, 0.0, opacity)
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

        case .openCluster:
            // Bintang tersebar **jarang**, tanpa inti: blob-blobnya kecil,
            // tersebar sampai dekat tepi, dan **tidak ada yang di tengah**.
            // Yang membedakannya dari gugus bola adalah ketiadaan pusat,
            // bukan ukurannya — jadi tidak ada blob di sekitar pusat, dan
            // ukurannya nyaris seragam supaya tidak ada yang tampak sebagai
            // inti.
            let layout: [(Double, Double, Double, Double, Double, Double)] = [
                ( 0.000000, -0.620000, 0.34, 1.0, 0.0, 0.55),
                (-0.560000, -0.300000, 0.31, 1.0, 0.0, 0.50),
                ( 0.520000, -0.340000, 0.33, 1.0, 0.0, 0.45),
                (-0.680000,  0.180000, 0.29, 1.0, 0.0, 0.52),
                ( 0.620000,  0.220000, 0.31, 1.0, 0.0, 0.48),
                (-0.340000,  0.580000, 0.33, 1.0, 0.0, 0.42),
                ( 0.300000,  0.620000, 0.29, 1.0, 0.0, 0.55)
            ]
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

        public init(centerX: Double, centerY: Double,
                    radius: Double, glyphFraction: Double) {
            self.centerX = centerX
            self.centerY = centerY
            self.radius = radius
            self.glyphFraction = glyphFraction
        }

        /// Radius glif tanda tanya (satuan radius).
        public var glyphRadius: Double { radius * glyphFraction }

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
    public static func candidateMarker(frameHalfExtent: Double = halfExtent,
                                       cornerFraction: Double = 0.34,
                                       inset: Double = 0.06,
                                       glyphFraction: Double = 0.52) -> CandidateMarker {
        let corner = max(0, frameHalfExtent * (1 - min(1, max(0, inset))))
        let radius = corner * min(1, max(0, cornerFraction))
        // `d + radius == corner`, jadi lencana tidak mungkin keluar.
        let d = corner - radius
        return CandidateMarker(centerX: d, centerY: -d,
                               radius: radius, glyphFraction: glyphFraction)
    }

    // MARK: Matahari

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
    /// hanyalah penurunan berangsur dari 0.94 ke 0.0 antara 0.72 R dan 1.0 R.
    /// Terukur: langkah terbesar turun ke 14 dari 255 — 92% lebih halus.
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
            SunStop(radiusFraction: 1.00, color: photosphere, opacity: 0.00),
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
    public struct HazeGeometry: Equatable, Sendable {
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
    public static func venusHaze(centerY: Double = 0.0,
                                 halfWidth: Double = 0.55,
                                 halfHeight: Double = 0.72) -> HazeGeometry {
        HazeGeometry(centerY: centerY, halfWidth: halfWidth, halfHeight: halfHeight)
    }

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
    public struct Spot: Equatable, Sendable {
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
    public static func jupiterSpot(centerX: Double = -0.10,
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
    public struct Band: Equatable, Sendable {
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
    ///     radius bola.
    public static func jupiterBands(count: Int = 7,
                                    heightFraction: Double = 0.11) -> [Band] {
        guard count > 0 else { return [] }
        let halfHeight = heightFraction / 2
        return (0..<count).map { index in
            let t = (Double(index) + 0.5) / Double(count)
            // −1 … +1, dari kutub utara ke selatan.
            let y = -1 + 2 * t
            // Tepi bola pada ketinggian itu — rumus proyeksi, bukan pilihan.
            let halfWidth = (1 - y * y).squareRoot()
            return Band(centerY: y, halfWidth: halfWidth, halfHeight: halfHeight)
        }
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
    public static func bandHalfWidthAt(height: Double) -> Double {
        min(1, max(0, 1 - height * height)).squareRoot()
    }

    /// Kekuatan **pemulihan peredupan limb** di atas pita permukaan, 0…1.
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
    /// Perbaikannya **bukan** "pita dibuat lebih gelap di tepi". Aturan itu
    /// menggelapkan pita di tempat yang salah untuk pita yang tidak menyentuh
    /// limb, dan ia menambah sumber kedua tentang dari mana cahaya datang.
    /// Yang benar adalah memakai **kembali gradien bola yang sama** (pusat di
    /// `sphereLightOffset`, warna `palette.light` → `palette.dark`) di atas
    /// pita, dipotong ke bentuk pitanya. Karena gradiennya sama, lengkung yang
    /// dipulihkan persis lengkung yang tadi terhapus, dan arah cahayanya tidak
    /// bisa berbeda pendapat dengan `drawSphere`.
    ///
    /// Nilainya **sebagian**, bukan 1: pada 1.0 pita tertutup gradien bola
    /// sama sekali (kontras pita 24.7% → 17.0%, pitanya berhenti terbaca), dan
    /// pada 0 lengkungnya kembali rata — cacatnya kembali utuh. Nilai 0.6
    /// memulihkan 75% lengkung sambil menyisakan 18.3% kontras pita, jadi
    /// **kedua** sisinya punya jarak ke ambangnya. Dijaga
    /// `testBandLimbShadingIsPartial` di Linux dan gerbang piksel
    /// `check_banded_disc_keeps_its_curvature`.
    public static let bandLimbShadingStrength: Double = 0.6

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
    public static let sphereLightOffset = (x: -0.32, y: -0.32)
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
    public struct CraterRelief: Equatable, Sendable {
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
        let difference = Self.normalizedDegrees(moon.raDeg - sun.raDeg)
        return difference < 180
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

    /// Bungkus sudut ke rentang 0…360.
    static func normalizedDegrees(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
