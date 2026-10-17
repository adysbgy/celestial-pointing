import XCTest
import CelestialEngine
@testable import PointingKit

/// Nama bintang untuk diucapkan VoiceOver — **tempat nama itu sampai ke telinga**.
///
/// **Cacat yang ditutup berkas ini.** `spokenStarColor(isConfirmed:)` sudah ada
/// dan teruji, dan ia menjanjikan bahwa pengguna VoiceOver mendapat warna bintang
/// yang sama dengan yang dilihat mata (`StarColorSpeech`). Tetapi tidak ada satu
/// pun layar yang memanggilnya tanpa syarat: pemanggilnya di
/// `ObjectDetailView.kindAccessibilityLabel` melewati **`CelestialVisual` yang
/// dirakit dari `CelestialObject`**, dan jalur itu tidak pernah mengisi
/// `objectID` untuk bintang (`nil` untuk benda tata surya **dan** bintang, lihat
/// catatan `objectID`).
///
/// Akibatnya seluruh rantai warna — tabel B−V, `drawableStarColorIndex`, pita
/// `starColorText`, dan uji-uji yang habis-habisan menjaganya — berakhir di
/// `nil`. Yang terjadi di telinga pengguna: **"Rigel, bintang"**. Bukan
/// "biru", bukan salah warna — diam. Persis kelas yang dikejar repo ini:
/// gerbang hijau, dan yang diukur bukan bagian yang bermasalah. Uji warna yang
/// ada memanggil `spokenStarColor` pada visual yang dirakit **tangan** dengan
/// `objectID` yang sudah terisi, jadi jalur yang rusak tidak pernah dilewati
/// satu uji pun.
///
/// Uji di berkas ini karena itu **tidak merakit visual dengan tangan**: ia
/// menempuh jalur yang sama dengan view (`CelestialVisual(object:)`), supaya
/// pemutusan rantai itu berbunyi di Linux.
final class StarNameSpeechTests: XCTestCase {

    private func object(id: String, kind: ObjectKind, magnitude: Double = 1.0) -> CelestialObject {
        CelestialObject(id: id, name: id.capitalized, kind: kind,
                        raDeg: 0, decDeg: 0, magnitude: magnitude)
    }

    // MARK: - Jalur view: object → visual → ucapan

    /// Setiap bintang di katalog yang punya warna harus **mengucapkan** warna
    /// itu setelah dikonversi lewat jalur yang dipakai view.
    ///
    /// Daftar nama diambil dari berkas ini, bukan dari `starColorIndex`
    /// (internal): uji ini menguji bahwa tabel itu **sampai** ke ucapan, dan
    /// membaca daftarnya dari tabel yang sama yang dipakai ucapan akan membuat
    /// bintang yang hilang dari tabel tetap hijau.
    func testEveryCatalogueStarSpeaksItsColourThroughTheViewPath() {
        let representatives: [(String, LocalizedText)] = [
            // Rigel B−V −0,03: batas "biru" adalah ≤ −0,10, jadi Rigel jatuh di
            // **putih kebiruan** — sama pitanya dengan Sirius. Perkiraan penulis
            // uji ("Betelgeuse merah, Rigel biru") adalah niat desain, bukan
            // tabel; yang berlaku tabel, dan gambar Rigel pun putih-biru.
            ("rigel", .starColorWhiteBlue),
            // B2, B−V −0,22 — di luar pita putih kebiruan, jadi **biru**.
            ("bellatrix", .starColorBlue),
            ("achernar", .starColorBlue),
            ("sirius", .starColorWhiteBlue),
            ("vega", .starColorWhiteBlue),
            ("capella", .starColorYellow),
            ("arcturus", .starColorOrange),
            ("betelgeuse", .starColorRed),
            ("antares", .starColorRed),
        ]
        for (id, expected) in representatives {
            let visual = CelestialVisual(object: object(id: id, kind: .star))
            XCTAssertEqual(visual.spokenStarColor(isConfirmed: true),
                           TextLocalization.text(expected),
                           "Bintang \(id) tidak mengucapkan warnanya lewat jalur view — "
                           + "objectID tidak sampai ke `CelestialVisual(object:)`")
        }
    }

    /// Dan diam saat engine ragu — janji yang sama dengan gambar.
    ///
    /// Uji ini **bukan** pengulangan uji warnanya: ia menjaga bahwa perbaikan
    /// jalur di atas tidak dicapai dengan mengabaikan `isConfirmed`. Kedua
    /// keadaan harus diuji pada visual yang **sama** dari jalur view; kalau
    /// hanya keadaan "yakin" yang diuji, perbaikan termudah adalah membuang
    /// penjaganya.
    func testViewPathStillSilentAboutColourWhenUncertain() {
        let visual = CelestialVisual(object: object(id: "betelgeuse", kind: .star))
        XCTAssertNil(visual.spokenStarColor(isConfirmed: false))
    }

    /// Benda lain tidak memperoleh warna bintang dari jalur ini.
    ///
    /// Kalau perbaikan dilakukan dengan mengisi `objectID` untuk **semua**
    /// jenis, planet yang id-nya kebetulan sama dengan id bintang di tabel
    /// akan lolos `kind == .star` tetap `nil` — tapi uji ini menyatakan
    /// untungnya secara eksplisit, karena ia yang akan merah kalau penjagaan
    /// `kind` di `spokenStarColor` dilonggarkan.
    func testPlanetNeverSpeaksAStarColour() {
        let jupiter = CelestialVisual(object: object(id: "jupiter", kind: .planet,
                                                     magnitude: -2.0))
        XCTAssertNil(jupiter.spokenStarColor(isConfirmed: true))
    }

    // MARK: - Kelas spektral tertulis di nama

    /// Nama bintang membawa kelas spektralnya** bila kelas itu ada**.
    ///
    /// "Rigel, bintang, biru" masih tidak bisa dibedakan dari "Betelgeuse,
    /// bintang, merah" di telinga selain hue — dan pengguna VoiceOver yang
    /// memakai katalog teleskop (yang menyebut B8, M1) tidak punya jalan
    /// untuk menghubungkan yang ia dengar dengan yang ia baca. Kelas spektral
    /// adalah satu-satunya potongan informasi itu yang **sudah ada** di
    /// komentar tabel warna (`"rigel": -0.03, // B8 — biru`), jadi tidak ada
    /// yang dikarang.
    func testClassIsSpokenForEveryCatalogueStarWithAKnownIndex() {
        XCTAssertEqual(CelestialVisual.spokenStarClass(spectralClass: "B8"), "B8")
        XCTAssertEqual(CelestialVisual.spokenStarClass(spectralClass: "A0"), "A0")
    }

    /// Id yang tidak punya kelas **tidak** diberi kelas tebakan.
    ///
    /// Ini yang paling rawan: "matahari" adalah G2V, "bulan" tidak punya
    /// kelas spektral sama sekali. Memberi keduanya kelas akan terdengar
    /// berwibawa dan sepenuhnya salah. `nil` adalah jawaban yang benar, dan
    /// `spokenStarClass` harus **melewatinya**, bukan menebak kelas dari
    /// warna (warna hanya memberi huruf; kelas memberi angka 0-9 yang justru
    /// membedakan B8 dari B2).
    func testUnknownClassIsNotGuessed() {
        XCTAssertNil(CelestialVisual.spokenStarClass(spectralClass: nil))
        XCTAssertNil(CelestialVisual.spokenStarClass(spectralClass: ""))
        XCTAssertNil(CelestialVisual.spectralClass(forStarID: "matahari"))
        XCTAssertNil(CelestialVisual.spectralClass(forStarID: "bulan"))
        XCTAssertNil(CelestialVisual.spectralClass(forStarID: ""))
    }

    /// Kelas setiap bintang di katalog yang **harus** punya kelas.
    ///
    /// Keseluruhan 25 bintang di `starColorIndex` punya kelas spektral di
    /// komentarnya. Kalau satu tertinggal, VoiceOver diam tentang bintang
    /// itu sementara pengguna mata membaca warnanya — sebelum berkas ini ada,
    /// itu terjadi pada **semua 25** sekaligus.
    func testEveryCataloguedStarHasItsClass() {
        let expected: [String: String] = [
            "sirius": "A1", "canopus": "F0", "arcturus": "K0", "vega": "A0",
            "capella": "G8", "rigel": "B8", "procyon": "F5", "achernar": "B6",
            "betelgeuse": "M1", "hadar": "B1", "altair": "A7", "acrux": "B0",
            "aldebaran": "K5", "spica": "B1", "antares": "M1", "pollux": "K0",
            "fomalhaut": "A3", "deneb": "A2", "regulus": "B8", "castor": "A1",
            "bellatrix": "B2", "alioth": "A1", "alnitak": "O9", "dubhe": "K0",
            "polaris": "F7",
        ]
        XCTAssertEqual(expected.count, 25, "katalog bintang bertambah/berkurang — "
                       + "tabel di berkas ini harus disesuaikan")
        for (id, spectralClass) in expected {
            XCTAssertEqual(CelestialVisual.spectralClass(forStarID: id), spectralClass,
                           "kelas spektral \(id) hilang atau salah")
        }
    }

    /// Kelas yang diucapkan harus **sama** dengan yang tertulis di komentar
    /// tabel warna — satu sumber, bukan dua daftar yang bisa berbeda pendapat.
    ///
    /// Uji ini membaca sumber paketnya, jadi ia menangkap kelas yang tertukar
    /// antar-dua tempat; kelas yang salah di **kedua** tempat tidak bisa
    /// ditangkap uji mana pun, dan itu dinyatakan sebagai batas di
    /// `StarNameSpeech` bukan disembunyikan.
    func testSpokenClassAgreesWithTheColourTableComment() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        // Packages/PointingKit/Tests/PointingKitTests/<berkas>.swift
        //   -> Packages/PointingKit/Tests/PointingKitTests
        //   -> Packages/PointingKit/Tests
        //   -> Packages/PointingKit
        //   -> Packages/PointingKit/Sources/PointingKit/CelestialVisual.swift
        let source = thisFile.deletingLastPathComponent()   // PointingKitTests
            .deletingLastPathComponent()                    // Tests
            .deletingLastPathComponent()                    // PointingKit
            .appendingPathComponent("Sources/PointingKit/CelestialVisual.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path),
                      "sumber paket tidak ditemukan di \(source.path) — uji ini "
                      + "tidak boleh lulus tanpa membaca apa pun")
        let text = try String(contentsOf: source, encoding: .utf8)

        // Baris bentuknya: `"rigel":      -0.03,   // B8 — biru`
        //
        // Nama ber-apostrof (`"achernar_alt"` tidak ada, tapi
        // `[a-z]+` sengaja sempit) dilewati; yang dihitung harus **25**, dan
        // angka itu ditegakkan di bawah supaya pola yang memendek jadi diam.
        // Polanya sengaja **hanya** untuk baris yang tidak memakai koma
        // (`"polaris": 0.60    // F7`, tanpa koma) — baris itu tertinggal dari
        // pola pertama, dan yang menangkapnya adalah selisih **nama yang
        // hilang**, bukan selisih jumlah. Itu disengaja: jumlah "24 lawan 25"
        // tidak memberi tahu baris mana, dan selama ini di repo ini laporan
        // seperti itulah yang dibaca setengah jalan.
        let pattern = #""([a-z]+)":\s*(-?[0-9.]+),?\s*//\s*([OBAFGKM][0-9])"#
        let regex = try NSRegularExpression(pattern: pattern)
        let ns = text as NSString
        var fromComment: [String: String] = [:]
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let id = ns.substring(with: match.range(at: 1))
            fromComment[id] = ns.substring(with: match.range(at: 3))
        }

        let spoken = CelestialVisual.starSpectralClassByID
        XCTAssertEqual(Set(spoken.keys), Set(fromComment.keys),
                       "nama di tabel kelas berbeda dari komentar tabel warna — "
                       + "kelas yang tidak ada di salah satu sisi tidak pernah diuji")
        for (id, classInComment) in fromComment {
            XCTAssertEqual(spoken[id], classInComment,
                           "kelas \(id) di ucapan tidak sama dengan komentar tabel warna")
        }
        XCTAssertEqual(fromComment.count, 25, "pembacaan komentar tabel warna kehilangan "
                       + "baris — uji ini tidak memeriksa apa pun bila angkanya nol")
    }

    // MARK: - Kalimat untuk pemanggil

    /// `spokenStarClassLine` merakit kalimatnya lewat katalog, bukan literal.
    ///
    /// Nilai bawaannya dicek di Linux (tidak ada `.lproj`), dan bentuk
    /// Inggris-nya dicek terpisah di bawah — dua-duanya karena Aturan 4/6
    /// hanya menjaga kunci, bukan kalimat yang akhirnya terbaca.
    func testClassLineSaysWhatItIsJoinedTo() {
        XCTAssertEqual(CelestialVisual.spokenStarClassLine(spectralClass: "B8"),
                       "kelas spektral B8")
        XCTAssertTrue(CelestialVisual.spokenStarClassLine(spectralClass: "B8")?
            .contains("B8") == true)
    }

    // MARK: - Yang tidak boleh berubah

    /// Bintang tanpa warna dikenal (belum di katalog) tetap utuh ukurannya —
    /// perbaikan ini hanya menyentuh ucapan, bukan gambar.
    func testFixingSpeechDoesNotChangeTheDrawnStarColour() {
        let visual = CelestialVisual(object: object(id: "rigel", kind: .star))
        XCTAssertEqual(visual.colorIndexBV, CelestialVisual.colorIndex(forStarID: "rigel"))
        // Dan bintang yang tidak ada di tabel tetap warna netral.
        let unknown = CelestialVisual(object: object(id: "bintangbaru", kind: .star))
        XCTAssertTrue(unknown.colorIndexBV.isNaN)
    }
}

/// Bentuk Inggris dari kalimat kelas spektral.
final class StarNameSpeechEnglishTests: BridgedTextTestCase {

    func testClassLineInEnglish() {
        EnglishTranslation.install([
            "star.class.line.spoken.label": "spectral class %1$@",
            // B−V 0,00 adalah Sirius/Vega: **putih kebiruan**, bukan biru.
            "star.color.whiteBlue.spoken.label": "blue-white",
        ])
        XCTAssertEqual(CelestialVisual.spokenStarClassLine(spectralClass: "B8"),
                       "spectral class B8")
        XCTAssertEqual(CelestialVisual.spokenStarColorLine(colorIndexBV: 0.0, isConfirmed: true),
                       "blue-white")
        // Indeks yang **tidak mengklaim** (saat ragu) tetap diam di jalur
        // indeks — supaya jalur ini tidak menjadi pintu belakang yang lolos
        // dari penjaga `isConfirmed`.
        XCTAssertNil(CelestialVisual.spokenStarColorLine(
            colorIndexBV: CelestialVisual.unknownStarColorIndex, isConfirmed: true))
        XCTAssertNil(CelestialVisual.spokenStarColorLine(colorIndexBV: -0.30, isConfirmed: false))
    }
}
