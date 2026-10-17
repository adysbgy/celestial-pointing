import XCTest
import CelestialEngine
@testable import PointingKit

/// Nama objek yang tampil ke pengguna harus **melewati katalog string**.
///
/// **Cacat yang ditutup berkas ini.** `EphemerisBody.displayName`
/// membekukan bentuk Bahasa Indonesia (`"Saturnus"`, `"Bulan"`,
/// `"Merkurius"`, `"Matahari"`) dan kata itu dipakai apa adanya sebagai
/// judul kartu, versi always-on, headline komplikasi, serta baris
/// Diagnostics. Sebelum berkas ini ada, saat bahasa perangkat English
/// app menampilkan `Moon` berdampingan dengan `Saturnus` — dua nama
/// untuk benda yang sama, dalam dua bahasa, dalam satu layar.
///
/// **Kenapa ini penting dan tak terlihat oleh gerbang yang ada.**
/// Aturan 4 `swift-ui-lint.sh` hanya menyapu literal `Text("...")` di
/// `Apps/`, sedangkan nama ini datang dari **data engine**. Aturan 6
/// hanya memeriksa kunci `LocalizedText`, sedangkan `displayName` bukan
/// kunci sama sekali — ia nilai biasa. Kelas cacat ini buta terhadap
/// seluruh linter yang ada, jadi butuh gerbang sendiri.
final class LocalizedObjectNameTests: XCTestCase {

    /// Bentuk Inggris yang diharapkan tiap benda.
    ///
    /// Ditulis penuh di sini, bukan diturunkan dari katalog, supaya
    /// pengujian benar-benar menguji penerjemahan dan bukan menguji
    /// tebakannya sendiri.
    private static let expectedEnglish: [EphemerisBody: String] = [
        .sun: "Sun",
        .moon: "Moon",
        .mercury: "Mercury",
        .venus: "Venus",
        .mars: "Mars",
        .jupiter: "Jupiter",
        .saturn: "Saturn",
        .uranus: "Uranus",
        .neptune: "Neptune",
    ]

    override func tearDown() {
        // Satu pengujian yang memasang `Lookup` tidak boleh bocor ke
        // pengujian berikutnya: kebocoran akan muncul sebagai teks yang
        // benar secara tak sengaja, bukan sebagai kegagalan.
        TextLocalization.reset()
        super.tearDown()
    }

    // MARK: - Setiap benda harus lewat katalog

    /// Setiap benda tata surya harus punya kunci katalog sendiri.
    ///
    /// Kunci wajib ber-namespace: kalau teksnya sendiri yang jadi kunci,
    /// `Saturnus` bisa menyatu diam-diam dengan kalimat lain yang
    /// kebetulan sama — persis cacat yang dijelaskan di
    /// `LocalizedText.rawValue`.
    func testEveryBodyHasItsOwnNamespacedCatalogKey() {
        let keys = EphemerisBody.allCases.map { BodyName.catalogKey(for: $0) }

        XCTAssertEqual(
            keys.count, Set(keys).count,
            "Dua benda berbagi satu kunci katalog"
        )
        for (body, key) in zip(EphemerisBody.allCases, keys) {
            XCTAssertTrue(
                key.hasPrefix("object.body."),
                "\(body) memakai kunci di luar namespace: \(key)"
            )
            XCTAssertFalse(
                key.contains(" "),
                "Kunci \(key) memuat spasi, jadi bisa menyatu dengan kalimat lain"
            )
        }
    }

    /// Nilai bawaan Indonesia harus **persis** `displayName`.
    ///
    /// Ini yang menjaga agar teks tak pernah melenceng dari basis data:
    /// basis data yang sumber, bukan salinan yang ditulis ulang tangan.
    func testIndonesianDefaultIsExactlyTheEngineName() {
        for body in EphemerisBody.allCases {
            XCTAssertEqual(
                BodyName.declaration(for: body).indonesian,
                body.displayName,
                "Teks default \(body) tidak sama dengan displayName"
            )
        }
    }

    /// Tanpa app terpasang (persis kondisi Linux), teks tetap Indonesia,
    /// tidak pernah kosong, dan tidak pernah menampakkan pengenal mentah.
    func testWithoutInstalledLookupTextIsIndonesianAndNeverEmpty() {
        TextLocalization.reset()

        for body in EphemerisBody.allCases {
            let text = BodyName.text(body)
            XCTAssertFalse(text.isEmpty, "\(body) menghasilkan teks kosong")
            XCTAssertFalse(
                text.hasPrefix("object.body."),
                "\(body) menampakkan pengenal mentah: \(text)"
            )
            XCTAssertEqual(text, body.displayName)
        }
    }

    // MARK: - Bentuk cacat yang nyata

    /// **Inilah cacatnya.** Dengan katalog terpasang, nama yang punya
    /// padanan Inggris harus berubah: `Saturnus` menjadi `Saturn`,
    /// `Bulan` menjadi `Moon`, `Matahari` menjadi `Sun`, dan
    /// `Merkurius` menjadi `Mercury`.
    ///
    /// Kalau pengujian ini gagal, berarti nama masih keluar dari data
    /// mentah — persis yang terjadi sebelum `BodyName` ada.
    func testIndonesianNameDoesNotSurviveIntoEnglish() {
        let expected = Self.expectedEnglish
        var byKey: [String: String] = [:]
        for (body, name) in expected {
            byKey[BodyName.catalogKey(for: body)] = name
        }
        let table = byKey
        TextLocalization.install { table[$0] }

        for (body, name) in expected {
            XCTAssertEqual(
                BodyName.text(body),
                name,
                "\(body) belum diterjemahkan ke Inggris"
            )
        }
    }

    /// Bentuk Indonesia dan Inggris **tak boleh sama persis** untuk
    /// keempat benda ini. Kesamaan itu justru gejala cacatnya: kalau
    /// `Saturnus` dan `Saturn` ternyata identik, salah satu dari keduanya
    /// bukan terjemahan dan pengujian sebelumnya sudah menyesatkan.
    func testTheFourFrozenNamesActuallyDifferBetweenLanguages() {
        let frozen: [(EphemerisBody, String)] = [
            (.sun, "Matahari"), (.moon, "Bulan"),
            (.mercury, "Merkurius"), (.saturn, "Saturnus"),
        ]
        for (body, indonesian) in frozen {
            let english = Self.expectedEnglish[body]
            XCTAssertNotEqual(
                BodyName.declaration(for: body).indonesian, english,
                "\(body): bentuk dua bahasa sama persis, salah satunya bukan terjemahan"
            )
            XCTAssertEqual(
                BodyName.declaration(for: body).indonesian, indonesian,
                "\(body) tak lagi memakai nama yang dibekukan engine"
            )
        }
    }

    // MARK: - Sumber terjemahan yang salah harus ditolak, bukan dipercaya

    /// **Gerbang yang benar-benar menangkap cacatnya.** Titik yang rusak
    /// bukan `BodyName` — itu fungsi baru yang belum ada. Yang rusak adalah
    /// pemanggilnya: `DisplayLabel.objectName(forObjectID:)` mengembalikan
    /// `body.displayName` mentah, jadi nama Bahasa Indonesia ikut ke layar
    /// apa adanya.
    ///
    /// Pengujian di atas akan tetap hijau walau pemanggilnya dibiarkan
    /// mentah, karena ia hanya memeriksa `BodyName`. Yang mengikat di sini
    /// adalah jalur yang benar-benar dipakai layar.
    func testTheCallSiteUsedByScreensAlsoLocalizes() {
        var byKey: [String: String] = [:]
        for (body, name) in Self.expectedEnglish {
            byKey[BodyName.catalogKey(for: body)] = name
        }
        let table = byKey
        TextLocalization.install { table[$0] }

        // `catalogue` sengaja kosong: ini persis jalur benda tata surya,
        // karena planet tidak ada di katalog bintang.
        let empty: [CelestialObject] = []
        XCTAssertEqual(
            DisplayLabel.objectName(forObjectID: "saturn", catalogue: empty), "Saturn",
            "objectName masih membekukan bentuk Indonesia ke layar"
        )
        XCTAssertEqual(
            DisplayLabel.objectNameOrIdentifier(forObjectID: "moon", catalogue: empty), "Moon",
            "objectNameOrIdentifier masih membekukan bentuk Indonesia ke layar"
        )
    }

    /// Kalibrasi dan laporan Experiment 1 memakai bentuk yang mengembalikan
    /// nama, jadi keduanya ikut tercakup — dan harus tetap begitu.
    func testBodiesStillResolveWhenNoCatalogueIsLoaded() {
        for body in EphemerisBody.allCases {
            XCTAssertEqual(
                DisplayLabel.objectName(forObjectID: body.rawValue, catalogue: []),
                body.displayName,
                "\(body) tak bisa ditemukan tanpa katalog"
            )
        }
    }

    /// `Bundle.localizedString` tidak pernah mengembalikan `nil`: kunci
    /// yang hilang justru dikembalikan sebagai `value`. Sistem harus
    /// bisa membedakan "katalog tidak punya ini" dari "katalog punya ini",
    /// kalau tidak pengenal mentah muncul sebagai teks di layar.
    func testLookupReturningTheKeyItselfIsRejected() {
        TextLocalization.install { key in key }

        for body in EphemerisBody.allCases {
            XCTAssertEqual(
                BodyName.text(body),
                body.displayName,
                "\(body) menampilkan pengenal mentah, bukan nama benda"
            )
        }
    }

    /// Sumber terjemahan yang mengembalikan string kosong juga ditolak:
    /// baris kosong membuat layar tampak rusak tanpa penjelasan.
    func testLookupReturningEmptyStringIsRejected() {
        TextLocalization.install { _ in "" }

        for body in EphemerisBody.allCases {
            XCTAssertEqual(
                BodyName.text(body),
                body.displayName,
                "\(body) menghasilkan teks kosong dari sumber terjemahan"
            )
        }
    }

    // MARK: - Jalur cadangan `ObjectDetailView` (cacat siklus ini)

    /// `ObjectDisplayName.text(of:)` — jalur yang dipakai `ObjectDetailView`
    /// saat `displayName` tidak diteruskan — **wajib melokalkan**.
    ///
    /// **Cacat yang diuji di sini.** `ObjectDetailView.objectDisplayName`
    /// (PointingView.swift) berbunyi `displayName ?? object.name`. Selama
    /// pemanggilnya di `PointingView` meneruskan `engine.displayedObjectName`,
    /// cabang `??` tidak pernah diambil — jadi cacatnya tidak terlihat. Ia
    /// hanya muncul untuk pemanggil yang **tidak** meneruskan namanya, dan
    /// di sanalah judul terbesar di kartu berubah menjadi bentuk engine
    /// yang membeku (`Saturnus`, `Bulan`) sementara badge dan baris jenis di
    /// sebelahnya berbahasa perangkat.
    ///
    /// **Kenapa `ObjectDisplayName.text(of:)` dan bukan
    /// `DisplayLabel.objectName(forObjectID:)`.** Panel itu tidak punya
    /// akses katalog (katalognya milik resolver), sedangkan
    /// `DisplayLabel.objectName` **menuntut** katalog sebagai parameter
    /// justru supaya label tidak diambil dari katalog yang salah. Accessor
    /// ini bekerja dari nama yang sudah dipasang engine, dan objek di tangan
    /// panel adalah sumber yang sama dengan yang dipertimbangkan engine —
    /// jadi tidak ada katalog kedua yang bisa berbeda pendapat.
    ///
    /// Uji ini **merah pada `object.name`** (bentuk Indonesia yang dibekukan)
    /// dan hijau hanya bila nama melewati accessor. Itu yang membuatnya
    /// menyematkan perbaikan, bukan sekadar menyetujui dirinya sendiri.
    func testDetailViewFallbackLocalizesTheEngineName() {
        var byKey: [String: String] = [:]
        for (body, name) in Self.expectedEnglish {
            byKey[BodyName.catalogKey(for: body)] = name
        }
        let table = byKey
        TextLocalization.install { table[$0] }

        for body in EphemerisBody.allCases {
            // Bentuk yang **dulu** dipakai cabang `??` di view.
            let raw = CelestialObject(
                id: body.rawValue, name: body.displayName, kind: .planet,
                raDeg: 0, decDeg: 0, magnitude: 0)
            XCTAssertEqual(
                raw.name, body.displayName,
                "prasyarat: nama engine memang bentuk Indonesia yang dibekukan"
            )
            // Hanya benda yang **punya** terjemahan berbeda dari bentuk
            // Indonesianya yang bisa dituntut berubah. `Venus` dan `Mars`
            // sama di dua bahasa, dan menuntut perubahan di sana akan
            // membuat uji ini merah karena sebab yang salah.
            guard let english = Self.expectedEnglish[body], english != raw.name
            else { continue }
            XCTAssertNotEqual(
                ObjectDisplayName.text(of: raw), raw.name,
                "\(body): cabang `?? object.name` membekukan bentuk Indonesia "
                + "ke judul kartu"
            )
            XCTAssertEqual(ObjectDisplayName.text(of: raw), english)
        }
    }

    /// Kontrol negatif: nama yang **tidak** punya terjemahan dikembalikan
    /// apa adanya, bukan dibuang atau dikarang.
    ///
    /// Tanpa kontrol ini, uji di atas bisa "lulus" oleh accessor yang
    /// mengembalikan string kosong untuk semua benda — dan judul kartu yang
    /// kosong lebih buruk daripada judul berbahasa salah.
    func testDetailViewFallbackKeepsNamesWithoutTranslation() {
        let sirius = CelestialObject(
            id: "sirius", name: "Sirius", kind: .star,
            raDeg: 101.3, decDeg: -16.7, magnitude: -1.4)
        XCTAssertEqual(ObjectDisplayName.text(of: sirius), "Sirius")
    }
}