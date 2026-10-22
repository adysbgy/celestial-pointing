import XCTest
import CelestialEngine
@testable import PointingKit

/// Uji untuk `LinkReport` — isi kolom laporan jam di iPhone.
///
/// **Cacat yang dijaga.** Sampai siklus ini kolom-kolom bagian "keadaan
/// terakhir dari jam" ditulis langsung di badan `LinkView`, dan tidak satu pun
/// dari 87 aturan UI membacanya (gerbangnya bekerja pada **teks** dan pada
/// **gambar**). Terukur, bukan diduga: menghapus seluruh cabang σ dari view —
/// baris yang baru saja ditambahkan siklus sebelumnya — meninggalkan 87 aturan
/// hijau dan `swift-typecheck.sh` exit 0.
///
/// Kerugiannya bukan hipotetis. `PointingLinkMessage` mengirim `altitudeDeg`
/// dan `azimuthDeg` di **setiap** pesan keadaan, dan tidak ada satu baris pun
/// di iPhone yang menampilkannya sejak awal. Medan yang dikirim tapi tidak
/// pernah dibaca tidak bisa dibedakan dari medan yang lupa dibaca.
///
/// Karena itu uji di bawah mengukur **baris mana yang ada dan apa isinya**,
/// bukan "view memanggil fungsi". Yang diuji adalah perilaku produk: layar
/// yang menjelaskan laporan jam wajib menyebut setiap fakta yang dilaporkan.
final class LinkReportTests: XCTestCase {

    // MARK: - Bahan

    private func message(state: PointingState = .lock,
                         objectID: String? = "jupiter",
                         objectName: String? = "Jupiter",
                         level: ConfidenceLevel? = .high,
                         altitude: Double? = 42.5,
                         azimuth: Double? = 118.0,
                         rate: Double? = 0.5,
                         sigma: Double? = 1.2,
                         isCalibrated: Bool? = true) -> PointingLinkMessage {
        PointingLinkMessage(
            kind: .pointingState,
            sentAt: Date(timeIntervalSince1970: 1_700_000_000),
            state: state,
            objectID: objectID,
            objectName: objectName,
            level: level,
            altitudeDeg: altitude,
            azimuthDeg: azimuth,
            angularRateDegPerSec: rate,
            pointingSigmaDeg: sigma,
            isCalibrated: isCalibrated
        )
    }

    private var catalogue: [CelestialObject] {
        [
            CelestialObject(id: "jupiter", name: "Jupiter", kind: .planet,
                            raDeg: 0, decDeg: 0, magnitude: -2.0),
            CelestialObject(id: "saturnus", name: "Saturnus", kind: .planet,
                            raDeg: 0, decDeg: 0, magnitude: 1.0),
        ]
    }

    private func titles(_ rows: [LinkReport.Row]) -> [String] {
        rows.map(\.title)
    }

    // MARK: - Arah tunjuk yang dilaporkan jam

    /// **Uji inti siklus ini.** Arah yang dikirim jam wajib menjadi baris.
    ///
    /// Sebelum perbaikan, tidak ada baris apa pun yang memuat ketinggian atau
    /// azimut, jadi uji ini merah pada kode lama — bukan hijau secara vakum.
    func testDirectionRowCarriesTheAltitudeAndAzimuthTheWatchSent() {
        let rows = LinkReport.stateRows(message(altitude: 42.5, azimuth: 118.0),
                                       catalogue: catalogue)
        let direction = rows.first { $0.title == TextLocalization.text(.linkRowDirection) }
        XCTAssertNotNil(direction, "Arah tunjuk yang dikirim jam tidak pernah menjadi baris")
        guard let direction else { return }
        // Nilainya **kedua** angka itu, dalam urutan yang disebut judulnya.
        XCTAssertTrue(direction.value.contains(NumberFormat.degrees(42.5)),
                      "Ketinggian yang dikirim jam hilang dari baris arah: \(direction.value)")
        XCTAssertTrue(direction.value.contains(NumberFormat.degrees(118.0)),
                      "Azimut yang dikirim jam hilang dari baris arah: \(direction.value)")
    }

    /// Arah yang **tidak** dikirim tidak boleh muncul sebagai baris kosong
    /// atau setengah pasangan.
    ///
    /// Setengah pasangan akan tertulis `42,5° / —`, yang terbaca seperti
    /// azimut yang gagal diukur — padahal artinya pesan itu tidak membawa
    /// arah sama sekali. Dua keadaan berbeda tidak boleh punya satu tampilan.
    func testHalfADirectionIsNotRenderedAsAMeasuredValue() {
        for (altitude, azimuth) in [(42.5, nil), (nil, 118.0)] as [(Double?, Double?)] {
            let rows = LinkReport.stateRows(
                message(altitude: altitude, azimuth: azimuth), catalogue: catalogue)
            XCTAssertFalse(
                titles(rows).contains(TextLocalization.text(.linkRowDirection)),
                "Arah setengah (\(String(describing: altitude)) / "
                + "\(String(describing: azimuth))) dirender sebagai pengukuran")
        }
    }

    /// Arah yang tidak berhingga juga bukan pengukuran.
    func testNonFiniteDirectionIsNotRendered() {
        let rows = LinkReport.stateRows(
            message(altitude: .nan, azimuth: 118.0), catalogue: catalogue)
        XCTAssertFalse(titles(rows).contains(TextLocalization.text(.linkRowDirection)))
    }

    // MARK: - Sigma

    /// σ yang tidak berhingga atau ≤ 0 **tidak boleh** tercetak sebagai
    /// akurasi. Ini bukan kasus teoretis: jam mengirim σ = 0 ketika ia tidak
    /// menyertakannya, dan `0,0°` terbaca seperti akurasi sempurna.
    func testSigmaRowOnlyAppearsWhenItIsAnActualMeasurement() {
        for bad in [0.0, -1.0, .nan, .infinity] {
            let rows = LinkReport.stateRows(message(sigma: bad), catalogue: catalogue)
            XCTAssertFalse(titles(rows).contains(TextLocalization.text(.linkRowSigma)),
                           "σ = \(bad) dirender sebagai akurasi")
        }
        let rows = LinkReport.stateRows(message(sigma: 1.2), catalogue: catalogue)
        let sigma = rows.first { $0.title == TextLocalization.text(.linkRowSigma) }
        XCTAssertNotNil(sigma, "σ terukur justru tidak tampil")
        XCTAssertEqual(sigma?.value, NumberFormat.degrees(1.2))
    }

    // MARK: - Laju

    /// Bentuk **ucapan** laju dibentuk dari angka yang sama dengan bentuk
    /// tulisnya, oleh `RowSpeech`.
    ///
    /// Diuji di `RowSpeech` bukan di `LinkReport`: `Row` sekarang hanya
    /// membawa judul dan nilai (lihat alasannya di sana), dan yang membentuk
    /// kalimat pengumuman adalah `row(...)` di view. Yang dijaga di sini
    /// adalah separuh yang tetap milik laporan — **angka yang tampil** sama
    /// dengan angka yang diucapkan.
    func testRateRowShowsTheSameNumberThatIsSpoken() {
        let rows = LinkReport.stateRows(message(rate: 0.5), catalogue: catalogue)
        let rate = rows.first { $0.title == TextLocalization.text(.linkRowRate) }
        XCTAssertNotNil(rate)
        guard let rate else { return }
        XCTAssertEqual(rate.value, NumberFormat.degreesPerSecond(0.5))
        XCTAssertTrue(rate.value.contains("0,5"),
                      "Nilai laju yang tampil bukan angka yang dikirim: \(rate.value)")
    }

    /// Bentuk ucapnya benar-benar berbeda dari bentuk tulisnya.
    ///
    /// Kalau keduanya sama, `RowSpeech.spokenRate` tidak menambah apa pun dan
    /// pengguna pembaca layar mendengar simbol "°/dtk".
    func testSpokenRateDiffersFromItsWrittenForm() {
        let written = NumberFormat.degreesPerSecond(0.5)
        XCTAssertNotEqual(RowSpeech.spokenRate(0.5), written)
    }

    // MARK: - Urutan & kelengkapan

    /// Jawaban lebih dulu, detail teknis kemudian.
    ///
    /// Ini keputusan produk, bukan selera: layar ini menjelaskan laporan, dan
    /// pembaca yang berhenti di baris ketiga harus sudah melihat apa yang
    /// dilihat jam. Urutan yang terbalik menaruh waktu pengiriman di atas
    /// nama objek.
    func testAnswerComesBeforeTechnicalDetail() {
        let rows = LinkReport.stateRows(message(), catalogue: catalogue)
        let all = titles(rows)
        func index(_ text: String) -> Int? { all.firstIndex(of: text) }

        guard let state = index(TextLocalization.text(.linkRowState)),
              let object = index(TextLocalization.text(.linkRowObject)),
              let time = index(TextLocalization.text(.linkRowTime)) else {
            return XCTFail("Baris wajib hilang: \(all)")
        }
        XCTAssertLessThan(state, object, "Keadaan harus di atas objek")
        XCTAssertLessThan(object, time, "Objek harus di atas waktu")
    }

    /// Nama objek memakai katalog **pembaca**, bukan nama beku dari jam.
    ///
    /// Sudah diuji di `LinkMessageTests` untuk `reportedObjectName`; diulang
    /// di sini karena `LinkReport` adalah pemanggil barunya, dan pemanggil
    /// yang lupa meneruskan katalog akan mengembalikan nama beku tanpa satu
    /// pun uji lain merah.
    func testObjectRowUsesTheReadersCatalogue() {
        let english = PointingLinkMessage(
            kind: .pointingState, sentAt: Date(timeIntervalSince1970: 1_700_000_000),
            state: .lock, objectID: "jupiter", objectName: "Jupiter",
            level: .high, altitudeDeg: 10, azimuthDeg: 20)
        let rows = LinkReport.stateRows(english, catalogue: catalogue)
        let object = rows.first { $0.title == TextLocalization.text(.linkRowObject) }
        XCTAssertEqual(object?.value, "Jupiter")
        XCTAssertNotEqual(object?.value, "—", "Nama objek jatuh ke tanda kosong")
    }

    /// Setiap baris punya judul **dan** nilai yang tidak kosong.
    ///
    /// Baris dengan judul kosong akan tampil sebagai angka tanpa keterangan;
    /// nilai kosong tampil sebagai label tanpa isi. Keduanya lolos semua
    /// gerbang teks karena tidak ada teks yang hilang — hanya satu bagian
    /// dari pasangan.
    func testEveryRowIsACompletePair() {
        let rows = LinkReport.stateRows(message(), catalogue: catalogue)
        XCTAssertFalse(rows.isEmpty, "Laporan kosong — uji di bawah akan vakum")
        for row in rows {
            XCTAssertFalse(row.title.trimmingCharacters(in: .whitespaces).isEmpty,
                           "Baris tanpa judul: \(row.value)")
            XCTAssertFalse(row.value.trimmingCharacters(in: .whitespaces).isEmpty,
                           "Baris tanpa nilai: \(row.title)")
        }
    }

    /// Pesan tanpa keadaan tetap menghasilkan baris yang jujur.
    ///
    /// Yang tidak boleh terjadi: baris hilang seluruhnya (pembaca tidak tahu
    /// apa pun) atau nilai yang dikarang. Yang benar: baris tetap ada dengan
    /// tanda kosong, dan **tidak ada** baris arah/σ/laju — karena memang tidak
    /// ada yang dilaporkan.
    func testMessageWithoutStateKeepsItsShapeWithoutInventingValues() {
        let empty = PointingLinkMessage(kind: .pointingState,
                                        sentAt: Date(timeIntervalSince1970: 1_700_000_000))
        let rows = LinkReport.stateRows(empty, catalogue: catalogue)
        let all = titles(rows)
        XCTAssertTrue(all.contains(TextLocalization.text(.linkRowState)))
        XCTAssertTrue(all.contains(TextLocalization.text(.linkRowObject)))
        XCTAssertFalse(all.contains(TextLocalization.text(.linkRowDirection)))
        XCTAssertFalse(all.contains(TextLocalization.text(.linkRowSigma)))
        XCTAssertFalse(all.contains(TextLocalization.text(.linkRowRate)))
        for row in rows where row.title != TextLocalization.text(.linkRowTime) {
            XCTAssertEqual(row.value, "—", "Nilai dikarang untuk medan yang tidak ada")
        }
    }

    /// Arah diformat lewat `NumberFormat`, jadi pemisah desimalnya ikut
    /// bahasa pembaca.
    ///
    /// Di bahasa Indonesia `42,5` — dan `42.5` dibaca sebagai empat ratus dua
    /// puluh lima. Baris ini baru, jadi ia harus lahir benar.
    func testDirectionUsesTheReadersDecimalSeparator() {
        NumberFormat.install(localeId: "id_ID")
        defer { NumberFormat.reset() }
        let text = LinkReport.directionText(altitudeDeg: 42.5, azimuthDeg: 118.0)
        XCTAssertTrue(text.contains("42,5"), "Pemisah desimal bukan bahasa pembaca: \(text)")
        XCTAssertFalse(text.contains("42.5"), "Titik desimal bocor di locale Indonesia: \(text)")
    }
}
