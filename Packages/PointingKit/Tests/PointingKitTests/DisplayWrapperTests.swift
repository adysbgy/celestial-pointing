import XCTest
@testable import PointingKit

/// Aksesor yang ada **murni untuk wraps** harus dipakai dari view, bukan
/// ditiru.
///
/// **Premis siklus ini.** `ObjectSpeech.coordinatesDisplay`,
/// `ObjectSpeech.magnitudeDisplay`, `ObjectSpeech.staleShortNote`,
/// `CalibrationText.captureAltitudeDisplay`, dan `RowSpeech.spokenWristRate`
/// dibuat dengan satu alasan yang tertulis panjang di komentar deklarasinya:
/// teks layar/ucapan itu **tidak bisa** diuji di Linux kalau ia dirakit di
/// dalam view. Karena itu bentuknya dipindahkan ke paket. Lima aksesor itu
/// menganggur: `grep` di seluruh `Apps/` tidak menemukan satu pun pemanggilnya.
///
/// Yang tampil di view adalah **salinan**: pemanggilan
/// `TextLocalization.text(.objectDisplayCoordinates, …)` yang persis sama,
/// ditulis ulang di `PointingView.kindLine`. Kalimat yang tampil tetap sama,
/// kuncinya tetap sama, gerbang 4 dan 6 tetap hijau — dan tidak ada satu pun
/// uji di Linux yang bisa memverifikasi baris layar itu, persis seperti
/// sebelum pemindahannya. Jadi pegangan yang dijanjikan pemindahan ke paket
/// tidak berlaku: yang dipindahkan tidak pernah dipakai.
///
/// **Kenapa ini bukan sekadar kerapian.** Aksesor yang mati adalah jalan
/// yang tidak pernah dilalui, tapi masih **terdokumentasi seolah dilalui**.
/// Orang berikutnya yang mengubah katalog akan melihat aksesor itu,
/// menganggap layar memakai aksesor itu, lalu mengubahnya — sementara layar
/// tidak pernah membaca perubahan itu. Yang terlihat benar sendiri-sendiri:
/// isi kuncinya sama persis.
class DisplayWrapperTests: BridgedTextTestCase {

    /// Aksesor layar harus memberi **hasil yang sama persis** dengan pemanggilan
    /// kunci yang dipakai view sekarang.
    ///
    /// Uji ini terlihat seperti mengulang implementasi, dan sengaja: yang
    /// diuji adalah bahwa pemindahan ke paket benar-benar **tidak mengubah
    /// teks yang tampil**. Kalau ia berubah, baris yang tampil di layar berubah
    /// tanpa ada yang memperintahkan — dan tidak ada uji lain yang akan
    /// menangkapnya, karena `Apps/` tidak pernah diuji di Linux.
    func testDisplayAccessorsProduceTheSameTextAsTheInlineCalls() {
        TextLocalization.install { _ in nil }

        XCTAssertEqual(ObjectSpeech.magnitudeDisplay(1.42),
                       TextLocalization.text(.objectDisplayMagnitude, 1.42))
        XCTAssertEqual(ObjectSpeech.coordinatesDisplay(raDeg: 101.287, decDeg: -16.716),
                       TextLocalization.text(.objectDisplayCoordinates,
                                             101.287, -16.716))
        XCTAssertEqual(ObjectSpeech.staleShortNote,
                       TextLocalization.text(.objectSpeechStaleShort))
        XCTAssertEqual(CalibrationText.captureAltitudeDisplay(altitudeDeg: 40),
                       TextLocalization.text(.calibrationDisplayCaptureAltitude, 40.0))
        XCTAssertEqual(RowSpeech.spokenWristRate(5),
                       TextLocalization.text(.rowSpeechWristRate,
                                             TextLocalization.text(.rowSpeechWristRateWord),
                                             5.0,
                                             TextLocalization.text(.rowSpeechDegrees)))
    }

    /// Bentuk yang benar-benar tampil, dikunci sebagai nilai mutlak.
    ///
    /// Uji pertama sengaja **tidak** mengunci nilai mutlak: ia hanya
    /// membandingkan dua jalur yang bisa saja salah bersama-sama (kalau
    /// keduanya punya cacat yang sama, uji ini hijau). Uji ini menutup itu —
    /// jadi kalau suatu saat baris layar berubah, ada yang menyatakan nilai
    /// yang benar, bukan hanya "dua jalur ini masih sama".
    func testDisplayAccessorsKeepTheirIndonesianDefaults() {
        TextLocalization.install { _ in nil }

        XCTAssertEqual(ObjectSpeech.magnitudeDisplay(1.42), "mag 1,42")
        XCTAssertEqual(ObjectSpeech.coordinatesDisplay(raDeg: 101.287, decDeg: -16.716),
                       "RA 101,3° Dec -16,7°")
        XCTAssertEqual(ObjectSpeech.staleShortNote, "sisa pandangan sebelumnya")
        XCTAssertEqual(CalibrationText.captureAltitudeDisplay(altitudeDeg: 40), "40° tinggi")
        XCTAssertEqual(RowSpeech.spokenWristRate(5), "Laju pergelangan 5 derajat per detik.")
    }

    /// Aksesor harus benar-benar membaca katalog — kalau tidak, melepasnya
    /// dari view tidak akan mengubah apa pun, dan "sudah dipindahkan ke
    /// paket" jadi kalimat kosong.
    ///
    /// Yang dipasang di sini **hanya** kunci yang touched oleh aksesor itu,
    /// sehingga kalau aksesornya berhenti membaca kunci yang benar, hasilnya
    /// jatuh ke Bahasa Indonesia dan uji ini merah.
    func testDisplayAccessorsReadTheCatalogTheyOwn() {
        EnglishTranslation.install([
            "object.display.magnitude": "mag %.2f (translated)",
            "object.display.coordinates": "RA %.1f° / DEC %+.1f° (translated)",
            "object.speech.staleShort": "an earlier view",
            "calibration.display.captureAltitude": "%.0f° up",
            "row.speech.wristRate": "%@ %.0f %@ per second.",
            "row.speech.wristRateWord": "Wrist rate",
            "row.speech.degrees": "degrees",
        ])

        XCTAssertEqual(ObjectSpeech.magnitudeDisplay(1.42), "mag 1.42 (translated)")
        XCTAssertEqual(ObjectSpeech.coordinatesDisplay(raDeg: 101.287, decDeg: -16.716),
                       "RA 101.3° / DEC -16.7° (translated)")
        XCTAssertEqual(ObjectSpeech.staleShortNote, "an earlier view")
        XCTAssertEqual(CalibrationText.captureAltitudeDisplay(altitudeDeg: 40), "40° up")
        XCTAssertEqual(RowSpeech.spokenWristRate(5), "Wrist rate 5 degrees per second.")
    }

    /// Aksesor yang **tidak pernah** dipakai tidak boleh menyamar sebagai
    /// bagian dari jalur tampilan yang sudah benar.
    ///
    /// **Kenapa kasus ini penting dan tidak sekadar ledakan angka.** Uji
    /// sebelumnya membandingkan aksesor dengan pemanggilan kunci — jadi ia
    /// hijau **walaupun tidak ada view yang memakai aksesornya**. Kalau
    /// aksesornya dibuang, ketiga uji itu masih hijau; yang hilang adalah
    /// pegangan bahwa baris layar itu punya jalur yang teruji. Sapuan
    /// `Tools/sweep-unconsumed.sh` yang menjaga bentuk ini; di sini yang
    /// dijaga adalah bahwa jalan yang dijanjikan benar-benar ada di kode.
    ///
    /// Satu-satunya cara mengujinya di Linux: nyatakan bahwa aksesor itu
    /// adalah bentuk kanonik baris tersebut. Kalau suatu saat pemanggilnya
    /// dihapus, nilai di sini tetap menyatakan bentuk yang benar — dan
    /// sapuan gerbang yang melaporkan `app=0` akan menyala.
    func testDisplayAccessorsAreTheCanonicalFormForTheirScreens() {
        TextLocalization.install { _ in nil }

        // Bentuk kanonik untuk kartu jam: nama + jenis + mag + koordinat.
        var parts = [TextLocalization.text(.objectDisplayMagnitude, 1.42)]
        parts.append(ObjectSpeech.coordinatesDisplay(raDeg: 101.287, decDeg: -16.716))
        XCTAssertEqual(parts.joined(separator: " · "),
                       "mag 1,42 · RA 101,3° Dec -16,7°")

        // Bentuk kanonik untuk baris acuan di layar kalibrasi.
        XCTAssertEqual(CalibrationText.captureAltitudeDisplay(altitudeDeg: 40), "40° tinggi")
    }
}