import XCTest
@testable import PointingKit

/// Format angka untuk tampilan: pemisah desimal harus mengikuti bahasa yang
/// sedang dipakai, bukan apa pun yang bawaan di perangkat.
final class NumberFormatTests: XCTestCase {

    /// **Isolasi antar-uji.** `NumberFormat` menyimpan bahasa aktif di satu
    /// proses, jadi uji yang memasangnya bocor ke semua uji berikutnya bila
    /// tidak dilepas. Bocornya tidak muncul sebagai kegagalan yang jujur: ia
    /// muncul sebagai angka yang tiba-tiba memakai koma di berkas lain —
    /// persis kelas kesalahpahaman yang gerbang ini hunts.
    override func setUp() {
        super.setUp()
        NumberFormat.reset()
    }

    override func tearDown() {
        NumberFormat.reset()
        super.tearDown()
    }

    // MARK: - Pemisah desimal

    /// **Titik adalah salah pada layar Bahasa Indonesia.**
    ///
    /// Semua baris angka di kedua app dulu memakai `String(format: "%.1f")`
    /// tanpa `locale:`, jadi pemisah desimal ikut bawaan perangkat — dan
    /// pada perangkat berbahasa Indonesia hasilnya `42.5°`, bukan `42,5°`.
    /// Ini bukan kosmetik: pemisah desimal adalah bagian dari cara membaca
    /// angka, dan `42.5` di locale koma bisa terbaca sebagai `425`.
    func testDecimalSeparatorFollowsTheActiveLanguage() {
        let value = NumberFormat.decimal(42.5, fractionDigits: 1, localeId: "id_ID")
        XCTAssertEqual(value, "42,5",
                       "Bahasa Indonesia memakai koma sebagai pemisah desimal")
    }

    /// Pemisah desimal harus **dibaca dari bahasa aktif**, bukan dari lokasi
    /// perangkat — supaya angka yang sama tampil sama di semua orang yang
    /// membaca app ini dengan bahasa yang sama.
    func testSameLanguageProducesTheSameSeparator() {
        let a = NumberFormat.decimal(42.5, fractionDigits: 1, localeId: "id_ID")
        let b = NumberFormat.decimal(42.5, fractionDigits: 1, localeId: "id_ID")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, NumberFormat.decimal(42.5, fractionDigits: 1, localeId: "en_US"),
                          "tanda baca desimal memang berbeda antar bahasa")
    }

    /// Bahasa yang tidak dikenal tidak boleh membuat format kosong atau gagal.
    ///
    /// Format yang gagal berarti baris angkanya hilang — lebih buruk daripada
    /// pemisah yang salah.
    func testUnknownLocaleFallsBackToSomethingReadable() {
        let value = NumberFormat.decimal(42.5, fractionDigits: 1, localeId: "zz_ZZ")
        XCTAssertFalse(value.isEmpty)
        XCTAssertTrue(value.contains("4"))
    }

    /// Pembulatan harus tetap dihormati: inilah yang membuat permintaan nol
    /// digit dan satu digit berbeda artinya.
    func testFractionDigitsAreRespected() {
        let whole = NumberFormat.decimal(42.56, fractionDigits: 0, localeId: "id_ID")
        XCTAssertFalse(whole.contains(","), "nol digit desimal tidak boleh menambah koma")
        let one = NumberFormat.decimal(42.56, fractionDigits: 1, localeId: "id_ID")
        XCTAssertTrue(one.contains(","))
    }

    /// Nilainya harus persis seperti yang dimasukkan — pembulatan hanya
    /// dipegang oleh `fractionDigits`.
    func testValueIsNotOtherwiseDistorted() {
        XCTAssertEqual(NumberFormat.decimal(-6.2, fractionDigits: 1, localeId: "id_ID"), "-6,2")
        XCTAssertEqual(NumberFormat.decimal(0, fractionDigits: 0, localeId: "id_ID"), "0")
    }

    /// Derajat dan persen memakai helper yang sama, karena keduanya punya
    /// aturan pemisah yang sama.
    ///
    /// `0.624` dipilih, bukan `0.625`: `String(format:)` memakai pembulatan
    /// bankir, jadi `0.625` menjadi `62`, bukan `63`. Itu perilaku yang sama
    /// dengan `%.0f` yang sudah dipakai app sebelum helper ini ada, jadi
    /// sengaja **tidak** dibetulkan di sini. Mengganti algoritme pembulatan
    /// adalah keputusan terpisah yang harus berdiri sendiri, bukan bawaan
    /// diam-diam dari perbaikan pemisah desimal.
    func testDegreesAndPercentShareTheSeparatorRule() {
        let degrees = NumberFormat.degrees(42.5, fractionDigits: 1, localeId: "id_ID")
        XCTAssertEqual(degrees, "42,5°")
        let percent = NumberFormat.percent(0.624, fractionDigits: 0, localeId: "id_ID")
        XCTAssertEqual(percent, "62%")
        // Pecahan yang tidak bulat tetap memakai koma.
        let fractional = NumberFormat.percent(0.5, fractionDigits: 1, localeId: "id_ID")
        XCTAssertEqual(fractional, "50,0%")
    }

    // MARK: - Bahasa yang belum terpasang

    /// Tanpa bridge, Bahasa Indonesia adalah bahasa UI app ini — jadi bawaan
    /// **wajib** memakai koma. Bridge yang belum terpasang bukan alasan untuk
    /// menampilkan angka dalam bahasa yang salah untuk pembaca app ini, dan
    /// Linux tidak punya `.lproj` sama sekali, jadi setiap uji tanpa bridge
    /// melewati nilai bawaan ini.
    func testDefaultLanguageIsIndonesianNotTheProcessLocale() {
        XCTAssertEqual(NumberFormat.activeLocaleId, "id_ID")
        XCTAssertEqual(NumberFormat.decimal(42.5, fractionDigits: 1), "42,5",
                       "bawaan harus Bahasa Indonesia, bukan locale proses")
    }

    // MARK: - Bridge: jalur yang benar-benar jalan di perangkat

    /// **Ini jalur yang dipakai app.** Semua uji lain menyebut `localeId:`
    /// secara eksplisit, jadi tanpa uji ini tidak ada satu pun yang
    /// menjalankan jalur yang benar-benar berjalan di perangkat: bahasa aktif
    /// yang dipasang bridge dari `Locale.preferredLanguages`.
    func testInstalledLanguageIsTheOneUsedByDefault() {
        NumberFormat.install(localeId: "en_US")
        XCTAssertEqual(NumberFormat.activeLocaleId, "en_US")
        XCTAssertEqual(NumberFormat.decimal(42.5, fractionDigits: 1), "42.5",
                       "bridge yang terpasang harus jadi sumber bahasa")

        NumberFormat.install(localeId: "id_ID")
        XCTAssertEqual(NumberFormat.degrees(42.5), "42,5°")
    }

    /// `reset()` benar-benar melepas bahasa — kalau tidak, satu uji yang
    /// memasang `en_US` akan membuat semua uji berikutnya mengukur
    /// Bahasa Inggris, dan suite tetap hijau.
    func testResetReleasesTheInstalledLanguage() {
        NumberFormat.install(localeId: "en_US")
        NumberFormat.reset()
        XCTAssertEqual(NumberFormat.activeLocaleId, NumberFormat.defaultLocaleId)
    }

    /// Bahasa yang dipasang **ikut mengunci** pemisah, bukan cuma identifier
    /// yang tersimpan. Tanpa ini, `install` bisa jujur menyimpan `en_US` dan
    /// formatnya tetap memakai locale proses — persis bentuk "hijau yang tidak
    /// hijau" yang repo ini berulang-ulang hunted.
    func testInstalledLanguageActuallyChangesTheSeparator() {
        NumberFormat.install(localeId: "id_ID")
        let indonesian = NumberFormat.decimal(42.5, fractionDigits: 1)
        NumberFormat.install(localeId: "en_US")
        let english = NumberFormat.decimal(42.5, fractionDigits: 1)
        XCTAssertNotEqual(indonesian, english,
                          "bahasa terpasang tidak boleh jadi hiasan pada properti")
        XCTAssertEqual(english, "42.5")
    }
}