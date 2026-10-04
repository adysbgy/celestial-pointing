import XCTest
import CelestialEngine
@testable import PointingKit

/// Uji untuk frasa pengumuman panel objek (magnitudo, keyakinan, koordinat,
/// penanda "sisa").
///
/// **Kenapa ini diuji di Linux.** Frasa ini dulu hidup sebagai literal di
/// dalam `PointingView` (jam) dan `DiagnosticsView` (iPhone) — keduanya
/// menyusunnya lewat `String(format:)` dan `parts.append(…)` di dalam helper.
/// Bentuk itu bukan argumen langsung mana pun, jadi aturan 4 di
/// `./swift-ui-lint.sh` tidak pernah melihatnya, dan katalog string tidak bisa
/// menjangkaunya. Pengguna Bahasa Inggris mendengar "magnitudo 1.46" tanpa satu
/// pun gerbang merah.
///
/// Setelah dipindah ke `ObjectSpeech`, dua hal yang dulu tidak bisa diperiksa
/// menjadi bisa, dan keduanya di sini:
///
/// 1. **Kedua app membaca frasa yang sama** — salinan lama sudah mulai
///    berbeda, dan cukup satu diperbaiki agar pengguna dua app mendengar dua
///    kalimat berbeda untuk objek yang sama.
/// 2. **Frasanya punya kunci katalog** — `LocalizedText.allKeys` (dan karena
///    itu gerbang paritas Aturan 6) menjangkaunya.
///
/// Yang **tidak** bisa diuji di sini: apakah VoiceOver benar-benar
/// mengucapkannya. Itu wilayah perangkat.
final class ObjectSpeechTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TextLocalization.reset()
    }

    override func tearDown() {
        TextLocalization.reset()
        super.tearDown()
    }

    /// Magnitudo diucapkan dengan katanya, bukan angka telanjang.
    func testMagnitudeCarriesItsWord() {
        let spoken = ObjectSpeech.magnitude(-1.46)
        XCTAssertTrue(spoken.contains("magnitudo"),
                      "angka tanpa kata tidak memberi tahu apa pun saat diucapkan")
        XCTAssertTrue(spoken.contains("1.46") || spoken.contains("-1.46"),
                      "nilai magnitudonya harus ikut")
    }

    /// Penanda "sisa" tidak pernah kosong — tanpa ia, objek basi terdengar
    /// persis seperti hasil pengukuran sekarang.
    func testStaleNoteIsNeverEmptyAndSaysWhatItMeans() {
        let note = ObjectSpeech.staleNote
        XCTAssertFalse(note.isEmpty)
        XCTAssertFalse(note.contains("object.speech"),
                       "kunci katalog bocor ke suara")
        XCTAssertTrue(note.lowercased().contains("sisa")
                      || note.lowercased().contains("sebelumnya"),
                      "penanda sisa harus menyatakan bahwa ia bukan hasil sekarang")
    }

    /// Tingkat keyakinan diucapkan dengan katanya, dan nilainya ikut.
    func testConfidenceCarriesTheLevelName() {
        for level in [ConfidenceLevel.high, .medium, .low] {
            let spoken = ObjectSpeech.confidence(level)
            XCTAssertTrue(spoken.contains(level.displayName),
                          "\(level): nama tingkatnya harus ikut diucapkan")
            XCTAssertFalse(spoken.contains("object.speech"))
        }
    }

    /// Koordinat mengucapkan "RA" dan "deklinasi" lengkap, dan tanda deklinasi
    /// selatan ikut terbaca.
    ///
    /// Tanpa tanda, deklinasi −16.7 terbaca sama dengan +16.7 — dua titik
    /// langit yang berbeda 33 derajat.
    func testCoordinatesSpeakBothAxisNamesAndKeepTheSign() {
        let spoken = ObjectSpeech.coordinates(raDeg: 101.3, decDeg: -16.7)
        XCTAssertTrue(spoken.contains("RA"), "RA harus disebut lengkap")
        XCTAssertTrue(spoken.contains("deklinasi"), "deklinasi harus disebut lengkap")
        XCTAssertTrue(spoken.contains("-16.7") || spoken.contains("−16.7"),
                      "tanda deklinasi selatan tidak boleh hilang")
    }

    /// Keempat kunci ada di `allKeys`, jadi gerbang paritas (Aturan 6)
    /// memeriksanya terhadap `Localizable.xcstrings`.
    func testSpeechKeysAreDeclaredForTheCatalogParityGate() {
        let declared = Set(LocalizedText.allKeys.map(\.rawValue))
        for key in [LocalizedText.objectSpeechMagnitude,
                    .objectSpeechStale,
                    .objectSpeechConfidence,
                    .objectSpeechCoordinates] {
            XCTAssertTrue(declared.contains(key.rawValue),
                          "\(key.rawValue) tidak ada di allKeys — gerbang "
                          + "paritas tidak akan melihatnya")
        }
    }

    /// Terjemahan Inggris mengendalikan kata dan posisi sisipannya.
    func testEnglishTranslationControlsTheWordsAndInsertion() {
        TextLocalization.install { key in
            switch key {
            case "object.speech.magnitude": return "magnitude %.2f"
            case "object.speech.stale": return "From an earlier view, not a current reading."
            case "object.speech.confidence": return "confidence %@"
            case "object.speech.coordinates": return "RA %.1f degrees, declination %+.1f degrees"
            // Nilai yang disisipkan diterjemahkan sendiri, jadi ia harus punya
            // entri katalognya sendiri — kalau tidak, kalimatnya Inggris tapi
            // tingkat keyakinannya tetap Indonesia.
            case "confidence.level.high.label": return "Certain"
            default: return nil
            }
        }
        defer { TextLocalization.reset() }

        XCTAssertEqual(ObjectSpeech.magnitude(1.46), "magnitude 1.46")
        XCTAssertEqual(ObjectSpeech.confidence(.high), "confidence Certain")
        XCTAssertEqual(ObjectSpeech.staleNote,
                       "From an earlier view, not a current reading.")
        XCTAssertEqual(ObjectSpeech.coordinates(raDeg: 101.3, decDeg: -16.7),
                       "RA 101.3 degrees, declination -16.7 degrees")
    }

    /// Tanpa katalog terpasang (Linux), frasanya tetap Bahasa Indonesia dan
    /// tidak pernah kosong.
    func testDefaultsRemainIndonesianWithoutACatalog() {
        XCTAssertEqual(ObjectSpeech.magnitude(1.46), "magnitudo 1.46")
        XCTAssertEqual(ObjectSpeech.confidence(.high), "tingkat keyakinan Yakin")
        XCTAssertEqual(ObjectSpeech.staleNote,
                       "Sisa pandangan sebelumnya, bukan hasil sekarang.")
    }
}
