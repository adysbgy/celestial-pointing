import XCTest
@testable import PointingKit

/// Baris "judul … nilai" yang **terdengar** sebagai satu pengumuman.
///
/// Alasan uji ini ada, bukan sekadar formalitas: bentuk `row(_:_:)` dipakai
/// di tiga layar dengan kode yang identik, tapi hanya dua yang mengumumkannya.
/// Yang ketiga membiarkan VoiceOver membaca dua elemen tanpa hubungan. Kalau
/// kalimat pengumumannya salah — atau hilang — **tidak ada satu pun layar yang
/// tampak keliru**, karena yang membacanya adalah suara, bukan mata.
final class RowSpeechTests: XCTestCase {

    // MARK: - Satu pengumuman, bukan dua

    /// Judul dan nilai harus jadi **satu** kalimat.
    ///
    /// Tanpa ini VoiceOver mengucapkan "Keadaan" lalu "Terkunci" sebagai dua
    /// item terpisah, dan pada layar dengan belasan baris, nilai yang
    /// diucapkan kedua kehilangan konteks apa yang diukur.
    func testRowLabelJoinsTitleAndValue() {
        let label = RowSpeech.label(title: "Keadaan", value: "Terkunci")
        XCTAssertEqual(label, "Keadaan: Terkunci", label)
    }

    /// Judul kosong tidak boleh menghasilkan pengumuman yang diawali ": ".
    func testEmptyTitleDoesNotProduceADanglingSeparator() {
        let label = RowSpeech.label(title: "", value: "Terkunci")
        XCTAssertFalse(label.hasPrefix(": "), "judul kosong tidak boleh menyisakan pemisah: \(label)")
    }

    // MARK: - Satuan diucapkan sebagai kata

    /// Satuan **harus** berupa kata: "°/dtk" bukan kalimat lisan.
    ///
    /// Ini uji yang paling penting di berkas ini. "0.5°/dtk" terbaca oleh
    /// mata dan tidak terbaca oleh pembaca layar — "/dtk" bukan kata dan "°"
    /// bukan satuan lisan. Kalau ada satu saja simbol yang lolos, baris itu
    /// terdengar seperti deretan karakter.
    func testEverySpokenValueUsesWordsNotSymbols() {
        XCTAssertFalse(RowSpeech.spokenRate(5).contains("°"),
                       "derajat harus berupa kata: \(RowSpeech.spokenRate(5))")
        XCTAssertFalse(RowSpeech.spokenRate(5).contains("/"),
                       "per detik harus berupa kata, bukan '/dtk': \(RowSpeech.spokenRate(5))")
        XCTAssertFalse(RowSpeech.spokenDegrees(41.2).contains("°"),
                       RowSpeech.spokenDegrees(41.2))
        XCTAssertFalse(RowSpeech.spokenError(2.5).contains("°"),
                       RowSpeech.spokenError(2.5))
    }

    /// Laju menyebut satuannya lengkap.
    func testRateIsSpokenWithItsUnit() {
        let spoken = RowSpeech.spokenRate(5)
        XCTAssertTrue(spoken.contains("derajat"), spoken)
        XCTAssertTrue(spoken.contains("per detik"), spoken)
    }

    /// Sudut menyebut satuannya.
    func testDegreesAreSpokenWithTheirUnit() {
        XCTAssertTrue(RowSpeech.spokenDegrees(41.2).contains("derajat"),
                      RowSpeech.spokenDegrees(41.2))
    }

    /// Galat menyebut **apa yang diukur**, bukan hanya angkanya.
    ///
    /// "2.5" tanpa kata "galat" terdengar seperti nilai apa saja.
    func testErrorNamesWhatItMeasures() {
        let spoken = RowSpeech.spokenError(2.5)
        XCTAssertTrue(spoken.hasPrefix("galat"), spoken)
        XCTAssertTrue(spoken.contains("derajat"), spoken)
    }

    // MARK: - Angka tidak dikarang

    /// Laju nol diucapkan sebagai nol, bukan sebagai angka yang hilang.
    ///
    /// Kasus ini sengaja diuji: `String(format: "%.0f", 0)` menghasilkan "0",
    /// tapi pemformatan yang keliru bisa menghasilkan string kosong atau
    /// "-0" — dan "laju minus nol derajat per detik" adalah kalimat yang
    /// membingungkan untuk keadaan "diam".
    func testZeroRateIsSpokenAsZero() {
        let spoken = RowSpeech.spokenRate(0)
        // Presisi satu desimal (mengikuti tampilan) berarti nol tertulis
        // "0.0". Yang diuji adalah sifatnya, bukan penulisannya: angkanya
        // nol, tidak kosong, dan tidak negatif.
        XCTAssertTrue(spoken.hasPrefix("0"), spoken)
        XCTAssertFalse(spoken.isEmpty, spoken)
        XCTAssertFalse(spoken.contains("-"), "nol tidak boleh tampil sebagai negatif: \(spoken)")
        XCTAssertTrue(spoken.contains("derajat per detik"), spoken)
    }

    /// Laju di bawah 1 **tidak boleh** dibulatkan jadi nol.
    ///
    /// Ini cacat nyata yang ditemukan saat menulis `spokenRate`: bentuk
    /// awalnya `%.0f`, jadi tampilan "0.4°/dtk" diucapkan "0 derajat per
    /// detik". Laju pergelangan saat diam memang bernilai di bawah 1 — jadi
    /// angka 0.4 yang berarti "bergerak pelan" terdengar sama dengan "diam".
    func testSubOneRateIsNotRoundedAway() {
        let spoken = RowSpeech.spokenRate(0.4)
        XCTAssertTrue(spoken.contains("0.4"),
                      "laju kecil tidak boleh hilang karena pembulatan: \(spoken)")
        XCTAssertFalse(spoken.hasPrefix("0 "),
                       "0.4 tidak boleh terdengar sebagai nol: \(spoken)")
    }

    /// Baris yang memakai nilai terucap tetap menyebut judulnya.
    func testSpokenRowKeepsItsTitle() {
        let row = RowSpeech.spokenRow(title: "Laju pergelangan",
                                      spokenValue: RowSpeech.spokenRate(5))
        XCTAssertTrue(row.hasPrefix("Laju pergelangan: "), row)
        XCTAssertTrue(row.contains("derajat per detik"), row)
    }

    /// Presisi tinggi dipertahankan, bukan dibulatkan jadi satu desimal.
    ///
    /// Baris teknis menampilkan RA/Dec dengan empat desimal dan dipakai untuk
    /// **membandingkan** dua kolom. Mengucapkan "101.2871" sebagai "101.3"
    /// berarti suara dan layar menyebut angka berbeda untuk nilai yang sama.
    func testHighPrecisionSurvivesSpeech() {
        let spoken = RowSpeech.spokenDegrees(101.2871, precision: 4)
        XCTAssertTrue(spoken.contains("101.2871"),
                      "presisi tampilan harus ikut diucapkan: \(spoken)")
        XCTAssertTrue(spoken.contains("derajat"), spoken)
    }

    /// Presisi apa pun tetap menghasilkan satuan yang utuh — bukan "%f".
    func testPrecisionNeverLeaksAFormatPlaceholder() {
        for precision in 0...4 {
            let spoken = RowSpeech.spokenDegrees(41.23456, precision: precision)
            XCTAssertFalse(spoken.contains("%"),
                           "format yang belum terisi bocor ke suara: \(spoken)")
            XCTAssertTrue(spoken.contains("derajat"), spoken)
        }
    }

    // MARK: - Kata-katanya milik katalog, bukan literal di dalam paket

    /// Terjemahan memasang kata yang menggantikan bawaan.
    ///
    /// Seluruh `RowSpeech` mengembalikan frasa Bahasa Indonesia tanpa melewati
    /// `LocalizedText` sampai unit ini: Aturan 6 memeriksa kunci yang
    /// **dideklarasikan**, dan frasa ini tidak punya kunci sama sekali.
    /// Akibatnya pengguna Bahasa Inggris mendengar "5.0 derajat per detik" dan
    /// "galat 2.5 derajat" tanpa satu pun gerbang merah. Uji ini memasang
    /// terjemahan Inggris untuk seluruh kunci `row.speech.*` dan memastikan
    /// setiap aksesornya membacanya.
    func testEnglishTranslationControlsTheWords() {
        let english: [String: String] = [
            "row.speech.label": "%@: %@",
            "row.speech.degrees": "degrees",
            "row.speech.degreesPerSecond": "degrees per second",
            "row.speech.errorWord": "error",
            "row.speech.error": "%@ %.1f %@",
        ]
        TextLocalization.install { english[$0] }
        defer { TextLocalization.reset() }

        XCTAssertEqual(RowSpeech.label(title: "State", value: "Locked"),
                       "State: Locked")
        XCTAssertEqual(RowSpeech.spokenRate(5), "5.0 degrees per second")
        XCTAssertEqual(RowSpeech.spokenDegrees(41.2), "41.2 degrees")
        XCTAssertEqual(RowSpeech.spokenDegrees(101.2871, precision: 4),
                       "101.2871 degrees")
        XCTAssertEqual(RowSpeech.spokenError(2.5), "error 2.5 degrees")
    }

    /// Kalimat galat memakai template katalog **apa adanya**, bukan template
    /// bawaan yang dikubur di kode.
    ///
    /// Kalau `spokenError` mengabaikan katalog dan memakai `id:` bawaannya,
    /// uji ini merah. Itu bentuk yang benar-benar pernah terjadi di repo ini:
    /// teks yang lahir di paket tanpa melewati `LocalizedText` sama sekali.
    ///
    /// **Kenapa tidak ada uji yang menukar urutan angka ke depan.** Itu
    /// memang keinginan bahasa lain, dan memang **tidak bisa** dilakukan lewat
    /// katalog: memindahkan `%.1f` melewati `%@` mengubah urutan tipe
    /// specifier, dan `%.1f` yang menerima `String` = crash di
    /// CoreFoundation. Aturan 11 menegakkan larangan itu untuk seluruh
    /// katalog. Batas ini nyata dan dicatat, bukan disembunyikan.
    func testErrorSentenceComesFromTheCatalogVerbatim() {
        TextLocalization.install { key in
            key == "row.speech.error" ? "«%@» %.1f [%@]" : nil
        }
        defer { TextLocalization.reset() }

        XCTAssertEqual(RowSpeech.spokenError(2.5), "«galat» 2.5 [derajat]",
                       "template katalog harus dipakai apa adanya")
    }

    /// Judul kosong tidak memanggil format sama sekali.
    ///
    /// Kalau ia melewati format, hasilnya `": Terkunci"` — pemisah yang
    /// menggantung tanpa judul di depannya.
    func testEmptyTitleBypassesTheFormat() {
        TextLocalization.install { _ in "%@" }
        defer { TextLocalization.reset() }

        XCTAssertEqual(RowSpeech.label(title: "", value: "Terkunci"), "Terkunci")
    }
}
