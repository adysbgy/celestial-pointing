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

    /// Seberapa "menyebar" objeknya (0 = titik, 1 = kabut lebar).
    ///
    /// Nebula dan galaksi tidak punya tepi, jadi ukurannya tidak bisa
    /// diturunkan dari magnitudo seperti bintang. Angka ini yang membedakan
    /// "titik kabur" dari "kabut lebar".
    public var fuzziness: Double

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
                fuzziness: Double = 0) {
        self.kind = kind
        self.planet = planet
        self.illuminationFraction = illuminationFraction
        self.isWaxing = isWaxing
        self.brightLimbAngleRadians = brightLimbAngleRadians
        self.colorIndexBV = colorIndexBV
        self.relativeSize = relativeSize
        self.fuzziness = fuzziness
    }

    // MARK: - Pembuatan dari objek engine

    /// Bangun model visual untuk sebuah objek hasil resolusi.
    ///
    /// - Parameters:
    ///   - object: objek yang dijawab engine.
    ///   - moonIlluminationFraction: fraksi fase Bulan dari `SkyContext`.
    ///     Hanya dipakai bila objeknya benar-benar Bulan — meneruskannya ke
    ///     benda lain akan menggambar fase pada Venus.
    ///   - isWaxing: arah fase Bulan, bila diketahui.
    ///   - brightLimbAngleRadians: sudut sisi terang Bulan di langit, bila
    ///     diketahui. Hanya dipakai bila objeknya Bulan.
    public init(object: CelestialObject,
                moonIlluminationFraction: Double? = nil,
                isWaxing: Bool? = nil,
                moonBrightLimbAngleRadians: Double? = nil) {
        switch object.kind {
        case .moon:
            self.init(kind: .moon,
                      illuminationFraction: moonIlluminationFraction,
                      isWaxing: isWaxing,
                      brightLimbAngleRadians: moonBrightLimbAngleRadians,
                      relativeSize: 1.0)
        case .planet:
            self.init(kind: .planet,
                      planet: Planet(objectID: object.id),
                      relativeSize: Self.sizeFromMagnitude(object.magnitude))
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
            // yang lain adalah **bentuknya** (`fuzziness`), dan itu dibaca dari
            // tabel per id: satu angka untuk semua akan membuat seluruh kelas
            // ini tampil sebagai bentuk yang sama persis.
            self.init(kind: .deepSky, relativeSize: 0.7,
                      fuzziness: DeepSkyCatalogue.fuzziness(forObjectID: object.id))
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
    /// - Parameter waxing: arah fase. **`nil` menghasilkan `nil`**: tanpa arah,
    ///   gambar apa pun yang digambar akan memihak ke satu sisi, dan itu
    ///   pernyataan yang tidak dihitung engine.
    /// - Returns: `nil` bila fase tidak bisa digambar (bukan Bulan, fraksi
    ///   tidak tersedia, atau arah tidak diketahui). UI lalu menggambar
    ///   piringan tanpa fase — bukan sabit yang memilih sisi.
    public func phaseGeometry(waxing: Bool?) -> PhaseGeometry? {
        guard kind == .moon, let f = illuminationFraction, let waxing else { return nil }
        let clamped = min(1, max(0, f))
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
    public static func brightLimbAngle(moon: HorizontalCoord,
                                       sun: HorizontalCoord) -> Double? {
        func enu(_ h: HorizontalCoord) -> (e: Double, n: Double, u: Double) {
            let alt = SkyMath.deg2rad(h.altitudeDeg)
            let az = SkyMath.deg2rad(h.azimuthDeg)
            return (cos(alt) * sin(az), cos(alt) * cos(az), sin(alt))
        }

        let m = enu(moon)
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

    /// Geometri kabut nebula: tiga blob tumpang-tindih tanpa tepi keras.
    ///
    /// **Kenapa ini di model, bukan di view.** Blob digeser dari pusat
    /// (supaya kabut tidak simetris sempurna, yang justru terlihat
    /// "digambar"). Geseran itu membuat batasnya **berbeda per sumbu**:
    /// blob yang terpusat aman dicek secara radial, blob yang digeser
    /// keluar frame lebih cepat. Karena itu ukurannya dihitung dari sisa
    /// ruang ke tepi frame, bukan dari radius mentah.
    public struct NebulaGeometry: Equatable, Sendable {
        public struct Blob: Equatable, Sendable {
            /// Geseran pusat blob dari tengah frame, sumbu x & y (satuan radius).
            public var offsetX: Double
            public var offsetY: Double
            /// Jari-jari blob (satuan radius).
            public var radius: Double
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
        let clamped = min(1, max(0, fuzziness))
        // Geseran ditulis tetap: bentuk kabut yang asimetris adalah yang
        // membuatnya tidak tampak seperti lingkaran yang digambar.
        let layout: [(Double, Double, Double, Double)] = [
            // (offsetX, offsetY, skala, opasitas)
            (-0.18, 0.12, 1.00, 0.42),
            ( 0.22, -0.16, 0.68, 0.30),
            ( 0.05, -0.04, 0.40, 0.55)
        ]
        let blobs = layout.map { offsetX, offsetY, scale, opacity in
            // Ruang yang tersisa dari pusat blob ke tepi frame terdekat.
            let headroomX = frameHalfExtent - abs(offsetX)
            let headroomY = frameHalfExtent - abs(offsetY)
            let headroom = min(headroomX, headroomY)
            // Lebar kabut: mengikuti `fuzziness`, tetapi tidak pernah
            // melebihi ruang yang tersisa.
            let extent = headroom * (0.62 + 0.38 * clamped)
            return NebulaGeometry.Blob(offsetX: offsetX,
                                       offsetY: offsetY,
                                       radius: extent * scale,
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
}

// MARK: - Geometri ciri planet

public extension CelestialVisual {

    /// Kutub es planet, dalam satuan radius dan relatif terhadap pusat bola.
    ///
    /// Satu tipe untuk **kedua** kutub, bukan satu angka per kutub.
    struct PolarCaps: Equatable, Sendable {
        /// Sisi atas (utara): tepi elipsnya tepat di tepi bola.
        public var north: Rect
        /// Sisi bawah (selatan): cermin dari utara terhadap ekuator.
        public var south: Rect
        /// Satu kutub: posisi & ukuran elipsnya.
        public struct Rect: Equatable, Sendable {
            /// Tepi atas elips, relatif terhadap pusat bola.
            public var topY: Double
            public var height: Double
            public var halfWidth: Double
        }

        public init(north: Rect, south: Rect) {
            self.north = north
            self.south = south
        }
    }

    /// Geometri kutub yang **benar secara konstruktif**: kutub selatan
    /// dihitung sebagai cermin kutub utara, bukan dari rumus kedua.
    ///
    /// **Kenapa ini di model, bukan di view.** Kutub adalah ciri pengenal
    /// Mars, dan PRD melarang visual yang mengklaim identitas — jadi bentuk
    /// yang salah adalah **klaim yang salah**, bukan sekadar rasa. Tapi
    /// bentuk yang salah mustahil dibaca dari teks mana pun di layar, jadi
    /// ia hanya bisa dijaga di tempat yang bisa diuji di Linux.
    ///
    /// **Bug yang ditutup oleh bentuk kacau ini.** Versi sebelumnya memakai
    /// `y - radius` untuk kutub utara tapi `y + radius - capHeight` untuk
    /// kutub selatan, dengan tinggi elips `2 · capHeight`. Kutub selatan
    /// berakhir di y = 1.26 — yaitu **0.26R di luar bola**, menggantung di
    /// ruang kosong — sementara kutub utara hanya meleset 0.004R. Jadi Mars
    /// tampil dengan kutub putih yang tidak simetris dan tidak menempel,
    /// persis di tanda yang paling mudah dibaca mata telanjang. Satu tipe
    /// dengan dua kutub yang dicerminkan membuat ketidak-simetrisan seperti
    /// ini tidak bisa ditulis ulang tanpa mengubah bentuk yang benar.
    ///
    /// - Parameters:
    ///   - capHeightFraction: setengah tinggi kutub, dalam satuan radius.
    ///   - halfWidthFraction: setengah lebar kutub, dalam satuan radius.
    ///
    /// Hasil dalam **satuan radius** (bukan poin): view yang sudah punya
    /// radius cukup mengalikan sendiri, jadi model ini tidak perlu tahu
    /// satuan apa yang sedang digambar.
    static func polarCaps(capHeightFraction: Double = 0.26,
                          halfWidthFraction: Double = 0.55) -> PolarCaps {
        let height = 2 * capHeightFraction
        // Kutub utara mulai tepat di tepi bola; kutub selatan cerminnya
        // mulai `2 · capHeight` di dalam tepi bawah — jadi keduanya berakhir
        // pada jarak yang sama dari ekuator.
        let northTop = -1.0
        let southTop = 1.0 - height
        func rect(_ topY: Double) -> PolarCaps.Rect {
            PolarCaps.Rect(topY: topY,
                           height: height,
                           halfWidth: halfWidthFraction)
        }
        return PolarCaps(north: rect(northTop), south: rect(southTop))
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
        return CelestialVisual.brightLimbAngle(moon: moonHorizontal, sun: sunHorizontal)
    }

    /// Bungkus sudut ke rentang 0…360.
    static func normalizedDegrees(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
