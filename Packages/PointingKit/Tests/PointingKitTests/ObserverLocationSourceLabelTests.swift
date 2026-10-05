import XCTest
@testable import PointingKit

/// Baris "Asal lokasi" tidak boleh menampilkan pengenal mesin.
///
/// **Kenapa kelas ini ada.** `ObserverLocation.source` adalah bentuk kabel:
/// ia diserialisasi ke JSON arsip (`ConfidenceTraceArchive`) dan dibandingkan
/// dengan `==`. Dua layar menampilkannya **apa adanya** ke baris yang judulnya
/// "Asal lokasi" — jadi pengguna membaca `corelocation` dan `fallback` di
/// tempat yang seharusnya menjawab "langit ini dihitung untuk mana?".
///
/// Ini cacat yang sama persis dengan dua yang sudah ditutup sebelumnya di
/// repo ini: `sirius` di headline Experiment 1 (`DisplayLabel`) dan
/// `stateRequest` di layar Tautan (`LinkMessageKind.displayName`). Yang
/// membuatnya bertahan lama juga sama: **tidak ada gerbang yang melihatnya**.
/// Aturan 4 menyapu literal di dalam argumen `Text(...)`; nilai ini datang
/// dari properti, bukan literal, jadi sapuannya kosong. Aturan 6 hanya
/// memeriksa kunci yang dideklarasikan, dan kuncinya belum ada.
///
/// Yang dijaga di sini bukan "ada labelnya", melainkan dua sifat yang lebih
/// mudah hilang diam-diam:
///   1. Tidak ada nilai `source` yang dikenal yang tampil apa adanya.
///   2. Nilai `source` yang **tidak** dikenal tidak disembunyikan — karena
///      baris ini dipakai untuk memutuskan apakah langitnya bisa dipercaya.
final class ObserverLocationSourceLabelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TextLocalization.reset()
    }

    override func tearDown() {
        TextLocalization.reset()
        super.tearDown()
    }

    private func make(source: String) -> ObserverLocation {
        ObserverLocation(latitudeDeg: -6.2, longitudeDeg: 106.8,
                         label: "x", source: source)
    }

    /// Sumber yang dikenal tidak pernah tampil sebagai pengenalnya.
    ///
    /// **Kenapa bandingannya persis, bukan case-insensitive — dan ini ketemu
    /// dari uji ini sendiri, bukan dipikirkan dulu.** Versi pertama memakai
    /// `lowercased()` di kedua sisi dengan alasan "huruf besar-kecil tidak
    /// mengubah bahwa ia terbaca mesin". Alasan itu salah, dan uji membuktikan
    /// salahnya pada `simulator`: nilai bakunya "Simulator", dan satu-satunya
    /// yang membedakan label itu dari pengenalnya adalah huruf kapitalnya.
    /// Kapitalisasi justru **cara** pengenal menjadi label — jadi
    /// case-insensitive akan menuntut label yang berbeda kata dari sumbernya
    /// untuk setiap kasus, termasuk yang memang sudah benar.
    ///
    /// Yang mau ditangkap adalah pengenal yang tak bisa dibaca
    /// (`corelocation`, `fallback`), dan itu persis yang dibedakan oleh
    /// perbandingan persis. Batasnya dicatat, bukan disembunyikan: bila suatu
    /// hari ada sumber yang nilainya memang satu kata yang sama dengan
    /// pengenalnya, itu keputusan yang harus diambil sadar — bukan dengan
    /// melonggarkan perbandingan.
    func testNoKnownSourceIsRenderedAsItsOwnIdentifier() {
        let sources = ["corelocation", ObserverLocation.fallbackSource,
                       "manual"]
        for source in sources {
            let shown = make(source: source).sourceDisplayName
            XCTAssertNotEqual(shown, source,
                              "source '\(source)' tampil apa adanya di layar")
            XCTAssertFalse(shown.isEmpty, "source '\(source)' tanpa label")
        }
    }

    /// Sumber tak dikenal **tetap menyebut sumbernya**.
    ///
    /// Kalau yang tak dikenal jatuh ke satu kata "Tidak diketahui" saja, dua
    /// sumber berbeda (mis. arsip dari versi lama vs nilai baru) tampak
    /// identik — padahal baris ini justru yang dipakai untuk memutuskan
    /// apakah langitnya dihitung untuk tempat yang benar.
    func testUnknownSourceKeepsNamingItself() {
        let shown = make(source: "horizons_reference").sourceDisplayName
        XCTAssertTrue(shown.contains("horizons_reference"),
                      "sumber tak dikenal kehilangan namanya: \(shown)")
    }

    /// Dua sumber berbeda tidak boleh menghasilkan label yang sama.
    ///
    /// Ini yang membuat uji di atas bermakna: kalau `switch`-nya jatuh ke
    /// `default` untuk semuanya, tiap label akan berbeda hanya karena namanya
    /// ikut disisipkan — dan barisnya kembali ke keadaan "pengenal mesin".
    func testKnownSourcesAreDistinguishable() {
        let labels = ["corelocation", ObserverLocation.fallbackSource,
                      "manual", "simulator"].map {
            make(source: $0).sourceDisplayName
        }
        XCTAssertEqual(Set(labels).count, labels.count,
                       "dua sumber berbeda memakai label yang sama: \(labels)")
    }

    /// Terjemahan mengendalikan katanya — bukan nilai bawaan.
    ///
    /// Alasan uji ini ada: tanpa bridge, `text()` mengembalikan Bahasa
    /// Indonesia, dan seluruh uji di atas akan hijau sekalipun katalog tidak
    /// pernah dibaca. Yang dibuktikan di sini bahwa katalog **dipakai**.
    func testEnglishTranslationControlsTheWords() {
        let english: [String: String] = [
            "location.source.corelocation": "Device GPS",
            "location.source.fallback": "Default (not your location)",
            "location.source.manual": "Entered manually",
            "location.source.simulator": "Simulator",
            "location.source.unknown": "Unknown (%@)",
        ]
        EnglishTranslation.install(english)

        XCTAssertEqual(make(source: "corelocation").sourceDisplayName, "Device GPS")
        XCTAssertEqual(make(source: ObserverLocation.fallbackSource).sourceDisplayName,
                       "Default (not your location)")
        XCTAssertEqual(make(source: "manual").sourceDisplayName, "Entered manually")
        XCTAssertEqual(make(source: "simulator").sourceDisplayName, "Simulator")
        XCTAssertEqual(make(source: "apa-itu").sourceDisplayName, "Unknown (apa-itu)")
    }

    /// Bentuk kabel tidak boleh ikut berubah demi tampilan.
    ///
    /// `source` diserialisasi ke arsip yang sudah tersimpan dan dibandingkan
    /// dengan `==` (`isFallback`, `ConfidenceTraceArchiveTests`). Mengganti
    /// nilainya adalah cara termurah untuk "memperbaiki" baris ini, dan cara
    /// paling cepat membuat arsip lama tidak terbaca.
    func testWireValueIsUnchanged() {
        XCTAssertEqual(ObserverLocation.fallbackSource, "fallback")
        XCTAssertEqual(make(source: "corelocation").source, "corelocation")
    }
}
